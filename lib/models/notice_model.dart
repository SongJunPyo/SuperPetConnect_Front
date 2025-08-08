class Notice {
  final int noticeIdx;
  final int accountIdx; // 작성자 계정 ID (FK)
  final String title;
  final String content;
  final bool noticeImportant; // 필드명 변경
  final bool noticeActive; // 필드명 변경
  final DateTime createdAt;
  final DateTime updatedAt;
  final String authorEmail; // JOIN을 통해 제공
  final String authorName; // JOIN을 통해 제공
  final int? viewCount;
  final int targetAudience; // 0: all, 1: hospital, 2: user

  Notice({
    required this.noticeIdx,
    required this.accountIdx,
    required this.title,
    required this.content,
    required this.noticeImportant,
    required this.noticeActive,
    required this.createdAt,
    required this.updatedAt,
    required this.authorEmail,
    required this.authorName,
    this.viewCount,
    required this.targetAudience,
  });

  factory Notice.fromJson(Map<String, dynamic> json) {
    return Notice(
      noticeIdx: json['notice_idx'],
      accountIdx: json['account_idx'],
      title: json['title'],
      content: json['content'],
      noticeImportant: json['notice_important'] ?? json['is_important'] ?? false, // 호환성을 위해 둘 다 지원
      noticeActive: json['notice_active'] ?? json['is_active'] ?? true, // 호환성을 위해 둘 다 지원
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      authorEmail: json['author_email'] ?? '',
      authorName: json['author_name'] ?? json['authorName'] ?? json['author_email']?.split('@')[0] ?? '관리자',
      viewCount: json['view_count'] ?? json['viewCount'],
      targetAudience: json['target_audience'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notice_idx': noticeIdx,
      'account_idx': accountIdx,
      'title': title,
      'content': content,
      'notice_important': noticeImportant,
      'notice_active': noticeActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'author_email': authorEmail,
      'author_name': authorName,
      'view_count': viewCount ?? 0,
      'target_audience': targetAudience,
    };
  }
}

class NoticeCreateRequest {
  final String title;
  final String content;
  final bool noticeImportant;
  final int targetAudience;

  NoticeCreateRequest({
    required this.title,
    required this.content,
    this.noticeImportant = false,
    this.targetAudience = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'notice_important': noticeImportant,
      'target_audience': targetAudience,
    };
  }
}

class NoticeUpdateRequest {
  final String? title;
  final String? content;
  final bool? noticeImportant;
  final bool? noticeActive;
  final int? targetAudience;

  NoticeUpdateRequest({
    this.title,
    this.content,
    this.noticeImportant,
    this.noticeActive,
    this.targetAudience,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};

    if (title != null) data['title'] = title;
    if (content != null) data['content'] = content;
    if (noticeImportant != null) data['notice_important'] = noticeImportant;
    if (noticeActive != null) data['notice_active'] = noticeActive;
    if (targetAudience != null) data['target_audience'] = targetAudience;

    return data;
  }
}

// NoticeListResponse는 더 이상 사용하지 않음 (새로운 API는 직접 배열 반환)
// class NoticeListResponse {
//   final List<Notice> notices;
//   final int totalCount;
//   final int page;
//   final int pageSize;
//
//   NoticeListResponse({
//     required this.notices,
//     required this.totalCount,
//     required this.page,
//     required this.pageSize,
//   });
//
//   factory NoticeListResponse.fromJson(Map<String, dynamic> json) {
//     return NoticeListResponse(
//       notices: (json['notices'] as List)
//           .map((notice) => Notice.fromJson(notice))
//           .toList(),
//       totalCount: json['total_count'],
//       page: json['page'],
//       pageSize: json['page_size'],
//     );
//   }
// }
