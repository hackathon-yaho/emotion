package com.hackathonyaho.voicejournal;

import com.hackathonyaho.voicejournal.auth.entity.Account;
import com.hackathonyaho.voicejournal.auth.entity.AccountProfile;
import com.hackathonyaho.voicejournal.auth.entity.Profile;
import com.hackathonyaho.voicejournal.auth.entity.UserBaseline;
import com.hackathonyaho.voicejournal.auth.repository.AccountProfileRepository;
import com.hackathonyaho.voicejournal.auth.repository.AccountRepository;
import com.hackathonyaho.voicejournal.auth.repository.ProfileRepository;
import com.hackathonyaho.voicejournal.auth.repository.UserBaselineRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/** 계약 §2-1-1 — 꺼진 기본값. 배포본이 대부분의 시간 도는 쪽이다. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class DevLoginDisabledTest {

    @Autowired MockMvc mvc;
    @Autowired AccountRepository accountRepository;
    @Autowired ProfileRepository profileRepository;
    @Autowired AccountProfileRepository accountProfileRepository;
    @Autowired UserBaselineRepository baselineRepository;

    @Test
    @DisplayName("꺼져 있으면 404 — 앱은 「아직 준비되지 않았다」로 보여준다")
    void disabledIs404() throws Exception {
        mvc.perform(post("/api/auth/dev")).andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("파기는 연결 없는 프로필만 지우고 카카오 사용자는 남긴다")
    void purgeKeepsKakaoUsers() throws Exception {
        UUID guest = profileRepository.save(Profile.create()).getId();
        baselineRepository.save(new UserBaseline(guest));

        UUID member = profileRepository.save(Profile.create()).getId();
        baselineRepository.save(new UserBaseline(member));
        Account account = accountRepository.save(new Account("kakao-purge-test"));
        accountProfileRepository.save(new AccountProfile(account.getId(), member));
        profileRepository.flush();

        mvc.perform(post("/internal/dev-profiles/purge").header("X-Internal-Secret", "test-internal-secret"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.deleted").isNumber());

        assertThat(profileRepository.existsById(guest)).isFalse();
        assertThat(profileRepository.existsById(member)).isTrue();
    }

    @Test
    @DisplayName("파기는 내부 시크릿 없이는 401")
    void purgeNeedsSecret() throws Exception {
        mvc.perform(post("/internal/dev-profiles/purge")).andExpect(status().isUnauthorized());
    }
}
