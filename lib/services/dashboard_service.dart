import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/config.dart';
import '../models/donation_post_date_model.dart';
import 'donation_date_service.dart';

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
      print('DEBUG: Base URL from Config: $baseUrl');
      
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      ).timeout(const Duration(seconds: 10));
      
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
      print('ERROR: 에러 타입: ${e.runtimeType}');
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
      print('DEBUG: Base URL from Config: $baseUrl');
      
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      ).timeout(const Duration(seconds: 10));
      
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
      print('ERROR: 에러 타입: ${e.runtimeType}');
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
  
  // 상세 게시글 정보 및 헌혁 날짜 조회 (with donation dates)
  static Future<DonationPost?> getDonationPostDetail(int postIdx) async {
    try {
      final uri = Uri.parse('$baseUrl/api/public/posts/$postIdx');

      print('DEBUG: 헌혁 게시글 상세 API 요청 - URL: $uri');
      final response = await http.get(uri);
      print('DEBUG: 헌혁 게시글 상세 응늵 상태코드: ${response.statusCode}');
      print('DEBUG: 헌혁 게시글 상세 응늵 본문: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        
        // 게시글 상세 정보로 DonationPost 생성
        final donationPost = DonationPost.fromJson(data);
        
        // 헌퀁 날짜 목록을 별도로 조회하여 추가
        try {
          final donationDates = await DonationDateService.getDonationDatesByPostIdx(postIdx);
          // 기존 DonationPost에 헌핲 날짜 정보 추가한 새로운 객체 생성
          return DonationPost(
            postIdx: donationPost.postIdx,
            title: donationPost.title,
            hospitalName: donationPost.hospitalName,
            location: donationPost.location,
            animalType: donationPost.animalType,
            emergencyBloodType: donationPost.emergencyBloodType,
            status: donationPost.status,
            types: donationPost.types,
            viewCount: donationPost.viewCount,
            createdAt: donationPost.createdAt,
            donationDate: donationPost.donationDate,
            updatedAt: donationPost.updatedAt,
            donationDates: donationDates, // 헌핲 날짜 정보 추가
          );
        } catch (e) {
          print('DEBUG: 헌핲 날짜 조회 실패, 기본 게시글 정보만 반환: $e');
          return donationPost; // 헌핲 날짜 조회 실패 시 기본 게시글 정보만 반환
        }
      } else {
        print('DEBUG: 헌핲 게시글 상세 API 실패 - 상태코드: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('ERROR: 헌핲 게시글 상세 API 오류: $e');
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
  final int postIdx;
  final String title;
  final String hospitalName;
  final String location;
  final int animalType;
  final String? emergencyBloodType;
  final int status;
  final int types;
  final int viewCount;
  final DateTime createdAt;
  final DateTime? donationDate;
  final DateTime? updatedAt;
  final List<DonationPostDate>? donationDates; // 헌혁 날짜 목록

  DonationPost({
    required this.postIdx,
    required this.title,
    required this.hospitalName,
    required this.location,
    required this.animalType,
    this.emergencyBloodType,
    required this.status,
    required this.types,
    required this.viewCount,
    required this.createdAt,
    this.donationDate,
    this.updatedAt,
    this.donationDates,
  });

  factory DonationPost.fromJson(Map<String, dynamic> json) {
    print('DEBUG: DonationPost.fromJson - Raw JSON: $json');
    print('DEBUG: Title from API: "${json['title'] ?? 'NULL'}"');
    
    // types 필드로 긴급/정기 판단: 0=긴급, 1=정기
    int typesValue = json['types'] ?? 1; // 기본값 정기(1)
    
    // registrationDate를 createdAt으로 사용
    DateTime createdAtFromReg = DateTime.tryParse(json['registrationDate'] ?? '') ?? DateTime.now();
    
    // donationDate 필드 직접 사용 (새 API에서 제공)
    DateTime? donationDateFromField = DateTime.tryParse(json['donationDate'] ?? '');
    
    // date를 donationDate로 사용 (fallback)
    DateTime? donationDateFromDate = DateTime.tryParse(json['date'] ?? '');
    
    // donation_dates 배열 처리
    List<DonationPostDate>? donationDatesList;
    if (json['donation_dates'] != null && json['donation_dates'] is List) {
      donationDatesList = (json['donation_dates'] as List)
          .map((item) => DonationPostDate.fromJson(item))
          .toList();
    }

    return DonationPost(
      postIdx: json['postIdx'] ?? json['post_id'] ?? json['id'] ?? 0,
      title: json['title'] ?? '',
      hospitalName: json['hospital_name'] ?? json['hospitalName'] ?? '',
      location: json['location'] ?? '',
      animalType: json['animalType'] ?? json['animal_type'] ?? 0,
      emergencyBloodType: json['emergencyBloodType'] ?? json['blood_type']?.toString() ?? json['bloodType']?.toString(),
      status: json['status'] ?? 0,
      types: typesValue,
      viewCount: json['view_count'] ?? json['viewCount'] ?? 0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) ?? createdAtFromReg : (json['createdDate'] != null ? DateTime.tryParse(json['createdDate']) ?? createdAtFromReg : createdAtFromReg),
      donationDate: donationDateFromField ?? (json['donation_date'] != null ? DateTime.tryParse(json['donation_date']) : donationDateFromDate),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? json['updatedAt'] ?? ''),
      donationDates: donationDatesList,
    );
  }

  // 혈액형 표시용 헬퍼 메서드
  String get displayBloodType {
    if (types == 0 && emergencyBloodType != null && emergencyBloodType!.isNotEmpty) {
      return emergencyBloodType!;
    }
    return '혈액형 무관';
  }

  bool get isUrgent => types == 0;
  
  // 헌혈 유형 확인 (긴급/정기)
  bool get isRegular => !isUrgent;
  
  String get typeText => types == 0 ? '긴급' : '정기';
  
  String get statusText {
    switch (status) {
      case 0: return '대기';
      case 1: return '승인';
      case 2: return '거절';
      case 3: return '마감';
      default: return '알 수 없음';
    }
  }
  
  String get animalTypeText => animalType == 0 ? '강아지' : '고양이';
  
  // 헌혁 날짜 표시용 헬퍼 메서드
  String get donationDatesText {
    if (donationDates == null || donationDates!.isEmpty) {
      return '예정된 헌혈 날짜가 없습니다.';
    }
    
    final sortedDates = List<DonationPostDate>.from(donationDates!)..sort((a, b) => a.donationDate.compareTo(b.donationDate));
    final dateTexts = sortedDates.map((date) => date.formattedDate).toList();
    
    if (dateTexts.length == 1) {
      return '헌혈 날짜: ${dateTexts.first}';
    } else if (dateTexts.length <= 3) {
      return '헌핲날짜: ${dateTexts.join(', ')}';
    } else {
      return '헌핲날짜: ${dateTexts.take(2).join(', ')} 외 ${dateTexts.length - 2}개';
    }
  }
  
  // 가장 빠른 헌혂 날짜 반환
  DateTime? get earliestDonationDate {
    if (donationDates == null || donationDates!.isEmpty) {
      return donationDate; // fallback으로 기존 donationDate 사용
    }
    
    final sortedDates = List<DonationPostDate>.from(donationDates!)..sort((a, b) => a.donationDate.compareTo(b.donationDate));
    return sortedDates.first.donationDate;
  }
}

class ColumnPost {
  final int columnIdx;
  final String title;
  final String authorName;
  final int viewCount;
  final String contentPreview;
  final bool isImportant;
  final DateTime createdAt;
  final DateTime updatedAt;

  ColumnPost({
    required this.columnIdx,
    required this.title,
    required this.authorName,
    required this.viewCount,
    required this.contentPreview,
    required this.isImportant,
    required this.createdAt,
    required this.updatedAt,
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
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
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
  final DateTime updatedAt;

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
    required this.updatedAt,
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
      updatedAt: DateTime.tryParse(json['updated_at'] ?? json['updatedAt'] ?? '') ?? DateTime.now(),
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