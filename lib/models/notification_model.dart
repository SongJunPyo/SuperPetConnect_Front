import 'notification_types.dart';

// 기본 알림 모델 클래스
class NotificationModel {
  final int notificationId;
  final int userId;
  final int typeId;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isRead;
  final int priority;
  final Map<String, dynamic>? relatedData; // 관련 추가 데이터

  NotificationModel({
    required this.notificationId,
    required this.userId,
    required this.typeId,
    required this.title,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.isRead = false,
    this.priority = NotificationPriority.normal,
    this.relatedData,
  });

  // JSON에서 객체로 변환
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      notificationId: json['notification_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      typeId: json['type_id'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt:
          json['updated_at'] != null
              ? DateTime.tryParse(json['updated_at'])
              : null,
      isRead: json['is_read'] ?? false,
      priority: json['priority'] ?? NotificationPriority.normal,
      relatedData: json['related_data'],
    );
  }

  // 객체에서 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'notification_id': notificationId,
      'user_id': userId,
      'type_id': typeId,
      'title': title,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_read': isRead,
      'priority': priority,
      'related_data': relatedData,
    };
  }

  // 관련 데이터에서 ID 추출 (게시글 ID, 사용자 ID 등)
  int? get relatedId {
    if (relatedData == null) return null;
    final value =
        relatedData!['post_id'] ??
        relatedData!['user_id'] ??
        relatedData!['column_id'];
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  // 읽음 상태로 변경한 새 객체 생성
  NotificationModel markAsRead() {
    return NotificationModel(
      notificationId: notificationId,
      userId: userId,
      typeId: typeId,
      title: title,
      content: content,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isRead: true,
      priority: priority,
      relatedData: relatedData,
    );
  }

  @override
  String toString() {
    return 'NotificationModel(id: $notificationId, title: $title, isRead: $isRead)';
  }
}

// 관리자 전용 알림 모델
class AdminNotificationModel extends NotificationModel {
  final AdminNotificationType adminType;

  AdminNotificationModel({
    required super.notificationId,
    required super.userId,
    required super.title,
    required super.content,
    required super.createdAt,
    required this.adminType,
    super.updatedAt,
    super.isRead = false,
    super.relatedData,
  }) : super(
         typeId: NotificationTypeIds.adminIds[adminType]!,
         priority: NotificationPriority.adminPriorities[adminType]!,
       );

  factory AdminNotificationModel.fromJson(Map<String, dynamic> json) {
    final typeId = json['type_id'] ?? 0;
    final adminType =
        NotificationTypeIds.getAdminTypeById(typeId) ??
        AdminNotificationType.systemNotice;

    return AdminNotificationModel(
      notificationId: json['notification_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt:
          json['updated_at'] != null
              ? DateTime.tryParse(json['updated_at'])
              : null,
      isRead: json['is_read'] ?? false,
      adminType: adminType,
      relatedData: json['related_data'],
    );
  }

  // 알림 타입 이름 가져오기
  String get typeName => NotificationTypeNames.adminNames[adminType] ?? '';

  // 알림 아이콘 가져오기
  String get typeIcon => NotificationTypeIcons.adminIcons[adminType] ?? '🔔';

  // 읽음 상태로 변경한 새 객체 생성 (타입 유지)
  @override
  AdminNotificationModel markAsRead() {
    return AdminNotificationModel(
      notificationId: notificationId,
      userId: userId,
      title: title,
      content: content,
      createdAt: createdAt,
      adminType: adminType,
      updatedAt: DateTime.now(),
      isRead: true,
      relatedData: relatedData,
    );
  }
}

// 병원 전용 알림 모델
class HospitalNotificationModel extends NotificationModel {
  final HospitalNotificationType hospitalType;

  HospitalNotificationModel({
    required super.notificationId,
    required super.userId,
    required super.title,
    required super.content,
    required super.createdAt,
    required this.hospitalType,
    super.updatedAt,
    super.isRead = false,
    super.relatedData,
  }) : super(
         typeId: NotificationTypeIds.hospitalIds[hospitalType]!,
         priority: NotificationPriority.hospitalPriorities[hospitalType]!,
       );

