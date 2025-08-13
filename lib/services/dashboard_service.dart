import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../utils/config.dart';
import '../models/donation_post_date_model.dart';
import 'donation_date_service.dart';

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
    // 웹에서 CORS 문제 임시 해결: 목 데이터 반환
    if (kIsWeb) {
      print('🌐 [WEB-COLUMNS] CORS 문제로 인해 목 데이터 반환');
      return NoticePost._getMockColumnData(limit);
    }
    
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

          print('🌐 [WEB-COLUMNS] API 요청 시도:');
          print('  플랫폼: ${kIsWeb ? "WEB" : "MOBILE"}');
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
          
          print('🌐 [WEB-COLUMNS] API 응답:');
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
          print('❌ [WEB-COLUMNS] API 예외 발생 ($endpoint):');
          print('   - 오류 타입: ${e.runtimeType}');
          print('   - 오류 메시지: $e');
          print('   - 플랫폼: ${kIsWeb ? "WEB" : "MOBILE"}');
          if (kIsWeb && e.toString().contains('XMLHttpRequest')) {
            print('   - CORS 또는 네트워크 오류 가능성 높음');
          }
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
    // 웹에서 CORS 문제 임시 해결: 목 데이터 반환
    if (kIsWeb) {
      print('🌐 [WEB-NOTICES] CORS 문제로 인해 목 데이터 반환');
      return NoticePost._getMockNoticeData(limit);
    }
    
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

          print('🌐 [WEB-NOTICES] API 요청 시도:');
          print('  플랫폼: ${kIsWeb ? "WEB" : "MOBILE"}');
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
          
          print('🌐 [WEB-NOTICES] API 응답:');
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
          print('❌ [WEB-NOTICES] API 예외 발생 ($endpoint):');
          print('   - 오류 타입: ${e.runtimeType}');
          print('   - 오류 메시지: $e');
          print('   - 플랫폼: ${kIsWeb ? "WEB" : "MOBILE"}');
          if (kIsWeb && e.toString().contains('XMLHttpRequest')) {
            print('   - CORS 또는 네트워크 오류 가능성 높음');
          }
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
  
  // 상세 게시글 정보 및 헌혈 날짜 조회 (통합 데이터 사용)
  static Future<DonationPost?> getDonationPostDetail(int postIdx) async {
    try {
      final uri = Uri.parse('$baseUrl/api/public/posts/$postIdx');

      print('DEBUG: 헌혈 게시글 상세 API 요청 - URL: $uri');
      final response = await http.get(uri);
      print('DEBUG: 헌혈 게시글 상세 응답 상태코드: ${response.statusCode}');
      print('DEBUG: 헌혈 게시글 상세 응답 본문: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        
        // 서버에서 통합된 데이터를 제공하므로 바로 DonationPost 생성
        final donationPost = DonationPost.fromJson(data);
        
        print('DEBUG: 상세 게시글 파싱 완료:');
        print('  - 제목: ${donationPost.title}');
        print('  - 작성일: ${donationPost.createdAt}');
        print('  - 헌혈 예정일: ${donationPost.donationDate}');
        print('  - 헌혈 시간: ${donationPost.donationTime}');
        print('  - availableDates: ${donationPost.availableDates?.keys.toList()}');
        
        return donationPost;
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
  final DateTime createdAt; // 게시글 작성일 (post_created_date)
  final DateTime? donationDate; // 실제 헌혈 예정일 (donation_date) 
  final DateTime? donationTime; // 실제 헌혈 시간 (donation_time)
  final DateTime? updatedAt;
  final List<DonationPostDate>? donationDates; // 헌혈 날짜 목록 (기존 호환성)
  final Map<String, List<Map<String, dynamic>>>? availableDates; // 서버의 available_dates 구조

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
    
    // 새로운 서버 API 응답 구조에 따른 날짜 파싱
    DateTime? donationDate;
    DateTime? donationTime;
    print('DEBUG: 헌홨 날짜/시간 파싱 시작');
    print('  - json[\'donation_date\']: "${json['donation_date']}"');
    print('  - json[\'donation_time\']: "${json['donation_time']}"');
    print('  - json[\'post_created_date\']: "${json['post_created_date']}"');
    print('  - json[\'available_dates\']: "${json['available_dates']}"');
    
    // 1. 실제 헌혈 예정일 파싱 (donation_date - DATETIME 타입)
    if (json['donation_date'] != null && json['donation_date'].toString().isNotEmpty && json['donation_date'] != 'null') {
      try {
        donationDate = DateTime.parse(json['donation_date'].toString());
        print('  - donation_date 필드 파싱 성공: $donationDate');
      } catch (e) {
        print('  - donation_date 필드 파싱 실패: $e');
        donationDate = null;
      }
    } else if (json['donationDate'] != null) {
      // 기존 호환성
      try {
        donationDate = DateTime.parse(json['donationDate'].toString());
        print('  - donationDate 필드 파싱 성공: $donationDate');
      } catch (e) {
        print('  - donationDate 필드 파싱 실패: $e');
        donationDate = null;
      }
    }
    
    // 2. 실제 헌혈 시간 파싱 (donation_time - DATETIME 타입)
    if (json['donation_time'] != null && json['donation_time'].toString().isNotEmpty && json['donation_time'] != 'null') {
      try {
        donationTime = DateTime.parse(json['donation_time'].toString());
        print('  - donation_time 필드 파싱 성공: $donationTime');
      } catch (e) {
        print('  - donation_time 필드 파싱 실패: $e');
        donationTime = null;
      }
    }
    
    print('  - 최종 donationDate: $donationDate');
    print('  - 최종 donationTime: $donationTime');
    
    // 3. 새로운 available_dates 구조 파싱 (단순한 Map 구조로 보관)
    Map<String, List<Map<String, dynamic>>>? availableDates;
    print('🔍 DEBUG: available_dates 파싱 시작');
    
    // camelCase (availableDates) 또는 snake_case (available_dates) 둘 다 확인
    final availableDatesField = json['availableDates'] ?? json['available_dates'];
    print('   - availableDates 존재 여부: ${json['availableDates'] != null}');
    print('   - available_dates 존재 여부: ${json['available_dates'] != null}');
    print('   - 최종 필드 타입: ${availableDatesField?.runtimeType}');
    print('   - 최종 필드 내용: ${availableDatesField}');
    
    if (availableDatesField != null && availableDatesField is Map) {
      try {
        availableDates = <String, List<Map<String, dynamic>>>{};
        final datesMap = availableDatesField as Map<String, dynamic>;
        
        for (final dateEntry in datesMap.entries) {
          final dateStr = dateEntry.key; // "2025-09-16"
          final timeList = dateEntry.value as List<dynamic>;
          
          final timeSlots = timeList.map((timeJson) {
            return {
              'post_times_idx': timeJson['post_times_idx'] ?? 0,
              'time': timeJson['time'] ?? '',
              'datetime': timeJson['datetime'] ?? '',
            };
          }).toList();
          
          availableDates[dateStr] = timeSlots;
        }
        
        print('✅ available_dates 파싱 성공: ${availableDates.keys.length}개 날짜');
        for (final entry in availableDates.entries) {
          print('   📅 ${entry.key}: ${entry.value.length}개 시간대');
          for (final timeSlot in entry.value) {
            print('     ⏰ post_times_idx: ${timeSlot['post_times_idx']}, time: ${timeSlot['time']}, datetime: ${timeSlot['datetime']}');
          }
        }
      } catch (e) {
        print('❌ available_dates 파싱 실패: $e');
        print('   - 스택 트레이스: ${e.toString()}');
        availableDates = null;
      }
    } else {
      print('⚠️ available_dates 필드가 없거나 Map 타입이 아님');
      
      // Fallback: timeRanges 배열을 available_dates로 변환
      if (json['timeRanges'] != null && json['timeRanges'] is List) {
        try {
          final timeRanges = json['timeRanges'] as List<dynamic>;
          if (timeRanges.isNotEmpty && donationDate != null) {
            // donationDate를 기준으로 단일 날짜 구조 생성
            final dateStr = donationDate.toIso8601String().split('T')[0];
            availableDates = <String, List<Map<String, dynamic>>>{};
            
            final timeSlots = timeRanges.map((timeRange) {
              return {
                'post_times_idx': timeRange['id'] ?? 0,
                'time': timeRange['time'] ?? '',
                'datetime': '$dateStr${timeRange['time'] != null ? 'T${timeRange['time']}:00' : 'T00:00:00'}',
              };
            }).toList();
            
            availableDates[dateStr] = timeSlots;
            print('📦 timeRanges fallback 성공: $dateStr에 ${timeSlots.length}개 시간대');
            for (final timeSlot in timeSlots) {
              print('   ⏰ ${timeSlot['time']} (id: ${timeSlot['post_times_idx']})');
            }
          }
        } catch (e) {
          print('❌ timeRanges fallback 실패: $e');
        }
      }
      
      // 테스트용 임시 데이터 비활성화 - 서버 데이터만 사용
      // TODO: 서버에서 available_dates를 올바르게 전달하면 이 코드 완전 제거
      if (false && json['title'] != null && json['title'].toString().contains('헌혈')) {
        print('🧪 테스트: 임시 데이터 생성 (현재 비활성화)');
        availableDates = {
          '2025-08-13': [
            {
              'post_times_idx': 101,
              'time': '09:00',
              'datetime': '2025-08-13T09:00:00',
            },
            {
              'post_times_idx': 102,
              'time': '14:00', 
              'datetime': '2025-08-13T14:00:00',
            }
          ],
          '2025-08-14': [
            {
              'post_times_idx': 103,
              'time': '10:00',
              'datetime': '2025-08-14T10:00:00',
            },
            {
              'post_times_idx': 104,
              'time': '16:00',
              'datetime': '2025-08-14T16:00:00',
            }
          ]
        };
        print('🧪 테스트 데이터 생성 완료: ${availableDates.keys.length}개 날짜');
      } else {
        availableDates = null;
      }
    }
    
    print('  - 최종 availableDates: ${availableDates?.keys.toList()}');
    
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
      donationTime: donationTime,
      updatedAt: null,
      availableDates: availableDates,
      donationDates: null,
    );
  }

  // 안전한 정수 파싱 헬퍼 메서드
  static int? _parseIntSafely(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return int.tryParse(value.toString());
  }

  // _parseAvailableDates 함수 제거됨 (이미 위에서 처리)

  // 게시글 작성일자 파싱 헬퍼 메서드 (새로운 서버 구조 적용)
  static DateTime _parseCreatedAt(Map<String, dynamic> json) {
    // 작성일자 파싱 우선순위: post_created_date > created_at > createdAt > registrationDate
    if (json['post_created_date'] != null && json['post_created_date'].toString().isNotEmpty && json['post_created_date'] != 'null') {
      try {
        final parsedDate = DateTime.parse(json['post_created_date'].toString());
        print('DEBUG: post_created_date 파싱 성공: $parsedDate');
        return parsedDate;
      } catch (e) {
        print('DEBUG: post_created_date 파싱 실패: $e');
      }
    }
    
    if (json['created_at'] != null && json['created_at'].toString().isNotEmpty && json['created_at'] != 'null') {
      try {
        final parsedDate = DateTime.parse(json['created_at'].toString());
        print('DEBUG: created_at 파싱 성공: $parsedDate');
        return parsedDate;
      } catch (e) {
        print('DEBUG: created_at 파싱 실패: $e');
      }
    }
    
    if (json['createdAt'] != null && json['createdAt'].toString().isNotEmpty && json['createdAt'] != 'null') {
      try {
        final parsedDate = DateTime.parse(json['createdAt'].toString());
        print('DEBUG: createdAt 파싱 성공: $parsedDate');
        return parsedDate;
      } catch (e) {
        print('DEBUG: createdAt 파싱 실패: $e');
      }
    }
    
    if (json['registrationDate'] != null && json['registrationDate'].toString().isNotEmpty && json['registrationDate'] != 'null') {
      try {
        final parsedDate = DateTime.parse(json['registrationDate'].toString());
        print('DEBUG: registrationDate 파싱 성공: $parsedDate');
        return parsedDate;
      } catch (e) {
        print('DEBUG: registrationDate 파싱 실패: $e');
      }
    }
    
    print('DEBUG: 모든 작성일 필드 파싱 실패, 현재 시간 사용');
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

  // 웹 CORS 문제 해결용 목 데이터
  static List<ColumnPost> _getMockColumnData(int limit) {
    final mockColumns = [
      ColumnPost(
        columnIdx: 1,
        title: "반려동물 헌혈의 중요성",
        authorName: "서울동물병원",
        authorNickname: "서울동물병원",
        isImportant: false,
        contentPreview: "반려동물 헌혈은 응급상황에서 생명을 구하는 중요한 의료행위입니다. 건강한 반려동물의 헌혈이 다른 동물의 생명을 구할 수 있습니다...",
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
        contentPreview: "헌혈을 위해서는 반려동물의 건강상태 확인이 필수입니다. 충분한 수분 섭취와 스트레스 관리가 중요합니다...",
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
        contentPreview: "헌혈을 위해서는 정확한 혈액형 검사가 필수입니다. DEA 1.1 검사를 통해 안전한 헌혈이 가능합니다...",
        viewCount: 198,
        createdAt: DateTime.now().subtract(Duration(days: 4)),
        updatedAt: DateTime.now().subtract(Duration(days: 4)),
      ),
    ];
    
    return mockColumns.take(limit).cast<ColumnPost>().toList();
  }

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
        contentPreview: "2025년 8월 15일 02:00~04:00 시스템 점검이 예정되어 있습니다. 해당 시간 동안 서비스 이용이 제한될 수 있습니다...",
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
        contentPreview: "헌혈 완료 후 디지털 인증서를 발급받을 수 있는 기능이 추가되었습니다. 마이페이지에서 확인하실 수 있습니다...",
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
        contentPreview: "긴급 헌혈 요청 시 더 빠른 알림을 위해 푸시 알림 시스템을 개선했습니다. 설정에서 알림을 활성화해주세요...",
        viewCount: 298,
        createdAt: DateTime.now().subtract(Duration(days: 2)),
        updatedAt: DateTime.now().subtract(Duration(days: 2)),
      ),
    ];
    
    return mockNotices.take(limit).cast<NoticePost>().toList();
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

  // 웹 CORS 문제 해결용 목 데이터
  static List<ColumnPost> _getMockColumnData(int limit) {
    final mockColumns = [
      ColumnPost(
        columnIdx: 1,
        title: "반려동물 헌혈의 중요성",
        authorName: "서울동물병원",
        authorNickname: "서울동물병원",
        isImportant: false,
        contentPreview: "반려동물 헌혈은 응급상황에서 생명을 구하는 중요한 의료행위입니다. 건강한 반려동물의 헌혈이 다른 동물의 생명을 구할 수 있습니다...",
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
        contentPreview: "헌혈을 위해서는 반려동물의 건강상태 확인이 필수입니다. 충분한 수분 섭취와 스트레스 관리가 중요합니다...",
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
        contentPreview: "헌혈을 위해서는 정확한 혈액형 검사가 필수입니다. DEA 1.1 검사를 통해 안전한 헌혈이 가능합니다...",
        viewCount: 198,
        createdAt: DateTime.now().subtract(Duration(days: 4)),
        updatedAt: DateTime.now().subtract(Duration(days: 4)),
      ),
    ];
    
    return mockColumns.take(limit).cast<ColumnPost>().toList();
  }

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
        contentPreview: "2025년 8월 15일 02:00~04:00 시스템 점검이 예정되어 있습니다. 해당 시간 동안 서비스 이용이 제한될 수 있습니다...",
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
        contentPreview: "헌혈 완료 후 디지털 인증서를 발급받을 수 있는 기능이 추가되었습니다. 마이페이지에서 확인하실 수 있습니다...",
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
        contentPreview: "긴급 헌혈 요청 시 더 빠른 알림을 위해 푸시 알림 시스템을 개선했습니다. 설정에서 알림을 활성화해주세요...",
        viewCount: 298,
        createdAt: DateTime.now().subtract(Duration(days: 2)),
        updatedAt: DateTime.now().subtract(Duration(days: 2)),
      ),
    ];
    
    return mockNotices.take(limit).cast<NoticePost>().toList();
  }
}