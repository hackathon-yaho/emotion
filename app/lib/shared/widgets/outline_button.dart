import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// 테두리 버튼 — 모서리 2, 거의 사각 (design-system §3).
class OutlineAction extends StatelessWidget {
  const OutlineAction({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.height = 60,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return _Tap(
      onPressed: onPressed,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: t.line),
          borderRadius: const BorderRadius.all(Radii.control),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[icon!, const SizedBox(width: Space.md)],
            Text(
              label,
              style: AppType.sans(
                size: AppType.bodySize,
                color: t.paper,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 채운 버튼 — 호박(accent). 화면의 주요 동작 하나에만 쓴다.
class FilledAction extends StatelessWidget {
  const FilledAction({
    super.key,
    required this.label,
    this.onPressed,
    this.height = 60,
    this.background,
    this.foreground,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return _Tap(
      onPressed: onPressed,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: background ?? t.accent,
          borderRadius: const BorderRadius.all(Radii.control),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppType.sans(
            size: AppType.bodySize,
            color: foreground ?? t.onAccent,
            weight: FontWeight.w500,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

/// 동작 라벨 — 누를 수 있음을 accent로 알린다. §4의 예외.
class ActionLink extends StatelessWidget {
  const ActionLink({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return _Tap(
      onPressed: onPressed,
      child: SizedBox(
        height: Space.tapMin,
        child: Row(
          children: [
            Text(
              label,
              style: AppType.sans(
                size: AppType.captionSizeLg,
                color: t.accent,
                height: 1.2,
              ),
            ),
            const SizedBox(width: Space.sm + 2),
            Icon(Icons.arrow_forward, size: 14, color: t.accent),
          ],
        ),
      ),
    );
  }
}

class _Tap extends StatelessWidget {
  const _Tap({required this.child, this.onPressed});

  final Widget child;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}
