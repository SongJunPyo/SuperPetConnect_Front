import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/config.dart';

class DashboardService {
  static String get baseUrl => Config.serverUrl;

  // 통합 메인 대시보드 API
  static Future<DashboardResponse> getDashboardData({
    int donationLimit = 10,
    int columnLimit = 10,
    int noticeLimit = 10,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/main/dashboard').replace(
        queryParameters: {
          'donation_limit': donationLimit.toString(),
          'column_limit': columnLimit.toString(),
          'notice_limit': noticeLimit.toString(),
        },
      );

      print('DEBUG: 통합 대시보드 API 요청 - URL: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
      );

      print('DEBUG: 통합 대시보드 응답 상태코드: ${response.statusCode}');
      print('DEBUG: 통합 대시보드 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return DashboardResponse.fromJson(data);
      } else {
        // API가 아직 구현되지 않은 경우 개별 API로 fallback
        return await _getFallbackDashboardData(
          donationLimit: donationLimit,
          columnLimit: columnLimit,
          noticeLimit: noticeLimit,
        );
      }
    } catch (e) {
      print('ERROR: 통합 대시보드 API 오류, fallback 사용: $e');
      // 에러 발생 시 개별 API로 fallback
      return await _getFallbackDashboardData(
        donationLimit: donationLimit,
        columnLimit: columnLimit,
        noticeLimit: noticeLimit,
      );
    }
  }

  // Fallback: 개별 API들을 사용하여 데이터 수집
  static Future<DashboardResponse> _getFallbackDashboardData({
    required int donationLimit,
    required int columnLimit,
    required int noticeLimit,
  }) async {
    try {
      print('DEBUG: Fallback API 사용 중...');

      // 각 API를 병렬로 호출
      final futures = await Future.wait([
        getPublicPosts(limit: donationLimit),
        getPublicColumns(limit: columnLimit),
        getPublicNotices(limit: noticeLimit),
      ]);

      return DashboardResponse(
        success: true,
        data: DashboardData(
          donations: futures[0] as List<DonationPost>,
          columns: futures[1] as List<ColumnPost>,
          notices: futures[2] as List<NoticePost>,
          statistics: DashboardStatistics(
            activeDonations: (futures[0] as List<DonationPost>).length,
            totalPublishedColumns: (futures[1] as List<ColumnPost>).length,
            totalActiveNotices: (futures[2] as List<NoticePost>).length,
          ),
        ),
      );
    } catch (e) {
      print('ERROR: Fallback API 오류: $e');
      throw Exception('대시보드 데이터 로드 실패: $e');
    }
  }

  // 개별 API: 헌혈 모집글
  static Future<List<DonationPost>> getPublicPosts({int limit = 10}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/public/posts').replace(
        queryParameters: {'limit': limit.toString()},
      );

      print('DEBUG: 헌혈 모집글 API 요청 - URL: $uri');
      final response = await http.get(uri);
      print('DEBUG: 헌혈 모집글 응답 상태코드: ${response.statusCode}');
      if (response.statusCode == 200) {
        print('DEBUG: 헌혈 모집글 응답 본문: ${response.body}');
      }
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        print('DEBUG: 헌혈 모집글 전체 응답 구조: $data');
        
        List<dynamic> postsData;
        if (data is Map<String, dynamic>) {
          // 서버가 객체로 래핑한 경우
          postsData = data['posts'] ?? data['data'] ?? data['donations'] ?? [];
        } else if (data is List) {
          // 서버가 직접 리스트로 반환한 경우
          postsData = data;
        } else {
          postsData = [];
        }
        
        final posts = postsData
            .map((item) => DonationPost.fromJson(item))
            .toList();
        print('DEBUG: 헌혈 모집글 파싱 결과: ${posts.length}개');
        return posts;
      } else {
        print('DEBUG: 헌혈 모집글 API 실패 - 상태코드: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('ERROR: 헌혈 모집글 API 오류: $e');
      return [];
    }
  }

  // 개별 API: 공개 칼럼
  static Future<List<ColumnPost>> getPublicColumns({int limit = 10}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/hospital/public/columns').replace(
        queryParameters: {
          'page': '1',
          'page_size': limit.toString(),
        },
      );

      print('DEBUG: 공개 칼럼 API 요청 - URL: $uri');
      final response = await http.get(uri);
      print('DEBUG: 공개 칼럼 응답 상태코드: ${response.statusCode}');
      print('DEBUG: 공개 칼럼 응답 본문: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final columns = (data['columns'] as List)
            .map((item) => ColumnPost.fromJson(item))
            .toList();
        print('DEBUG: 공개 칼럼 파싱 결과: ${columns.length}개');
        return columns;
      } else {
        print('DEBUG: 공개 칼럼 API 실패 - 상태코드: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('ERROR: 공개 칼럼 API 오류: $e');
      return [];
    }
  }

  // 개별 API: 공개 공지사항  
  static Future<List<NoticePost>> getPublicNotices({int limit = 10}) async {
    // 서버 제한: 최대 50
    if (limit > 50) {
      limit = 50;
      print('DEBUG: 공지사항 API limit을 50으로 제한');
    }
    try {
      final uri = Uri.parse('$baseUrl/api/public/notices/').replace(
        queryParameters: {'limit': limit.toString()},
      );

      print('DEBUG: 공개 공지사항 API 요청 - URL: $uri');
      final response = await http.get(uri);
      print('DEBUG: 공개 공지사항 응답 상태코드: ${response.statusCode}');
      print('DEBUG: 공개 공지사항 응답 본문: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        print('DEBUG: 공개 공지사항 전체 응답 구조: $data');
        print('DEBUG: 데이터 타입: ${data.runtimeType}');
        
        List<dynamic> noticesData;
        if (data is Map<String, dynamic>) {
          noticesData = data['notices'] ?? data['data'] ?? [];
        } else if (data is List) {
          noticesData = data;
        } else {
          noticesData = [];
        }
        
        final notices = noticesData
            .map((item) => NoticePost.fromJson(item))
            .toList();
        print('DEBUG: 공개 공지사항 파싱 결과: ${notices.length}개');
        
        // target_audience 확인용 디버그 로그
        for (var notice in notices) {
          print('DEBUG: 공지사항 "${notice.title}" - target_audience: ${notice.targetAudience}');
        }
        
        return notices;
      } else {
        print('DEBUG: 공개 공지사항 API 실패 - 상태코드: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('ERROR: 공개 공지사항 API 오류: $e');
      return [];
    }
  }

  // 개별 공지사항 상세 조회 API (조회수 자동 증가)
  static Future<NoticePost?> getNoticeDetail(int noticeIdx) async {
    try {
      final uri = Uri.parse('$baseUrl/api/public/notices/$noticeIdx');

      print('DEBUG: 공지사항 상세 API 요청 - URL: $uri');
      final response = await http.get(uri);
      print('DEBUG: 공지사항 상세 응답 상태코드: ${response.statusCode}');
      print('DEBUG: 공지사항 상세 응답 본문: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return NoticePost.fromJson(data);
      } else {
        print('DEBUG: 공지사항 상세 API 실패 - 상태코드: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('ERROR: 공지사항 상세 API 오류: $e');
      return null;
    }
  }
}

// 데이터 모델들
class DashboardResponse {
  final bool success;
  final DashboardData data;

  DashboardResponse({
    required this.success,
    required this.data,
  });

  factory DashboardResponse.fromJson(Map<String, dynamic> json) {
    return DashboardResponse(
      success: json['success'] ?? true,
      data: DashboardData.fromJson(json['data']),
    );
  }
}

class DashboardData {
  final List<DonationPost> donations;
  final List<ColumnPost> columns;
  final List<NoticePost> notices;
  final DashboardStatistics statistics;

  DashboardData({
    required this.donations,
    required this.columns,
    required this.notices,
    required this.statistics,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      donations: (json['donations'] as List)
          .map((item) => DonationPost.fromJson(item))
          .toList(),
      columns: (json['columns'] as List)
          .map((item) => ColumnPost.fromJson(item))
          .toList(),
      notices: (json['notices'] as List)
          .map((item) => NoticePost.fromJson(item))
          .toList(),
      statistics: DashboardStatistics.fromJson(json['statistics']),
    );
  }
}

class DonationPost {
  final int postId;
  final String title;
  final String hospitalName;
  final String location;
  final String animalType;
  final String bloodType;
  final String status;
  final bool isUrgent;
  final int viewCount;
  final DateTime createdAt;
  final DateTime? donationDate;
  final DateTime? updatedAt;

  DonationPost({
    required this.postId,
    required this.title,
    required this.hospitalName,
    required this.location,
    required this.animalType,
    required this.bloodType,
    required this.status,
    required this.isUrgent,
    required this.viewCount,
    required this.createdAt,
    this.donationDate,
    this.updatedAt,
  });

  factory DonationPost.fromJson(Map<String, dynamic> json) {
    print('DEBUG: DonationPost.fromJson - Raw JSON: $json');
    print('DEBUG: Title from API: "${json['title'] ?? 'NULL'}"');
    
    // types 필드로 긴급/장기 판단: 1=긴급, 2=장기
    bool isUrgentFromTypes = (json['types'] ?? 2) == 1;
    
    // registrationDate를 createdAt으로 사용
    DateTime createdAtFromReg = DateTime.tryParse(json['registrationDate'] ?? '') ?? DateTime.now();
    
    // donationDate 필드 직접 사용 (새 API에서 제공)
    DateTime? donationDateFromField = DateTime.tryParse(json['donationDate'] ?? '');
    
    // date를 donationDate로 사용 (fallback)
    DateTime? donationDateFromDate = DateTime.tryParse(json['date'] ?? '');
    
    return DonationPost(
      postId: json['post_id'] ?? json['id'] ?? 0,
      title: json['title'] ?? '',
      hospitalName: json['hospital_name'] ?? json['hospitalName'] ?? '',
      location: json['location'] ?? '',
      animalType: json['animal_type'] ?? json['animalType'] ?? '',
      bloodType: json['blood_type']?.toString() ?? json['bloodType']?.toString() ?? '',
      status: json['status'] ?? 'recruiting',
      isUrgent: json['is_urgent'] ?? json['isUrgent'] ?? isUrgentFromTypes,
      viewCount: json['view_count'] ?? json['viewCount'] ?? 0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) ?? createdAtFromReg : createdAtFromReg,
      donationDate: donationDateFromField ?? (json['donation_date'] != null ? DateTime.tryParse(json['donation_date']) : donationDateFromDate),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? json['updatedAt'] ?? ''),
    );
  }

  // 혈액형 표시용 헬퍼 메서드
  String get displayBloodType {
    if (bloodType.isEmpty || bloodType.toLowerCase() == 'null' || bloodType == 'null') {
      return 'ALL';
    }
    return bloodType;
  }

  // 헌혈 유형 확인 (긴급/정기)
  bool get isRegular => !isUrgent;
}

class ColumnPost {
  final int columnIdx;
  final String title;
  final String authorName;
  final int viewCount;
  final String contentPreview;
  final bool isImportant;
  final DateTime createdAt;

  ColumnPost({
    required this.columnIdx,
    required this.title,
    required this.authorName,
    required this.viewCount,
    required this.contentPreview,
    required this.isImportant,
    required this.createdAt,
  });

  factory ColumnPost.fromJson(Map<String, dynamic> json) {
    return ColumnPost(
      columnIdx: json['column_idx'] ?? 0,
      title: json['title'] ?? '',
      authorName: json['author_name'] ?? '',
      viewCount: json['view_count'] ?? 0,
      contentPreview: json['content_preview'] ?? json['content'] ?? '',
      isImportant: json['is_important'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

class NoticePost {
  final int noticeIdx;
  final String title;
  final bool isImportant;
  final String contentPreview;
  final int targetAudience;
  final String authorEmail;
  final String authorName;
  final int viewCount;
  final DateTime createdAt;

  NoticePost({
    required this.noticeIdx,
    required this.title,
    required this.isImportant,
    required this.contentPreview,
    required this.targetAudience,
    required this.authorEmail,
    required this.authorName,
    required this.viewCount,
    required this.createdAt,
  });

  factory NoticePost.fromJson(Map<String, dynamic> json) {
    print('DEBUG: NoticePost.fromJson - Raw JSON: $json');
    
    return NoticePost(
      noticeIdx: json['notice_idx'] ?? json['id'] ?? 0,
      title: json['title'] ?? '',
      isImportant: json['is_important'] ?? json['isImportant'] ?? false,
      contentPreview: json['content_preview'] ?? json['content'] ?? '',
      targetAudience: json['target_audience'] ?? json['targetAudience'] ?? 0,
      authorEmail: json['author_email'] ?? json['authorEmail'] ?? '',
      authorName: json['author_name'] ?? json['authorName'] ?? '관리자',
      viewCount: json['view_count'] ?? json['viewCount'] ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] ?? json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class DashboardStatistics {
  final int activeDonations;
  final int totalPublishedColumns;
  final int totalActiveNotices;

  DashboardStatistics({
    required this.activeDonations,
    required this.totalPublishedColumns,
    required this.totalActiveNotices,
  });

  factory DashboardStatistics.fromJson(Map<String, dynamic> json) {
    return DashboardStatistics(
      activeDonations: json['active_donations'] ?? 0,
      totalPublishedColumns: json['total_published_columns'] ?? 0,
      totalActiveNotices: json['total_active_notices'] ?? 0,
    );
  }
}