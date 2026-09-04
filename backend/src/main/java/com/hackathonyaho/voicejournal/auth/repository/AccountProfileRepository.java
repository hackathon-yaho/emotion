package com.hackathonyaho.voicejournal.auth.repository;

import com.hackathonyaho.voicejournal.auth.entity.AccountProfile;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface AccountProfileRepository extends JpaRepository<AccountProfile, UUID> {

    Optional<AccountProfile> findByAccountId(UUID accountId);
}
