import 'package:flutter_test/flutter_test.dart';

import 'package:voice_journal/core/session/spoken_end.dart';

/// **오탐이 더 비싸다.** 잘못 끊으면 털어놓던 대화가 닫힌다 — 놓치면 버튼이
/// 그대로 있다. 그래서 애매한 것은 전부 「아니다」쪽으로 둔다.
void main() {
  group('끝내자는 말로 본다', () {
    for (final s in [
      '응 오늘은 여기까지만 하자',
      '오늘은 여기까지 할게요',
      '대화 끝내자',
      '이제 그만하자',
      '그만할래',
      '오늘 여기까지',
      '이만 마칠게요',
      '대화 종료해줘',
    ]) {
      test('"$s"', () => expect(SpokenEnd.says(s), isTrue));
    }
  });

  group('끝내자는 말이 아니다 — 애매하면 넘어간다', () {
    for (final s in [
      // 대화가 아니라 **일** 이야기다. 여기서 끊으면 최악이다.
      '회의를 이제 그만 좀 했으면 좋겠어 팀장님한테 말도 못 하고',
      '야근을 그만하고 싶은데 그게 마음대로 되나',
      '이번 프로젝트는 여기까지 온 것만 해도 다행이라고 생각해',
      '그 사람이 이제 그만하자고 하더라고',
      '오늘은 회의가 너무 많았어',
      '',
      '음...',
    ]) {
      test('"$s"', () => expect(SpokenEnd.says(s), isFalse));
    }
  });

  // 꼬리는 `EviService._content`가 떼고 들어온다 (계약 v1.13). 여기서 다시
  // 확인하는 이유는, 그 단계가 빠지면 **음성 종료가 조용히 죽기** 때문이다 —
  // 문장이 길어져 16자 규칙에 걸리고 맺음도 못 읽는다.
  test('표정 꼬리가 붙어 있으면 못 읽는다 — 떼고 들어와야 한다', () {
    expect(SpokenEnd.says('그만할래 {calm, tired, interested}'), isFalse);
    expect(SpokenEnd.says('그만할래'), isTrue);
  });

  test('띄어쓰기가 고르지 않아도 읽는다 — 전사는 고르지 않다', () {
    expect(SpokenEnd.says('오늘은여기까지하자'), isTrue);
    expect(SpokenEnd.says('그 만 하 자'), isTrue);
  });
}
