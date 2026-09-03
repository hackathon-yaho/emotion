import 'package:flutter/material.dart';

/// 디자인 토큰 — `docs/01-product/design-system.md` §4가 단일 출처.
///
/// 값을 여기서 바꾸지 말고 문서를 먼저 고친다. 라이트는 다크의 자동 반전이
/// 아니며, 각 모드에서 따로 고른 값이다.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.bg,
    required this.lift,
    required this.paper,
    required this.muted,
    required this.faint,
    required this.line,
    required this.accent,
    required this.onAccent,
    required this.care,
    required this.cool,
    required this.warm,
    required this.shade,
    required this.dblShadow,
  });

  /// 배경.
  final Color bg;

  /// 시트·오버레이 **전용**. 카드 배경으로 쓰면 「카드를 쓰지 않는다」가 무너진다.
  final Color lift;

  /// 본문.
  final Color paper;

  /// 보조 본문.
  final Color muted;

  /// 라벨·비활성.
  final Color faint;

  /// 헤어라인 — 구획은 카드가 아니라 이것과 여백으로 한다.
  final Color line;

  /// 동작(호박). 누를 수 있는 라벨에만.
  final Color accent;

  /// accent 위에 얹는 글자색.
  final Color onAccent;

  /// S07 위기 안내 **전용**. 다른 용도로 쓰지 않는다 (§4).
  final Color care;

  /// 말한 내용 = 텍스트 valence. 차가운 쪽.
  final Color cool;

  /// 목소리 = 음성 valence. 따뜻한 쪽.
  final Color warm;

  /// 갭 구간 음영. 중립 — 색으로 좋음/나쁨을 말하지 않는다.
  final Color shade;

  /// 「두 겹」 그림자. 두 벌을 겹치지 않고 그림자 한 겹으로 구현한다 (§1).
  final Color dblShadow;

  static const dark = AppTokens(
    bg: Color(0xFF0D0D0C),
    lift: Color(0xFF161614),
    paper: Color(0xFFF2EFE9),
    muted: Color(0xFF8A8781),
    faint: Color(0xFF55534E),
    line: Color(0x1FF2EFE9), // rgba(242,239,233,0.12)
    accent: Color(0xFFC98A4B),
    onAccent: Color(0xFF0D0D0C),
    care: Color(0xFFC98087),
    cool: Color(0xFF5A8FC9),
    warm: Color(0xFFC25A38),
    shade: Color(0x12F2EFE9), // rgba(242,239,233,0.07)
    dblShadow: Color(0xE6C25A38), // rgba(194,90,56,0.9)
  );

  static const light = AppTokens(
    bg: Color(0xFFF5F2EC),
    lift: Color(0xFFFFFFFF),
    paper: Color(0xFF1A1815),
    muted: Color(0xFF6B675F),
    faint: Color(0xFF9A968D),
    line: Color(0x241A1815), // rgba(26,24,21,0.14)
    accent: Color(0xFF8A5A22),
    onAccent: Color(0xFFFFFFFF),
    care: Color(0xFFA85A62),
    cool: Color(0xFF2F6FA8),
    warm: Color(0xFFB5411F),
    shade: Color(0x0F1A1815), // rgba(26,24,21,0.06)
    dblShadow: Color(0xA6B5411F), // rgba(181,65,31,0.65)
  );

  @override
  AppTokens copyWith({
    Color? bg,
    Color? lift,
    Color? paper,
    Color? muted,
    Color? faint,
    Color? line,
    Color? accent,
    Color? onAccent,
    Color? care,
    Color? cool,
    Color? warm,
    Color? shade,
    Color? dblShadow,
  }) {
    return AppTokens(
      bg: bg ?? this.bg,
      lift: lift ?? this.lift,
      paper: paper ?? this.paper,
      muted: muted ?? this.muted,
      faint: faint ?? this.faint,
      line: line ?? this.line,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      care: care ?? this.care,
      cool: cool ?? this.cool,
      warm: warm ?? this.warm,
      shade: shade ?? this.shade,
      dblShadow: dblShadow ?? this.dblShadow,
    );
  }

  @override
  AppTokens lerp(covariant AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens(
      bg: Color.lerp(bg, other.bg, t)!,
      lift: Color.lerp(lift, other.lift, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      faint: Color.lerp(faint, other.faint, t)!,
      line: Color.lerp(line, other.line, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      care: Color.lerp(care, other.care, t)!,
      cool: Color.lerp(cool, other.cool, t)!,
      warm: Color.lerp(warm, other.warm, t)!,
      shade: Color.lerp(shade, other.shade, t)!,
      dblShadow: Color.lerp(dblShadow, other.dblShadow, t)!,
    );
  }
}

/// 간격·크기 스케일 — design-system §3. 전 화면에서 이것만 쓴다.
abstract final class Space {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;

  /// 화면 좌우 여백. 넓은 화면 확장 아트보드만 40.
  static const screenH = 24.0;

  /// 최소 터치 타깃.
  static const tapMin = 48.0;
}

/// 모서리 — 버튼·입력은 거의 사각(2), 바텀시트 상단만 20. 카드가 없으므로
/// 카드 반경도 없다 (§3).
abstract final class Radii {
  static const control = Radius.circular(2);
  static const sheet = Radius.circular(20);
}

/// 「두 겹」 오프셋 — 3px, 흐림 0 (§1).
abstract final class Doubled {
  static const offset = Offset(3, 3);
  static const blur = 0.0;

  static List<Shadow> shadows(Color color) =>
      [Shadow(color: color, offset: offset, blurRadius: blur)];
}
