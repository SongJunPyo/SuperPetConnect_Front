// 웹 브라우저 알림 헬퍼
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'package:flutter/foundation.dart';

// 웹에서만 dart:html 사용 (package:web 마이그레이션 예정)
import 'dart:html' as html;

/// 웹 브라우저 알림 헬퍼 클래스
class WebNotificationHelper {
  static bool _permissionRequested = false;
  static String _permission = 'default';

  /// 브라우저 알림 권한 요청
  static Future<bool> requestPermission() async {
    if (!kIsWeb) return false;

    try {
      _permission = await html.Notification.requestPermission();
      _permissionRequested = true;
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
    debugPrint('[WebNotification] showNotification 호출 - kIsWeb: $kIsWeb');
    if (!kIsWeb) return;

    try {
      debugPrint(
        '[WebNotification] 권한 상태 확인 - requested: $_permissionRequested, permission: $_permission',
      );

      // 권한이 없으면 먼저 요청
      if (!_permissionRequested) {
        debugPrint('[WebNotification] 권한 미요청 상태, 권한 요청 시작');
        requestPermission().then((granted) {
          debugPrint('[WebNotification] 권한 요청 결과: $granted');
          if (granted) {
            _displayNotification(title: title, body: body, icon: icon);
          }
        });
        return;
      }

      if (_permission == 'granted') {
        debugPrint('[WebNotification] 권한 있음, 알림 표시 시도');
        _displayNotification(title: title, body: body, icon: icon);
      } else {
        debugPrint('[WebNotification] 권한 없음: $_permission');
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
    debugPrint('[WebNotification] _displayNotification 호출 - title: $title');
    try {
      final notification = html.Notification(
        title,
        body: body,
        icon: icon ?? '/icons/Icon-192.png',
      );
      debugPrint('[WebNotification] Notification 객체 생성 완료');

      // 알림 클릭 시 해당 탭으로 포커스
      notification.onClick.listen((event) {
        debugPrint('[WebNotification] 알림 클릭됨');
        // 현재 윈도우로 포커스 이동
        html.document.documentElement?.focus();
        notification.close();
      });

      // 5초 후 자동으로 닫기
      Future.delayed(const Duration(seconds: 5), () {
        notification.close();
      });

      debugPrint('[WebNotification] 브라우저 알림 표시 성공!');
    } catch (e) {
      debugPrint('[WebNotification] 알림 생성 실패: $e');
    }
  }

  /// 알림 권한 상태 확인
  static bool get isPermissionGranted => _permission == 'granted';
}
