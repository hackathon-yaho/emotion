package com.hackathonyaho.voicejournal.trend.controller;

import com.hackathonyaho.voicejournal.auth.security.ProfileContext;
import com.hackathonyaho.voicejournal.trend.dto.TrendResponse;
import com.hackathonyaho.voicejournal.trend.service.TrendService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/** 응답 스키마는 계약 §2-8이 단일 출처다. */
@RestController
@RequestMapping("/api/trend")
@RequiredArgsConstructor
public class TrendController {

    private final TrendService trendService;

    @GetMapping
    public ResponseEntity<TrendResponse> trend(@RequestParam(required = false) String range) {
        return ResponseEntity.ok(trendService.trend(ProfileContext.require(), range));
    }
}
