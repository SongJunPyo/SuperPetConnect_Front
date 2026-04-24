import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../models/notification_types.dart';
import '../models/notification_mapping.dart';
import '../utils/preferences_manager.dart';

/// 서버/FCM 알림을 클라이언트 모델로 변환하는 유틸리티
///
/// FCM 메시지, WebSocket 메시지, REST API 응답을 통합된 NotificationModel로 변환합니다.
class NotificationConverter {
  /// FCM RemoteMessage를 NotificationModel로 변환
  static Future<NotificationModel?> fromFCM(RemoteMessage message) async {
    try {
      final userType = await getCurrentUserType();
      if (userType == null) return null;

      final data = message.data;
      final notificationType = data['type'] ?? '';

      // 서버 알림 타입 매핑 확인
      if (!ServerNotificationMapping.isNotificationForUserType(
        notificationType,
        userType,
      )) {
        return null;
      }

      final clientType = ServerNotificationMapping.getClientNotificationType(
        notificationType,
        userType,
      );
      if (clientType == null) return null;

      // 관련 데이터 파싱
      final relatedData = parseRelatedData(data);

      final title = message.notification?.title ?? '알림';
      final content = message.notification?.body ?? '';
      final notificationId = DateTime.now().millisecondsSinceEpoch;

      return createNotificationByUserType(
        userType: userType,
        clientType: clientType,
        notificationId: notificationId,
        title: title,
        content: content,
        relatedData: relatedData,
      );
    } catch (e) {
      debugPrint('[NotificationConverter] FCM 변환 실패: $e');
      return null;
    }
  }

  /// WebSocket/REST 응답을 NotificationModel로 변환
  static NotificationModel? fromServerData(
    Map<String, dynamic> data,
    UserType userType,
  ) {
    try {
      // 시스템 메시지 무시 (pong, connection_established 등)
      final ignoredTypes = ['pong', 'connection_established', 'ping'];
      if (ignoredTypes.contains(data['type'])) {
        return null;
      }

      final serverNotification = ServerNotificationData.fromJson(data);

      if (!ServerNotificationMapping.isNotificationForUserType(
        serverNotification.type,
        userType,
      )) {
        return null;
      }

      final clientType = ServerNotificationMapping.getClientNotificationType(
        serverNotification.type,
        userType,
      );
      if (clientType == null) return null;

      // notification_id 우선, 없으면 timestamp 사용
      final notificationId =
          serverNotification.notificationId ?? serverNotification.timestamp;

      return createNotificationByUserType(
        userType: userType,
        clientType: clientType,
        notificationId: notificationId,
        title: serverNotification.title,
        content: serverNotification.body,
        relatedData: serverNotification.data,
      );
    } catch (e) {
      debugPrint('[NotificationConverter] 서버 데이터 변환 실패: $e');
      return null;
    }
  }

  /// FCM 데이터에서 알림 타입 문자열 추출
  static String? getNotificationTypeFromFCM(RemoteMessage message) {
    return message.data['type'];
  }

  /// 현재 사용자 타입 가져오기
  static Future<UserType?> getCurrentUserType() async {
    try {
      final accountType = await PreferencesManager.getAccountType();
      return accountType != null
          ? UserTypeMapper.fromDbType(accountType)
          : null;
    } catch (e) {
      debugPrint('[NotificationConverter] 사용자 타입 조회 실패: $e');
      return null;
    }
  }

  /// 관련 데이터 파싱 (navigation, post_id 등)
  static Map<String, dynamic> parseRelatedData(Map<String, dynamic> data) {
    Map<String, dynamic> relatedData = {};

    // navigation 데이터 파싱
    if (data.containsKey('navigation')) {
      try {
        final navData =
            data['navigation'] is String
                ? jsonDecode(data['navigation'])
                : data['navigation'];
        if (navData is Map<String, dynamic>) {
          relatedData.addAll(navData);
        }
      } catch (e) {
        debugPrint('[NotificationConverter] navigation 파싱 실패: $e');
      }
    }

    // post_info 데이터 파싱
    if (data.containsKey('post_info')) {
      try {
        final postInfo =
            data['post_info'] is String
                ? jsonDecode(data['post_info'])
                : data['post_info'];
        if (postInfo is Map<String, dynamic>) {
          relatedData.addAll(postInfo);
        }
      } catch (e) {
        debugPrint('[NotificationConverter] post_info 파싱 실패: $e');
      }
    }

    // 기타 관련 데이터 추가
    final keysToExtract = [
      'post_idx',
      'post_id',
      'application_id',
      'user_id',
      'hospital_id',
      'column_id',
    ];

    for (final key in keysToExtract) {
      if (data.containsKey(key)) {
        relatedData[key] = data[key];
      }
    }

    return relatedData;
  }

  /// 알려지지 않은 서버 알림 타입에 대한 fallback NotificationModel 생성
  ///
  /// 백엔드가 새 NotificationType을 추가했는데 프론트 매핑이 따라가지 못하는 경우,
  /// title/body만이라도 사용자에게 표시하기 위한 safety-net. 유저타입별 `systemNotice`로
  /// 승격시켜 UI 목록에 노출합니다. silent drop 방지용.
  static NotificationModel createFallbackNotification({
    required UserType userType,
    required int notificationId,
    required String title,
    required String content,
    Map<String, dynamic>? relatedData,
  }) {
    final dynamic clientType;
    switch (userType) {
      case UserType.admin:
        clientType = AdminNotificationType.systemNotice;
        break;
      case UserType.hospital:
        clientType = HospitalNotificationType.systemNotice;
        break;
      case UserType.user:
        clientType = UserNotificationType.systemNotice;
        break;
    }
    return createNotificationByUserType(
      userType: userType,
      clientType: clientType,
      notificationId: notificationId,
      title: title,
      content: content,
      relatedData: relatedData,
    );
  }

  /// 사용자 타입별 NotificationModel 생성
  static NotificationModel createNotificationByUserType({
    required UserType userType,
    required dynamic clientType,
    required int notificationId,
    required String title,
    required String content,
    Map<String, dynamic>? relatedData,
  }) {
    switch (userType) {
      case UserType.admin:
        return NotificationFactory.createAdminNotification(
          notificationId: notificationId,
          userId: 0,
          type: clientType as AdminNotificationType,
          title: title,
          content: content,
          relatedData: relatedData,
        );
      case UserType.hospital:
        return NotificationFactory.createHospitalNotification(
          notificationId: notificationId,
          userId: 0,
          type: clientType as HospitalNotificationType,
          title: title,
          content: content,
          relatedData: relatedData,
        );
      case UserType.user:
        return NotificationFactory.createUserNotification(
          notificationId: notificationId,
          userId: 0,
          type: clientType as UserNotificationType,
          title: title,
          content: content,
          relatedData: relatedData,
        );
    }
  }

  // NOTE: FCM type → 클라이언트 enum 매핑의 단일 원천은 [ServerNotificationMapping]
  // (lib/models/notification_mapping.dart) 입니다. fromFCM / fromServerData 모두
  // 이 매핑을 통해 변환하며, 별도 switch 기반 helper는 유지하지 않습니다.
  // (과거 getAdminNotificationTypeFromFCM 등은 2026-04 리팩토링에서 제거되었습니다.)
}
