import '../utils/app_constants.dart';

class User {
  final int accountIdx;
  final String email;
  final String name;
  final String? nickname; // nickname은 null 허용
  final String phoneNumber;
  final String address;
  final double latitude;
  final double longitude;
  final int userType;
  final int status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? blacklistReason;
  final int? remainingDays;

  User({
    required this.accountIdx,
    required this.email,
    required this.name,
    this.nickname,
    required this.phoneNumber,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.userType,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.blacklistReason,
    this.remainingDays,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      accountIdx: json['account_idx'] ?? 0,
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      nickname: json['nickname'], // null 허용
      phoneNumber: json['phone_number'] ?? '',
      address: json['address'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      userType: json['user_type'] ?? 2,
      status: json['status'] ?? 0,
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'])
              : null,
      updatedAt:
          json['updated_at'] != null
              ? DateTime.tryParse(json['updated_at'])
              : null,
      blacklistReason: json['blacklist_reason'],
      remainingDays: json['remaining_days'],
    );
  }

  String get userTypeText {
    switch (userType) {
      case 0:
        return '관리자';
      case 1:
        return '병원';
      case 2:
        return '일반 사용자';
      default:
        return '알 수 없음';
    }
  }

  String get statusText => AppConstants.getAccountStatusText(status);

  bool get isActive => status == 1;
  bool get isSuspended => status == 2 || status == 3;
}

class UserListResponse {
  final List<User> users;
  final int totalCount;
  final int currentPage;
  final int totalPages;
  final bool hasNext;
  final bool hasPrevious;

  UserListResponse({
    required this.users,
    required this.totalCount,
    required this.currentPage,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrevious,
  });

  factory UserListResponse.fromJson(Map<String, dynamic> json) {
    return UserListResponse(
      users:
          (json['users'] as List<dynamic>?)
              ?.map((user) => User.fromJson(user))
              .toList() ??
          [],
      totalCount: json['total_count'] ?? 0,
      currentPage: json['current_page'] ?? 1,
      totalPages: json['total_pages'] ?? 1,
      hasNext: json['has_next'] ?? false,
      hasPrevious: json['has_previous'] ?? false,
    );
  }
}

class UserStats {
  final int totalUsers;
  final int activeUsers;
  final int suspendedUsers;
  final int pendingUsers;
  final int regularUsers;
  final int hospitalUsers;
  final int adminUsers;

  UserStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.suspendedUsers,
    required this.pendingUsers,
    required this.regularUsers,
    required this.hospitalUsers,
    required this.adminUsers,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      totalUsers: json['total_users'] ?? 0,
      activeUsers: json['active_users'] ?? 0,
      suspendedUsers: json['suspended_users'] ?? 0,
      pendingUsers: json['pending_users'] ?? 0,
      regularUsers: json['regular_users'] ?? 0,
      hospitalUsers: json['hospital_users'] ?? 0,
      adminUsers: json['admin_users'] ?? 0,
    );
  }
}

class BlacklistRequest {
  final int accountIdx;
  final String reason;
  final int suspensionDays;

  BlacklistRequest({
    required this.accountIdx,
    required this.reason,
    required this.suspensionDays,
  });

  Map<String, dynamic> toJson() {
    return {
      'account_idx': accountIdx,
      'reason': reason,
      'suspension_days': suspensionDays,
    };
  }
}
