// 웹 FCM 초기화 stub — 모바일 빌드용 no-op.
//
// UnifiedNotificationManager가 conditional import로 web/mobile 분기:
//   import 'web_fcm_init_stub.dart' if (dart.library.html) 'web_fcm_init.dart';
//
// 모바일에서는 본 stub이 사용되어 호출은 가능하지만 동작 0.
// FCM은 모바일에서 FCMHandler가 별도 처리.

import 'dart:async';
import '../models/notification_model.dart';

class WebFcmInit {
  static final StreamController<NotificationModel> _controller =
      StreamController<NotificationModel>.broadcast();

  /// 알림 스트림 — 모바일에서는 빈 스트림 (이벤트 없음)
  static Stream<NotificationModel> get notificationStream => _controller.stream;

  /// FCM 초기화 — 모바일에서는 no-op
  static Future<void> initialize() async {}

  /// 로그인 직후 토큰 재등록 — 모바일에서는 no-op
  static Future<void> updateTokenAfterLogin() async {}

  /// 로그아웃 직전 토큰 삭제 — 모바일에서는 no-op
  static Future<void> deleteCurrentDeviceToken() async {}

  /// 리소스 정리 — 모바일에서는 no-op
  static void dispose() {}
}
