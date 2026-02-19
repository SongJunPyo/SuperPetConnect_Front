class ColumnPost {
  final int columnIdx;
  final String title;
  final String authorName;
  final String authorNickname;
  final int viewCount;
  final String contentPreview;
  final String? contentDelta; // Delta JSON 리치 텍스트
  final String? columnUrl;
  final bool isImportant;
  final int targetAudience; // 0: 전체, 1: 관리자, 2: 병원, 3: 사용자
  final DateTime createdAt;
  final DateTime updatedAt;

  ColumnPost({
    required this.columnIdx,
    required this.title,
    required this.authorName,
    required this.authorNickname,
    required this.viewCount,
    required this.contentPreview,
    this.contentDelta,
    this.columnUrl,
    required this.isImportant,
    required this.targetAudience,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ColumnPost.fromJson(Map<String, dynamic> json) {
    return ColumnPost(
      columnIdx: json['column_idx'] ?? 0,
      title: json['title'] ?? '',
      authorName: json['hospital_name'] ?? '병원',
      authorNickname:
          (json['hospital_nickname'] != null &&
                  json['hospital_nickname'].toString() != 'null' &&
                  json['hospital_nickname'].toString().isNotEmpty)
              ? json['hospital_nickname']
              : '닉네임 없음',
      viewCount: json['view_count'] ?? 0,
      contentPreview: json['content'] ?? '', // content_preview 제거됨, content 사용
      contentDelta: json['content_delta'],
      columnUrl: json['column_url'] ?? json['columnUrl'],
      isImportant: json['is_important'] ?? false,
      targetAudience: json['target_audience'] ?? json['targetAudience'] ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }
}
