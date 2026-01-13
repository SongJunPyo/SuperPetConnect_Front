import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../models/notification_types.dart';

/// 알림 타입별 네비게이션 처리 서비스
///
/// 알림 클릭 시 적절한 페이지로 이동하는 로직을 중앙에서 관리합니다.
class NotificationNavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// 알림 클릭 시 적절한 페이지로 이동
  static void navigateToNotification(
    NotificationModel notification,
    UserType userType,
  ) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('[NotificationNavigationService] Navigator context 없음');
      return;
    }

    switch (userType) {
      case UserType.admin:
        _handleAdminNavigation(context, notification);
        break;
      case UserType.hospital:
        _handleHospitalNavigation(context, notification);
        break;
      case UserType.user:
        _handleUserNavigation(context, notification);
        break;
    }
  }

  /// 관리자 알림 네비게이션
  static void _handleAdminNavigation(
    BuildContext context,
    NotificationModel notification,
  ) {
    if (notification is AdminNotificationModel) {
      switch (notification.adminType) {
        case AdminNotificationType.signupRequest:
          Navigator.pushNamed(context, '/admin/signup-management');
          break;
        case AdminNotificationType.postApprovalRequest:
          Navigator.pushNamed(
            context,
            '/admin/post-management',
            arguments: {
              'initialTab': 'pending_approval',
              'highlightPost': notification.relatedId,
            },
          );
          break;
        case AdminNotificationType.donationApplicationRequest:
          Navigator.pushNamed(
            context,
            '/admin/donation-approval',
            arguments: {
              'highlightApplication': notification.relatedId,
            },
          );
          break;
        case AdminNotificationType.columnApprovalRequest:
          Navigator.pushNamed(context, '/admin/column-management');
          break;
        case AdminNotificationType.donationCompleted:
          Navigator.pushNamed(
            context,
            '/admin/post-management',
            arguments: {
              'initialTab': 'completed',
              'highlightPost': notification.relatedId,
            },
          );
          break;
        case AdminNotificationType.systemNotice:
          // 시스템 공지는 특별한 페이지 없음
          break;
      }
    }
  }

  /// 병원 알림 네비게이션
  static void _handleHospitalNavigation(
    BuildContext context,
    NotificationModel notification,
  ) {
    if (notification is HospitalNotificationModel) {
      switch (notification.hospitalType) {
        case HospitalNotificationType.postApproved:
        case HospitalNotificationType.postRejected:
          Navigator.pushReplacementNamed(
            context,
            '/hospital/dashboard',
            arguments: {'highlightPostId': notification.relatedId},
          );
          break;
        case HospitalNotificationType.recruitmentDeadline:
        case HospitalNotificationType.timeslotFilled:
        case HospitalNotificationType.allTimeslotsFilled:
          Navigator.pushReplacementNamed(
            context,
            '/hospital/post-check',
            arguments: {'highlightPostId': notification.relatedId},
          );
          break;
        case HospitalNotificationType.donationApplication:
          Navigator.pushReplacementNamed(
            context,
            '/hospital/post-check',
            arguments: {
              'highlightPostId': notification.relatedId,
              'showApplicants': true,
            },
          );
          break;
        case HospitalNotificationType.columnApproved:
        case HospitalNotificationType.columnRejected:
          Navigator.pushReplacementNamed(
            context,
            '/hospital/columns',
            arguments: {'highlightColumnId': notification.relatedId},
          );
          break;
        case HospitalNotificationType.systemNotice:
          Navigator.pushReplacementNamed(context, '/hospital/dashboard');
          break;
      }
    }
  }

  /// 사용자 알림 네비게이션
  static void _handleUserNavigation(
    BuildContext context,
    NotificationModel notification,
  ) {
    if (notification is UserNotificationModel) {
      Navigator.pushReplacementNamed(
        context,
        '/user/dashboard',
        arguments: {
          'highlightNotificationId': notification.notificationId,
          'initialTab': 'donation_history',
        },
      );
    }
  }

  /// FCM/로컬 알림 탭 시 네비게이션 처리
  static void handleNotificationTap({
    required String? notificationType,
    required Map<String, dynamic>? data,
    required UserType userType,
  }) {
    final context = navigatorKey.currentContext;
    if (context == null || notificationType == null) return;

    switch (userType) {
      case UserType.admin:
        _handleAdminNotificationTap(context, notificationType, data);
        break;
      case UserType.hospital:
        _handleHospitalNotificationTap(context, notificationType, data);
        break;
      case UserType.user:
        _handleUserNotificationTap(context, notificationType, data);
        break;
    }
  }

  static void _handleAdminNotificationTap(
    BuildContext context,
    String type,
    Map<String, dynamic>? data,
  ) {
    switch (type) {
      case 'new_user_registration':
        Navigator.pushNamed(context, '/admin/signup-management');
        break;
      case 'new_post_approval':
        Navigator.pushNamed(
          context,
          '/admin/post-management',
          arguments: {
            'initialTab': 'pending_approval',
            'highlightPost': _extractId(data, 'post_id'),
          },
        );
        break;
      case 'new_donation_application':
        Navigator.pushNamed(
          context,
          '/admin/donation-approval',
          arguments: {
            'highlightApplication': _extractId(data, 'application_id'),
          },
        );
        break;
      case 'column_approval':
        Navigator.pushNamed(context, '/admin/column-management');
        break;
      case 'donation_completed':
        Navigator.pushNamed(
          context,
          '/admin/post-management',
          arguments: {
            'initialTab': 'completed',
            'highlightPost': _extractId(data, 'post_id'),
          },
        );
        break;
      default:
        Navigator.pushNamed(context, '/admin/dashboard');
    }
  }

  static void _handleHospitalNotificationTap(
    BuildContext context,
    String type,
    Map<String, dynamic>? data,
  ) {
    switch (type) {
      case 'donation_application':
      case 'new_donation_application_hospital':
        Navigator.pushNamed(
          context,
          '/hospital/post-check',
          arguments: {
            'highlightPostId': _extractId(data, 'post_id'),
            'showApplicants': true,
          },
        );
        break;
      case 'timeslot_filled':
      case 'all_timeslots_filled':
        Navigator.pushNamed(
          context,
          '/hospital/post-check',
          arguments: {
            'highlightPostId': _extractId(data, 'post_id'),
          },
        );
        break;
      case 'donation_post_approved':
      case 'donation_post_rejected':
        Navigator.pushReplacementNamed(
          context,
          '/hospital/dashboard',
          arguments: {'highlightPostId': _extractId(data, 'post_id')},
        );
        break;
      case 'column_approved':
      case 'column_rejected':
        Navigator.pushReplacementNamed(
          context,
          '/hospital/columns',
          arguments: {'highlightColumnId': _extractId(data, 'column_id')},
        );
        break;
      default:
        Navigator.pushReplacementNamed(context, '/hospital/dashboard');
    }
  }

  static void _handleUserNotificationTap(
    BuildContext context,
    String type,
    Map<String, dynamic>? data,
  ) {
    switch (type) {
      case 'donation_application_approved':
      case 'donation_application_rejected':
        Navigator.pushReplacementNamed(
          context,
          '/user/dashboard',
          arguments: {
            'highlightPostId': _extractId(data, 'post_id'),
            'highlightApplicationId': _extractId(data, 'application_id'),
            'initialTab': 'donation_history',
          },
        );
        break;
      default:
        Navigator.pushReplacementNamed(context, '/user/dashboard');
    }
  }

  /// 데이터에서 ID 추출 (String 또는 int)
  static int? _extractId(Map<String, dynamic>? data, String key) {
    if (data == null) return null;

    final value = data[key];
    if (value == null) return null;

    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}
