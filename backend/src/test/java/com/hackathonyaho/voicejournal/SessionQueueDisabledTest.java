package com.hackathonyaho.voicejournal;

import com.hackathonyaho.voicejournal.auth.entity.Profile;
import com.hackathonyaho.voicejournal.auth.entity.UserBaseline;
import com.hackathonyaho.voicejournal.auth.repository.ProfileRepository;
import com.hackathonyaho.voicejournal.auth.repository.UserBaselineRepository;
import com.hackathonyaho.voicejournal.auth.security.JwtProvider;
import com.hackathonyaho.voicejournal.session.service.HumeChatClient;
import com.hackathonyaho.voicejournal.session.service.HumeTokenService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * <b>기본값(꺼짐)이 큐 도입 전과 같은지</b>를 못 박는다 (계약 §2-14).
 *
 * <p>꺼진 상태가 기본이라 이 경로가 실서비스의 정상 경로다. 켜진 경로만 검증하면
 * <b>평소에 도는 쪽이 검증되지 않는다.</b>
 */
@SpringBootTest(properties = "app.session.queue.enabled=false")
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class SessionQueueDisabledTest {

    @Autowired MockMvc mvc;
    @Autowired JwtProvider jwtProvider;
    @Autowired ProfileRepository profileRepository;
    @Autowired UserBaselineRepository baselineRepository;

    @MockitoBean HumeTokenService humeTokenService;
    @MockitoBean HumeChatClient humeChatClient;

    @Test
    @DisplayName("큐가 꺼져 있으면 Hume에 묻지도 않고 201이다")
    void disabledNeverAsksHume() throws Exception {
        given(humeTokenService.issue())
                .willReturn(new HumeTokenService.Token("hume_at_test", Instant.now().plusSeconds(1800)));
        UUID profileId = profileRepository.save(Profile.create()).getId();
        baselineRepository.save(new UserBaseline(profileId));

        mvc.perform(post("/api/session/start")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + jwtProvider.issue(profileId).token()))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.sessionId").exists());

        // 정원 조회는 요금·지연이 붙는 외부 호출이다. 꺼져 있으면 한 번도 안 나가야 한다.
        verify(humeChatClient, never()).activeCount(anyInt());
    }
}
