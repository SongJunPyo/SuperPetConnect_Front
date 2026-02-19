class NoticePost {
  final int noticeIdx;
  final String title;
  final int noticeImportant; // 0=일반(뱃지 OFF), 1=긴급(뱃지 ON)
  final String contentPreview;
  final String? noticeUrl;
  final int targetAudience;
  final String authorEmail;
  final String authorName;
  final String authorNickname;
  final int viewCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  NoticePost({
    required this.noticeIdx,
    required this.title,
    required this.noticeImportant,
    required this.contentPreview,
    this.noticeUrl,
    required this.targetAudience,
    required this.authorEmail,
    required this.authorName,
    required this.authorNickname,
    required this.viewCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NoticePost.fromJson(Map<String, dynamic> json) {
    final rawTargetAudience = json['target_audience'] ?? json['targetAudience'];
    final finalTargetAudience = rawTargetAudience ?? 0;

    return NoticePost(
      noticeIdx: json['notice_idx'] ?? json['id'] ?? 0,
      title: json['title'] ?? '',
      noticeImportant: _parseNoticeImportant(
        json['notice_important'],
      ), // 0=일반, 1=긴급
      contentPreview: json['content'] ?? '', // content_preview 제거됨, content 사용
      noticeUrl: json['notice_url'] ?? json['noticeUrl'],
      targetAudience: finalTargetAudience,
      authorEmail: json['author_email'] ?? json['authorEmail'] ?? '',
      authorName: json['author_name'] ?? '작성자',
      authorNickname:
          (json['author_nickname'] != null &&
                  json['author_nickname'].toString() != 'null' &&
                  json['author_nickname'].toString().isNotEmpty)
              ? json['author_nickname']
              : '닉네임 없음',
      viewCount: json['view_count'] ?? json['viewCount'] ?? 0,
      createdAt:
          DateTime.tryParse(json['created_at'] ?? json['createdAt'] ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at'] ?? json['updatedAt'] ?? '') ??
          DateTime.now(),
    );
  }

  // notice_important 필드 파싱 헬퍼 메서드 (bool/int 호환)
  static int _parseNoticeImportant(dynamic value) {
    if (value == null) return 0; // 기본값: 뱃지 숨김(0)
    if (value is int) return value;
    if (value is bool) return value ? 1 : 0; // true=뱃지 표시(1), false=뱃지 숨김(0)
    if (value is String) {
      if (value.toLowerCase() == 'true') return 1;
      if (value.toLowerCase() == 'false') return 0;
      return int.tryParse(value) ?? 0;
    }
    return 0; // fallback: 뱃지 숨김(0)
  }

  // notice_important 필드를 이용한 헬퍼 메서드 (1=뱃지 표시, 0=뱃지 숨김)
  bool get showBadge => noticeImportant == 1;
  String get badgeText => '공지';
}
