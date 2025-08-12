import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/config.dart';
import '../models/donation_post_date_model.dart';
import 'donation_date_service.dart';

// 새로운 API 구조를 위한 TimeSlot 클래스
class TimeSlot {
  final int postTimesIdx;
  final String time;
  final String datetime;

  TimeSlot({
    required this.postTimesIdx,
    required this.time,
    required this.datetime,
  });

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      postTimesIdx: json['post_times_idx'] ?? 0,
      time: json['time'] ?? '',
      datetime: json['datetime'] ?? '',
    );
  }

  String get formattedTime => time;
}

class DashboardService {
  static String get baseUrl => Config.serverUrl;
  
  // 닉네임이 유효한지 확인하는 헬퍼 메서드
  static bool _isValidNickname(dynamic nickname) {
    if (nickname == null) return false;
    final nicknameStr = nickname.toString();
    if (nicknameStr.isEmpty) return false;
    if (nicknameStr.toLowerCase() == 'null') return false;
    return true;
  }

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
  static Future<List<DonationPost>> getPublicPosts({
    int limit = 10,
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
      
      final uri = Uri.parse('$baseUrl/api/posts').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      
      print('DEBUG: 헌혈 모집글 API 요청 - URL: $uri');

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
        
        final posts = postsData
            .take(limit)
            .map((item) => DonationPost.fromJson(item))
            .toList();
        print('DEBUG: 헌혈 모집글 로드 완료: ${posts.length}개');
        return posts;
      } else {
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
      // 먼저 다른 엔드포인트들을 시도해보자
      List<String> apiEndpoints = [
        '$baseUrl/api/public/columns',
        '$baseUrl/api/columns',
        '$baseUrl/api/hospital/public/columns',
      ];
      
      for (String endpoint in apiEndpoints) {
        try {
          final uri = Uri.parse(endpoint).replace(
            queryParameters: {
              'page': '1',
              'page_size': limit.toString(),
            },
          );

          print('🌐 칼럼 API 요청 시도:');
          print('  URL: $uri');
          print('  서버: $baseUrl');
          print('  시간: ${DateTime.now()}');

          final response = await http.get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Cache-Control': 'no-cache, no-store, must-revalidate',
              'Pragma': 'no-cache',
              'Expires': '0',
            },
          ).timeout(const Duration(seconds: 15));
          
          print('🌐 칼럼 API 응답:');
          print('  상태코드: ${response.statusCode}');
          print('  응답 헤더: ${response.headers}');
          print('  실제 Raw 응답: ${response.body}');
          
          // 응답을 JSON으로 파싱하여 구조 확인
          if (response.statusCode == 200) {
            try {
              final rawData = jsonDecode(utf8.decode(response.bodyBytes));
              print('  파싱된 JSON: $rawData');
              
              List<dynamic> columnsData;
              if (rawData is Map<String, dynamic>) {
                columnsData = rawData['columns'] ?? rawData['data'] ?? [];
              } else if (rawData is List) {
                columnsData = rawData;
              } else {
                columnsData = [];
              }
              
              if (columnsData.isNotEmpty) {
                final firstColumn = columnsData.first;
                print('  첫번째 칼럼 데이터: $firstColumn');
                print('  hospital_nickname 필드: "${firstColumn['hospital_nickname']}" (타입: ${firstColumn['hospital_nickname'].runtimeType})');
              }
              
              final columns = columnsData
                  .map((item) => ColumnPost.fromJson(item))
                  .toList();
              print('🌐 성공: ${endpoint}에서 ${columns.length}개 칼럼 로드');
              return columns;
            } catch (e) {
              print('  JSON 파싱 오류: $e');
              continue; // 다음 엔드포인트 시도
            }
          } else {
            print('ERROR: 칼럼 API HTTP 오류 - 상태코드: ${response.statusCode}');
            continue; // 다음 엔드포인트 시도
          }
        } catch (e) {
          print('ERROR: 칼럼 API 예외 발생 ($endpoint): $e');
          continue; // 다음 엔드포인트 시도
        }
      }
      
