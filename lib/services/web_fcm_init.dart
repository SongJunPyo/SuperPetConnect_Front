// 웹 FCM 초기화 + 토큰 발급/등록 골격 (BE [B] merge 후 활성화 예정).
//
// 현재 상태: PREP — _enabled = false. getToken() 호출 안 함.
// BE의 단일 토큰 모델이 살아있는 동안 웹 토큰 발급 시 모바일 토큰을 덮어쓰는
// 사고를 방지하기 위한 가드 (BE 회신 메시지 명시 사항).
//
// 활성화 절차 (BE [B] merge ping 받은 후):
// 1. _enabled = true 토글
// 2. POST /api/user/fcm-token 호출 시 platform: 'web' 필드 추가 (BE [B]가 수용)
// 3. lib/services/unified_notification_manager.dart의 web 분기를
//    WebSocket → 본 모듈로 교체
// 4. lib/services/websocket_handler.dart는 BE [C] merge 후 제거
//
// VAPID 키는 dart-define으로 주입:
//   flutter run -d chrome --dart-define=FCM_VAPID_KEY=BCaX2N50yOe7GS8...
// SW 파일에 하드코딩 금지 (BE 가드).

import 'package:flutter/foundation.dart';

class WebFcmInit {
  // BE [B] merge 후 true로 토글. false인 동안 getToken / 토큰 등록 호출 차단.
  static const bool _enabled = false;

  // VAPID 공개키 — 빌드 시 dart-define으로 주입.
  // 누락 시 web push 등록 불가 (의도된 안전장치).
  static const String _vapidKey = String.fromEnvironment('FCM_VAPID_KEY');

  /// 웹 환경에서 FCM 초기화 + 토큰 등록.
  /// _enabled=false면 즉시 반환. 모바일에서는 호출되어도 kIsWeb 가드로 무시.
  static Future<void> initialize() async {
    if (!kIsWeb) return;
    if (!_enabled) {
      debugPrint('[WebFcmInit] PREP 단계 — _enabled=false. getToken 호출 스킵.');
      return;
    }
    if (_vapidKey.isEmpty) {
      debugPrint(
        '[WebFcmInit] VAPID 키 누락. '
        '--dart-define=FCM_VAPID_KEY=... 로 주입 필요.',
      );
      return;
    }

    // 활성화 시 추가 작업 (BE [B] merge 후 구현):
    // - Firebase.initializeApp(options: DefaultFirebaseOptions.web)
    // - FirebaseMessaging.instance.requestPermission()
    // - final token = await FirebaseMessaging.instance.getToken(vapidKey: _vapidKey)
    // - POST /api/user/fcm-token { fcm_token, platform: 'web' }
    // - FirebaseMessaging.instance.onTokenRefresh.listen(...)
    // - FirebaseMessaging.onMessage.listen(...) — 포그라운드
    // - SW의 postMessage 수신 → NotificationService.dispatchByType
  }

  /// 로그아웃 시 호출 — 현재 디바이스 토큰만 백엔드에서 제거.
  /// 활성화 후 구현 (BE의 DELETE /api/user/fcm-token endpoint 사용).
  static Future<void> deleteCurrentDeviceToken() async {
    if (!kIsWeb || !_enabled) return;
    // 활성화 시:
    // - final token = await FirebaseMessaging.instance.getToken(vapidKey: _vapidKey)
    // - DELETE /api/user/fcm-token { fcm_token: token }
  }
}
