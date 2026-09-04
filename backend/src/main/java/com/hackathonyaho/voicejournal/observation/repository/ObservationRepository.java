package com.hackathonyaho.voicejournal.observation.repository;

import com.hackathonyaho.voicejournal.observation.entity.Observation;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface ObservationRepository extends JpaRepository<Observation, UUID> {

    boolean existsByProfileIdAndTagAndStatus(UUID profileId, String tag, String status);

    List<Observation> findTop3ByProfileIdAndStatusOrderByCreatedAtDesc(UUID profileId, String status);
}
