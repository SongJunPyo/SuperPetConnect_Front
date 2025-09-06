// models/black_list_model.dart

class BlackList {
  final int blackUserIdx;
  final int accountIdx;
  final String userEmail;
  final String userName;
  final String userPhone;
  final String content;
  final int dDay;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  BlackList({
    required this.blackUserIdx,
    required this.accountIdx,
    required this.userEmail,
    required this.userName,
    required this.userPhone,
    required this.content,
    required this.dDay,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory BlackList.fromJson(Map<String, dynamic> json) {
    return BlackList(
      blackUserIdx: json['black_user_idx'],
      accountIdx: json['account_idx'],
      userEmail: json['user_email'] ?? '',
      userName: json['user_name'] ?? '',
      userPhone: json['user_phone'] ?? '',
      content: json['content'] ?? '',
      dDay: json['d_day'] ?? 0,
      isActive: json['is_active'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'black_user_idx': blackUserIdx,
      'account_idx': accountIdx,
      'user_email': userEmail,
      'user_name': userName,
      'user_phone': userPhone,
      'content': content,
      'd_day': dDay,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  // 정지 상태 체크
  bool get isSuspended => isActive && dDay > 0;

  // 남은 일수 텍스트
  String get remainingDaysText {
    if (!isActive) return '해제됨';
    if (dDay <= 0) return '해제 대기';
    return '$dDay일 남음';
  }

  // 상태 텍스트
  String get statusText {
    if (!isActive) return '해제';
    if (dDay <= 0) return '만료';
    return '정지';
  }
}

// 블랙리스트 등록 요청 모델
class BlackListCreateRequest {
  final int accountIdx;
  final String content;
  final int dDay;

  BlackListCreateRequest({
    required this.accountIdx,
    required this.content,
    required this.dDay,
  });

  Map<String, dynamic> toJson() {
    return {
      'account_idx': accountIdx,
      'content': content,
      'd_day': dDay,
    };
  }
}

// 블랙리스트 수정 요청 모델
class BlackListUpdateRequest {
  final String? content;
  final int? dDay;

  BlackListUpdateRequest({
    this.content,
    this.dDay,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    
    if (content != null) data['content'] = content;
    if (dDay != null) data['d_day'] = dDay;
    
    return data;
  }
}


// 사용자 블랙리스트 상태 확인 모델
class UserBlackListStatus {
  final bool isBlacklisted;
  final bool isSuspended;
  final int dDay;
  final String? content; // 관리자만 볼 수 있음

  UserBlackListStatus({
    required this.isBlacklisted,
    required this.isSuspended,
    required this.dDay,
    this.content,
  });

  factory UserBlackListStatus.fromJson(Map<String, dynamic> json) {
    return UserBlackListStatus(
      isBlacklisted: json['is_blacklisted'] ?? false,
      isSuspended: json['is_suspended'] ?? false,
      dDay: json['d_day'] ?? 0,
      content: json['content'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_blacklisted': isBlacklisted,
      'is_suspended': isSuspended,
      'd_day': dDay,
      if (content != null) 'content': content,
    };
  }

  // 남은 일수 텍스트
  String get remainingDaysText {
    if (!isSuspended) return '정상';
    if (dDay <= 0) return '해제 대기';
    return '$dDay일 남음';
  }

  // 상태 텍스트
  String get statusText {
    if (!isBlacklisted) return '정상';
    if (!isSuspended) return '해제됨';
    if (dDay <= 0) return '만료 대기';
    return '정지 중';
  }
}

// 블랙리스트 목록 응답 모델 (페이징 포함)
class BlackListResponse {
  final List<BlackList> blackLists;
  final int totalCount;
  final int page;
  final int pageSize;
  final bool hasNext;
  final bool hasPrevious;

  BlackListResponse({
    required this.blackLists,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.hasNext,
    required this.hasPrevious,
  });

  factory BlackListResponse.fromJson(Map<String, dynamic> json) {
    return BlackListResponse(
      blackLists: (json['black_lists'] as List? ?? [])
          .map((item) => BlackList.fromJson(item))
          .toList(),
      totalCount: json['total_count'] ?? 0,
      page: json['page'] ?? 1,
      pageSize: json['page_size'] ?? 10,
      hasNext: json['has_next'] ?? false,
      hasPrevious: json['has_previous'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'black_lists': blackLists.map((item) => item.toJson()).toList(),
      'total_count': totalCount,
      'page': page,
      'page_size': pageSize,
      'has_next': hasNext,
      'has_previous': hasPrevious,
    };
  }
}