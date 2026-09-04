import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:voice_journal/core/router/routes.dart';
import 'package:voice_journal/core/theme/app_theme.dart';
import 'package:voice_journal/core/theme/tokens.dart';
import 'package:voice_journal/shared/widgets/app_frame.dart';

/// design-system §2 — 넓은 화면 폭 규칙은 **모든 라우트에 같게** 걸려야 한다.
/// 셸 라우트만 420으로 고정되고 셸 밖 화면은 전폭으로 늘어나던 문제를 막는다.
void main() {
  const marker = Key('frame-content');

  Future<double> measure(WidgetTester tester, String location, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: AppFrame(
          uri: Uri.parse(location),
          child: const SizedBox.expand(child: ColoredBox(key: marker, color: Color(0xFF000000))),
        ),
      ),
    );
    return tester.getSize(find.byKey(marker)).width;
  }

  group('프레임 폭', () {
    testWidgets('좁은 화면(<600)은 전폭을 쓴다', (tester) async {
      expect(await measure(tester, Routes.home, const Size(390, 844)), 390);
      expect(await measure(tester, Routes.conversation, const Size(390, 844)), 390);
    });

    testWidgets('넓은 화면에서 탭 화면과 셸 밖 화면이 같은 폭이다', (tester) async {
      const wide = Size(1280, 800);
      final tab = await measure(tester, Routes.home, wide);
      final outside = await measure(tester, Routes.conversation, wide);
      final settings = await measure(tester, Routes.settings, wide);
      final detail = await measure(tester, Routes.recordDetailOf('sess_1'), wide);
      final summary = await measure(tester, Routes.summary, wide);
      final evidence = await measure(tester, Routes.evidenceOf('obs_014'), wide);

      expect(tab, AppFrame.shellWidth);
      expect(outside, tab);
      expect(settings, tab);
      expect(detail, tab);
      expect(summary, tab);
      expect(evidence, tab);
    });

    testWidgets('S04 추세도 셸 폭이다 — 넓히지 않는다', (tester) async {
      // 한때 900까지 넓혔다. 근거가 "30일에서 점 마커가 살아남는 폭"이었는데
      // 모바일은 전폭이라 넓힐 수가 없어 그쪽에서 성립하지 않았다. 밀도는
      // 차트가 푼다 (TwoLineChart의 선택적 마커).
      final w = await measure(tester, Routes.trend, const Size(1280, 800));
      expect(w, AppFrame.shellWidth);
    });

    testWidgets('§2-1 예외 — 데모 모드는 오른쪽 패널만큼만 넓어진다', (tester) async {
      final w = await measure(
        tester,
        '${Routes.conversation}?demo=1',
        const Size(1280, 800),
      );
      expect(w, AppFrame.shellWidth + Space.xl + AppFrame.demoPanelWidth);
      expect(AppFrame.hasSidePanel(w), isTrue);
      // 좁은 화면에서는 오른쪽 패널을 쓰지 않는다.
      expect(AppFrame.hasSidePanel(390), isFalse);
    });

    testWidgets('예외 화면도 남는 폭이 좁으면 셸 폭 아래로 내려가지 않는다', (tester) async {
      final w = await measure(
        tester,
        '${Routes.conversation}?demo=1',
        const Size(620, 800),
      );
      expect(w, greaterThanOrEqualTo(AppFrame.shellWidth));
      expect(w, lessThanOrEqualTo(620));
    });
  });
}
