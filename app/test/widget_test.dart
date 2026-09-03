import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:voice_journal/core/theme/app_theme.dart';
import 'package:voice_journal/core/theme/tokens.dart';

void main() {
  group('디자인 토큰', () {
    test('다크·라이트가 서로 다른 값을 갖는다 (자동 반전이 아니다)', () {
      expect(AppTokens.dark.bg, isNot(AppTokens.light.bg));
      expect(AppTokens.dark.accent, isNot(AppTokens.light.accent));
      expect(AppTokens.dark.cool, isNot(AppTokens.light.cool));
    });

    test('두 채널 색은 서로 다르다 — 말한 내용과 목소리가 구분되어야 한다', () {
      expect(AppTokens.dark.cool, isNot(AppTokens.dark.warm));
      expect(AppTokens.light.cool, isNot(AppTokens.light.warm));
    });

    test('care는 accent와 다르다 — S07 전용 색이 동작 색과 섞이지 않는다', () {
      expect(AppTokens.dark.care, isNot(AppTokens.dark.accent));
      expect(AppTokens.light.care, isNot(AppTokens.light.accent));
    });

    test('care는 채널 색과도 다르다 — 위기 색이 목소리 색으로 읽히면 안 된다', () {
      expect(AppTokens.dark.care, isNot(AppTokens.dark.warm));
      expect(AppTokens.light.care, isNot(AppTokens.light.warm));
    });
  });

  group('테마', () {
    testWidgets('두 테마 모두 AppTokens 확장을 실어 보낸다', (tester) async {
      for (final theme in [AppTheme.dark(), AppTheme.light()]) {
        late AppTokens seen;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) {
                seen = context.tokens;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(seen, isNotNull);
      }
    });

    test('카드 그림자를 쓰지 않는다 — 카드가 없는 언어', () {
      expect(AppTheme.dark().cardTheme.elevation, 0);
      expect(AppTheme.light().cardTheme.elevation, 0);
    });
  });

  group('간격 스케일', () {
    test('전부 4의 배수다 (design-system §3)', () {
      for (final v in [
        Space.xs,
        Space.sm,
        Space.md,
        Space.lg,
        Space.xl,
        Space.xxl,
        Space.xxxl,
        Space.screenH,
        Space.tapMin,
      ]) {
        expect(v % 4, 0, reason: '$v 는 4의 배수가 아니다');
      }
    });

    test('최소 터치 타깃이 48이다', () {
      expect(Space.tapMin, greaterThanOrEqualTo(48.0));
    });
  });

  group('두 겹', () {
    test('오프셋은 정확히 3px이고 흐림이 없다 (design-system §1)', () {
      expect(Doubled.offset, const Offset(3, 3));
      expect(Doubled.blur, 0.0);
    });

    test('그림자는 한 겹만 만든다 — 두 벌을 겹치지 않는다', () {
      expect(Doubled.shadows(AppTokens.dark.dblShadow).length, 1);
    });
  });
}
