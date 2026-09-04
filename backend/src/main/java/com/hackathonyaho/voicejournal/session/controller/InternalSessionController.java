package com.hackathonyaho.voicejournal.session.controller;

import com.hackathonyaho.voicejournal.session.dto.response.InternalSessionResponse;
import com.hackathonyaho.voicejournal.session.service.SessionService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

/**
 * AI서버 전용 (계약 §3-4). 인증은 {@code X-Internal-Secret} 하나이며
 * {@code InternalAuthFilter}가 먼저 본다 — JWT는 오지 않는다.
 *
 * <p><b>이 응답이 늦거나 죽으면 새 대화가 시작되지 않는다.</b> AI서버가 조회 실패를
 * fail-closed로 처리해 Hume에 401을 돌려주기 때문이다(계약 §4).
 */
@RestController
@RequestMapping("/internal/sessions")
@RequiredArgsConstructor
public class InternalSessionController {

    private final SessionService sessionService;

    @GetMapping("/{sessionId}")
    public ResponseEntity<InternalSessionResponse> context(@PathVariable UUID sessionId) {
        return ResponseEntity.ok(sessionService.context(sessionId));
    }
}
