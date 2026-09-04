-- 감정 케어 보이스 저널 — 스키마 단일 출처는 backend/docs/data-model.md다.
-- 컬럼을 고치려면 spec.md §6-1 → data-model.md → 이 파일 순서로 고친다.
--
-- ddl-auto: none 이므로 JPA는 스키마를 만들지 않는다.
-- 같은 파일을 로컬 compose Postgres와 배포 Supabase 양쪽에 적용한다.
-- gen_random_uuid()는 PostgreSQL 13+ 내장이라 확장 설치가 필요 없다.
--
-- 테이블 생성 순서는 부모 먼저다 (FK가 전부 ON DELETE NO ACTION).

-- ── 계정 · 프로필 (F1 · 식별자 분리) ────────────────────────────────
-- 감정 데이터는 profile_id만 참조한다. account(카카오 식별자)와의 연결은
-- account_profile 한 곳에만 있다 — PRD §5.1.

create table if not exists account (
    id         uuid primary key default gen_random_uuid(),
    kakao_id   text        not null unique,
    created_at timestamptz not null default now()
);

create table if not exists profile (
    id         uuid primary key default gen_random_uuid(),
    demo_mode  boolean     not null default false,
    created_at timestamptz not null default now()
);

create table if not exists account_profile (
    account_id uuid primary key references account (id),
    profile_id uuid not null unique references profile (id)
);

-- ── 대화 세션 (F2) ──────────────────────────────────────────────────

create table if not exists voice_session (
    id                   uuid primary key default gen_random_uuid(),
    profile_id           uuid         not null references profile (id),
    started_at           timestamptz  not null default now(),
    ended_at             timestamptz,
    duration_sec         integer,
    threshold_mode       text         not null check (threshold_mode in ('fixed', 'personal')),
    -- 그 세션에 실제로 적용된 임계값 스냅샷. F9-02 음영 판정이 이 값을 쓴다.
    -- 현재 설정값으로 소급 판정하면 임계값 확정 시 과거 음영이 통째로 바뀐다.
    gap_threshold        numeric(3, 2) not null,
    end_reason           text         check (end_reason in ('user_end', 'soft_wrap', 'hard_cut', 'timeout', 'resumed')),
    summary              text,
    hume_chat_group_id   text,
    -- NULL이면 배치 미처리. 스케줄러가 이 조건으로 훑는다 (F7-01).
    pattern_processed_at timestamptz
);

create index if not exists idx_session_profile_started on voice_session (profile_id, started_at desc);
create index if not exists idx_session_open on voice_session (profile_id) where ended_at is null;
create index if not exists idx_session_batch_pending on voice_session (ended_at)
    where ended_at is not null and pattern_processed_at is null;

-- ── 턴 로그 (F3 · F5 · F6) ──────────────────────────────────────────

create table if not exists turn_log (
    id             uuid primary key default gen_random_uuid(),
    session_id     uuid         not null references voice_session (id),
    turn_index     integer      not null,
    role           text         not null check (role in ('user', 'assistant')),
    -- 발화 시각(AI가 보냄) / 적재 시각. 재시도되면 두 값이 갈린다.
    -- occurred_at은 unique 위반을 "재시도"와 "다른 발화"로 가르는 기준이다 (계약 §3-2 v1.5).
    occurred_at    timestamptz  not null,
    -- AES-GCM 암호문(base64). 평문이 들어가면 F5-02 위반이다.
    transcript_enc text         not null,
    text_valence   numeric(3, 2),
    voice_valence  numeric(3, 2),
    gap            numeric(3, 2),
    gap_triggered  boolean      not null default false,
    top_prosody    jsonb,
    created_at     timestamptz  not null default now(),
    unique (session_id, turn_index)
);

create index if not exists idx_turn_session_index on turn_log (session_id, turn_index);
create index if not exists idx_turn_occurred on turn_log (occurred_at);

create table if not exists turn_tag (
    turn_id uuid not null references turn_log (id),
    tag     text not null,
    primary key (turn_id, tag)
);

create index if not exists idx_turn_tag_tag on turn_tag (tag);

-- ── 개인 baseline (F3-04 · F3-05) ───────────────────────────────────

create table if not exists user_baseline (
    profile_id    uuid primary key references profile (id),
    -- 증가는 세션 종료의 기본 동작이다 (F3-05가 아니다 — 컷돼도 F3-04가 살아야 한다).
    session_count integer      not null default 0,
    avg_gap       numeric(3, 2),
    stddev_gap    numeric(3, 2),
    updated_at    timestamptz  not null default now()
);

-- ── 관찰 (F7) ───────────────────────────────────────────────────────

create table if not exists observation (
    id           uuid primary key default gen_random_uuid(),
    profile_id   uuid         not null references profile (id),
    sentence     text         not null,
    -- 아래 5개가 계약 §2-6의 evidence 객체 그대로다. 문장 ↔ 숫자 불일치는 0건이어야 한다.
    tag          text         not null,
    occurrences  integer      not null,
    tag_avg_gap  numeric(3, 2) not null,
    user_avg_gap numeric(3, 2) not null,
    ratio        numeric(4, 2) not null,
    status       text         not null default 'active' check (status in ('active', 'invalidated')),
    feedback     text         check (feedback in ('agree', 'disagree')),
    created_at   timestamptz  not null default now()
);

create index if not exists idx_observation_profile on observation (profile_id, created_at desc);

create table if not exists observation_evidence (
    observation_id uuid not null references observation (id),
    turn_id        uuid not null references turn_log (id),
    primary key (observation_id, turn_id)
);

-- F10-02가 "이 턴을 근거로 쓰던 관찰"을 역방향으로 찾는다. 없으면 전체 스캔이다.
create index if not exists idx_evidence_turn on observation_evidence (turn_id);

-- ── 위기 이벤트 (F4-04) ─────────────────────────────────────────────
-- turn_id 컬럼을 두지 않는다. 조인 한 번으로 "그때 무슨 말을 했는지"에
-- 도달하는 경로를 가장 민감한 지점에서 아예 만들지 않는다 (spec §6-1).

create table if not exists crisis_event (
    id          uuid primary key default gen_random_uuid(),
    profile_id  uuid        not null references profile (id),
    session_id  uuid        not null references voice_session (id),
    detected_by text        not null check (detected_by in ('rule', 'llm')),
    created_at  timestamptz not null default now()
);

create index if not exists idx_crisis_session on crisis_event (session_id);

-- ── 운영 로그 (F11-03) ──────────────────────────────────────────────
-- 탈퇴 삭제 대상이 아니다 (사용자 데이터를 담지 않는다).
-- message에 발화 내용·sessionId를 넣지 않는다 — sessionRef 해시만 (FR-092).

create table if not exists ops_error_log (
    id         uuid primary key default gen_random_uuid(),
    service    text        not null,
    code       text        not null,
    message    text        not null,
    created_at timestamptz not null default now()
);
