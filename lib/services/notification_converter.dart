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

  /// FCM 타입을 관리자 알림 타입으로 변환
  static AdminNotificationType? getAdminNotificationTypeFromFCM(
    String fcmType,
  ) {
    switch (fcmType) {
      case 'new_user_registration':
        return AdminNotificationType.signupRequest;
      case 'new_post_approval':
        return AdminNotificationType.postApprovalRequest;
      case 'new_donation_application':
        return AdminNotificationType.donationApplicationRequest;
      case 'column_approval':
        return AdminNotificationType.columnApprovalRequest;
      case 'donation_completed':
        return AdminNotificationType.donationCompleted;
      default:
        return null;
    }
  }

  /// FCM 타입을 병원 알림 타입으로 변환
  static HospitalNotificationType? getHospitalNotificationTypeFromFCM(
    String fcmType,
  ) {
    switch (fcmType) {
      case 'donation_application':
      case 'new_donation_application_hospital':
        return HospitalNotificationType.donationApplication;
      case 'timeslot_filled':
        return HospitalNotificationType.timeslotFilled;
      case 'all_timeslots_filled':
        return HospitalNotificationType.allTimeslotsFilled;
      case 'donation_post_approved':
        return HospitalNotificationType.postApproved;
      case 'donation_post_rejected':
        return HospitalNotificationType.postRejected;
      case 'column_approved':
        return HospitalNotificationType.columnApproved;
      case 'column_rejected':
        return HospitalNotificationType.columnRejected;
      default:
        return null;
    }
  }

  /// FCM 타입을 사용자 알림 타입으로 변환
  static UserNotificationType? getUserNotificationTypeFromFCM(String fcmType) {
    switch (fcmType) {
      case 'account_approved':
      case 'account_rejected':
      case 'donation_application_approved':
      case 'donation_application_rejected':
        return UserNotificationType.systemNotice;
      default:
        return null;
    }
  }
}
