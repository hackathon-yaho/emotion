package com.hackathonyaho.voicejournal.auth.service;

import com.hackathonyaho.voicejournal.auth.dto.response.AuthResponse;
import com.hackathonyaho.voicejournal.auth.dto.response.MeResponse;
import com.hackathonyaho.voicejournal.auth.entity.Account;
import com.hackathonyaho.voicejournal.auth.entity.AccountProfile;
import com.hackathonyaho.voicejournal.auth.entity.Profile;
import com.hackathonyaho.voicejournal.auth.entity.UserBaseline;
import com.hackathonyaho.voicejournal.auth.repository.AccountProfileRepository;
import com.hackathonyaho.voicejournal.auth.repository.AccountRepository;
import com.hackathonyaho.voicejournal.auth.repository.ProfileRepository;
import com.hackathonyaho.voicejournal.auth.repository.UserBaselineRepository;
import com.hackathonyaho.voicejournal.auth.security.JwtProvider;
import com.hackathonyaho.voicejournal.common.global.ErrorCode;
import com.hackathonyaho.voicejournal.common.global.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

/** F1-01 로그인 · F1-02 세션 유지. 서비스는 클래스 하나로 둔다 (인터페이스+Impl 없음). */
@Service
@RequiredArgsConstructor
public class AuthService {

    private final KakaoOAuthService kakaoOAuthService;
    private final JwtProvider jwtProvider;
    private final AccountRepository accountRepository;
    private final ProfileRepository profileRepository;
    private final AccountProfileRepository accountProfileRepository;
    private final UserBaselineRepository userBaselineRepository;

    /**
     * 재로그인 시 <b>동일한 profileId</b>가 나와야 한다 (TC-01) — 기존 데이터가
     * 그대로 조회되는 근거다. kakaoId로 account를 찾아 연결자를 따라간다.
     */
    @Transactional
    public AuthResponse loginWithKakao(String kakaoAccessToken) {
        String kakaoId = kakaoOAuthService.verifyAndGetKakaoId(kakaoAccessToken);

        var existing = accountRepository.findByKakaoId(kakaoId);
        boolean isNewUser = existing.isEmpty();

        UUID profileId = existing
                .map(account -> accountProfileRepository.findByAccountId(account.getId())
                        .orElseThrow(() -> new BusinessException(
                                ErrorCode.INTERNAL_ERROR, "account without profile link"))
                        .getProfileId())
                .orElseGet(() -> createNewUser(kakaoId));

        JwtProvider.Issued issued = jwtProvider.issue(profileId);
        return new AuthResponse(issued.token(), issued.expiresAt(), profileId, isNewUser);
    }

    /**
     * account + profile + account_profile + user_baseline을 한 트랜잭션에서 만든다.
     *
     * <p>baseline을 여기서 같이 만드는 이유는 {@code GET /api/me}와 F3-04가
     * 이 행이 있다고 가정하고 읽기 때문이다 — 없으면 세션 시작마다 분기가 는다.
     */
    private UUID createNewUser(String kakaoId) {
        Account account = accountRepository.save(new Account(kakaoId));
        Profile profile = profileRepository.save(Profile.create());
        accountProfileRepository.save(new AccountProfile(account.getId(), profile.getId()));
        userBaselineRepository.save(new UserBaseline(profile.getId()));
        return profile.getId();
    }

    @Transactional(readOnly = true)
    public MeResponse me(UUID profileId) {
        Profile profile = profileRepository.findById(profileId)
                .orElseThrow(() -> new BusinessException(ErrorCode.UNAUTHORIZED, "profile not found"));

        UserBaseline baseline = userBaselineRepository.findById(profileId)
                .orElseGet(() -> new UserBaseline(profileId));

        return new MeResponse(
                profile.getId(),
                profile.getCreatedAt(),
                baseline.getSessionCount(),
                baseline.isPersonalThresholdReady() ? "personal" : "fixed",
                profile.isDemoMode(),
                // Phase 2에서 채운다. 그때까지 앱은 항상 "이어할 대화 없음"으로 본다.
                null);
    }
}
