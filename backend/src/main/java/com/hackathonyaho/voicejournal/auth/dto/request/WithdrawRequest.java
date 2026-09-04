package com.hackathonyaho.voicejournal.auth.dto.request;

/**
 * 계약 §2-3 (v1.6). <b>선택 본문</b> — 카카오 연결 해제(unlink)에만 쓴다.
 *
 * <p>없어도 탈퇴는 성립하고 응답은 똑같이 204다. 리프레시 토큰을 보관하지 않기로 했기
 * 때문에(모든 사용자의 2개월짜리 카카오 자격증명을 들고 있게 된다), 탈퇴 시점에 앱이
 * 인가를 한 번 더 통과해 코드를 가져온다.
 */
public record WithdrawRequest(String kakaoAuthCode, String redirectUri) {

    public boolean canUnlink() {
        return kakaoAuthCode != null && !kakaoAuthCode.isBlank()
                && redirectUri != null && !redirectUri.isBlank();
    }
}