      print('ERROR: 모든 칼럼 API 엔드포인트 실패');
      return [];
    } catch (e) {
      print('ERROR: 칼럼 API 전체 예외 발생: $e');
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
      // 여러 엔드포인트를 시도해보자
      List<String> apiEndpoints = [
        '$baseUrl/api/public/notices',
        '$baseUrl/api/notices',
        '$baseUrl/api/public/notices/',
      ];
      
      for (String endpoint in apiEndpoints) {
        try {
          final uri = Uri.parse(endpoint).replace(
            queryParameters: {'limit': limit.toString()},
          );

          print('🌐 공지사항 API 요청 시도:');
          print('  URL: $uri');
          print('  서버: $baseUrl');
          print('  시간: ${DateTime.now()}');

          final response = await http.get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Cache-Control': 'no-cache, no-store, must-revalidate',
              'Pragma': 'no-cache',
              'Expires': '0',
            },
          ).timeout(const Duration(seconds: 15));
          
          print('🌐 공지사항 API 응답:');
          print('  상태코드: ${response.statusCode}');
          print('  응답 헤더: ${response.headers}');
          print('  실제 Raw 응답: ${response.body}');
          
          // 응답을 JSON으로 파싱하여 구조 확인
          if (response.statusCode == 200) {
            try {
              final rawData = jsonDecode(utf8.decode(response.bodyBytes));
              print('  파싱된 JSON: $rawData');
              List<dynamic> noticesData;
              if (rawData is Map<String, dynamic>) {
                noticesData = rawData['notices'] ?? rawData['data'] ?? [];
              } else if (rawData is List) {
                noticesData = rawData;
              } else {
                noticesData = [];
              }
              if (noticesData.isNotEmpty) {
                final firstNotice = noticesData.first;
                print('  첫번째 공지사항 데이터: $firstNotice');
                print('  author_nickname 필드: "${firstNotice['author_nickname']}" (타입: ${firstNotice['author_nickname'].runtimeType})');
              }
              
              final notices = noticesData
                  .map((item) => NoticePost.fromJson(item))
                  .toList();
              
              print('🌐 성공: ${endpoint}에서 ${notices.length}개 공지사항 로드');
              return notices;
            } catch (e) {
              print('  JSON 파싱 오류: $e');
              continue; // 다음 엔드포인트 시도
            }
          } else {
            print('ERROR: 공지사항 API HTTP 오류 - 상태코드: ${response.statusCode}');
            continue; // 다음 엔드포인트 시도
          }
        } catch (e) {
          print('ERROR: 공지사항 API 예외 발생 ($endpoint): $e');
          continue; // 다음 엔드포인트 시도
        }
      }
      
      print('ERROR: 모든 공지사항 API 엔드포인트 실패');
      return [];
    } catch (e) {
      print('ERROR: 공지사항 API 전체 예외 발생: $e');
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
  
  // 상세 게시글 정보 및 헌혈 날짜 조회 (with donation dates)
  static Future<DonationPost?> getDonationPostDetail(int postIdx) async {
    try {
      final uri = Uri.parse('$baseUrl/api/public/posts/$postIdx');

      print('DEBUG: 헌혈 게시글 상세 API 요청 - URL: $uri');
      final response = await http.get(uri);
      print('DEBUG: 헌혈 게시글 상세 응답 상태코드: ${response.statusCode}');
      print('DEBUG: 헌혈 게시글 상세 응답 본문: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        
          
        // 게시글 상세 정보로 DonationPost 생성
        final donationPost = DonationPost.fromJson(data);
        
        // 헌퀁 날짜 목록을 별도로 조회하여 추가
        try {
          final donationDates = await DonationDateService.getDonationDatesByPostIdx(postIdx);
          // 기존 DonationPost에 헌혈 날짜 정보 추가한 새로운 객체 생성
          return DonationPost(
            postIdx: donationPost.postIdx,
            title: donationPost.title,
            hospitalName: donationPost.hospitalName,
            hospitalNickname: donationPost.hospitalNickname, // 병원 닉네임 추가
            location: donationPost.location,
            description: donationPost.description, // 설명 추가
            animalType: donationPost.animalType,
            emergencyBloodType: donationPost.emergencyBloodType,
            status: donationPost.status,
            types: donationPost.types,
            viewCount: donationPost.viewCount,
            createdAt: donationPost.createdAt,
            donationDate: donationPost.donationDate,
            updatedAt: donationPost.updatedAt,
            donationDates: donationDates, // 헌혈 날짜 정보 추가
          );
        } catch (e) {
          print('DEBUG: 헌혈 날짜 조회 실패, 기본 게시글 정보만 반환: $e');
          return donationPost; // 헌혈 날짜 조회 실패 시 기본 게시글 정보만 반환
        }
      } else {
        print('DEBUG: 헌혈 게시글 상세 API 실패 - 상태코드: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('ERROR: 헌혈 게시글 상세 API 오류: $e');
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
  final String? hospitalNickname; // 병원 닉네임 추가 (nullable로 변경)
  final String location;
  final String description; // 설명 추가
  final int animalType;
  final String? emergencyBloodType;
  final int status;
  final int types;
  final int viewCount;
  final DateTime createdAt;
  final DateTime? donationDate;
  final DateTime? updatedAt;
  final List<DonationPostDate>? donationDates; // 헌혈 날짜 목록 (기존 호환성)
  final Map<String, List<TimeSlot>>? availableDates; // 새로운 API 구조

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
    this.updatedAt,
    this.donationDates,
    this.availableDates,
  });

  factory DonationPost.fromJson(Map<String, dynamic> json) {
    // types 필드로 긴급/정기 판단: 0=긴급, 1=정기
    int typesValue = json['types'] ?? 1; // 기본값 정기(1)
    
    // 병원 정보 처리 - 여러 API 응답 구조 지원
    String hospitalName = '';
    String? hospitalNickname;
    String location = '';
    
    // 1. 최상위 레벨에서 직접 가져오기 (새로운 API 응답 방식)
    if (json['hospitalName'] != null && json['hospitalName'].toString().trim().isNotEmpty) {
      hospitalName = json['hospitalName'].toString().trim();
    }
    
    if (json['location'] != null && json['location'].toString().trim().isNotEmpty) {
      location = json['location'].toString().trim();
    }
    
    // 2. hospital 객체에서 가져오기 (기존 방식)
    if (json['hospital'] != null) {
      final hospital = json['hospital'] as Map<String, dynamic>;
      
      if (hospitalName.isEmpty) {
        hospitalName = hospital['name']?.toString() ?? '';
      }
      
      final nicknameValue = hospital['nickname'];
      if (nicknameValue != null && nicknameValue.toString().trim().isNotEmpty && nicknameValue.toString().toLowerCase() != 'null') {
        hospitalNickname = nicknameValue.toString().trim();
      }
      
      if (location.isEmpty) {
        location = hospital['address']?.toString() ?? '';
      }
    }
    
    // 3. 최상위 hospital_nickname 필드 확인
    final topLevelNickname = json['hospital_nickname'];
    if (topLevelNickname != null && topLevelNickname.toString().trim().isNotEmpty && topLevelNickname.toString().toLowerCase() != 'null') {
      hospitalNickname = topLevelNickname.toString().trim();
    }
    
    // 닉네임이 없다면 hospitalName을 닉네임으로 사용 (임시 해결책)
    if (hospitalNickname == null && hospitalName.isNotEmpty && hospitalName != '병원') {
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
    print('DEBUG: 병원 정보 파싱 결과');
    print('  - hospitalName: "$hospitalName"');
    print('  - hospitalNickname: "$hospitalNickname"');
    print('  - location: "$location"');
    print('  - 원본 JSON hospitalName: "${json['hospitalName']}"');
    print('  - 원본 JSON location: "${json['location']}"');
    
    // API 응답의 date 필드를 헌혈 예정일로 사용
    DateTime? donationDate;
    print('DEBUG: 헌혈 날짜 파싱 시작');
    print('  - json[\'date\']: "${json['date']}"');
    print('  - json[\'donationDate\']: "${json['donationDate']}"');
    print('  - json[\'registrationDate\']: "${json['registrationDate']}"');
    
    if (json['date'] != null && json['date'].toString().isNotEmpty) {
      donationDate = DateTime.tryParse(json['date'].toString());
      print('  - date 필드 파싱 결과: $donationDate');
    } else if (json['donationDate'] != null) {
      donationDate = DateTime.tryParse(json['donationDate'].toString());
      print('  - donationDate 필드 파싱 결과: $donationDate');
    } else if (json['post_date'] != null) {
      donationDate = DateTime.tryParse(json['post_date'].toString());
      print('  - post_date 필드 파싱 결과: $donationDate');
    }
    
    print('  - 최종 donationDate: $donationDate');
    
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
      print('ERROR: postIdx 파싱 오류: $e');
      postIdx = 0;
    }

    return DonationPost(
      postIdx: postIdx,
      title: json['title'] ?? '',
      hospitalName: hospitalName.isNotEmpty ? hospitalName : '병원',
      hospitalNickname: hospitalNickname, // 병원 닉네임 추가
      location: location,
      description: json['descriptions']?.toString() ?? json['description']?.toString() ?? '',
      animalType: json['animalType'] is String ? (json['animalType'] == 'dog' ? 0 : 1) : (json['animalType'] ?? 0),
      emergencyBloodType: json['emergency_blood_type']?.toString() ?? json['bloodType']?.toString(),
      status: _parseIntSafely(json['status']) ?? 0,
      types: typesValue,
      viewCount: _parseIntSafely(json['viewCount']) ?? 0,
      createdAt: _parseCreatedAt(json),
      donationDate: donationDate,
      updatedAt: null,
      donationDates: null,
      availableDates: _parseAvailableDates(json['availableDates']),
    );
  }

  // 안전한 정수 파싱 헬퍼 메서드
  static int? _parseIntSafely(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return int.tryParse(value.toString());
  }

  // availableDates 파싱 헬퍼 메서드
  static Map<String, List<TimeSlot>>? _parseAvailableDates(dynamic availableDatesJson) {
    if (availableDatesJson == null) return null;
    
    try {
      final Map<String, List<TimeSlot>> result = {};
      
      if (availableDatesJson is Map<String, dynamic>) {
        for (final entry in availableDatesJson.entries) {
          final dateStr = entry.key;
          final timesList = entry.value;
          
          if (timesList is List) {
            final timeSlots = timesList
                .map((timeJson) => TimeSlot.fromJson(timeJson as Map<String, dynamic>))
                .toList();
            result[dateStr] = timeSlots;
          }
        }
      }
      
      return result.isNotEmpty ? result : null;
    } catch (e) {
      print('ERROR: availableDates 파싱 실패: $e');
      return null;
    }
  }

  // 게시글 등록일자 파싱 헬퍼 메서드
  static DateTime _parseCreatedAt(Map<String, dynamic> json) {
    // 등록일자 파싱 우선순위: created_at > createdAt > registrationDate
    if (json['created_at'] != null) {
      return DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now();
    } else if (json['createdAt'] != null) {
      return DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now();
    } else if (json['registrationDate'] != null) {
      return DateTime.tryParse(json['registrationDate'].toString()) ?? DateTime.now();
    }
    return DateTime.now(); // fallback
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
  
  // 헌혈 날짜 표시용 헬퍼 메서드
  String get donationDatesText {
    if (donationDates == null || donationDates!.isEmpty) {
      return '예정된 헌혈 날짜가 없습니다.';
    }
    
    final sortedDates = List<DonationPostDate>.from(donationDates!)..sort((a, b) => a.donationDate.compareTo(b.donationDate));
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
    
    final sortedDates = List<DonationPostDate>.from(donationDates!)..sort((a, b) => a.donationDate.compareTo(b.donationDate));
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
    required this.isImportant,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ColumnPost.fromJson(Map<String, dynamic> json) {
    print('🎉 ColumnPost 닉네임 체크:');
    print('  hospital_nickname: "${json['hospital_nickname']}"');
    print('  최종 사용할 닉네임: "${(json['hospital_nickname'] != null && json['hospital_nickname'].toString() != 'null' && json['hospital_nickname'].toString().isNotEmpty) ? json['hospital_nickname'] : '닉네임 없음'}"');
    
    return ColumnPost(
      columnIdx: json['column_idx'] ?? 0,
      title: json['title'] ?? '',
      authorName: json['hospital_name'] ?? '병원',
      authorNickname: (json['hospital_nickname'] != null && json['hospital_nickname'].toString() != 'null' && json['hospital_nickname'].toString().isNotEmpty) 
          ? json['hospital_nickname'] 
          : '닉네임 없음',
      viewCount: json['view_count'] ?? 0,
      contentPreview: json['content'] ?? '', // content_preview 제거됨, content 사용
      isImportant: json['is_important'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }
}

class NoticePost {
  final int noticeIdx;
  final String title;
  final int noticeImportant; // 0=긴급, 1=정기 (int로 변경)
  final String contentPreview;
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
    required this.targetAudience,
    required this.authorEmail,
    required this.authorName,
    required this.authorNickname,
    required this.viewCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NoticePost.fromJson(Map<String, dynamic> json) {
    print('🎉 NoticePost 닉네임 체크:');
    print('  author_nickname: "${json['author_nickname']}"');
    print('  최종 사용할 닉네임: "${(json['author_nickname'] != null && json['author_nickname'].toString() != 'null' && json['author_nickname'].toString().isNotEmpty) ? json['author_nickname'] : '닉네임 없음'}"');
    
    return NoticePost(
      noticeIdx: json['notice_idx'] ?? json['id'] ?? 0,
      title: json['title'] ?? '',
      noticeImportant: _parseNoticeImportant(json['notice_important']), // 0=긴급, 1=정기
      contentPreview: json['content'] ?? '', // content_preview 제거됨, content 사용
      targetAudience: json['target_audience'] ?? json['targetAudience'] ?? 0,
      authorEmail: json['author_email'] ?? json['authorEmail'] ?? '',
      authorName: json['author_name'] ?? '작성자',
      authorNickname: (json['author_nickname'] != null && json['author_nickname'].toString() != 'null' && json['author_nickname'].toString().isNotEmpty) 
          ? json['author_nickname'] 
          : '닉네임 없음',
      viewCount: json['view_count'] ?? json['viewCount'] ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] ?? json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }
  
  // notice_important 필드 파싱 헬퍼 메서드 (bool/int 호환)
  static int _parseNoticeImportant(dynamic value) {
    print('DEBUG: NoticePost notice_important 값 타입: ${value.runtimeType}, 값: $value'); // 디버그 로그 추가
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