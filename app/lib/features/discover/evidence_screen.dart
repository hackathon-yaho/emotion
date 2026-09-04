import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/fixtures/sample_data.dart';
import '../../core/models/observation_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/hairline.dart';
import '../../shared/widgets/meta_row.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/small_label.dart';
import '../../shared/widgets/two_line_chart.dart';

/// S03-1 관찰 근거 (F7-07).
///
/// **`turns` 길이와 `evidence.occurrences`가 같아야 한다** — 다르면 계약 위반
/// 이며 PRD §1.4의 "evidence 불일치 0건" 지표 실패로 집계한다. 화면에 그리기
/// 전에 [ObservationEvidence.isConsistent]로 확인한다.
///
/// 근거 턴에는 **텍스트·음성 valence를 둘 다** 보여준다 (design-system §7-9) —
/// "근거"라면 갭이 어디서 왔는지가 보여야 한다.
class EvidenceScreen extends StatelessWidget {
  const EvidenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final d = Sample.evidenceDetail;
    final e = d.evidence;

    return ScreenScaffold(
      topPadding: 40,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackRow(onBack: () => context.pop()),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: Space.xl),
                  const SmallLabel('이 관찰의 근거'),
                  const SizedBox(height: Space.lg + 2),
                  Text(
                    d.sentence,
                    style: AppType.serif(
                      size: AppType.titleSize,
                      color: t.paper,
                    ),
                  ),
                  const SizedBox(height: Space.xl),
                  MetaRow([
                    '${e.tag} ${e.occurrences}회',
                    '태그 평균 갭 ${e.tagAvgGap.toStringAsFixed(2)}',
                    '내 평균 ${e.userAvgGap.toStringAsFixed(2)}',
                  ]),
                  const SizedBox(height: Space.xl - Space.xs),
                  const ChartLegend(),
                  const SizedBox(height: Space.xl - Space.xs),

                  if (!d.isConsistent)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.lg),
                      child: Text(
                        // 계약 위반 — 숫자와 실제 건수가 다르면 그 관찰은
                        // "근거 없는 문장"이 된다.
                        '근거 숫자가 맞지 않습니다. 다시 불러와 주세요.',
                        style: AppType.sans(
                          size: AppType.captionSizeLg,
                          color: t.muted,
                          height: 1.6,
                        ),
                      ),
                    ),

                  for (final turn in d.turns) _TurnRow(turn: turn),
                  const Hairline(),

                  const SizedBox(height: Space.xl),
                  Text(
                    '${d.turns.length}건 중 ${d.turns.length}건입니다.',
                    style: AppType.sans(
                      size: AppType.captionSize,
                      color: t.faint,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: Space.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TurnRow extends StatelessWidget {
  const _TurnRow({required this.turn});

  final EvidenceTurn turn;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final at = turn.occurredAt;
    final time =
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Hairline(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.xl - Space.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SmallLabel('${at.month}.${at.day} $time'),
              const SizedBox(height: Space.md),
              Text(
                turn.transcript,
                style: AppType.sans(
                  size: AppType.captionSizeLg + 1,
                  color: t.paper,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: Space.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  ChannelValue(color: t.cool, value: _fmt(turn.textValence)),
                  const SizedBox(width: Space.md + 2),
                  ChannelValue(color: t.warm, value: _fmt(turn.voiceValence)),
                  const SizedBox(width: Space.md + 2),
                  Container(width: 1, height: 10, color: t.line),
                  const SizedBox(width: Space.md + 2),
                  Text(
                    '갭 ${_fmt(turn.gap)}',
                    style: AppType.sans(
                      size: AppType.labelSize,
                      color: t.paper,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// null은 "측정하지 못했다" — 0으로 대체하지 않는다 (계약서 §1-3).
  static String _fmt(double? v) {
    if (v == null) return '—';
    return '${v < 0 ? '−' : ''}${v.abs().toStringAsFixed(2)}';
  }
}

class _BackRow extends StatelessWidget {
  const _BackRow({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onBack,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: Space.tapMin,
        height: Space.tapMin,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Icon(Icons.chevron_left, size: 24, color: t.muted),
        ),
      ),
    );
  }
}
