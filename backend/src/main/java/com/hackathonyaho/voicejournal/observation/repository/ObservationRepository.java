package com.hackathonyaho.voicejournal.observation.repository;

import com.hackathonyaho.voicejournal.observation.entity.Observation;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface ObservationRepository extends JpaRepository<Observation, UUID> {

    boolean existsByProfileIdAndTagAndStatus(UUID profileId, String tag, String status);

    List<Observation> findTop3ByProfileIdAndStatusOrderByCreatedAtDesc(UUID profileId, String status);

    /** 최신순 고정 (계약 §1-4). invalidated는 빠진다 — 근거가 사라진 관찰은 보이면 안 된다. */
    Page<Observation> findByProfileIdAndStatusOrderByCreatedAtDesc(UUID profileId, String status, Pageable pageable);
}
