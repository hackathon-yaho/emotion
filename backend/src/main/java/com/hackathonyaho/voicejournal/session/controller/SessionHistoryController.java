package com.hackathonyaho.voicejournal.session.controller;

import com.hackathonyaho.voicejournal.auth.security.ProfileContext;
import com.hackathonyaho.voicejournal.common.global.Paging;
import com.hackathonyaho.voicejournal.session.dto.response.SessionDetailResponse;
import com.hackathonyaho.voicejournal.session.dto.response.SessionListResponse;
import com.hackathonyaho.voicejournal.session.service.SessionHistoryService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

/**
 * 대화 기록 (F9-04·05). 응답 스키마는 계약 §2-9·§2-10이 단일 출처다.
 *
 * <p>경로가 {@code /api/sessions}(복수)로 {@code /api/session}(단수, 대화 제어)과
 * 갈린다 — 계약 그대로다.
 */
@RestController
@RequestMapping("/api/sessions")
@RequiredArgsConstructor
public class SessionHistoryController {

    private final SessionHistoryService sessionHistoryService;

    @GetMapping
    public ResponseEntity<SessionListResponse> list(@RequestParam(required = false) Integer limit,
                                                    @RequestParam(required = false) Integer offset) {
        return ResponseEntity.ok(
                sessionHistoryService.list(ProfileContext.require(), Paging.of(limit, offset)));
    }

    @GetMapping("/{sessionId}")
    public ResponseEntity<SessionDetailResponse> detail(@PathVariable UUID sessionId) {
        return ResponseEntity.ok(sessionHistoryService.detail(ProfileContext.require(), sessionId));
    }
}
