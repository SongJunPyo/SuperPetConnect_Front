class Notice {
  final int noticeIdx;
  final String title;
  final String content;
  final bool isImportant;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String authorName;
  final String authorEmail;

  Notice({
    required this.noticeIdx,
    required this.title,
    required this.content,
    required this.isImportant,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.authorName,
    required this.authorEmail,
  });

  factory Notice.fromJson(Map<String, dynamic> json) {
    return Notice(
      noticeIdx: json['notice_idx'],
      title: json['title'],
      content: json['content'],
      isImportant: json['is_important'],
      isActive: json['is_active'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      authorName: json['author_name'],
      authorEmail: json['author_email'],
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
      'author_name': authorName,
      'author_email': authorEmail,
    };
  }
}

class NoticeCreateRequest {
  final String title;
  final String content;
  final bool isImportant;

  NoticeCreateRequest({
    required this.title,
    required this.content,
    this.isImportant = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'is_important': isImportant,
    };
  }
}

class NoticeUpdateRequest {
  final String? title;
  final String? content;
  final bool? isImportant;
  final bool? isActive;

  NoticeUpdateRequest({
    this.title,
    this.content,
    this.isImportant,
    this.isActive,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    
    if (title != null) data['title'] = title;
    if (content != null) data['content'] = content;
    if (isImportant != null) data['is_important'] = isImportant;
    if (isActive != null) data['is_active'] = isActive;
    
    return data;
  }
}

class NoticeListResponse {
  final List<Notice> notices;
  final int totalCount;
  final int page;
  final int pageSize;

  NoticeListResponse({
    required this.notices,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  factory NoticeListResponse.fromJson(Map<String, dynamic> json) {
    return NoticeListResponse(
      notices: (json['notices'] as List)
          .map((notice) => Notice.fromJson(notice))
          .toList(),
      totalCount: json['total_count'],
      page: json['page'],
      pageSize: json['page_size'],
    );
  }
}