// 웹 브라우저 알림 헬퍼
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'package:flutter/foundation.dart';

// 웹에서만 dart:html 사용 (package:web 마이그레이션 예정)
import 'dart:html' as html;

/// 웹 브라우저 알림 헬퍼 클래스
class WebNotificationHelper {
  static String _permission = 'default';

  /// 현재 브라우저 알림 권한 상태 확인 (권한 요청 없이 조회만)
  /// 반환값: 'default' (미요청), 'granted' (허용), 'denied' (거부)
  static String checkCurrentPermission() {
    if (!kIsWeb) return 'denied';

    try {
      _permission = html.Notification.permission ?? 'default';
      return _permission;
    } catch (e) {
      debugPrint('[WebNotification] 권한 상태 확인 실패: $e');
      return 'default';
    }
  }

  /// 브라우저 알림 권한 요청
  /// 반드시 사용자 클릭 이벤트 내에서 호출해야 브라우저가 허용합니다.
  static Future<bool> requestPermission() async {
    if (!kIsWeb) return false;

    try {
      _permission = await html.Notification.requestPermission();
      debugPrint('[WebNotification] 권한 상태: $_permission');
      return _permission == 'granted';
    } catch (e) {
      debugPrint('[WebNotification] 권한 요청 실패: $e');
      return false;
    }
  }

  /// 브라우저 알림 표시
  static void showNotification({
    required String title,
    required String body,
    String? icon,
  }) {
    if (!kIsWeb) return;

    try {
      if (_permission == 'granted') {
        _displayNotification(title: title, body: body, icon: icon);
      }
    } catch (e) {
      debugPrint('[WebNotification] 알림 표시 실패: $e');
    }
  }

  static void _displayNotification({
    required String title,
    required String body,
    String? icon,
  }) {
    try {
      final notification = html.Notification(
        title,
        body: body,
        icon: icon ?? '/icons/Icon-192.png',
      );

      // 알림 클릭 시 해당 탭으로 포커스
      notification.onClick.listen((event) {
        html.document.documentElement?.focus();
        notification.close();
      });

      // 5초 후 자동으로 닫기
      Future.delayed(const Duration(seconds: 5), () {
        notification.close();
      });
    } catch (e) {
      debugPrint('[WebNotification] 알림 생성 실패: $e');
    }
  }

  /// 알림 권한 허용 여부
  static bool get isPermissionGranted => _permission == 'granted';

  /// 알림 권한을 아직 요청하지 않았는지 여부
  static bool get isPermissionDefault => _permission == 'default';
}
