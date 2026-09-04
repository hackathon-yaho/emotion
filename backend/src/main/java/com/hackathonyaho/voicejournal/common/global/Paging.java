package com.hackathonyaho.voicejournal.common.global;

/**
 * 계약 §1-4. <b>정렬은 항상 최신순이고 클라이언트가 바꾸지 않는다</b> — 정렬 파라미터를
 * 열면 화면마다 다른 순서가 생기고, "어제 본 그 카드"를 다시 찾기 어려워진다.
 */
public record Paging(int limit, int offset) {

    private static final int DEFAULT_LIMIT = 20;
    private static final int MAX_LIMIT = 100;

    /** 범위를 벗어난 값은 오류가 아니라 조용히 자른다 — 목록 조회가 400으로 끊길 이유가 없다. */
    public static Paging of(Integer limit, Integer offset) {
        int size = limit == null ? DEFAULT_LIMIT : Math.min(Math.max(limit, 1), MAX_LIMIT);
        return new Paging(size, offset == null ? 0 : Math.max(offset, 0));
    }
}
