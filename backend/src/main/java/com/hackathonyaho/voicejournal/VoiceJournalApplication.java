package com.hackathonyaho.voicejournal;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * F2-06 정리와 F7-01 배치가 같은 스케줄러에 올라탄다 — 추가 인프라 0.
 * 인스턴스는 Render Free라 1개뿐이므로 분산 락이 필요 없다.
 */
@EnableScheduling
@SpringBootApplication
public class VoiceJournalApplication {

    public static void main(String[] args) {
        SpringApplication.run(VoiceJournalApplication.class, args);
    }
}
