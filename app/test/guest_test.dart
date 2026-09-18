import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:voice_journal/core/storage/token_storage.dart';

/// 둘러보기(`POST /api/auth/dev`, 계약 v1.14 §2-1-1)로 들어온 사용자는
/// **카카오 계정과 연결돼 있지 않다.**
///
/// 그 사람을 탈퇴에서 카카오 인가로 보내면 계정이 없는 사람은 **지우지도
/// 못하고**, 있는 사람은 **우리 앱과 연결된 적 없는 자기 계정을 인가**하게
/// 된다. 9/21 심사·투표에서 투표자가 자기 기록을 못 지우는 상태가 된다.
void main() {
  late _MemoryStorage store;
  late TokenStorage tokens;

  setUp(() {
    store = _MemoryStorage();
    tokens = TokenStorage(store);
  });

  test('표시가 없으면 둘러보기가 아니다 — 카카오 사용자가 기본이다', () async {
    expect(await tokens.readGuest(), isFalse);
  });

  test('둘러보기로 들어오면 남고, 카카오로 들어오면 지워진다', () async {
    await tokens.writeGuest(true);
    expect(await tokens.readGuest(), isTrue);
    await tokens.writeGuest(false);
    expect(await tokens.readGuest(), isFalse);
  });

  test('로그아웃·탈퇴하면 표시도 함께 지운다 — JWT와 같은 수명이다', () async {
    await tokens.writeJwt('jwt');
    await tokens.writeGuest(true);
    await tokens.clearAll();
    expect(await tokens.readGuest(), isFalse);
    expect(await tokens.readJwt(), isNull);
  });
}

/// `FlutterSecureStorage`를 흉내 낸 최소 저장소 — 플러그인 없이 돈다.
class _MemoryStorage implements FlutterSecureStorage {
  final _map = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _map[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _map.remove(key);
    } else {
      _map[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _map.remove(key);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
