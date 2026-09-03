import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'network/api_client.dart';
import 'storage/token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((_) => TokenStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(tokens: ref.watch(tokenStorageProvider));
});

/// 테마 모드. 기본은 시스템 설정을 따르고 S06에서 수동 전환한다
/// (design-system §4).
final themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.system);

/// 대화가 진행 중인지.
///
/// JWT 만료(401)를 만나도 **대화 중이면 대화를 끊지 않는다** (F1-02). 인터셉터
/// 대신 이 신호를 보고 판단한다.
final inConversationProvider = StateProvider<bool>((_) => false);
