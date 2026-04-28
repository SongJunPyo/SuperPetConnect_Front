import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// 공용 다이얼로그 헬퍼.
///
/// 단순 확인 (취소 + 확인)과 단순 알림 (확인 1개) 패턴이 코드베이스
/// 전체에 흩어져 있던 것을 하나로 통합. 폼 입력이 있는 다이얼로그나
/// 커스텀 콘텐츠가 필요한 경우는 직접 `AlertDialog`를 사용한다.
///
/// 사용 예:
/// ```dart
/// // 확인 다이얼로그 (취소/확인)
/// final ok = await AppDialog.confirm(
///   context,
///   title: '계정 삭제',
///   message: '정말 삭제하시겠습니까?',
///   confirmLabel: '삭제',
///   isDestructive: true,
/// );
/// if (ok != true) return;
///
/// // 알림 다이얼로그 (확인 1개)
/// await AppDialog.notice(
///   context,
///   title: '승인 실패',
///   message: '잠시 후 다시 시도해주세요.',
/// );
/// ```
class AppDialog {
  AppDialog._();

  /// 취소/확인 2버튼 다이얼로그. 사용자가 확인을 누르면 `true`,
  /// 취소/외부 영역 탭 시 `false` 또는 `null` 반환.
  ///
  /// [isDestructive]가 true면 확인 버튼이 빨강으로 강조된다 (삭제 등).
  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = '확인',
    String cancelLabel = '취소',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel),
          ),
          if (isDestructive)
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
              ),
              child: Text(confirmLabel),
            )
          else
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(confirmLabel),
            ),
        ],
      ),
    );
  }

  /// 확인 1버튼 다이얼로그. [onOk]가 있으면 확인 시 호출.
  static Future<void> notice(
    BuildContext context, {
    required String title,
    required String message,
    String okLabel = '확인',
    VoidCallback? onOk,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onOk?.call();
            },
            child: Text(okLabel),
          ),
        ],
      ),
    );
  }
}
