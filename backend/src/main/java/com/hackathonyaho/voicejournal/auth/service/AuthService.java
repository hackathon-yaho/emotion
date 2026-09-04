package com.hackathonyaho.voicejournal.auth.service;

import com.hackathonyaho.voicejournal.auth.dto.response.AuthResponse;
import com.hackathonyaho.voicejournal.auth.dto.response.MeResponse;
import com.hackathonyaho.voicejournal.auth.entity.Account;
import com.hackathonyaho.voicejournal.auth.entity.AccountProfile;
import com.hackathonyaho.voicejournal.auth.entity.Profile;
import com.hackathonyaho.voicejournal.auth.entity.UserBaseline;
import com.hackathonyaho.voicejournal.auth.dto.request.WithdrawRequest;
import com.hackathonyaho.voicejournal.auth.repository.AccountDeletionRepository;
import com.hackathonyaho.voicejournal.auth.repository.AccountProfileRepository;
import com.hackathonyaho.voicejournal.auth.repository.AccountRepository;
import com.hackathonyaho.voicejournal.auth.repository.ProfileRepository;
import com.hackathonyaho.voicejournal.auth.repository.UserBaselineRepository;
import com.hackathonyaho.voicejournal.auth.security.JwtProvider;
import com.hackathonyaho.voicejournal.session.service.SessionService;
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
    private final SessionService sessionService;
    private final AccountDeletionRepository accountDeletionRepository;

    /**
     * 재로그인 시 <b>동일한 profileId</b>가 나와야 한다 (TC-01) — 기존 데이터가
     * 그대로 조회되는 근거다. kakaoId로 account를 찾아 연결자를 따라간다.
     */
    @Transactional
    public AuthResponse loginWithKakao(String kakaoAuthCode, String redirectUri) {
        String kakaoId = kakaoOAuthService.exchangeCodeForKakaoId(kakaoAuthCode, redirectUri);

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

    /**
     * 탈퇴 (F10-03 · F1-04). <b>유예 기간을 두지 않는다</b> — 즉시 전량 삭제가 신뢰의
     * 핵심이다(FR-003).
     *
     * <p><b>이 메서드에 트랜잭션을 걸지 않는다.</b> 삭제는 안쪽에서 커밋되고 unlink는
     * 그 <b>뒤에</b> 일어나야 한다. 한 트랜잭션에 묶으면 unlink가 성공한 뒤 커밋이
     * 실패하는 경로가 생겨 <b>"카카오는 끊겼는데 데이터는 남은" 상태</b>가 만들어진다 —
     * 사용자 데이터가 먼저 사라져야 한다.
     *
     * <p>unlink 실패는 오류로 올리지 않는다. 우리 데이터는 이미 없으므로 탈퇴는 성립한다.
     */
    public void withdraw(UUID profileId, WithdrawRequest request) {
        accountDeletionRepository.deleteAllFor(profileId);

        if (request != null && request.canUnlink()) {
            kakaoOAuthService.unlink(request.kakaoAuthCode(), request.redirectUri());
        }
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
                // 비정상 중단으로 열려 있는 세션. 앱은 이게 있으면 "이어서 이야기할까요?"를 띄운다.
                sessionService.openSession(profileId));
    }
}
