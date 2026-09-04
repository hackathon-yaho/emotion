package com.hackathonyaho.voicejournal.session.service;

import lombok.Getter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.time.Instant;
import java.util.Deque;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.ConcurrentLinkedDeque;

/**
 * 동시 접속 대기열 (계약 §2-14).
 *
 * <p><b>메모리에만 둔다.</b> 줄이 서 있다는 것은 서버가 한가하지 않다는 뜻이라 Render가
 * 재우지 않고, 재배포로 줄이 사라지면 대기자는 폴링에서 404를 받아 다시 선다. 테이블을
 * 하나 늘려 마이그레이션·정리 스케줄러·탈퇴 시 삭제까지 따라오게 할 값이 아니다.
 *
 * <p><b>폴링이 끊긴 티켓은 만료된다.</b> 브라우저를 닫은 사람이 줄을 영원히 막기 때문이다.
 */
@Component
public class SessionQueue {

    private record Ticket(UUID ticketId, UUID profileId, Instant lastPollAt) {
    }

    private final Deque<Ticket> queue = new ConcurrentLinkedDeque<>();

    @Getter
    private final boolean enabled;
    @Getter
    private final int capacity;
    private final Duration ticketTtl;

    public SessionQueue(@Value("${app.session.queue.enabled}") boolean enabled,
                        @Value("${app.session.queue.capacity}") int capacity,
                        @Value("${app.session.queue.ticket-ttl-sec}") int ticketTtlSec) {
        this.enabled = enabled;
        this.capacity = capacity;
        this.ticketTtl = Duration.ofSeconds(ticketTtlSec);
    }

    /** 한 사람에게 티켓 하나다 — 새로 고침마다 줄이 늘어나면 순번이 뜻을 잃는다. */
    public synchronized UUID enqueue(UUID profileId) {
        sweep();
        for (Ticket t : queue) {
            if (t.profileId().equals(profileId)) {
                touch(t.ticketId());
                return t.ticketId();
            }
        }
        UUID ticketId = UUID.randomUUID();
        queue.addLast(new Ticket(ticketId, profileId, Instant.now()));
        return ticketId;
    }

    /**
     * 폴링 시각을 갱신하고 순번을 돌려준다.
     *
     * @return 1부터 센 순번. <b>비어 있으면 티켓이 없거나 만료됐다</b>
     */
    public synchronized Optional<Integer> poll(UUID ticketId, UUID profileId) {
        sweep();
        int position = 1;
        for (Ticket t : queue) {
            if (t.ticketId().equals(ticketId)) {
                // 남의 티켓으로는 순번도 못 본다 — 그 응답이 곧 입장권이기 때문이다.
                if (!t.profileId().equals(profileId)) {
                    return Optional.empty();
                }
                touch(ticketId);
                return Optional.of(position);
            }
            position++;
        }
        return Optional.empty();
    }

    public synchronized void remove(UUID ticketId) {
        queue.removeIf(t -> t.ticketId().equals(ticketId));
    }

    public synchronized int size() {
        sweep();
        return queue.size();
    }

    /** 줄이 비었는지. <b>새치기 판단에 쓴다</b> — 만료된 티켓은 세지 않는다. */
    public synchronized boolean isEmpty() {
        sweep();
        return queue.isEmpty();
    }

    private void touch(UUID ticketId) {
        Ticket old = queue.stream().filter(t -> t.ticketId().equals(ticketId)).findFirst().orElse(null);
        if (old == null) {
            return;
        }
        // 순서를 지켜야 하므로 제자리에서 바꾼다. ConcurrentLinkedDeque에 set이 없어
        // 같은 위치를 유지하려면 통째로 다시 쌓는다 — 줄이 길어야 대여섯이라 충분하다.
        Ticket[] snapshot = queue.toArray(new Ticket[0]);
        queue.clear();
        for (Ticket t : snapshot) {
            queue.addLast(t.ticketId().equals(ticketId)
                    ? new Ticket(t.ticketId(), t.profileId(), Instant.now())
                    : t);
        }
    }

    /** 폴링을 멈춘 티켓을 걷어낸다. 별도 스케줄러를 두지 않는다 — 줄을 만질 때마다 돈다. */
    private void sweep() {
        Instant deadline = Instant.now().minus(ticketTtl);
        queue.removeIf(t -> t.lastPollAt().isBefore(deadline));
    }
}
