package com.hackathonyaho.voicejournal.auth.service;

import com.hackathonyaho.voicejournal.common.global.ErrorCode;
import com.hackathonyaho.voicejournal.common.global.exception.BusinessException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestClient;

import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * 카카오 인가 코드를 토큰으로 교환하고 회원번호를 가져온다 (F1-01 ③, 계약 §2-1 v1.6).
 *
 * <p><b>왜 액세스 토큰을 받지 않는가</b> — 배포가 웹인데 웹에서는 앱이 토큰을 손에 쥘
 * 수 없다. `kakao_flutter_sdk` 2.0.1의 웹 구현은 로그인 API가 전부 {@code notSupported}를
 * 던지고 {@code authorize()}는 페이지를 리다이렉트한 뒤 빈 문자열을 돌려준다(앱 확인,
 * 2026-09-05). 그래서 코드를 토큰으로 바꾸는 것은 서버 몫이다.
 *
 * <p><b>덤으로 안전해진다</b> — REST 키와 클라이언트 시크릿이 서버에만 남고, 우리 키로
 * 교환한 토큰은 <b>정의상 우리 앱 것</b>이라 예전의 {@code app_id} 대조가 필요 없어진다.
 */
@Slf4j
@Service
public class KakaoOAuthService {

    private static final String TOKEN_URL = "https://kauth.kakao.com/oauth/token";
    private static final String USER_ME_URL = "https://kapi.kakao.com/v2/user/me";
    private static final String UNLINK_URL = "https://kapi.kakao.com/v1/user/unlink";

    private final RestClient client;
    private final String restApiKey;
    private final String clientSecret;
    private final Set<String> allowedRedirectUris;

    public KakaoOAuthService(@Value("${app.kakao.rest-api-key}") String restApiKey,
                             @Value("${app.kakao.client-secret:}") String clientSecret,
                             @Value("${app.kakao.redirect-uris}") List<String> redirectUris) {
        this.client = RestClient.create();
        this.restApiKey = restApiKey;
        this.clientSecret = clientSecret;
        this.allowedRedirectUris = Set.copyOf(redirectUris);
    }

    /** 인가 코드 → 액세스 토큰 → 회원번호. 로그인 경로가 쓴다. */
    public String exchangeCodeForKakaoId(String authCode, String redirectUri) {
        return fetchKakaoId(exchangeCode(authCode, redirectUri));
    }

    /**
     * 탈퇴 시 카카오 연결 해제 (F10-03). <b>어드민 키를 쓰지 않는다</b> — 사용자
     * 액세스 토큰으로 자기 계정만 끊는다. 어드민 키 방식은 {@code target_id}로 남을
     * 끊는 경로라 서버에 두면 모든 사용자를 조작할 수 있게 된다.
     *
     * <p><b>실패해도 예외를 던지지 않는다.</b> 우리 데이터는 이미 지워진 뒤이므로
     * 탈퇴는 성립한다 — 여기서 500을 올리면 사용자는 탈퇴가 실패한 것으로 본다.
     */
    public void unlink(String authCode, String redirectUri) {
        try {
            String accessToken = exchangeCode(authCode, redirectUri);
            client.post()
                    .uri(UNLINK_URL)
                    .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
                    .retrieve()
                    .toBodilessEntity();
        } catch (Exception e) {
            log.warn("kakao unlink failed ({}) — 데이터 삭제는 이미 끝났다", e.getClass().getSimpleName());
        }
    }

    /**
     * <b>등록하지 않은 주소를 그대로 넘기지 않는다.</b> 이 값은 카카오에 그대로 전달되는데,
     * 열어두면 공격자가 자기 주소로 인가를 받아 그 코드를 우리 서버로 교환시킬 수 있다.
     */
    private String exchangeCode(String authCode, String redirectUri) {
        if (!allowedRedirectUris.contains(redirectUri)) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "redirectUri is not registered");
        }

        MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
        form.add("grant_type", "authorization_code");
        form.add("client_id", restApiKey);
        form.add("redirect_uri", redirectUri);
        form.add("code", authCode);
        if (!clientSecret.isBlank()) {
            form.add("client_secret", clientSecret);
        }

        Map<?, ?> body = call(() -> client.post()
                .uri(TOKEN_URL)
                .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .body(form)
                .retrieve()
                .body(Map.class), "oauth/token");

        Object accessToken = body.get("access_token");
        if (accessToken == null) {
            throw new BusinessException(ErrorCode.KAKAO_VERIFY_FAILED, "no access_token in token response");
        }
        return String.valueOf(accessToken);
    }

    /** 회원번호. 같은 사람이라도 앱마다 다른 값이다. */
    private String fetchKakaoId(String accessToken) {
        Map<?, ?> me = call(() -> client.get()
                .uri(USER_ME_URL)
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
                .retrieve()
                .body(Map.class), "user/me");

        Object id = me.get("id");
        if (id == null) {
            throw new BusinessException(ErrorCode.KAKAO_VERIFY_FAILED, "user/me has no id");
        }
        return String.valueOf(id);
    }

    private Map<?, ?> call(java.util.function.Supplier<Map> request, String label) {
        try {
            Map<?, ?> body = request.get();
            if (body == null) {
                throw new BusinessException(ErrorCode.KAKAO_VERIFY_FAILED, "empty body from " + label);
            }
            return body;
        } catch (BusinessException e) {
            throw e;
        } catch (Exception e) {
            // 인가 코드·토큰·키를 로그에 남기지 않는다.
            log.warn("kakao call failed: {} ({})", label, e.getClass().getSimpleName());
            throw new BusinessException(ErrorCode.KAKAO_VERIFY_FAILED, "kakao call failed: " + label);
        }
    }
}
