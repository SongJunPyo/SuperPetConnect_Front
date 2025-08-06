class Notice {
  final int noticeIdx;
  final String title;
  final String content;
  final bool isImportant;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String authorEmail;
  final String authorName;
  final int? viewCount;
  final int targetAudience; // 0: all, 2: hospital, 3: user

  Notice({
    required this.noticeIdx,
    required this.title,
    required this.content,
    required this.isImportant,
    required this.isActive,
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
      title: json['title'],
      content: json['content'],
      isImportant: json['is_important'] ?? false,
      isActive: json['is_active'] ?? true,
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
      'title': title,
      'content': content,
      'is_important': isImportant,
      'is_active': isActive,
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
  final bool isImportant;
  final int targetAudience;

  NoticeCreateRequest({
    required this.title,
    required this.content,
    this.isImportant = false,
    this.targetAudience = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'is_important': isImportant,
      'target_audience': targetAudience,
    };
  }
}

class NoticeUpdateRequest {
  final String? title;
  final String? content;
  final bool? isImportant;
  final bool? isActive;
  final int? targetAudience;

  NoticeUpdateRequest({
    this.title,
    this.content,
    this.isImportant,
    this.isActive,
    this.targetAudience,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};

    if (title != null) data['title'] = title;
    if (content != null) data['content'] = content;
    if (isImportant != null) data['is_important'] = isImportant;
    if (isActive != null) data['is_active'] = isActive;
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
