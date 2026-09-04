import 'package:flutter/material.dart';

import '../../core/theme/typography.dart';

/// 카카오 로그인 버튼.
///
/// **우리 색·모서리 규칙의 유일한 예외다** (design-system §4-2). 카카오 브랜드
/// 가이드를 따르며 임의로 색을 바꾸거나 다크 테마에 맞춰 변형하지 않는다 —
/// 소셜 로그인 버튼은 제공자가 규정한 형태를 쓰는 것이 전제다.
///
/// 말풍선은 **자리를 잡아둔 대체 도형**이다. 구현 시 카카오 디벨로퍼스의
/// 공식 애셋으로 교체한다.
class KakaoButton extends StatelessWidget {
  const KakaoButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  static const _yellow = Color(0xFFFEE500);
  static const _ink = Color(0xD9000000); // 검정 85%

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: _yellow,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomPaint(
              size: const Size(19, 19),
              painter: _BubblePainter(_ink),
            ),
            const SizedBox(width: 10),
            Text(
              // spec F1-01의 트리거 문구와 일치시킨다
              '카카오로 시작하기',
              style: AppType.sans(
                size: AppType.bodySize,
                color: _ink,
                weight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  _BubblePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final paint = Paint()..color = color;
    final path = Path()
      ..addOval(Rect.fromLTWH(1.8 * s, 3.2 * s, 20.4 * s, 15.2 * s))
      ..moveTo(7.5 * s, 15 * s)
      ..lineTo(6.4 * s, 20.8 * s)
      ..lineTo(12 * s, 17 * s)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BubblePainter old) => old.color != color;
}
