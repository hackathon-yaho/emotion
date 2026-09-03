import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

/// 로딩 스켈레톤.
///
/// **헤어라인 굵기의 가는 막대**로만 만든다. 카드 모양 스켈레톤을 쓰지 않는다
/// — 카드가 없는 언어에서 카드 실루엣이 뜨면 로딩이 끝난 뒤 화면이 달라진다
/// (design-system §7-10).
class SkeletonLines extends StatefulWidget {
  const SkeletonLines({
    super.key,
    required this.widths,
    this.gap = Space.xxl + Space.sm,
  });

  /// 각 막대의 가로 비율 (0~1).
  final List<double> widths;
  final double gap;

  @override
  State<SkeletonLines> createState() => _SkeletonLinesState();
}

class _SkeletonLinesState extends State<SkeletonLines>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    duration: const Duration(milliseconds: 1600),
    vsync: this,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final line = context.tokens.line;
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < widget.widths.length; i++) ...[
            if (i > 0) SizedBox(height: widget.gap),
            FractionallySizedBox(
              widthFactor: widget.widths[i],
              child: Container(height: 2, color: line),
            ),
          ],
        ],
      ),
    );
  }
}
