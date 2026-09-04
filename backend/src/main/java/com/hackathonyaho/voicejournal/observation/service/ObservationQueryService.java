package com.hackathonyaho.voicejournal.observation.service;

import com.hackathonyaho.voicejournal.common.global.ErrorCode;
import com.hackathonyaho.voicejournal.common.global.Paging;
import com.hackathonyaho.voicejournal.common.global.exception.BusinessException;
import com.hackathonyaho.voicejournal.observation.dto.response.FeedbackResponse;
import com.hackathonyaho.voicejournal.observation.dto.response.ObservationEvidenceResponse;
import com.hackathonyaho.voicejournal.observation.dto.response.ObservationListResponse;
import com.hackathonyaho.voicejournal.observation.entity.Observation;
import com.hackathonyaho.voicejournal.observation.repository.ObservationEvidenceRepository;
import com.hackathonyaho.voicejournal.observation.repository.ObservationRepository;
import com.hackathonyaho.voicejournal.turn.entity.TurnLog;
import com.hackathonyaho.voicejournal.turn.repository.TurnLogRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Comparator;
import java.util.List;
import java.util.UUID;

/** 관찰 조회 (F7-06·07·08). 응답 필드의 단일 출처는 계약 §2-6·§2-7·§2-7-1이다. */
@Service
@RequiredArgsConstructor
public class ObservationQueryService {

    private final ObservationRepository observationRepository;
    private final ObservationEvidenceRepository evidenceRepository;
    private final TurnLogRepository turnLogRepository;

    @Transactional(readOnly = true)
    public ObservationListResponse list(UUID profileId, Paging paging) {
        // invalidated는 조회에서 제외한다 — 근거 대화가 지워진 관찰은 보이면 안 된다(F10-02).
        var page = observationRepository.findByProfileIdAndStatusOrderByCreatedAtDesc(
                profileId, Observation.ACTIVE,
                PageRequest.of(paging.offset() / paging.limit(), paging.limit()));

        return new ObservationListResponse(
                page.getTotalElements(),
                page.getContent().stream()
                        .map(o -> new ObservationListResponse.Item(
                                o.getId().toString(), o.getCreatedAt(), o.getSentence(),
                                evidenceOf(o), o.getFeedback()))
                        .toList());
    }

    @Transactional(readOnly = true)
    public ObservationEvidenceResponse evidence(UUID profileId, UUID observationId) {
        Observation observation = mine(profileId, observationId);

        List<UUID> turnIds = evidenceRepository.turnIdsOf(observationId);
        List<ObservationEvidenceResponse.Turn> turns = turnLogRepository.findAllById(turnIds).stream()
                .sorted(Comparator.comparing(TurnLog::getOccurredAt))
                // transcript는 변환기가 복호화해 평문으로 나온다 (Phase 3).
                .map(t -> new ObservationEvidenceResponse.Turn(
                        t.getId(), t.getSessionId(), t.getOccurredAt(), t.getTranscript(),
                        t.getTextValence(), t.getVoiceValence(), t.getGap()))
                .toList();

        return new ObservationEvidenceResponse(
                observation.getId().toString(), observation.getSentence(), evidenceOf(observation), turns);
    }

    /**
     * 관찰당 1회, 재호출은 덮어쓴다 (계약 §2-7-1).
     *
     * <p><b>{@code disagree}가 관찰을 삭제하지 않는다.</b> 사용자가 부정해도 우리가
     * 계산한 숫자가 틀린 것은 아니고 evidence는 그대로 유효하다 — 삭제하면 §1.4
     * "evidence 불일치 0건"의 판정 대상이 사라져 지표가 왜곡된다.
     */
    @Transactional
    public FeedbackResponse feedback(UUID profileId, UUID observationId, String feedback) {
        Observation observation = mine(profileId, observationId);
        observation.applyFeedback(feedback);
        return new FeedbackResponse(observation.getId().toString(), observation.getFeedback());
    }

    private ObservationListResponse.Evidence evidenceOf(Observation o) {
        return new ObservationListResponse.Evidence(
                o.getTag(), o.getOccurrences(), o.getTagAvgGap(), o.getUserAvgGap(), o.getRatio());
    }

    /** 무효화된 관찰도 404다 — 근거가 사라진 관찰을 문장만 보여주면 FR-053이 깨진다. */
    private Observation mine(UUID profileId, UUID observationId) {
        Observation observation = observationRepository.findById(observationId)
                .filter(o -> o.getProfileId().equals(profileId))
                .filter(o -> Observation.ACTIVE.equals(o.getStatus()))
                .orElseThrow(() -> new BusinessException(
                        ErrorCode.OBSERVATION_NOT_FOUND, "observation not found or invalidated"));
        return observation;
    }
}
