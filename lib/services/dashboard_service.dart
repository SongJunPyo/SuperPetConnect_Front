import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../utils/config.dart';
import '../models/donation_post_date_model.dart';

// 시간 포맷팅 유틸리티 클래스
class TimeFormatUtils {
  // "14:10" -> "오후 02:10" 형태로 변환
  static String formatTime(String time24) {
    if (time24.isEmpty) return '시간 미정';

    try {
      final parts = time24.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = parts[1];
        if (hour == 0) {
          return '오전 12:$minute';
        } else if (hour < 12) {
          return '오전 ${hour.toString().padLeft(2, '0')}:$minute';
        } else if (hour == 12) {
          return '오후 12:$minute';
        } else {
          return '오후 ${(hour - 12).toString().padLeft(2, '0')}:$minute';
        }
      }
    } catch (e) {
      // 파싱 실패 시 원본 값 반환
      return time24;
    }
    return '시간 미정';
  }

  // "14:10" 그대로 반환
  static String simple24HourTime(String time24) {
    return time24.isNotEmpty ? time24 : '미정';
  }
}

class DashboardService {
  static const int dashboardDonationLimit = 11;
  static const int dashboardColumnLimit = 11;
  static const int dashboardNoticeLimit = 11;
  static const int detailListPageSize = 15;

  static String get baseUrl => Config.serverUrl;

  // 통합 메인 대시보드 API
  static Future<DashboardResponse> getDashboardData({
    int donationLimit = dashboardDonationLimit,
    int columnLimit = dashboardColumnLimit,
    int noticeLimit = dashboardNoticeLimit,
  }) async {
    try {
      final queryParameters = <String, String>{};
      if (donationLimit != dashboardDonationLimit) {
        queryParameters['donation_limit'] = donationLimit.toString();
      }
      if (columnLimit != dashboardColumnLimit) {
        queryParameters['column_limit'] = columnLimit.toString();
      }
      if (noticeLimit != dashboardNoticeLimit) {
        queryParameters['notice_limit'] = noticeLimit.toString();
      }

      final uri = Uri.parse('$baseUrl/api/main/dashboard').replace(
        queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
      );

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

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
      throw Exception('대시보드 데이터 로드 실패: $e');
    }
  }

