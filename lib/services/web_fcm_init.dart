// 웹 FCM 초기화 + 토큰 발급/등록 + 메시지 수신 (BE [C] merge sync).
//
// 본 파일은 dart:html을 사용하므로 mobile 빌드에서 컴파일 에러.
// UnifiedNotificationManager가 conditional import로 분기:
//   import 'web_fcm_init_stub.dart' if (dart.library.html) 'web_fcm_init.dart';
//
// VAPID 키는 dart-define으로 주입:
//   flutter run -d chrome --dart-define=FCM_VAPID_KEY=BCaX2N50yOe7GS8...
// SW 파일에 하드코딩 금지 (BE 가드).
//
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../models/notification_model.dart';
import '../utils/api_endpoints.dart';
import '../utils/config.dart';
import '../utils/preferences_manager.dart';
import 'auth_http_client.dart';
import 'notification_converter.dart';
import 'notification_service.dart';

class WebFcmInit {
  // VAPID 공개키 — 빌드 시 dart-define으로 주입.
  // 누락 시 web push 등록 불가 (의도된 안전장치).
  static const String _vapidKey = String.fromEnvironment('FCM_VAPID_KEY');

  static final StreamController<NotificationModel> _notificationController =
      StreamController<NotificationModel>.broadcast();

  static StreamSubscription<RemoteMessage>? _onMessageSub;
  static StreamSubscription<String>? _onTokenRefreshSub;
  static StreamSubscription<html.MessageEvent>? _swMessageSub;

  static String? _currentToken;
  static bool _initialized = false;

  /// 새 알림 스트림 — UnifiedNotificationManager가 구독
  static Stream<NotificationModel> get notificationStream =>
      _notificationController.stream;

  /// 웹 FCM 초기화 — 권한 요청, 토큰 발급, 백엔드 등록, 리스너 설정.
  static Future<void> initialize() async {
    if (!kIsWeb) return;
    if (_initialized) return;
    if (_vapidKey.isEmpty) {
      debugPrint(
        '[WebFcmInit] VAPID 키 누락. '
        '--dart-define=FCM_VAPID_KEY=... 로 주입 필요. 초기화 중단.',
      );
      return;
    }

    try {
      // 1. Service Worker 명시 등록 + activated 대기
      // firebase_messaging의 자동 등록에 의존하면 좀비 SW 상태(activated 도달 실패)로
      // PushManager.subscribe가 AbortError 발생할 수 있음. 명시 등록 + ready 대기로 해소.
      await _ensureServiceWorkerReady();

      // 2. 알림 권한 요청 (브라우저가 사용자에게 다이얼로그 표시)
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        debugPrint(
          '[WebFcmInit] 권한 거부됨: ${settings.authorizationStatus}',
        );
        return;
      }

      // 3. FCM 토큰 발급 (VAPID 키 필요)
      final token =
          await FirebaseMessaging.instance.getToken(vapidKey: _vapidKey);
      if (token == null || token.isEmpty) {
        debugPrint('[WebFcmInit] 토큰 발급 실패');
        return;
      }
      _currentToken = token;

      // 3. 백엔드 등록 (POST /api/user/fcm-token, platform: 'web')
      await _sendTokenToServer(token);

      // 4. 토큰 갱신 리스너
      _onTokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
        (newToken) {
          _currentToken = newToken;
          _sendTokenToServer(newToken);
        },
      );

      // 5. 포그라운드 메시지 리스너 — NotificationModel 변환 후 스트림 전달
      _onMessageSub = FirebaseMessaging.onMessage.listen((message) async {
        try {
          final notification = await NotificationConverter.fromFCM(message);
          if (notification != null) {
            _notificationController.add(notification);
          }
        } catch (e) {
          debugPrint('[WebFcmInit] onMessage 처리 실패: $e');
        }
      });

      // 6. SW의 notificationclick → postMessage 수신 → dispatchByType
      _setupSwMessageListener();

