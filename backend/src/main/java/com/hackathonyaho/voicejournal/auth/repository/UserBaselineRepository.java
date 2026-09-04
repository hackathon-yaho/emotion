package com.hackathonyaho.voicejournal.auth.repository;

import com.hackathonyaho.voicejournal.auth.entity.UserBaseline;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface UserBaselineRepository extends JpaRepository<UserBaseline, UUID> {
}
