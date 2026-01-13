// 서버-프론트엔드 알림 타입 매핑 및 통합 관리

import 'notification_types.dart';

/// 서버에서 사용하는 알림 타입과 프론트엔드 타입 매핑
class ServerNotificationMapping {
  
  /// 서버 알림 타입 -> 프론트엔드 사용자별 타입 매핑
  static const Map<String, Map<UserType, dynamic>> serverToClientMapping = {
    
    // === 관리자가 받는 알림들 ===
    'new_user_registration': {
      UserType.admin: AdminNotificationType.signupRequest,
    },
    
    'new_post_approval': {
      UserType.admin: AdminNotificationType.postApprovalRequest, // 헌혈 게시글 승인 요청
    },
    
    'new_donation_application': {
      UserType.admin: AdminNotificationType.donationApplicationRequest, // 관리자는 헌혈 신청 승인 요청
    },

    // === 병원이 받는 알림들 ===
    'new_donation_application_hospital': {
      UserType.hospital: HospitalNotificationType.donationApplication, // 새 신청 알림
    },

    // 특정 시간대 모집 완료
    'timeslot_filled': {
      UserType.hospital: HospitalNotificationType.timeslotFilled,
    },

    // 모든 시간대 모집 완료
    'all_timeslots_filled': {
      UserType.hospital: HospitalNotificationType.allTimeslotsFilled,
    },

    // 헌혈 완료 보고 (병원 → 관리자)
    'donation_completed': {
      UserType.admin: AdminNotificationType.donationCompleted,
    },
    
    'donation_post_approved': {
      UserType.hospital: HospitalNotificationType.postApproved,
    },

    'donation_post_rejected': {
      UserType.hospital: HospitalNotificationType.postRejected,
    },

    'column_approved': {
      UserType.hospital: HospitalNotificationType.columnApproved,
    },

    'column_rejected': {
      UserType.hospital: HospitalNotificationType.columnRejected,
    },

    'donation_application': {
      UserType.hospital: HospitalNotificationType.donationApplication, // 새 헌혈 신청 접수
    },

    // === 관리자용 컬럼 승인 요청 ===
    'column_approval': {
      UserType.admin: AdminNotificationType.columnApprovalRequest,
    },

    // === 사용자가 받는 알림들 ===
    'account_approved': {
      UserType.user: UserNotificationType.systemNotice,
    },
    
    'account_rejected': {
      UserType.user: UserNotificationType.systemNotice,
    },
    
    'application_approved': {
      UserType.user: UserNotificationType.systemNotice,
    },

    'application_rejected': {
      UserType.user: UserNotificationType.systemNotice,
    },

    'donation_application_approved': {
      UserType.user: UserNotificationType.systemNotice,
    },

    'donation_application_rejected': {
      UserType.user: UserNotificationType.systemNotice,
    },
  };

  /// 프론트엔드 타입 -> 서버 타입 역매핑 (필요시 사용)
  static const Map<dynamic, String> clientToServerMapping = {
    AdminNotificationType.signupRequest: 'new_user_registration',
    AdminNotificationType.postApprovalRequest: 'new_donation_application',
    
    HospitalNotificationType.postApproved: 'donation_post_approved',
    HospitalNotificationType.columnApproved: 'column_approved',
    
    // 사용자는 주로 수신만 하므로 역매핑은 시스템 알림으로 통합
  };

  /// 서버 알림 타입으로부터 적절한 프론트엔드 타입 추출
  static dynamic getClientNotificationType(String serverType, UserType userType) {
    final mapping = serverToClientMapping[serverType];
    if (mapping == null) return null;
    return mapping[userType];
  }

  /// 서버 알림 타입이 해당 사용자 타입에게 해당하는지 확인
  static bool isNotificationForUserType(String serverType, UserType userType) {
    final mapping = serverToClientMapping[serverType];
    if (mapping == null) return false;
    return mapping.containsKey(userType);
  }

  /// 서버 알림 데이터로부터 NotificationModel 생성을 위한 우선순위 결정
  static int getNotificationPriority(String serverType) {
    switch (serverType) {
      case 'new_user_registration':
        return NotificationPriority.normal;
      case 'new_post_approval':
        return NotificationPriority.high;
      case 'new_donation_application':
        return NotificationPriority.high;
      case 'donation_post_approved':
      case 'column_approved':
        return NotificationPriority.high;
      case 'account_approved':
      case 'account_rejected':
        return NotificationPriority.urgent;
      case 'application_approved':
      case 'application_rejected':
        return NotificationPriority.high;
      default:
        return NotificationPriority.normal;
    }
  }

  /// 서버 알림 타입별 아이콘 매핑
  static String getNotificationIcon(String serverType) {
    switch (serverType) {
      case 'new_user_registration':
        return '👤';
      case 'new_donation_application':
      case 'new_donation_application_hospital':
        return '💉';
      case 'donation_post_approved':
        return '✅';
      case 'column_approved':
        return '📄';
      case 'account_approved':
        return '🎉';
      case 'account_rejected':
        return '❌';
      case 'application_approved':
        return '✅';
      case 'application_rejected':
        return '❌';
      default:
        return '🔔';
    }
  }
}

/// 서버로부터 받은 알림 데이터 구조
class ServerNotificationData {
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final int timestamp;
  final int? notificationId;

  ServerNotificationData({
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.timestamp,
    this.notificationId,
  });

  factory ServerNotificationData.fromJson(Map<String, dynamic> json) {
    // timestamp 파싱: String 또는 int 모두 처리
    int parseTimestamp(dynamic value) {
      if (value == null) return DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return DateTime.now().millisecondsSinceEpoch ~/ 1000;
    }

    // notification_id 파싱: String 또는 int 모두 처리
    int? parseNotificationId(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    return ServerNotificationData(
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      data: Map<String, dynamic>.from(json['data'] ?? {}),
      timestamp: parseTimestamp(json['timestamp']),
      notificationId: parseNotificationId(json['notification_id'] ?? json['id']),
    );
  }

  /// data에서 related_id 추출 (post_id, application_id, column_id 등)
  int? get relatedId {
    return data['post_id'] ?? data['application_id'] ?? data['column_id'] ?? data['user_id'];
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'title': title,
      'body': body,
      'data': data,
      'timestamp': timestamp,
      if (notificationId != null) 'notification_id': notificationId,
    };
  }
}