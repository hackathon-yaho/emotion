package com.hackathonyaho.voicejournal;

import com.hackathonyaho.voicejournal.session.service.SessionQueue;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/** 대기열 자체의 규칙. Spring 없이 돈다 — 시간 규칙을 확정적으로 보려면 TTL을 0으로 준다. */
class SessionQueueUnitTest {

    @Test
    @DisplayName("폴링이 끊긴 티켓은 만료된다 — 브라우저를 닫은 사람이 줄을 막지 않게")
    void expiresWhenPollingStops() throws InterruptedException {
        SessionQueue queue = new SessionQueue(true, 5, 0);
        UUID owner = UUID.randomUUID();
        UUID ticket = queue.enqueue(owner);

        // TTL 0이면 등록 시각을 지난 순간부터 만료다. 시계 해상도만큼만 기다린다.
        Thread.sleep(10);

        // 별도 스케줄러가 없다 — 줄을 만지는 순간 걷힌다.
        assertThat(queue.size()).isZero();
        assertThat(queue.poll(ticket, owner)).isEmpty();
    }

    @Test
    @DisplayName("순번은 선 순서대로다 — 앞사람이 빠지면 당겨진다")
    void positionsFollowArrival() {
        SessionQueue queue = new SessionQueue(true, 5, 60);
        UUID first = UUID.randomUUID();
        UUID second = UUID.randomUUID();

        UUID t1 = queue.enqueue(first);
        UUID t2 = queue.enqueue(second);

        assertThat(queue.poll(t1, first)).contains(1);
        assertThat(queue.poll(t2, second)).contains(2);

        queue.remove(t1);
        assertThat(queue.poll(t2, second)).contains(2 - 1);
    }

    /** 폴링이 순번을 앞당기면 계속 새로 고치는 사람이 줄을 추월한다. */
    @Test
    @DisplayName("폴링해도 순번이 바뀌지 않는다")
    void pollingDoesNotJumpTheLine() {
        SessionQueue queue = new SessionQueue(true, 5, 60);
        UUID first = UUID.randomUUID();
        UUID second = UUID.randomUUID();
        UUID t1 = queue.enqueue(first);
        UUID t2 = queue.enqueue(second);

        for (int i = 0; i < 5; i++) {
            queue.poll(t2, second);
        }

        assertThat(queue.poll(t1, first)).contains(1);
        assertThat(queue.poll(t2, second)).contains(2);
    }
}
