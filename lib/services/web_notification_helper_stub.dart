// 웹 브라우저 알림 헬퍼 (모바일용 스텁)
// 모바일에서는 아무 동작도 하지 않음

/// 웹 브라우저 알림 헬퍼 클래스 (스텁)
class WebNotificationHelper {
  /// 현재 브라우저 알림 권한 상태 확인 (모바일에서는 항상 'denied')
  static String checkCurrentPermission() => 'denied';

  /// 브라우저 알림 권한 요청 (모바일에서는 항상 false)
  static Future<bool> requestPermission() async => false;

  /// 브라우저 알림 표시 (모바일에서는 아무것도 안 함)
  static void showNotification({
    required String title,
    required String body,
    String? icon,
  }) {}

  /// 알림 권한 허용 여부 (모바일에서는 항상 false)
  static bool get isPermissionGranted => false;

  /// 알림 권한을 아직 요청하지 않았는지 여부 (모바일에서는 항상 false)
  static bool get isPermissionDefault => false;
}
