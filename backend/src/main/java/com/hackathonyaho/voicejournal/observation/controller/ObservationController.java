package com.hackathonyaho.voicejournal.observation.controller;

import com.hackathonyaho.voicejournal.auth.security.ProfileContext;
import com.hackathonyaho.voicejournal.common.global.Paging;
import com.hackathonyaho.voicejournal.observation.dto.request.FeedbackRequest;
import com.hackathonyaho.voicejournal.observation.dto.response.FeedbackResponse;
import com.hackathonyaho.voicejournal.observation.dto.response.ObservationEvidenceResponse;
import com.hackathonyaho.voicejournal.observation.dto.response.ObservationListResponse;
import com.hackathonyaho.voicejournal.observation.service.ObservationQueryService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

/** 응답 스키마는 계약 §2-6·§2-7·§2-7-1이 단일 출처다. */
@RestController
@RequestMapping("/api/observations")
@RequiredArgsConstructor
public class ObservationController {

    private final ObservationQueryService observationQueryService;

    @GetMapping
    public ResponseEntity<ObservationListResponse> list(@RequestParam(required = false) Integer limit,
                                                        @RequestParam(required = false) Integer offset) {
        return ResponseEntity.ok(
                observationQueryService.list(ProfileContext.require(), Paging.of(limit, offset)));
    }

    /** F7-07. <b>스코프 컷에서도 자르지 않는다</b>(spec §11) — 신뢰 서사의 마지막 고리다. */
    @GetMapping("/{observationId}/evidence")
    public ResponseEntity<ObservationEvidenceResponse> evidence(@PathVariable UUID observationId) {
        return ResponseEntity.ok(
                observationQueryService.evidence(ProfileContext.require(), observationId));
    }

    /** F7-08 (P1). §1.4의 "맞아요" 지표를 실제로 수집하는 경로다. */
    @PostMapping("/{observationId}/feedback")
    public ResponseEntity<FeedbackResponse> feedback(@PathVariable UUID observationId,
                                                     @Valid @RequestBody FeedbackRequest request) {
        return ResponseEntity.ok(observationQueryService.feedback(
                ProfileContext.require(), observationId, request.feedback()));
    }
}