  factory HospitalNotificationModel.fromJson(Map<String, dynamic> json) {
    final typeId = json['type_id'] ?? 0;
    final hospitalType =
        NotificationTypeIds.getHospitalTypeById(typeId) ??
        HospitalNotificationType.systemNotice;

    return HospitalNotificationModel(
      notificationId: json['notification_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt:
          json['updated_at'] != null
              ? DateTime.tryParse(json['updated_at'])
              : null,
      isRead: json['is_read'] ?? false,
      hospitalType: hospitalType,
      relatedData: json['related_data'],
    );
  }

  // 알림 타입 이름 가져오기
  String get typeName =>
      NotificationTypeNames.hospitalNames[hospitalType] ?? '';

  // 알림 아이콘 가져오기
  String get typeIcon =>
      NotificationTypeIcons.hospitalIcons[hospitalType] ?? '🔔';

  // 읽음 상태로 변경한 새 객체 생성 (타입 유지)
  @override
  HospitalNotificationModel markAsRead() {
    return HospitalNotificationModel(
      notificationId: notificationId,
      userId: userId,
      title: title,
      content: content,
      createdAt: createdAt,
      hospitalType: hospitalType,
      updatedAt: DateTime.now(),
      isRead: true,
      relatedData: relatedData,
    );
  }
}

// 사용자 전용 알림 모델
class UserNotificationModel extends NotificationModel {
  final UserNotificationType userType;

  UserNotificationModel({
    required super.notificationId,
    required super.userId,
    required super.title,
    required super.content,
    required super.createdAt,
    required this.userType,
    super.updatedAt,
    super.isRead = false,
    super.relatedData,
  }) : super(
         typeId: NotificationTypeIds.userIds[userType]!,
         priority: NotificationPriority.userPriorities[userType]!,
       );

  factory UserNotificationModel.fromJson(Map<String, dynamic> json) {
    final typeId = json['type_id'] ?? 0;
    final userType =
        NotificationTypeIds.getUserTypeById(typeId) ??
        UserNotificationType.systemNotice;

    return UserNotificationModel(
      notificationId: json['notification_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt:
          json['updated_at'] != null
              ? DateTime.tryParse(json['updated_at'])
              : null,
      isRead: json['is_read'] ?? false,
      userType: userType,
      relatedData: json['related_data'],
    );
  }

  // 알림 타입 이름 가져오기
  String get typeName => NotificationTypeNames.userNames[userType] ?? '';

  // 알림 아이콘 가져오기
  String get typeIcon => NotificationTypeIcons.userIcons[userType] ?? '🔔';

  // 읽음 상태로 변경한 새 객체 생성 (타입 유지)
  @override
  UserNotificationModel markAsRead() {
    return UserNotificationModel(
      notificationId: notificationId,
      userId: userId,
      title: title,
      content: content,
      createdAt: createdAt,
      userType: userType,
      updatedAt: DateTime.now(),
      isRead: true,
      relatedData: relatedData,
    );
  }
}

// 알림 목록 응답 모델
class NotificationListResponse {
  final List<NotificationModel> notifications;
  final int totalCount;
  final int unreadCount;
  final bool hasMore;

  NotificationListResponse({
    required this.notifications,
    required this.totalCount,
    required this.unreadCount,
    this.hasMore = false,
  });

  factory NotificationListResponse.fromJson(Map<String, dynamic> json) {
    final notificationsData = json['notifications'] as List? ?? [];
    final notifications =
        notificationsData
            .map((item) => NotificationModel.fromJson(item))
            .toList();

    return NotificationListResponse(
      notifications: notifications,
      totalCount: json['total_count'] ?? 0,
      unreadCount: json['unread_count'] ?? 0,
      hasMore: json['has_more'] ?? false,
    );
  }
}

// 알림 생성 헬퍼 클래스
class NotificationFactory {
  // 관리자 알림 생성
  static AdminNotificationModel createAdminNotification({
    required int notificationId,
    required int userId,
    required AdminNotificationType type,
    required String title,
    required String content,
    Map<String, dynamic>? relatedData,
    bool isRead = false,
    DateTime? createdAt,
  }) {
    return AdminNotificationModel(
      notificationId: notificationId,
      userId: userId,
      title: title,
      content: content,
      createdAt: createdAt ?? DateTime.now(),
      adminType: type,
      relatedData: relatedData,
      isRead: isRead,
    );
  }

  // 병원 알림 생성
  static HospitalNotificationModel createHospitalNotification({
    required int notificationId,
    required int userId,
    required HospitalNotificationType type,
    required String title,
    required String content,
    Map<String, dynamic>? relatedData,
    bool isRead = false,
    DateTime? createdAt,
  }) {
    return HospitalNotificationModel(
      notificationId: notificationId,
      userId: userId,
      title: title,
      content: content,
      createdAt: createdAt ?? DateTime.now(),
      hospitalType: type,
      relatedData: relatedData,
      isRead: isRead,
    );
  }

  // 사용자 알림 생성
  static UserNotificationModel createUserNotification({
    required int notificationId,
    required int userId,
    required UserNotificationType type,
    required String title,
    required String content,
    Map<String, dynamic>? relatedData,
    bool isRead = false,
    DateTime? createdAt,
  }) {
    return UserNotificationModel(
      notificationId: notificationId,
      userId: userId,
      title: title,
      content: content,
      createdAt: createdAt ?? DateTime.now(),
      userType: type,
      relatedData: relatedData,
      isRead: isRead,
    );
  }
}
