import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 서체·타입 스케일 — design-system §3.
///
/// 두 종만 쓴다. 관찰 문장·화면 제목·109 번호는 **명조**, 나머지 전부는
/// **산세리프**. 셋째 서체를 넣지 않는다.
///
/// 산세리프는 문서상 Pretendard지만 Google Fonts에 없어 지금은 Noto Sans KR로
/// 대체한다(캔버스와 동일). `fonts/`에 Pretendard를 넣고 pubspec에 등록한 뒤
/// [sans]만 바꾸면 전 화면에 적용된다.
abstract final class AppType {
  static TextStyle sans({
    required double size,
    required Color color,
    FontWeight weight = FontWeight.w400,
    double height = 1.7,
    double? letterSpacing,
    List<Shadow>? shadows,
  }) {
    return GoogleFonts.notoSansKr(
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      shadows: shadows,
    );
  }

  /// 명조. 실제로 발견된 문장에만 쓴다 — 빈 상태에는 쓰지 않는다 (§7-11).
  static TextStyle serif({
    required double size,
    required Color color,
    FontWeight weight = FontWeight.w400,
    double height = 1.7,
    List<Shadow>? shadows,
  }) {
    return GoogleFonts.gowunBatang(
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: height,
      shadows: shadows,
    );
  }

  // ── 스케일 (§3) ─────────────────────────────────────────────

  /// 본문 16. **하한이다 — 15 이하로 내리지 않는다.**
  static const bodySize = 16.0;

  /// 보조·캡션 13~14.
  static const captionSize = 13.0;
  static const captionSizeLg = 14.0;

  /// 화면 제목 24~28.
  static const titleSize = 24.0;
  static const titleSizeLg = 28.0;

  /// 탭 라벨 · 차트 축·틱 라벨 12.
  static const labelSize = 12.0;

  /// 작은 라벨 — 자간 0.14em (§3).
  static const smallLabelSize = 11.0;
  static const smallLabelSpacing = 0.14 * smallLabelSize;
}