  // 개별 API: 헌혈 모집글
  static Future<List<DonationPost>> getPublicPosts({
    int limit = 11,
    String? region,
    String? subRegion,
  }) async {
    try {
      Map<String, String> queryParams = {};

      // 지역 필터링 파라미터 추가
      if (region != null && region.isNotEmpty && region != '전체 지역') {
        queryParams['region'] = region;
        if (subRegion != null && subRegion.isNotEmpty) {
          queryParams['sub_region'] = subRegion;
        }
      }

      final uri = Uri.parse(
        '$baseUrl/api/posts',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

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

        final posts =
            postsData
                .take(limit)
                .map((item) => DonationPost.fromJson(item))
                .toList();
        return posts;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // 개별 API: 공개 칼럼
  static Future<List<ColumnPost>> getPublicColumns({
    int limit = dashboardColumnLimit,
  }) async {
    if (kIsWeb) {
      return ColumnPost._getMockColumnData(limit);
    }

    try {
      final pageSize = limit.clamp(1, detailListPageSize).toInt();
      final response = await fetchColumnsPage(page: 1, pageSize: pageSize);
      return response.columns.take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<PaginatedColumnsResult> fetchColumnsPage({
    int page = 1,
    int pageSize = detailListPageSize,
  }) async {
    if (kIsWeb) {
      final columns = ColumnPost._getMockColumnData(pageSize);
      return PaginatedColumnsResult(
        columns: columns,
        pagination: PaginationMeta.singlePage(
          currentPage: page,
          pageSize: pageSize,
          totalCount: columns.length,
        ),
      );
    }

    final endpoints = [
      '$baseUrl/api/public/columns',
      '$baseUrl/api/columns',
      '$baseUrl/api/hospital/public/columns',
    ];

    final queryParameters = <String, String>{};
    if (page > 1) {
      queryParameters['page'] = page.toString();
    }
    if (pageSize != detailListPageSize) {
      queryParameters['page_size'] = pageSize.toString();
    }

    for (final endpoint in endpoints) {
      try {
        final uri = Uri.parse(endpoint).replace(
          queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
        );

        final response = await http
            .get(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Cache-Control': 'no-cache, no-store, must-revalidate',
                'Pragma': 'no-cache',
                'Expires': '0',
              },
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final rawData = jsonDecode(utf8.decode(response.bodyBytes));
          final columnsData =
              (rawData is Map<String, dynamic> ? rawData['columns'] : null) ??
              (rawData is List ? rawData : []) ??
              [];

          final paginationJson =
              rawData is Map<String, dynamic> ? rawData['pagination'] : null;

          final columns =
              (columnsData as List).map((item) {
                return ColumnPost.fromJson(
                  (item as Map).cast<String, dynamic>(),
                );
              }).toList();

          final pagination =
              paginationJson is Map<String, dynamic>
                  ? PaginationMeta.fromJson(paginationJson)
                  : PaginationMeta.derived(
                    currentPage: page,
                    pageSize: pageSize,
                    itemCount: columns.length,
                  );

          return PaginatedColumnsResult(
            columns: columns,
            pagination: pagination,
          );
        }
      } catch (e) {
        if (kIsWeb && e.toString().contains('XMLHttpRequest')) {
          break;
        }
        continue;
      }
    }

    throw Exception('칼럼 목록을 불러오지 못했습니다.');
  }

  // 개별 API: 공개 공지사항
  static Future<List<NoticePost>> getPublicNotices({
    int limit = dashboardNoticeLimit,
  }) async {
    // 웹에서 CORS 문제 임시 해결: 목 데이터 반환
    if (kIsWeb) {
      return NoticePost._getMockNoticeData(limit);
    }

    try {
      final pageSize = limit.clamp(1, detailListPageSize).toInt();
      final response = await fetchNoticesPage(page: 1, pageSize: pageSize);
      return response.notices.take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<PaginatedNoticesResult> fetchNoticesPage({
    int page = 1,
    int pageSize = detailListPageSize,
  }) async {
    if (kIsWeb) {
      final notices = NoticePost._getMockNoticeData(pageSize);
      return PaginatedNoticesResult(
        notices: notices,
        pagination: PaginationMeta.singlePage(
          currentPage: page,
          pageSize: pageSize,
          totalCount: notices.length,
        ),
      );
    }

    final endpoints = [
      '$baseUrl/api/public/notices',
      '$baseUrl/api/notices',
      '$baseUrl/api/public/notices/',
    ];

    final queryParameters = <String, String>{};
    if (page > 1) {
      queryParameters['page'] = page.toString();
    }
    if (pageSize != detailListPageSize) {
      queryParameters['page_size'] = pageSize.toString();
    }

    for (final endpoint in endpoints) {
      try {
        final uri = Uri.parse(endpoint).replace(
          queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
        );

        final response = await http
            .get(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Cache-Control': 'no-cache, no-store, must-revalidate',
                'Pragma': 'no-cache',
                'Expires': '0',
              },
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final rawData = jsonDecode(utf8.decode(response.bodyBytes));
          final noticesData =
              (rawData is Map<String, dynamic> ? rawData['notices'] : null) ??
              (rawData is List ? rawData : []) ??
              [];

          final paginationJson =
              rawData is Map<String, dynamic> ? rawData['pagination'] : null;

          final notices =
              (noticesData as List).map((item) {
                return NoticePost.fromJson(
                  (item as Map).cast<String, dynamic>(),
                );
              }).toList();

          final pagination =
              paginationJson is Map<String, dynamic>
                  ? PaginationMeta.fromJson(paginationJson)
                  : PaginationMeta.derived(
                    currentPage: page,
                    pageSize: pageSize,
                    itemCount: notices.length,
                  );

          return PaginatedNoticesResult(
            notices: notices,
            pagination: pagination,
          );
        }
      } catch (e) {
        if (kIsWeb && e.toString().contains('XMLHttpRequest')) {
          break;
        }
        continue;
      }
    }

    throw Exception('공지 목록을 불러오지 못했습니다.');
  }

  // 개별 공지사항 상세 조회 API (조회수 자동 증가)
  static Future<NoticePost?> getNoticeDetail(int noticeIdx) async {
    try {
      final uri = Uri.parse('$baseUrl/api/public/notices/$noticeIdx');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return NoticePost.fromJson(data);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // 상세 게시글 정보 및 헌혈 날짜 조회 (통합 데이터 사용)
  static Future<DonationPost?> getDonationPostDetail(int postIdx) async {
    try {
      final uri = Uri.parse('$baseUrl/api/public/posts/$postIdx');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        // 서버에서 통합된 데이터를 제공하므로 바로 DonationPost 생성
        final donationPost = DonationPost.fromJson(data);

        return donationPost;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}

// 데이터 모델들
class DashboardResponse {
  final bool success;
  final DashboardData data;

  DashboardResponse({required this.success, required this.data});

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
      donations:
          (json['donations'] as List)
              .map((item) => DonationPost.fromJson(item))
              .toList(),
      columns:
          (json['columns'] as List)
              .map((item) => ColumnPost.fromJson(item))
              .toList(),
      notices:
          (json['notices'] as List)
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
  final String? hospitalNickname; // 병원 닉네임 추가 (nullable로 변경)
  final String location;
  final String description; // 설명 추가
  final int animalType;
  final String? emergencyBloodType;
  final int status;
  final int types;
  final int viewCount;
  final DateTime createdAt; // 게시글 작성일 (post_created_date)
  final DateTime? donationDate; // 실제 헌혈 예정일 (donation_date)
  final DateTime? donationTime; // 실제 헌혈 시간 (donation_time)
  final DateTime? updatedAt;
  final List<DonationPostDate>? donationDates; // 헌혈 날짜 목록 (기존 호환성)
  final Map<String, List<Map<String, dynamic>>>?
  availableDates; // 서버의 available_dates 구조
  final int applicantCount; // 신청자 수
  final String? userName; // 병원 담당자 이름

  DonationPost({
    required this.postIdx,
    required this.title,
    required this.hospitalName,
    this.hospitalNickname, // 병원 닉네임 추가 (nullable)
    required this.location,
    required this.description, // 설명 추가
    required this.animalType,
    this.emergencyBloodType,
    required this.status,
    required this.types,
    required this.viewCount,
    required this.createdAt,
    this.donationDate,
    this.donationTime,
    this.updatedAt,
    this.donationDates,
    this.availableDates,
    required this.applicantCount,
    this.userName,
  });

  // 헌혈 예정일을 반환하는 getter (실제 헌혈 예정일 우선, 없으면 게시글 작성일)
  DateTime get date => donationDate ?? createdAt;

  // 게시글 작성일 표시용 getter
  DateTime get postCreatedDate => createdAt;

  // 실제 헌혈 일시 표시용 getter (날짜+시간 통합)
  DateTime? get actualDonationDateTime => donationTime ?? donationDate;

  factory DonationPost.fromJson(Map<String, dynamic> json) {
    // types 필드로 긴급/정기 판단: 0=긴급, 1=정기
    int typesValue = json['types'] ?? 1; // 기본값 정기(1)

    // 병원 정보 처리 - 여러 API 응답 구조 지원
    String hospitalName = '';
    String? hospitalNickname;
    String location = '';

    // 1. 최상위 레벨에서 직접 가져오기 (새로운 API 응답 방식)
    if (json['hospitalName'] != null &&
        json['hospitalName'].toString().trim().isNotEmpty) {
      hospitalName = json['hospitalName'].toString().trim();
    }

    if (json['location'] != null &&
        json['location'].toString().trim().isNotEmpty) {
      location = json['location'].toString().trim();
    }

    // 2. hospital 객체에서 가져오기 (기존 방식)
    if (json['hospital'] != null) {
      final hospital = json['hospital'] as Map<String, dynamic>;

      if (hospitalName.isEmpty) {
        hospitalName = hospital['name']?.toString() ?? '';
      }

      final nicknameValue = hospital['nickname'];
      if (nicknameValue != null &&
          nicknameValue.toString().trim().isNotEmpty &&
          nicknameValue.toString().toLowerCase() != 'null') {
        hospitalNickname = nicknameValue.toString().trim();
      }

      if (location.isEmpty) {
        location = hospital['address']?.toString() ?? '';
      }
    }

    // 3. 최상위 nickname, hospital_nickname 또는 hospitalNickname 필드 확인
    final topLevelNickname =
        json['nickname'] ??
        json['hospital_nickname'] ??
        json['hospitalNickname'];
    if (topLevelNickname != null &&
        topLevelNickname.toString().trim().isNotEmpty &&
        topLevelNickname.toString().toLowerCase() != 'null') {
      hospitalNickname = topLevelNickname.toString().trim();
    }

    // 닉네임이 없다면 hospitalName을 닉네임으로 사용 (임시 해결책)
    if (hospitalNickname == null &&
        hospitalName.isNotEmpty &&
        hospitalName != '병원') {
      hospitalNickname = hospitalName;
    }

    // 4. 기본값 설정
    if (hospitalName.isEmpty) {
      hospitalName = '병원';
    }
    if (location.isEmpty) {
      location = '주소 정보 없음';
    }

    // 디버그: 파싱된 병원 정보 출력

    // 새로운 서버 API 응답 구조에 따른 날짜 파싱
    DateTime? donationDate;
    DateTime? donationTime;

    // 1. 실제 헌혈 예정일 파싱 (donation_date - DATETIME 타입)
    if (json['donation_date'] != null &&
        json['donation_date'].toString().isNotEmpty &&
        json['donation_date'] != 'null') {
      try {
        donationDate = DateTime.parse(json['donation_date'].toString());
      } catch (e) {
        donationDate = null;
      }
    } else if (json['donationDate'] != null) {
      // 기존 호환성
      try {
        donationDate = DateTime.parse(json['donationDate'].toString());
      } catch (e) {
        donationDate = null;
      }
    }

    // 2. 실제 헌혈 시간 파싱 (donation_time - DATETIME 타입)
    if (json['donation_time'] != null &&
        json['donation_time'].toString().isNotEmpty &&
        json['donation_time'] != 'null') {
      try {
        donationTime = DateTime.parse(json['donation_time'].toString());
      } catch (e) {
        donationTime = null;
      }
    }

    // 3. 새로운 available_dates 구조 파싱 (단순한 Map 구조로 보관)
    Map<String, List<Map<String, dynamic>>>? availableDates;

    // camelCase (availableDates) 또는 snake_case (available_dates) 둘 다 확인
    final availableDatesField =
        json['availableDates'] ?? json['available_dates'];

    if (availableDatesField != null && availableDatesField is Map) {
      try {
        availableDates = <String, List<Map<String, dynamic>>>{};
        final datesMap = availableDatesField as Map<String, dynamic>;

        for (final dateEntry in datesMap.entries) {
          final dateStr = dateEntry.key; // "2025-09-16"
          final timeList = dateEntry.value as List<dynamic>;

          final timeSlots =
              timeList.map((timeJson) {
                return {
                  'post_times_idx': timeJson['post_times_idx'] ?? 0,
                  'time': timeJson['time'] ?? '',
                  'datetime': timeJson['datetime'] ?? '',
                };
              }).toList();

          availableDates[dateStr] = timeSlots;
        }

        // availableDates 처리 완료: ${availableDates.length} 개의 날짜
      } catch (e) {
        availableDates = null;
      }
    } else {
      // Fallback: timeRanges 배열을 available_dates로 변환
      if (json['timeRanges'] != null && json['timeRanges'] is List) {
        try {
          final timeRanges = json['timeRanges'] as List<dynamic>;
          if (timeRanges.isNotEmpty && donationDate != null) {
            // donationDate를 기준으로 단일 날짜 구조 생성
            final dateStr = donationDate.toIso8601String().split('T')[0];
            availableDates = <String, List<Map<String, dynamic>>>{};

            final timeSlots =
                timeRanges.map((timeRange) {
                  return {
                    'post_times_idx': timeRange['id'] ?? 0,
                    'time': timeRange['time'] ?? '',
                    'datetime':
                        '$dateStr${timeRange['time'] != null ? 'T${timeRange['time']}:00' : 'T00:00:00'}',
                  };
                }).toList();

            availableDates[dateStr] = timeSlots;
            // timeSlots 처리 완료
          }
        } catch (e) {
          // timeRanges 변환 실패 시 로그 출력
          debugPrint('Failed to convert timeRanges: $e');
        }
      }

      // 테스트용 임시 데이터 제거됨 - 서버 데이터만 사용
      availableDates = null;
    }

    // ID를 정수로 안전하게 변환
    int postIdx = 0;
    try {
      if (json['id'] != null) {
        if (json['id'] is String) {
          postIdx = int.tryParse(json['id']) ?? 0;
        } else if (json['id'] is int) {
          postIdx = json['id'];
        } else {
          postIdx = int.tryParse(json['id'].toString()) ?? 0;
        }
      }
    } catch (e) {
      postIdx = 0;
    }

    return DonationPost(
      postIdx: postIdx,
      title: json['title'] ?? '',
      hospitalName: hospitalName.isNotEmpty ? hospitalName : '병원',
      hospitalNickname: hospitalNickname, // 병원 닉네임 추가
      location: location,
      description:
          json['descriptions']?.toString() ??
          json['description']?.toString() ??
          '',
      animalType:
          json['animalType'] is String
              ? (json['animalType'] == 'dog' ? 0 : 1)
              : (json['animalType'] ?? 0),
      emergencyBloodType:
          json['emergency_blood_type']?.toString() ??
          json['bloodType']?.toString(),
      status: _parseStatus(json['status']),
      types: typesValue,
      viewCount: _parseIntSafely(json['viewCount']) ?? 0,
      createdAt: _parseCreatedAt(json),
      donationDate: donationDate,
      donationTime: donationTime,
      updatedAt: null,
      availableDates: availableDates,
      donationDates: null,
      applicantCount:
          _parseIntSafely(json['applicantCount'] ?? json['applicant_count']) ??
          0,
      userName: json['userName']?.toString() ?? json['user_name']?.toString(),
    );
  }

  // 안전한 정수 파싱 헬퍼 메서드
  static int? _parseIntSafely(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return int.tryParse(value.toString());
  }

  // status 파싱 헬퍼 메서드 (string과 int 모두 처리)
  static int _parseStatus(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      // 공개 API의 string status를 int로 변환
      switch (value.toLowerCase()) {
        case '대기':
          return 0;
        case '모집중':
        case '승인':
          return 1;
        case '거절':
          return 2;
        case '모집마감':
        case '마감':
          return 3;
        case '완료':
          return 3;
        case '취소':
          return 4;
        default:
          return int.tryParse(value) ?? 0;
      }
    }
    return 0;
  }

  // _parseAvailableDates 함수 제거됨 (이미 위에서 처리)

  // 게시글 작성일자 파싱 헬퍼 메서드 (새로운 서버 구조 적용)
  static DateTime _parseCreatedAt(Map<String, dynamic> json) {
    // 작성일자 파싱 우선순위: post_created_date > created_at > createdAt > registrationDate
    if (json['post_created_date'] != null &&
        json['post_created_date'].toString().isNotEmpty &&
        json['post_created_date'] != 'null') {
      try {
        final parsedDate = DateTime.parse(json['post_created_date'].toString());
        return parsedDate;
      } catch (e) {
        // 날짜 파싱 실패 시 다음 필드 시도
        debugPrint('Failed to parse date: $e');
      }
    }

    if (json['created_at'] != null &&
        json['created_at'].toString().isNotEmpty &&
        json['created_at'] != 'null') {
      try {
        final parsedDate = DateTime.parse(json['created_at'].toString());
        return parsedDate;
      } catch (e) {
        // 날짜 파싱 실패 시 다음 필드 시도
        debugPrint('Failed to parse date: $e');
      }
    }

    if (json['createdAt'] != null &&
        json['createdAt'].toString().isNotEmpty &&
        json['createdAt'] != 'null') {
      try {
        final parsedDate = DateTime.parse(json['createdAt'].toString());
        return parsedDate;
      } catch (e) {
        // 날짜 파싱 실패 시 다음 필드 시도
        debugPrint('Failed to parse date: $e');
      }
    }

    if (json['registrationDate'] != null &&
        json['registrationDate'].toString().isNotEmpty &&
        json['registrationDate'] != 'null') {
      try {
        final parsedDate = DateTime.parse(json['registrationDate'].toString());
        return parsedDate;
      } catch (e) {
        // 날짜 파싱 실패 시 다음 필드 시도
        debugPrint('Failed to parse date: $e');
      }
    }

    return DateTime.now(); // fallback
  }

  // 혈액형 표시용 헬퍼 메서드
  String get displayBloodType {
    if (types == 0 &&
        emergencyBloodType != null &&
        emergencyBloodType!.isNotEmpty) {
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
      case 0:
        return '대기';
      case 1:
        return '승인';
      case 2:
        return '거절';
      case 3:
        return '마감';
      default:
        return '알 수 없음';
    }
  }

  String get animalTypeText => animalType == 0 ? '강아지' : '고양이';

  // 헌혈 날짜 표시용 헬퍼 메서드
  String get donationDatesText {
    if (donationDates == null || donationDates!.isEmpty) {
      return '예정된 헌혈 날짜가 없습니다.';
    }

    final sortedDates = List<DonationPostDate>.from(donationDates!)
      ..sort((a, b) => a.donationDate.compareTo(b.donationDate));
    final dateTexts = sortedDates.map((date) => date.formattedDate).toList();

    if (dateTexts.length == 1) {
      return '헌혈 날짜: ${dateTexts.first}';
    } else if (dateTexts.length <= 3) {
      return '헌혈날짜: ${dateTexts.join(', ')}';
    } else {
      return '헌혈날짜: ${dateTexts.take(2).join(', ')} 외 ${dateTexts.length - 2}개';
    }
  }

  // 가장 빠른 헌혈 날짜 반환
  DateTime? get earliestDonationDate {
    if (donationDates == null || donationDates!.isEmpty) {
      return donationDate; // fallback으로 기존 donationDate 사용
    }

    final sortedDates = List<DonationPostDate>.from(donationDates!)
      ..sort((a, b) => a.donationDate.compareTo(b.donationDate));
    return sortedDates.first.donationDate;
  }
}

class ColumnPost {
  final int columnIdx;
  final String title;
  final String authorName;
  final String authorNickname;
  final int viewCount;
  final String contentPreview;
  final String? columnUrl;
  final bool isImportant;
  final DateTime createdAt;
  final DateTime updatedAt;

  ColumnPost({
    required this.columnIdx,
    required this.title,
    required this.authorName,
    required this.authorNickname,
    required this.viewCount,
    required this.contentPreview,
    this.columnUrl,
    required this.isImportant,
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
      columnUrl: json['column_url'] ?? json['columnUrl'],
      isImportant: json['is_important'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  // 웹 CORS 문제 해결용 목 데이터
  static List<ColumnPost> _getMockColumnData(int limit) {
    final mockColumns = [
      ColumnPost(
        columnIdx: 1,
        title: "반려동물 헌혈의 중요성",
        authorName: "서울동물병원",
        authorNickname: "서울동물병원",
        isImportant: false,
        contentPreview:
            "반려동물 헌혈은 응급상황에서 생명을 구하는 중요한 의료행위입니다. 건강한 반려동물의 헌혈이 다른 동물의 생명을 구할 수 있습니다...",
        columnUrl: "https://example.com/columns/1",
        viewCount: 245,
        createdAt: DateTime.now().subtract(Duration(days: 1)),
        updatedAt: DateTime.now().subtract(Duration(days: 1)),
      ),
      ColumnPost(
        columnIdx: 2,
        title: "헌혈 전 준비사항",
        authorName: "부산반려동물병원",
        authorNickname: "부산반려동물병원",
        isImportant: true,
        contentPreview:
            "헌혈을 위해서는 반려동물의 건강상태 확인이 필수입니다. 충분한 수분 섭취와 스트레스 관리가 중요합니다...",
        columnUrl: "https://example.com/columns/2",
        viewCount: 189,
        createdAt: DateTime.now().subtract(Duration(days: 2)),
        updatedAt: DateTime.now().subtract(Duration(days: 2)),
      ),
      ColumnPost(
        columnIdx: 3,
        title: "헌혈 후 관리 방법",
        authorName: "대구수의클리닉",
        authorNickname: "대구수의클리닉",
        isImportant: false,
        contentPreview: "헌혈 후에는 충분한 휴식과 영양 공급이 필요합니다. 24시간 동안 격한 운동은 피해주세요...",
        columnUrl: null,
        viewCount: 156,
        createdAt: DateTime.now().subtract(Duration(days: 3)),
        updatedAt: DateTime.now().subtract(Duration(days: 3)),
      ),
      ColumnPost(
        columnIdx: 4,
        title: "반려동물 혈액형 검사의 필요성",
        authorName: "광주동물병원",
        authorNickname: "광주동물병원",
        isImportant: false,
        contentPreview:
            "헌혈을 위해서는 정확한 혈액형 검사가 필수입니다. DEA 1.1 검사를 통해 안전한 헌혈이 가능합니다...",
        columnUrl: "https://example.com/columns/4",
        viewCount: 198,
        createdAt: DateTime.now().subtract(Duration(days: 4)),
        updatedAt: DateTime.now().subtract(Duration(days: 4)),
      ),
    ];

    return mockColumns.take(limit).cast<ColumnPost>().toList();
  }
}

class NoticePost {
  final int noticeIdx;
  final String title;
  final int noticeImportant; // 0=긴급, 1=정기 (int로 변경)
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
    return NoticePost(
      noticeIdx: json['notice_idx'] ?? json['id'] ?? 0,
      title: json['title'] ?? '',
      noticeImportant: _parseNoticeImportant(
        json['notice_important'],
      ), // 0=긴급, 1=정기
      contentPreview: json['content'] ?? '', // content_preview 제거됨, content 사용
      noticeUrl: json['notice_url'] ?? json['noticeUrl'],
      targetAudience: json['target_audience'] ?? json['targetAudience'] ?? 0,
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
    if (value == null) return 1; // 기본값: 뱃지 숨김(1)
    if (value is int) return value;
    if (value is bool) return value ? 0 : 1; // true=뱃지 표시(0), false=뱃지 숨김(1)
    if (value is String) {
      if (value.toLowerCase() == 'true') return 0;
      if (value.toLowerCase() == 'false') return 1;
      return int.tryParse(value) ?? 1;
    }
    return 1; // fallback: 뱃지 숨김(1)
  }

  // notice_important 필드를 이용한 헬퍼 메서드 (0=뱃지 표시, 1=뱃지 숨김)
  bool get showBadge => noticeImportant == 0;
  String get badgeText => '공지';

  static List<NoticePost> _getMockNoticeData(int limit) {
    final mockNotices = [
      NoticePost(
        noticeIdx: 1,
        title: "시스템 점검 안내",
        authorName: "관리자",
        authorEmail: "admin@superpetconnect.com",
        authorNickname: "관리자",
        noticeImportant: 0,
        targetAudience: 0,
        noticeUrl: "https://example.com/system-check",
        contentPreview:
            "2025년 8월 15일 02:00~04:00 시스템 점검이 예정되어 있습니다. 해당 시간 동안 서비스 이용이 제한될 수 있습니다...",
        viewCount: 512,
        createdAt: DateTime.now().subtract(Duration(hours: 2)),
        updatedAt: DateTime.now().subtract(Duration(hours: 2)),
      ),
      NoticePost(
        noticeIdx: 2,
        title: "헌혈 인증서 발급 기능 추가",
        authorName: "관리자",
        authorEmail: "admin@superpetconnect.com",
        authorNickname: "관리자",
        noticeImportant: 1,
        targetAudience: 1,
        noticeUrl: "https://example.com/certification",
        contentPreview:
            "헌혈 완료 후 디지털 인증서를 발급받을 수 있는 기능이 추가되었습니다. 마이페이지에서 확인하실 수 있습니다...",
        viewCount: 387,
        createdAt: DateTime.now().subtract(Duration(days: 1)),
        updatedAt: DateTime.now().subtract(Duration(days: 1)),
      ),
      NoticePost(
        noticeIdx: 3,
        title: "긴급 헌혈 요청 알림 개선",
        authorName: "관리자",
        authorEmail: "admin@superpetconnect.com",
        authorNickname: "관리자",
        noticeImportant: 1,
        targetAudience: 2,
        noticeUrl: null,
        contentPreview:
            "긴급 헌혈 요청 시 더 빠른 알림을 위해 푸시 알림 시스템을 개선했습니다. 설정에서 알림을 활성화해주세요...",
        viewCount: 298,
        createdAt: DateTime.now().subtract(Duration(days: 2)),
        updatedAt: DateTime.now().subtract(Duration(days: 2)),
      ),
    ];

    return mockNotices.take(limit).cast<NoticePost>().toList();
  }
}

class PaginatedColumnsResult {
  final List<ColumnPost> columns;
  final PaginationMeta pagination;

  PaginatedColumnsResult({required this.columns, required this.pagination});
}

class PaginatedNoticesResult {
  final List<NoticePost> notices;
  final PaginationMeta pagination;

  PaginatedNoticesResult({required this.notices, required this.pagination});
}

class PaginationMeta {
  final int currentPage;
  final int pageSize;
  final int totalCount;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;
  final bool isEnd;

  const PaginationMeta({
    required this.currentPage,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
    required this.isEnd,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    final hasNextValue = _toBool(json['has_next'] ?? json['hasNext']);
    final hasPrevValue = _toBool(json['has_prev'] ?? json['hasPrev']);
    final isEndRaw = json['is_end'] ?? json['isEnd'];
    final isEndValue = isEndRaw != null ? _toBool(isEndRaw) : !hasNextValue;
    return PaginationMeta(
      currentPage: _toInt(json['current_page'] ?? json['page'], fallback: 1),
      pageSize: _toInt(
        json['page_size'] ?? json['pageSize'],
        fallback: DashboardService.detailListPageSize,
      ),
      totalCount: _toInt(
        json['total_count'] ?? json['totalCount'],
        fallback: 0,
      ),
      totalPages: _toInt(
        json['total_pages'] ?? json['totalPages'],
        fallback: 0,
      ),
      hasNext: hasNextValue,
      hasPrev: hasPrevValue,
      isEnd: isEndValue,
    );
  }

  factory PaginationMeta.derived({
    required int currentPage,
    required int pageSize,
    required int itemCount,
  }) {
    final hasNextValue = itemCount >= pageSize;
    return PaginationMeta(
      currentPage: currentPage,
      pageSize: pageSize,
      totalCount: (currentPage - 1) * pageSize + itemCount,
      totalPages: hasNextValue ? currentPage + 1 : currentPage,
      hasNext: hasNextValue,
      hasPrev: currentPage > 1,
      isEnd: !hasNextValue,
    );
  }

  factory PaginationMeta.singlePage({
    required int currentPage,
    required int pageSize,
    required int totalCount,
  }) {
    return PaginationMeta(
      currentPage: currentPage,
      pageSize: pageSize,
      totalCount: totalCount,
      totalPages: 1,
      hasNext: false,
      hasPrev: false,
      isEnd: true,
    );
  }

  bool get noMoreData => isEnd;

  static bool _toBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == '1';
    }
    return false;
  }

  static int _toInt(dynamic value, {required int fallback}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
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
