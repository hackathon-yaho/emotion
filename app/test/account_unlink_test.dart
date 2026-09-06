import 'package:flutter_test/flutter_test.dart';

import 'package:voice_journal/core/auth/account_unlink.dart';
import 'package:voice_journal/core/data/journal_repository.dart';
import 'package:voice_journal/core/storage/token_storage.dart';

/// F10-03 — 탈퇴할 때 카카오 연결까지 끊는다 (계약 v1.6 §2-3).
///
/// 웹은 인가 페이지로 나갔다가 **앱이 통째로 다시 뜬다.** 돌아온 코드가
/// 로그인용인지 탈퇴용인지 주소로는 구별할 수 없어, 나가기 전에 적어 둔
/// 표시로 가른다. 그 갈림이 틀리면 **로그인하려던 사람의 계정을 지운다** —
/// 되돌릴 수 없는 동작이라 경계를 테스트로 잠근다.
void main() {
  late _FakeStorage storage;
  late _FakeRepo repo;

  setUp(() {
    storage = _FakeStorage();
    repo = _FakeRepo();
  });

  Future<UnlinkOutcome> run(String url) => finishUnlinkIfReturned(
        storage: storage,
        repo: repo,
        here: Uri.parse(url),
      );

  test('표시가 없으면 아무것도 하지 않는다 — 로그인 복귀를 삼키지 않는다', () async {
    storage.pending = false;
    expect(await run('http://localhost:3000/?code=abc'), UnlinkOutcome.none);
    expect(repo.deleted, isEmpty);
  });

  test('코드를 들고 돌아오면 지우고 연결을 끊는다', () async {
    storage.pending = true;
    expect(await run('http://localhost:3000/?code=abc'), UnlinkOutcome.done);
    expect(repo.deleted, [
      ('abc', 'http://localhost:3000/'),
    ]);
    expect(storage.pending, isFalse, reason: '표시는 먼저 지운다');
  });

  test('배포 주소에서도 등록된 Redirect URI를 그대로 만든다', () async {
    storage.pending = true;
    await run('https://hackathon-yaho.github.io/emotion/?code=xyz');
    expect(repo.deleted.single.$2, 'https://hackathon-yaho.github.io/emotion/');
  });

  test('동의 화면에서 취소하면 **지우지 않는다**', () async {
    storage.pending = true;
    expect(await run('http://localhost:3000/?error=access_denied'),
        UnlinkOutcome.cancelled);
    expect(repo.deleted, isEmpty);
    expect(storage.pending, isFalse);
  });

  test('코드 없이 돌아와도 지우지 않는다', () async {
    storage.pending = true;
    expect(await run('http://localhost:3000/'), UnlinkOutcome.cancelled);
    expect(repo.deleted, isEmpty);
  });

  test('서버가 실패하면 failed — 기기를 비우라고 말하지 않는다', () async {
    storage.pending = true;
    repo.fail = true;
    expect(await run('http://localhost:3000/?code=abc'), UnlinkOutcome.failed);
    expect(storage.pending, isFalse,
        reason: '표시가 남으면 다음 로그인 복귀를 탈퇴로 오해한다');
  });
}

class _FakeStorage extends TokenStorage {
  bool pending = false;

  @override
  Future<bool> readPendingUnlink() async => pending;

  @override
  Future<void> markPendingUnlink() async => pending = true;

  @override
  Future<void> clearPendingUnlink() async => pending = false;
}

class _FakeRepo implements JournalRepository {
  final deleted = <(String?, String?)>[];
  bool fail = false;

  @override
  Future<void> deleteAccount({String? kakaoAuthCode, String? redirectUri}) async {
    if (fail) throw Exception('boom');
    deleted.add((kakaoAuthCode, redirectUri));
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
