package com.hackathonyaho.voicejournal.auth.repository;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

/**
 * 탈퇴 전량 삭제 (F10-03). <b>10개 테이블, 단일 트랜잭션, 자식부터 부모 순서.</b>
 *
 * <p>{@code ops_error_log}는 <b>지우지 않는다</b> — 사용자 데이터를 담지 않고 장애 분석에
 * 필요하다(spec §6-1).
 *
 * <p>FK가 {@code NO ACTION}이라 순서를 어기면 제약 위반으로 즉시 실패하고 전체가
 * 롤백된다 — <b>순서 실수가 조용히 넘어가지 않는다.</b>
 */
@Component
@RequiredArgsConstructor
public class AccountDeletionRepository {

    private final JdbcTemplate jdbc;

    @Transactional
    public void deleteAllFor(UUID profileId) {
        jdbc.update("delete from observation_evidence where observation_id in"
                + " (select id from observation where profile_id = ?)", profileId);
        jdbc.update("delete from observation where profile_id = ?", profileId);
        jdbc.update("delete from turn_tag where turn_id in (select t.id from turn_log t"
                + " join voice_session s on s.id = t.session_id where s.profile_id = ?)", profileId);
        jdbc.update("delete from turn_log where session_id in"
                + " (select id from voice_session where profile_id = ?)", profileId);
        jdbc.update("delete from crisis_event where profile_id = ?", profileId);
        jdbc.update("delete from voice_session where profile_id = ?", profileId);
        jdbc.update("delete from user_baseline where profile_id = ?", profileId);
        // 연결자를 지우기 전에 account_id를 잡는다 — 지운 뒤에는 어느 계정이었는지
        // 알 방법이 없다. 세션 삭제의 ①과 같은 함정이다.
        List<UUID> accountIds = jdbc.queryForList(
                "select account_id from account_profile where profile_id = ?", UUID.class, profileId);

        jdbc.update("delete from account_profile where profile_id = ?", profileId);
        for (UUID accountId : accountIds) {
            jdbc.update("delete from account where id = ?", accountId);
        }
        jdbc.update("delete from profile where id = ?", profileId);
    }
}
