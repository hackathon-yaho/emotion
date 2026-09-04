package com.hackathonyaho.voicejournal.auth.repository;

import com.hackathonyaho.voicejournal.auth.entity.Account;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface AccountRepository extends JpaRepository<Account, UUID> {

    Optional<Account> findByKakaoId(String kakaoId);
}
