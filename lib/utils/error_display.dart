// 에러 표시 공용 유틸리티
//
// 프로젝트 전반에서 반복되던 아래 패턴을 한 곳으로 통합:
//   ScaffoldMessenger.of(context).showSnackBar(
//     SnackBar(content: Text('실패: ${e.toString().replaceAll('Exception: ', '')}')),
//   );
//
// 서비스 레이어가 `throw Exception('메시지')` 형태로 에러를 던지는 기존 패턴을
// 그대로 수용하면서, "Exception: " 접두사 제거와 SnackBar 표시를 자동화.

import 'package:flutter/material.dart';

/// Exception 래핑된 에러 메시지에서 "Exception: " 접두사를 제거.
/// 이미 정제된 문자열이면 그대로 반환.
String formatErrorMessage(Object error) {
  final raw = error.toString();
  return raw.startsWith('Exception: ')
      ? raw.substring('Exception: '.length)
      : raw;
}

/// 에러 메시지를 SnackBar로 표시.
///
/// - [error]: `Exception`, `String`, 또는 `toString()`이 의미있는 모든 객체
/// - [prefix]: 메시지 앞에 붙일 고정 문구 (예: '삭제 실패')
/// - [backgroundColor]: 기본은 테마 기본값. 실패 강조가 필요하면 `Colors.red` 전달
///
/// ```dart
/// try { await service.deleteItem(); }
/// catch (e) { if (mounted) showErrorToast(context, e, prefix: '삭제 실패'); }
/// ```
void showErrorToast(
  BuildContext context,
  Object error, {
  String? prefix,
  Color? backgroundColor,
}) {
  final msg = formatErrorMessage(error);
  final text = prefix != null && prefix.isNotEmpty ? '$prefix: $msg' : msg;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text),
      backgroundColor: backgroundColor,
    ),
  );
}

/// 성공 메시지를 SnackBar로 표시 (대칭 유틸).
void showSuccessToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
