// services/black_list_service.dart

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/black_list_model.dart';
import '../utils/config.dart';

class BlackListService {
  static String get baseUrl => '${Config.serverUrl}/api/admin/black-list';

  // 인증 토큰 가져오기
  static Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // 공통 헤더 생성 (관리자 권한 포함)
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getAuthToken();
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    };
  }

  // ===== 블랙리스트 관리 API =====

  // 1. 블랙리스트 등록 (관리자)
  static Future<BlackList> createBlackList(BlackListCreateRequest request) async {
    try {
      final headers = await _getHeaders();
      
      print('DEBUG: 블랙리스트 등록 요청 - URL: $baseUrl');
      print('DEBUG: 요청 본문: ${jsonEncode(request.toJson())}');

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: jsonEncode(request.toJson()),
      );

      print('DEBUG: 응답 상태코드: ${response.statusCode}');
      print('DEBUG: 응답 본문: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return BlackList.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('권한이 없습니다. 관리자 계정으로 로그인해주세요.');
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(
          '블랙리스트 등록 실패: ${error['detail'] ?? error['message'] ?? response.body}',
        );
      }
    } catch (e) {
      print('ERROR: 블랙리스트 등록 중 오류: $e');
      throw Exception('블랙리스트 등록 중 오류 발생: $e');
    }
  }

  // 2. 블랙리스트 목록 조회 (관리자)
  static Future<BlackListResponse> getBlackLists({
    int page = 1,
    int pageSize = 10,
    String? search,
    bool? activeOnly, // true: 정지 중, false: 해제됨, null: 전체
  }) async {
    try {
      final headers = await _getHeaders();
      
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };
      
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      
      if (activeOnly != null) {
        queryParams['active_only'] = activeOnly.toString();
      }

      final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
      
      print('DEBUG: 블랙리스트 목록 조회 - URL: $uri');

      final response = await http.get(uri, headers: headers);

      print('DEBUG: 블랙리스트 목록 응답 상태코드: ${response.statusCode}');
      print('DEBUG: 블랙리스트 목록 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return BlackListResponse.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('권한이 없습니다. 관리자 계정으로 로그인해주세요.');
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(
          '블랙리스트 목록 조회 실패: ${error['detail'] ?? error['message'] ?? response.body}',
        );
      }
    } catch (e) {
      print('ERROR: 블랙리스트 목록 조회 중 오류: $e');
      throw Exception('블랙리스트 목록 조회 중 오류 발생: $e');
    }
  }

  // 3. 특정 블랙리스트 상세 조회 (관리자)
  static Future<BlackList> getBlackListDetail(int blackUserIdx) async {
    try {
      final headers = await _getHeaders();
      
      print('DEBUG: 블랙리스트 상세 조회 - URL: $baseUrl/$blackUserIdx');

      final response = await http.get(
        Uri.parse('$baseUrl/$blackUserIdx'),
        headers: headers,
      );

      print('DEBUG: 블랙리스트 상세 응답 상태코드: ${response.statusCode}');
      print('DEBUG: 블랙리스트 상세 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return BlackList.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('블랙리스트를 찾을 수 없습니다.');
      } else if (response.statusCode == 401) {
        throw Exception('권한이 없습니다. 관리자 계정으로 로그인해주세요.');
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(
          '블랙리스트 조회 실패: ${error['detail'] ?? error['message'] ?? response.body}',
        );
      }
    } catch (e) {
      print('ERROR: 블랙리스트 조회 중 오류: $e');
      throw Exception('블랙리스트 조회 중 오류 발생: $e');
    }
  }

  // 4. 블랙리스트 정보 수정 (관리자)
  static Future<BlackList> updateBlackList(
    int blackUserIdx,
    BlackListUpdateRequest request,
  ) async {
    try {
      final headers = await _getHeaders();
      
      print('DEBUG: 블랙리스트 수정 요청 - URL: $baseUrl/$blackUserIdx');
      print('DEBUG: 수정 요청 본문: ${jsonEncode(request.toJson())}');

      final response = await http.put(
        Uri.parse('$baseUrl/$blackUserIdx'),
        headers: headers,
        body: jsonEncode(request.toJson()),
      );

      print('DEBUG: 수정 응답 상태코드: ${response.statusCode}');
      print('DEBUG: 수정 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return BlackList.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('권한이 없습니다. 관리자 계정으로 로그인해주세요.');
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else if (response.statusCode == 404) {
        throw Exception('블랙리스트를 찾을 수 없습니다.');
      } else {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(
          '블랙리스트 수정 실패: ${error['detail'] ?? error['message'] ?? response.body}',
        );
      }
    } catch (e) {
      print('ERROR: 블랙리스트 수정 중 오류: $e');
      throw Exception('블랙리스트 수정 중 오류 발생: $e');
    }
  }

  // 5. 블랙리스트 삭제 (관리자)
  static Future<void> deleteBlackList(int blackUserIdx) async {
    try {
      final headers = await _getHeaders();
      
      print('DEBUG: 블랙리스트 삭제 요청 - URL: $baseUrl/$blackUserIdx');

      final response = await http.delete(
        Uri.parse('$baseUrl/$blackUserIdx'),
        headers: headers,
      );

      print('DEBUG: 삭제 응답 상태코드: ${response.statusCode}');
      print('DEBUG: 삭제 응답 본문: ${response.body}');

      if (response.statusCode == 204 || response.statusCode == 200) {
        return; // 성공적으로 삭제됨
      } else if (response.statusCode == 401) {
        throw Exception('권한이 없습니다. 관리자 계정으로 로그인해주세요.');
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else if (response.statusCode == 404) {
        throw Exception('블랙리스트를 찾을 수 없습니다.');
      } else {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(
          '블랙리스트 삭제 실패: ${error['detail'] ?? error['message'] ?? response.body}',
        );
      }
    } catch (e) {
      print('ERROR: 블랙리스트 삭제 중 오류: $e');
      throw Exception('블랙리스트 삭제 중 오류 발생: $e');
    }
  }

  // 6. 즉시 해제 (관리자)
  static Future<BlackList> releaseBlackList(int blackUserIdx) async {
    try {
      final headers = await _getHeaders();
      
      print('DEBUG: 블랙리스트 즉시 해제 요청 - URL: $baseUrl/$blackUserIdx/release');

      final response = await http.patch(
        Uri.parse('$baseUrl/$blackUserIdx/release'),
        headers: headers,
      );

      print('DEBUG: 해제 응답 상태코드: ${response.statusCode}');
      print('DEBUG: 해제 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return BlackList.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('권한이 없습니다. 관리자 계정으로 로그인해주세요.');
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else if (response.statusCode == 404) {
        throw Exception('블랙리스트를 찾을 수 없습니다.');
      } else {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw Exception('즉시 해제 실패: ${error['detail'] ?? error['message'] ?? response.body}');
      }
    } catch (e) {
      print('ERROR: 블랙리스트 해제 중 오류: $e');
      throw Exception('블랙리스트 해제 중 오류 발생: $e');
    }
  }

  // 7. 블랙리스트 통계 (관리자)
  static Future<BlackListStats> getBlackListStats() async {
    try {
      final headers = await _getHeaders();
      
      print('DEBUG: 블랙리스트 통계 조회 - URL: $baseUrl/stats');

      final response = await http.get(
        Uri.parse('$baseUrl/stats'),
        headers: headers,
      );

      print('DEBUG: 통계 응답 상태코드: ${response.statusCode}');
      print('DEBUG: 통계 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return BlackListStats.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('권한이 없습니다. 관리자 계정으로 로그인해주세요.');
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(
          '통계 조회 실패: ${error['detail'] ?? error['message'] ?? response.body}',
        );
      }
    } catch (e) {
      print('ERROR: 블랙리스트 통계 조회 중 오류: $e');
      throw Exception('블랙리스트 통계 조회 중 오류 발생: $e');
    }
  }

  // 8. D-Day 수동 업데이트 (관리자)
  static Future<Map<String, dynamic>> updateDDay() async {
    try {
      final headers = await _getHeaders();
      
      print('DEBUG: D-Day 수동 업데이트 요청 - URL: $baseUrl/update-d-day');

      final response = await http.patch(
        Uri.parse('$baseUrl/update-d-day'),
        headers: headers,
      );

      print('DEBUG: D-Day 업데이트 응답 상태코드: ${response.statusCode}');
      print('DEBUG: D-Day 업데이트 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('권한이 없습니다. 관리자 계정으로 로그인해주세요.');
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw Exception('D-Day 업데이트 실패: ${error['detail'] ?? error['message'] ?? response.body}');
      }
    } catch (e) {
      print('ERROR: D-Day 업데이트 중 오류: $e');
      throw Exception('D-Day 업데이트 중 오류 발생: $e');
    }
  }

  // 9. 사용자 정지 상태 확인 (본인 또는 관리자)
  static Future<UserBlackListStatus> getUserBlackListStatus(int accountIdx) async {
    try {
      final headers = await _getHeaders();
      
      final url = '${Config.serverUrl}/api/admin/user/$accountIdx/black-list-status';
      print('DEBUG: 사용자 정지 상태 확인 - URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      print('DEBUG: 사용자 상태 확인 응답 상태코드: ${response.statusCode}');
      print('DEBUG: 사용자 상태 확인 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return UserBlackListStatus.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('권한이 없습니다. 로그인해주세요.');
      } else if (response.statusCode == 404) {
        throw Exception('사용자를 찾을 수 없습니다.');
      } else {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(
          '사용자 상태 확인 실패: ${error['detail'] ?? error['message'] ?? response.body}',
        );
      }
    } catch (e) {
      print('ERROR: 사용자 상태 확인 중 오류: $e');
      throw Exception('사용자 상태 확인 중 오류 발생: $e');
    }
  }

  // ===== 편의 메서드 =====

  // 10. 현재 활성화된 블랙리스트만 조회
  static Future<List<BlackList>> getActiveBlackLists({
    int page = 1,
    int pageSize = 10,
    String? search,
  }) async {
    final response = await getBlackLists(
      page: page,
      pageSize: pageSize,
      search: search,
      activeOnly: true,
    );
    return response.blackLists;
  }

  // 11. 해제된 블랙리스트만 조회
  static Future<List<BlackList>> getReleasedBlackLists({
    int page = 1,
    int pageSize = 10,
    String? search,
  }) async {
    final response = await getBlackLists(
      page: page,
      pageSize: pageSize,
      search: search,
      activeOnly: false,
    );
    return response.blackLists;
  }

  // 12. 사용자가 현재 정지 중인지 확인
  static Future<bool> isUserSuspended(int accountIdx) async {
    try {
      final status = await getUserBlackListStatus(accountIdx);
      return status.isSuspended;
    } catch (e) {
      print('WARNING: 사용자 정지 상태 확인 실패: $e');
      return false; // 확인 실패 시 정지되지 않은 것으로 간주
    }
  }

  // 13. 특정 사용자의 현재 블랙리스트 정보 조회
  static Future<BlackList?> getUserCurrentBlackList(int accountIdx) async {
    try {
      final blackLists = await getActiveBlackLists(pageSize: 100); // 충분히 큰 페이지 크기
      
      for (final blackList in blackLists) {
        if (blackList.accountIdx == accountIdx && blackList.isActive) {
          return blackList;
        }
      }
      
      return null; // 활성화된 블랙리스트가 없음
    } catch (e) {
      print('WARNING: 사용자 블랙리스트 조회 실패: $e');
      return null;
    }
  }

  // 14. 블랙리스트 검색 (이메일, 이름, 전화번호로 검색)
  static Future<List<BlackList>> searchBlackLists(String query) async {
    final response = await getBlackLists(
      page: 1,
      pageSize: 50, // 검색 결과는 적당한 크기로 제한
      search: query,
    );
    return response.blackLists;
  }
}