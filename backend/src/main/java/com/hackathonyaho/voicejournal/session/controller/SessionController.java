package com.hackathonyaho.voicejournal.session.controller;

import com.hackathonyaho.voicejournal.auth.security.ProfileContext;
import com.hackathonyaho.voicejournal.session.dto.request.ChatGroupRequest;
import com.hackathonyaho.voicejournal.session.dto.request.SessionEndRequest;
import com.hackathonyaho.voicejournal.session.dto.response.SessionEndResponse;
import com.hackathonyaho.voicejournal.session.dto.response.SessionQueueResponse;
import com.hackathonyaho.voicejournal.session.dto.response.SessionResumeResponse;
import com.hackathonyaho.voicejournal.session.dto.response.SessionStartResponse;
import com.hackathonyaho.voicejournal.session.service.SessionService;
import com.hackathonyaho.voicejournal.turn.dto.response.LiveSignalResponse;
import com.hackathonyaho.voicejournal.turn.service.TurnService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

/** 응답 스키마는 계약 §2-4·§2-5·§2-5-1이 단일 출처다. */
@RestController
@RequestMapping("/api/session")
@RequiredArgsConstructor
public class SessionController {

    private final SessionService sessionService;
    private final TurnService turnService;

    /**
     * 계약 §2-4. 요청 본문 없음.
     *
     * <p><b>정원이 찼으면 201이 아니라 202 + 대기 순번</b>이다(§2-14). 큐가 꺼져 있으면
     * 202가 나갈 일이 없다 — 앱은 상태 코드로 갈라 보면 된다.
     */
    @PostMapping("/start")
    public ResponseEntity<?> start() {
        SessionService.StartResult result = sessionService.startOrEnqueue(ProfileContext.require());
        return result.queued() != null
                ? ResponseEntity.status(HttpStatus.ACCEPTED).body(result.queued())
                : ResponseEntity.status(HttpStatus.CREATED).body(result.session());
    }

    /** 계약 §2-14. <b>position이 0인 응답에 세션이 실려 온다 — 그게 입장권이다.</b> */
    @GetMapping("/queue/{ticketId}")
    public ResponseEntity<SessionQueueResponse> queue(@PathVariable UUID ticketId) {
        return ResponseEntity.ok(sessionService.pollQueue(ProfileContext.require(), ticketId));
    }

    /** 계약 §2-14. 사용자가 기다리기를 그만둔다. 없는 티켓이어도 204다. */
    @DeleteMapping("/queue/{ticketId}")
    public ResponseEntity<Void> leaveQueue(@PathVariable UUID ticketId) {
        sessionService.leaveQueue(ProfileContext.require(), ticketId);
        return ResponseEntity.noContent().build();
    }

    /** 계약 §2-5. */
    @PostMapping("/{sessionId}/end")
    public ResponseEntity<SessionEndResponse> end(@PathVariable UUID sessionId,
                                                  @Valid @RequestBody(required = false) SessionEndRequest request) {
        String reason = request == null ? "user_end" : request.endReasonOrDefault();
        return ResponseEntity.ok(sessionService.end(ProfileContext.require(), sessionId, reason));
    }

    /**
     * 계약 §2-13. <b>S02에서만</b> {@code livePollIntervalSec} 간격으로 폴링한다.
     *
     * <p>새 계산·새 저장이 없다 — {@code /internal/turns}로 이미 받은 값을 되돌려줄 뿐이다.
     */
    @GetMapping("/{sessionId}/live")
    public ResponseEntity<LiveSignalResponse> live(@PathVariable UUID sessionId,
                                                   @RequestParam(required = false) Integer sinceTurnIndex) {
        return ResponseEntity.ok(turnService.live(ProfileContext.require(), sessionId, sinceTurnIndex));
    }

    /** 계약 §2-5-2. 멱등 — 같은 값이 몇 번 와도 204다. */
    @PostMapping("/{sessionId}/chat-group")
    public ResponseEntity<Void> chatGroup(@PathVariable UUID sessionId,
                                          @Valid @RequestBody ChatGroupRequest request) {
        sessionService.attachChatGroup(ProfileContext.require(), sessionId, request.chatGroupId());
        return ResponseEntity.noContent().build();
    }

    /** 계약 §2-5-1 (P1). */
    @PostMapping("/{sessionId}/resume")
    public ResponseEntity<SessionResumeResponse> resume(@PathVariable UUID sessionId) {
        return ResponseEntity.ok(sessionService.resume(ProfileContext.require(), sessionId));
    }
}
