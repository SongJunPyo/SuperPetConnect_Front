/// 칼럼 미리보기/요약 모델 (목록·대시보드용).
///
/// 백엔드 응답(`HospitalColumnResponse` 시리즈)에 `target_audience` 와
/// `is_important` 필드는 처음부터 존재하지 않음. 칼럼은 모든 사용자에게
/// 동일하게 노출되며 중요도 구분도 없음 (운영 정책 2026-04-28).
class ColumnPost {
  final int columnIdx;
  final String title;
  final String authorName;
  final String authorNickname;
  final String? hospitalProfileImage; // 병원 프로필 사진
  final int viewCount;
  final String contentPreview;
  final String? contentDelta; // Delta JSON 리치 텍스트
  final String? columnUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  ColumnPost({
    required this.columnIdx,
    required this.title,
    required this.authorName,
    required this.authorNickname,
    this.hospitalProfileImage,
    required this.viewCount,
    required this.contentPreview,
    this.contentDelta,
    this.columnUrl,
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
      hospitalProfileImage: json['hospital_profile_image'],
      viewCount: json['view_count'] ?? 0,
      contentPreview: json['content'] ?? '',
      contentDelta: json['content_delta'],
      columnUrl: json['column_url'] ?? json['columnUrl'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }
}
