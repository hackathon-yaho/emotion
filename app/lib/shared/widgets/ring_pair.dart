import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// S02 대화 화면의 어긋난 두 링.
///
/// 차가운 링 = 말한 내용, 따뜻한 링 = 목소리 (design-system §1).
///
/// **색은 고정이고 간격·크기·투명도만 상태에 반응한다.** 색이 감정에 따라
/// 변하면 사용자가 "화면이 어두워졌네"로 읽어 사실상 갭 노출이 된다 —
/// FR-030이 막으려던 관찰당하는 느낌이 그대로 생긴다.
class RingPair extends StatelessWidget {
  const RingPair({
    super.key,
    required this.size,
    required this.offset,
    required this.coolOpacity,
    required this.warmOpacity,
    this.box = 208,
  });

  /// 링 지름.
  final double size;

  /// 두 링이 어긋난 거리.
  final double offset;

  final double coolOpacity;
  final double warmOpacity;

  /// 링을 담는 정사각 영역.
  final double box;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final base = (box - size) / 2;

    return SizedBox(
      width: box,
      height: box,
      child: Stack(
        children: [
          _ring(base - offset / 2, t.cool, coolOpacity),
          _ring(base + offset / 2, t.warm, warmOpacity),
        ],
      ),
    );
  }

  Widget _ring(double pos, Color color, double opacity) {
    return Positioned(
      left: pos,
      top: pos,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: opacity)),
        ),
      ),
    );
  }
}
