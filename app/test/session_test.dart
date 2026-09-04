import 'package:flutter_test/flutter_test.dart';

import 'package:voice_journal/core/auth/kakao_login.dart';
import 'package:voice_journal/core/session/session_clock.dart';

void main() {
  group('F2-03 세션 길이', () {
    test('하드컷 60초 전에 표시한다', () {
      expect(SessionClock.nearEndAfter(420), const Duration(seconds: 360));
      expect(SessionClock.hardCutAfter(420), const Duration(seconds: 420));
    });

    test('남은 시간이 1분 이하면 즉시 표시한다 — 음수면 타이머가 안 걸린다', () {
      // 이어하기는 잔여 시간이 들어온다 (NFR-06). 40초 남은 세션에서
      // 60을 빼면 음수가 되어 "마무리됩니다"가 통째로 빠졌다.
      expect(SessionClock.nearEndAfter(40), Duration.zero);
      expect(SessionClock.nearEndAfter(0), Duration.zero);
    });

    test('음수 잔여 시간도 0으로 다룬다', () {
      expect(SessionClock.hardCutAfter(-5), Duration.zero);
    });

    test('앱이 보내는 사유는 user_end · hard_cut 둘뿐이다 (§2-5)', () {
      // timeout·resumed는 서버 내부 기록이라 앱이 보내지 않는다.
      expect(SessionClock.reasonUserEnd, 'user_end');
      expect(SessionClock.reasonHardCut, 'hard_cut');
    });
  });

  group('카카오 인가 (계약 v1.6 §2-1)', () {
    test('Redirect URI는 등록값과 같은 모양이어야 한다 — 디렉터리로 끝난다', () {
      expect(
        KakaoLogin.redirectUriFrom(
          Uri.parse('https://hackathon-yaho.github.io/emotion/index.html'),
        ).toString(),
        'https://hackathon-yaho.github.io/emotion/',
      );
      expect(
        KakaoLogin.redirectUriFrom(
          Uri.parse('http://localhost:3000/?code=abc#/today'),
        ).toString(),
        'http://localhost:3000/',
      );
      expect(
        KakaoLogin.redirectUriFrom(
          Uri.parse('https://hackathon-yaho.github.io/emotion/#/records/1'),
        ).toString(),
        'https://hackathon-yaho.github.io/emotion/',
      );
    });

    test('인가 코드를 주소에서 꺼낸다', () {
      expect(
        KakaoLogin.codeFrom(Uri.parse('http://localhost:3000/?code=abcd#/')),
        'abcd',
      );
      expect(KakaoLogin.codeFrom(Uri.parse('http://localhost:3000/')), isNull);
      expect(
        KakaoLogin.codeFrom(Uri.parse('http://localhost:3000/?code=')),
        isNull,
        reason: '빈 코드는 없는 것과 같다',
      );
    });

    test('사용자가 취소하면 error가 온다 — 오류로 다루지 않을 신호', () {
      expect(
        KakaoLogin.deniedIn(Uri.parse('http://localhost:3000/?error=access_denied')),
        isTrue,
      );
      expect(KakaoLogin.deniedIn(Uri.parse('http://localhost:3000/?code=x')), isFalse);
    });

    test('키가 없으면 인가 URL을 만들지 않는다 — 조용히 실패하지 않기 위해', () {
      // `--dart-define=KAKAO_REST_KEY`가 비어 있는 빌드에서는 null이다.
      // 화면은 이 null을 받아 문구로 안내한다.
      expect(
        KakaoLogin.authorizeUrl(redirectUri: Uri.parse('http://localhost:3000/')),
        isNull,
      );
    });
  });
}
