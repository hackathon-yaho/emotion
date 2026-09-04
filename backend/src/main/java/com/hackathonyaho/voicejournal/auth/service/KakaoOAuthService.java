package com.hackathonyaho.voicejournal.auth.service;

import com.hackathonyaho.voicejournal.common.global.ErrorCode;
import com.hackathonyaho.voicejournal.common.global.exception.BusinessException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.Map;

/**
 * 카카오 액세스 토큰 검증 (F1-01 ③).
 *
 * <p>앱이 카카오 SDK로 로그인해 받은 토큰을 우리가 확인한다. 리다이렉트·쿠키
 * 방식을 쓰지 않는 이유는 앱(GitHub Pages)과 백엔드(Render)의 도메인이 완전히
 * 달라 쿠키가 서드파티가 되기 때문이다.
 */
@Slf4j
@Service
public class KakaoOAuthService {

    private static final String KAPI = "https://kapi.kakao.com";

    private final RestClient client;
    private final long appId;

    public KakaoOAuthService(@Value("${app.kakao.app-id}") long appId) {
        this.appId = appId;
        this.client = RestClient.builder().baseUrl(KAPI).build();
    }

    /**
     * 토큰을 검증하고 <b>카카오 회원번호</b>를 돌려준다.
     *
     * <p>두 단계다. ①을 빼면 아무 카카오 앱에서 발급된 토큰이든 통과한다 —
     * {@code /v2/user/me}는 "이 토큰이 어느 앱 것인지"를 묻지 않고 그냥 사용자
     * 정보를 돌려주고, 카카오 앱은 누구나 만들 수 있다. <b>빠뜨려도 정상 로그인은
     * 멀쩡히 동작해서 테스트로는 안 잡힌다.</b>
     */
    public String verifyAndGetKakaoId(String accessToken) {
        verifyTokenBelongsToOurApp(accessToken);
        return fetchKakaoId(accessToken);
    }

    /** ① 이 토큰이 우리 앱에서 발급된 것인가. */
    private void verifyTokenBelongsToOurApp(String accessToken) {
        Map<?, ?> info = call(accessToken, "/v1/user/access_token_info");
        Object tokenAppId = info.get("app_id");
        if (tokenAppId == null) {
            throw new BusinessException(ErrorCode.KAKAO_VERIFY_FAILED, "access_token_info has no app_id");
        }
        if (((Number) tokenAppId).longValue() != appId) {
            // 어느 앱인지는 남기지 않는다 — 공격자에게 주는 정보다.
            throw new BusinessException(ErrorCode.KAKAO_VERIFY_FAILED, "token issued for another kakao app");
        }
    }

    /** ② 회원번호. 같은 사람이라도 앱마다 다른 값이다. */
    private String fetchKakaoId(String accessToken) {
        Map<?, ?> me = call(accessToken, "/v2/user/me");
        Object id = me.get("id");
        if (id == null) {
            throw new BusinessException(ErrorCode.KAKAO_VERIFY_FAILED, "user/me has no id");
        }
        return String.valueOf(id);
    }

    private Map<?, ?> call(String accessToken, String path) {
        try {
            Map<?, ?> body = client.get()
                    .uri(path)
                    .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
                    .retrieve()
                    .body(Map.class);
            if (body == null) {
                throw new BusinessException(ErrorCode.KAKAO_VERIFY_FAILED, "empty body from " + path);
            }
            return body;
        } catch (BusinessException e) {
            throw e;
        } catch (Exception e) {
            // 토큰 값을 로그에 남기지 않는다.
            log.warn("kakao call failed: {} ({})", path, e.getClass().getSimpleName());
            throw new BusinessException(ErrorCode.KAKAO_VERIFY_FAILED, "kakao call failed: " + path);
        }
    }
}
