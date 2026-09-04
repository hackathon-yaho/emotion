package com.hackathonyaho.voicejournal.session.controller;

import com.hackathonyaho.voicejournal.auth.security.ProfileContext;
import com.hackathonyaho.voicejournal.session.dto.request.SessionEndRequest;
import com.hackathonyaho.voicejournal.session.dto.response.SessionEndResponse;
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

    /** 계약 §2-4. 요청 본문 없음. */
    @PostMapping("/start")
    public ResponseEntity<SessionStartResponse> start() {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(sessionService.start(ProfileContext.require()));
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

    /** 계약 §2-5-1 (P1). */
    @PostMapping("/{sessionId}/resume")
    public ResponseEntity<SessionResumeResponse> resume(@PathVariable UUID sessionId) {
        return ResponseEntity.ok(sessionService.resume(ProfileContext.require(), sessionId));
    }
}
