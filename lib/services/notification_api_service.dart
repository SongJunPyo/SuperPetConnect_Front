import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'auth_http_client.dart';
import '../models/notification_model.dart';
import '../models/notification_types.dart';
import '../models/notification_mapping.dart';
import '../utils/config.dart';
import '../utils/api_endpoints.dart';

/// 알림 REST API 서비스
///
/// 알림 목록 조회, 읽음 처리 등 REST API 호출을 담당합니다.
/// 실시간 알림은 NotificationProvider + UnifiedNotificationManager에서 처리합니다.
class NotificationApiService {

  // 관리자 알림 조회
  static Future<NotificationListResponse> getAdminNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.notificationsAdmin}?page=$page&limit=$limit'),
      );

      if (response.statusCode == 200) {
        final data = response.parseJson();
        return _parseServerNotificationResponse(data, UserType.admin);
      } else {
        debugPrint('[NotificationApiService] Admin 알림 조회 실패 - statusCode: ${response.statusCode}');
        // API 실패 시 빈 결과 반환
        return NotificationListResponse(
          notifications: [],
          totalCount: 0,
          unreadCount: 0,
          hasMore: false,
        );
      }
    } catch (e) {
      debugPrint('[NotificationApiService] Admin 알림 조회 오류: $e');
      // 네트워크 오류 시 빈 결과 반환
      return NotificationListResponse(
        notifications: [],
        totalCount: 0,
        unreadCount: 0,
        hasMore: false,
      );
    }
  }

  // 병원 알림 조회
  static Future<NotificationListResponse> getHospitalNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.notificationsHospital}?page=$page&limit=$limit'),
      );

      if (response.statusCode == 200) {
        final data = response.parseJson();
        return _parseServerNotificationResponse(data, UserType.hospital);
      } else {
        return NotificationListResponse(
          notifications: [],
          totalCount: 0,
          unreadCount: 0,
          hasMore: false,
        );
      }
    } catch (e) {
      return NotificationListResponse(
        notifications: [],
        totalCount: 0,
        unreadCount: 0,
        hasMore: false,
      );
    }
  }

  // 사용자 알림 조회
  static Future<NotificationListResponse> getUserNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.notificationsUser}?page=$page&limit=$limit'),
      );

      if (response.statusCode == 200) {
        final data = response.parseJson();
        return _parseServerNotificationResponse(data, UserType.user);
      } else {
        return NotificationListResponse(
          notifications: [],
          totalCount: 0,
          unreadCount: 0,
          hasMore: false,
        );
      }
    } catch (e) {
      return NotificationListResponse(
        notifications: [],
        totalCount: 0,
        unreadCount: 0,
        hasMore: false,
      );
    }
  }

  // 서버 알림 응답 파싱 (서버에서 역할별 필터링 완료)
  static NotificationListResponse _parseServerNotificationResponse(
    Map<String, dynamic> data,
    UserType userType,
  ) {
    final notificationsData = data['notifications'] as List? ?? [];
    final notifications = <NotificationModel>[];

    for (final item in notificationsData) {
      final notificationData = item as Map<String, dynamic>;

      try {
        // 서버 알림 데이터를 ServerNotificationData로 변환
        final serverNotification = ServerNotificationData.fromJson(
          notificationData,
        );

        // 서버에서 이미 역할별 필터링이 완료되었으므로 클라이언트 타입 매핑만 수행
        final clientType =
            ServerNotificationMapping.getClientNotificationType(
              serverNotification.type,
              userType,
            );

        if (clientType != null) {
          // 읽음 상태와 생성 시간 파싱
          final rawIsRead = notificationData['is_read'];
          final isRead =
              rawIsRead == true || rawIsRead == 1 || rawIsRead == '1';
          final createdAt =
              notificationData['created_at'] != null
                  ? DateTime.tryParse(
                    notificationData['created_at'].toString(),
                  )
                  : (serverNotification.timestamp > 0
                      ? DateTime.fromMillisecondsSinceEpoch(
                        serverNotification.timestamp * 1000,
                      )
                      : DateTime.now());

          // 사용자 타입별 알림 모델 생성
          NotificationModel? clientNotification;

          switch (userType) {
            case UserType.admin:
              clientNotification =
                  NotificationFactory.createAdminNotification(
                    notificationId:
                        notificationData['id'] ??
                        DateTime.now().millisecondsSinceEpoch,
                    userId: notificationData['user_id'] ?? 0,
                    type: clientType as AdminNotificationType,
                    title: serverNotification.title,
                    content: serverNotification.body,
                    relatedData: serverNotification.data,
                    isRead: isRead,
                    createdAt: createdAt,
                  );
              break;

            case UserType.hospital:
              clientNotification =
                  NotificationFactory.createHospitalNotification(
                    notificationId:
                        notificationData['id'] ??
                        DateTime.now().millisecondsSinceEpoch,
                    userId: notificationData['user_id'] ?? 0,
                    type: clientType as HospitalNotificationType,
                    title: serverNotification.title,
                    content: serverNotification.body,
                    relatedData: serverNotification.data,
                    isRead: isRead,
                    createdAt: createdAt,
                  );
              break;

            case UserType.user:
              clientNotification = NotificationFactory.createUserNotification(
                notificationId:
                    notificationData['id'] ??
                    DateTime.now().millisecondsSinceEpoch,
                userId: notificationData['user_id'] ?? 0,
                type: clientType as UserNotificationType,
                title: serverNotification.title,
                content: serverNotification.body,
                relatedData: serverNotification.data,
                isRead: isRead,
                createdAt: createdAt,
              );
              break;
          }

          // ignore: unnecessary_null_comparison
          if (clientNotification != null) {
            notifications.add(clientNotification);
          }
        }
      } catch (e) {
        debugPrint('[NotificationApiService] 알림 파싱 실패 - id: ${notificationData['id']}, error: $e');
        // 파싱 실패한 개별 알림은 무시하고 계속 진행
      }
    }

    return NotificationListResponse(
      notifications: notifications,
      totalCount: data['total_count'] ?? notifications.length,
      unreadCount:
          data['unread_count'] ?? notifications.where((n) => !n.isRead).length,
      hasMore: data['has_more'] ?? false,
    );
  }

  // 개별 알림 읽음 처리
  static Future<bool> markAsRead(int notificationId) async {
    try {
      final response = await AuthHttpClient.patch(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.notificationRead(notificationId)}'),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // 전체 알림 읽음 처리
  static Future<bool> markAllAsRead() async {
    try {
      final response = await AuthHttpClient.patch(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.notificationReadAll}'),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // 읽지 않은 알림 개수 조회
  static Future<int> getUnreadCount() async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.notificationUnreadCount}'),
      );

      if (response.statusCode == 200) {
        final data = response.parseJson();
        final count = data['unread_count'] ?? 0;
        return count;
      } else {}
    } catch (e) {
      // 알림 목록 처리 실패 시 로그 출력
      debugPrint('Failed to process notification list: $e');
    }

    return 0; // 오류 시 0 반환
  }

  // 개별 알림 삭제
  static Future<bool> deleteNotification(int notificationId) async {
    try {
      final response = await AuthHttpClient.delete(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.notificationDetail(notificationId)}'),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        debugPrint('[NotificationApiService] 알림 삭제 실패: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('[NotificationApiService] 알림 삭제 오류: $e');
      return false;
    }
  }

  // 다건 알림 삭제
  static Future<bool> deleteNotifications(List<int> notificationIds) async {
    try {
      final response = await AuthHttpClient.delete(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.notificationBatch}'),
        body: json.encode({'notification_ids': notificationIds}),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        debugPrint(
          '[NotificationApiService] 다건 알림 삭제 실패: ${response.statusCode}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('[NotificationApiService] 다건 알림 삭제 오류: $e');
      return false;
    }
  }

  // 전체 알림 삭제
  static Future<bool> deleteAllNotifications() async {
    try {
      final response = await AuthHttpClient.delete(Uri.parse('${Config.serverUrl}${ApiEndpoints.notificationAll}'));

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        debugPrint(
          '[NotificationApiService] 전체 알림 삭제 실패: ${response.statusCode}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('[NotificationApiService] 전체 알림 삭제 오류: $e');
      return false;
    }
  }
}
