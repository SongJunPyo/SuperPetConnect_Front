// 웹 브라우저 알림 헬퍼 (모바일용 스텁)
// 모바일에서는 아무 동작도 하지 않음

import 'package:flutter/foundation.dart';

/// 웹 브라우저 알림 헬퍼 클래스 (스텁)
class WebNotificationHelper {
  /// 브라우저 알림 권한 요청 (모바일에서는 항상 false)
  static Future<bool> requestPermission() async {
    debugPrint('[WebNotification] 모바일 환경 - 스킵');
    return false;
  }

  /// 브라우저 알림 표시 (모바일에서는 아무것도 안 함)
  static void showNotification({
    required String title,
    required String body,
    String? icon,
  }) {
    debugPrint('[WebNotification-STUB] showNotification 호출됨 - 이 로그가 보이면 스텁 파일 사용 중!');
    // 모바일에서는 FCM 푸시를 사용하므로 아무것도 하지 않음
  }

  /// 알림 권한 상태 확인 (모바일에서는 항상 false)
  static bool get isPermissionGranted => false;
}
