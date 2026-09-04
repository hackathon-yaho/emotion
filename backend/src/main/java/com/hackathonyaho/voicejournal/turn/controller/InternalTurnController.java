package com.hackathonyaho.voicejournal.turn.controller;

import com.hackathonyaho.voicejournal.turn.dto.request.TurnIngestRequest;
import com.hackathonyaho.voicejournal.turn.service.TurnService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/**
 * AI서버 전용 (계약 §3-2). 인증은 {@code InternalAuthFilter}가 본다.
 *
 * <p><b>fire-and-forget이다.</b> 무거운 처리를 여기 넣지 않는다 — 응답이 느려지면
 * AI서버의 대화 응답 경로에 영향이 간다. baseline 재계산 같은 것은 세션 종료 시점에 한다.
 */
@RestController
@RequestMapping("/internal/turns")
@RequiredArgsConstructor
public class InternalTurnController {

    private final TurnService turnService;

    /** <b>202다.</b> 처리를 기다리게 하지 않는다. 중복도 202로 조용히 넘긴다. */
    @PostMapping
    @ResponseStatus(HttpStatus.ACCEPTED)
    public ResponseEntity<Void> ingest(@Valid @RequestBody TurnIngestRequest request) {
        turnService.ingest(request);
        return ResponseEntity.accepted().build();
    }
}
