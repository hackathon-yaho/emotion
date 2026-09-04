package com.hackathonyaho.voicejournal.health.controller;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.Map;

/**
 * F11-02. 인증 불필요 (계약 §2-12).
 *
 * <p>이 엔드포인트가 나중에 두 가지를 동시에 막는다 — Render 15분 슬립(cron이
 * 10분마다 호출)과 Supabase 유휴 일시정지. <b>그래서 DB에 실제로 닿아야 한다.</b>
 * 단순히 {@code {"status":"ok"}}를 돌려주면 DB가 죽어도 살아 있다고 보고한다.
 */
@Slf4j
@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class HealthController {

    private final JdbcTemplate jdbcTemplate;

    @GetMapping("/health")
    public Map<String, String> health() {
        String db;
        try {
            jdbcTemplate.queryForObject("select 1", Integer.class);
            db = "ok";
        } catch (Exception e) {
            log.error("health: db unreachable", e);
            db = "down";
        }
        return Map.of(
                "status", "ok".equals(db) ? "ok" : "degraded",
                "db", db,
                "timestamp", Instant.now().toString());
    }
}