      _initialized = true;
      debugPrint('[WebFcmInit] 초기화 완료');
    } catch (e) {
      debugPrint('[WebFcmInit] 초기화 실패: $e');
    }
  }

  /// 로그인 직후 호출 — 토큰이 있으면 백엔드에 재등록.
  /// 신규 로그인 시 같은 fcm_token이 다른 account에 등록되어 있으면 BE가 소유 이전.
  static Future<void> updateTokenAfterLogin() async {
    if (!kIsWeb) return;
    final token = _currentToken;
    if (token != null) {
      await _sendTokenToServer(token);
      return;
    }
    // 토큰이 아직 없으면 (initialize 전 로그인 등) 다시 발급 시도
    if (_vapidKey.isEmpty) return;
    try {
      final newToken =
          await FirebaseMessaging.instance.getToken(vapidKey: _vapidKey);
      if (newToken != null && newToken.isNotEmpty) {
        _currentToken = newToken;
        await _sendTokenToServer(newToken);
      }
    } catch (e) {
      debugPrint('[WebFcmInit] 로그인 후 토큰 등록 실패: $e');
    }
  }

  /// 로그아웃 직전 호출 — 현재 디바이스 토큰만 백엔드에서 제거.
  /// 다른 디바이스 토큰(모바일 등)은 유지.
  static Future<void> deleteCurrentDeviceToken() async {
    if (!kIsWeb) return;
    final token = _currentToken;
    if (token == null) return;
    try {
      await AuthHttpClient.delete(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.fcmToken}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fcm_token': token}),
      );
    } catch (e) {
      debugPrint('[WebFcmInit] 토큰 삭제 실패: $e');
    }
  }

  /// 토큰을 백엔드에 등록 (platform: 'web' 명시).
  /// auth_token이 없으면 조용히 스킵 — 로그인 후 updateTokenAfterLogin()에서 재시도.
  /// 모바일 FCMHandler._sendTokenToServer와 동일 패턴.
  static Future<void> _sendTokenToServer(String token) async {
    final authToken = (await PreferencesManager.getAuthToken()) ?? '';
    if (authToken.isEmpty) {
      // 로그인 전이거나 토큰 만료 상태 — 등록 스킵, _currentToken은 보존되어
      // updateTokenAfterLogin() 호출 시 재시도됨
      return;
    }
    try {
      final response = await AuthHttpClient.post(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.fcmToken}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fcm_token': token, 'platform': 'web'}),
      );
      if (response.statusCode != 200) {
        debugPrint(
          '[WebFcmInit] 토큰 등록 실패: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[WebFcmInit] 토큰 등록 예외: $e');
    }
  }

  /// firebase-messaging-sw.js를 명시 등록하고 activated 상태까지 대기.
  ///
  /// firebase_messaging 패키지가 SW 자동 등록을 시도하지만 좀비 상태(Source/Status
  /// 비어있음, activated 미도달)에 빠지는 케이스 발생. 이 경우 PushManager.subscribe가
  /// AbortError로 실패해 토큰 발급 안 됨. 명시 등록 + sw.ready 대기로 활성 보장.
  static Future<void> _ensureServiceWorkerReady() async {
    final sw = html.window.navigator.serviceWorker;
    if (sw == null) {
      throw StateError('Service Worker not supported in this browser');
    }
    // 이미 등록되어 있으면 register가 기존 등록을 반환, 아니면 신규 등록
    await sw.register('/firebase-messaging-sw.js');
    // activated 상태까지 대기 (activating 단계가 끝날 때까지)
    await sw.ready;
  }

  /// SW의 notificationclick → window.postMessage 메시지 구독.
  /// firebase-messaging-sw.js의 notificationclick 핸들러가 client.postMessage로
  /// {source: 'fcm-sw', type: 'notification-click', data: {...}}를 보냄.
  static void _setupSwMessageListener() {
    _swMessageSub?.cancel();
    _swMessageSub = html.window.onMessage.listen((event) {
      try {
        final data = event.data;
        if (data is Map &&
            data['source'] == 'fcm-sw' &&
            data['type'] == 'notification-click') {
          final payload =
              Map<String, dynamic>.from(data['data'] as Map? ?? const {});
          NotificationService.dispatchByType(payload);
        }
      } catch (e) {
        debugPrint('[WebFcmInit] SW 메시지 처리 실패: $e');
      }
    });
  }

  /// 리소스 정리 — 로그아웃/dispose 시 호출.
  static void dispose() {
    _onMessageSub?.cancel();
    _onTokenRefreshSub?.cancel();
    _swMessageSub?.cancel();
    _initialized = false;
  }
}
