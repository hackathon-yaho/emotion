import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// 수치 몇 개를 세로 구분선으로 잇는 줄 — evidence·기록 항목에 쓴다.
class MetaRow extends StatelessWidget {
  const MetaRow(this.items, {super.key, this.size = AppType.captionSize});

  final List<String> items;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) ...[
            const SizedBox(width: Space.md + 2),
            Container(width: 1, height: 11, color: t.line),
            const SizedBox(width: Space.md + 2),
          ],
          Text(
            items[i],
            style: AppType.sans(size: size, color: t.muted, height: 1.2),
          ),
        ],
      ],
    );
  }
}

/// 계열 색 점 + 값 — 말한 내용/목소리를 나란히 보여줄 때.
class ChannelValue extends StatelessWidget {
  const ChannelValue({super.key, required this.color, required this.value});

  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Container(width: 10, height: 2, color: color),
        const SizedBox(width: 6),
        Text(
          value,
          style: AppType.sans(
            size: AppType.labelSize,
            color: t.muted,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
