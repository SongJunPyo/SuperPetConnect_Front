import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/hospital_column_model.dart';
import '../utils/config.dart';

class HospitalColumnService {
  static String get baseUrl => '${Config.serverUrl}/api/hospital';
  static String get publicBaseUrl => '${Config.serverUrl}/api/hospital/public';

  // 토큰 가져오기
  static Future<String> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ?? '';
  }

  // 병원의 칼럼 작성 권한 확인
  static Future<bool> checkColumnPermission() async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        return false;
      }

      final response = await http.get(
        Uri.parse('${Config.serverUrl}/api/auth/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return data['column_active'] == true;
      }
      
      return false;
    } catch (e) {
      print('ERROR: 칼럼 권한 확인 중 오류: $e');
      return false;
    }
  }

  // 칼럼 작성 (병원 전용)
  static Future<HospitalColumn> createColumn(
    HospitalColumnCreateRequest request,
  ) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다. 다시 로그인해주세요.');
      }

      print('DEBUG: 칼럼 작성 요청 - URL: $baseUrl/columns');
      print('DEBUG: 요청 본문: ${jsonEncode(request.toJson())}');
      print('DEBUG: 토큰: $token');

      final response = await http.post(
        Uri.parse('$baseUrl/columns'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(request.toJson()),
      );

      print('DEBUG: 칼럼 작성 응답 상태코드: ${response.statusCode}');
      print('DEBUG: 칼럼 작성 응답 본문: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return HospitalColumn.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
      } else if (response.statusCode == 403) {
        try {
          final error = jsonDecode(utf8.decode(response.bodyBytes));
          final message = error['detail'] ?? error['message'] ?? '권한이 없습니다.';
          throw Exception(message);
        } catch (e) {
          throw Exception('병원 계정만 접근할 수 있습니다. 또는 칼럼 작성 권한이 비활성화되었습니다.');
        }
      } else if (response.statusCode == 500) {
        try {
          final error = jsonDecode(utf8.decode(response.bodyBytes));
          final message = error['detail'] ?? error['message'] ?? '서버 오류가 발생했습니다.';
          throw Exception('서버 오류: $message');
        } catch (e) {
          throw Exception('서버에서 오류가 발생했습니다. 관리자에게 문의하세요.');
        }
      } else {
        try {
          final error = jsonDecode(utf8.decode(response.bodyBytes));
          throw Exception(
            '칼럼 작성 실패: ${error['detail'] ?? error['message'] ?? response.body}',
          );
        } catch (e) {
          throw Exception('알 수 없는 오류가 발생했습니다. (상태코드: ${response.statusCode})');
        }
      }
    } catch (e) {
      print('ERROR: 칼럼 작성 중 오류: $e');
      throw Exception('칼럼 작성 중 오류 발생: $e');
    }
  }

  // 공개 칼럼 목록 조회 (모든 사용자)
  static Future<HospitalColumnListResponse> getPublicColumns({
    int page = 1,
    int pageSize = 10,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final uri = Uri.parse('$publicBaseUrl/columns').replace(
        queryParameters: queryParams,
      );

      print('DEBUG: 공개 칼럼 목록 조회 - URL: $uri');

      final response = await http.get(uri);

      print('DEBUG: 공개 칼럼 목록 응답 상태코드: ${response.statusCode}');
      print('DEBUG: 공개 칼럼 목록 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return HospitalColumnListResponse.fromJson(data);
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(
          '칼럼 목록 조회 실패: ${error['detail'] ?? error['message'] ?? response.body}',
        );
      }
    } catch (e) {
      print('ERROR: 칼럼 목록 조회 중 오류: $e');
      throw Exception('칼럼 목록 조회 중 오류 발생: $e');
    }
  }

  // 서버 API 테스트용 함수
  static Future<void> testServerConnection() async {
    try {
      print('DEBUG: 서버 연결 테스트 시작');
      print('DEBUG: baseUrl = $baseUrl');
      print('DEBUG: publicBaseUrl = $publicBaseUrl');
      
      final token = await _getAuthToken();
      print('DEBUG: 토큰 길이: ${token.length}');
      
      // 공개 칼럼 목록 조회 테스트 (인증 불필요)
      final publicResponse = await http.get(
        Uri.parse('$publicBaseUrl/columns?page=1&page_size=10'),
      );
      print('DEBUG: 공개 칼럼 API 응답: ${publicResponse.statusCode} - ${publicResponse.body}');
      
    } catch (e) {
      print('ERROR: 서버 연결 테스트 실패: $e');
    }
  }

  // 칼럼 상세 조회 (모든 사용자)
  static Future<HospitalColumn> getColumnDetail(int columnIdx) async {
    try {
      final token = await _getAuthToken();
      
      print('DEBUG: 칼럼 상세 조회 - URL: $baseUrl/columns/$columnIdx');
      print('DEBUG: 토큰 유무: ${token.isNotEmpty}');

      // 먼저 인증된 사용자로 시도 (미발행 칼럼도 조회 가능)
      final response = await http.get(
        Uri.parse('$baseUrl/columns/$columnIdx'),
        headers: token.isNotEmpty ? {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        } : {},
      );

      print('DEBUG: 칼럼 상세 응답 상태코드: ${response.statusCode}');
      print('DEBUG: 칼럼 상세 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return HospitalColumn.fromJson(data);
      } else if (response.statusCode == 404) {
        // 404인 경우 "내 칼럼" 목록에서 찾아보기
        print('DEBUG: 직접 조회 실패, 내 칼럼 목록에서 검색 시도');
        try {
          final myColumns = await getMyColumns(page: 1, pageSize: 50);
          final targetColumn = myColumns.columns.firstWhere(
            (column) => column.columnIdx == columnIdx,
          );
          print('DEBUG: 내 칼럼 목록에서 찾음: ${targetColumn.title}');
          return targetColumn;
        } catch (e) {
          print('ERROR: 내 칼럼 목록에서도 찾을 수 없음: $e');
          throw Exception('칼럼을 찾을 수 없습니다.');
        }
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(
          '칼럼 조회 실패: ${error['detail'] ?? error['message'] ?? response.body}',
        );
      }
    } catch (e) {
      print('ERROR: 칼럼 조회 중 오류: $e');
      if (e.toString().contains('칼럼을 찾을 수 없습니다')) {
        rethrow;
      }
      throw Exception('칼럼 조회 중 오류 발생: $e');
    }
  }

  // 내 칼럼 목록 조회 (병원 전용)
  static Future<HospitalColumnListResponse> getMyColumns({
    int page = 1,
    int pageSize = 10,
    bool? isPublished,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다. 다시 로그인해주세요.');
      }

      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (isPublished != null) {
        queryParams['is_published'] = isPublished.toString();
      }

      final uri = Uri.parse('$baseUrl/columns/my').replace(
        queryParameters: queryParams,
      );

      print('DEBUG: 내 칼럼 목록 조회 - URL: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('DEBUG: 내 칼럼 목록 응답 상태코드: ${response.statusCode}');
      print('DEBUG: 내 칼럼 목록 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return HospitalColumnListResponse.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
      } else if (response.statusCode == 403) {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        final message = error['detail'] ?? error['message'] ?? '권한이 없습니다.';
        throw Exception(message);
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(
          '내 칼럼 목록 조회 실패: ${error['detail'] ?? error['message'] ?? response.body}',
        );
      }
    } catch (e) {
      print('ERROR: 내 칼럼 목록 조회 중 오류: $e');
      throw Exception('내 칼럼 목록 조회 중 오류 발생: $e');
    }
  }

  // 칼럼 수정 (작성자만)
  static Future<HospitalColumn> updateColumn(
    int columnIdx,
    HospitalColumnUpdateRequest request,
  ) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다. 다시 로그인해주세요.');
      }

      print('DEBUG: 칼럼 수정 요청 - URL: $baseUrl/columns/$columnIdx');
      print('DEBUG: 수정 요청 본문: ${jsonEncode(request.toJson())}');

      final response = await http.put(
        Uri.parse('$baseUrl/columns/$columnIdx'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(request.toJson()),
      );

      print('DEBUG: 칼럼 수정 응답 상태코드: ${response.statusCode}');
      print('DEBUG: 칼럼 수정 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return HospitalColumn.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
      } else if (response.statusCode == 403) {
        throw Exception('수정 권한이 없습니다.');
      } else if (response.statusCode == 404) {
        throw Exception('칼럼을 찾을 수 없습니다.');
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(
          '칼럼 수정 실패: ${error['detail'] ?? error['message'] ?? response.body}',
        );
      }
    } catch (e) {
      print('ERROR: 칼럼 수정 중 오류: $e');
      throw Exception('칼럼 수정 중 오류 발생: $e');
    }
  }

  // 칼럼 삭제 (작성자만)
  static Future<void> deleteColumn(int columnIdx) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다. 다시 로그인해주세요.');
      }

      print('DEBUG: 칼럼 삭제 요청 - URL: $baseUrl/columns/$columnIdx');

      final response = await http.delete(
        Uri.parse('$baseUrl/columns/$columnIdx'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('DEBUG: 칼럼 삭제 응답 상태코드: ${response.statusCode}');
      print('DEBUG: 칼럼 삭제 응답 본문: ${response.body}');

      if (response.statusCode == 204 || response.statusCode == 200) {
        return; // 성공적으로 삭제됨
      } else if (response.statusCode == 401) {
        throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
      } else if (response.statusCode == 403) {
        throw Exception('삭제 권한이 없습니다.');
      } else if (response.statusCode == 404) {
        throw Exception('칼럼을 찾을 수 없습니다.');
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(
          '칼럼 삭제 실패: ${error['detail'] ?? error['message'] ?? response.body}',
        );
      }
    } catch (e) {
      print('ERROR: 칼럼 삭제 중 오류: $e');
      throw Exception('칼럼 삭제 중 오류 발생: $e');
    }
  }

  // 관리자용: 모든 칼럼 목록 조회 (새로운 전용 API 사용)
  static Future<HospitalColumnListResponse> getAllColumns({
    int page = 1,
    int pageSize = 20,
    bool? isPublished,
    DateTime? startDate,
    DateTime? endDate,
    String? search,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다. 다시 로그인해주세요.');
      }

      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (isPublished != null) {
        queryParams['is_published'] = isPublished.toString();
      }

      if (startDate != null) {
        queryParams['start_date'] = DateFormat('yyyy-MM-dd').format(startDate);
      }

      if (endDate != null) {
        queryParams['end_date'] = DateFormat('yyyy-MM-dd').format(endDate);
      }

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final uri = Uri.parse('${Config.serverUrl}/api/admin/columns').replace(
        queryParameters: queryParams,
      );

      print('DEBUG: 관리자 칼럼 목록 조회 (전용 API) - URL: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('DEBUG: 관리자 칼럼 목록 응답 상태코드: ${response.statusCode}');
      print('DEBUG: 관리자 칼럼 목록 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return HospitalColumnListResponse.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 없습니다.');
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(
          '관리자 칼럼 목록 조회 실패: ${error['detail'] ?? error['message'] ?? response.body}',
        );
      }
    } catch (e) {
      print('ERROR: 관리자 칼럼 목록 조회 중 오류: $e');
      rethrow;
    }
  }

  // 관리자용: 칼럼 발행 승인/해제 (전용 API 사용)
  static Future<HospitalColumn> adminTogglePublish(int columnIdx) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다. 다시 로그인해주세요.');
      }

      print('DEBUG: 관리자 칼럼 발행 토글 요청 - URL: ${Config.serverUrl}/api/admin/columns/$columnIdx/publish');

      final response = await http.patch(
        Uri.parse('${Config.serverUrl}/api/admin/columns/$columnIdx/publish'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('DEBUG: 관리자 칼럼 발행 토글 응답 상태코드: ${response.statusCode}');
      print('DEBUG: 관리자 칼럼 발행 토글 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return HospitalColumn.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 없습니다.');
      } else if (response.statusCode == 404) {
        throw Exception('칼럼을 찾을 수 없습니다.');
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(
          '공개 상태 변경 실패: ${error['detail'] ?? error['message'] ?? response.body}',
        );
      }
    } catch (e) {
      print('ERROR: 관리자 칼럼 공개 상태 변경 중 오류: $e');
      throw Exception('공개 상태 변경 중 오류 발생: $e');
    }
  }

  // 조회수 증가 (세션 스토리지로 중복 방지)
  static Future<void> increaseViewCount(int columnIdx) async {
    try {
      final token = await _getAuthToken();
      
      print('DEBUG: 조회수 증가 요청 - URL: $baseUrl/columns/$columnIdx/view');
      
      final response = await http.post(
        Uri.parse('$baseUrl/columns/$columnIdx/view'),
        headers: token.isNotEmpty ? {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        } : {
          'Content-Type': 'application/json',
        },
      );

      print('DEBUG: 조회수 증가 응답 상태코드: ${response.statusCode}');
      print('DEBUG: 조회수 증가 응답 본문: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('DEBUG: 조회수 증가 성공');
        return;
      } else {
        print('WARNING: 조회수 증가 실패 - 상태코드: ${response.statusCode}');
        // 조회수 증가 실패는 사용자 경험에 영향을 주지 않도록 예외를 던지지 않음
      }
    } catch (e) {
      print('WARNING: 조회수 증가 중 오류 (무시됨): $e');
      // 조회수 증가 실패는 사용자 경험에 영향을 주지 않도록 예외를 던지지 않음
    }
  }

  // 관리자용: 칼럼 상세 조회 (전용 API 사용)
  static Future<HospitalColumn> getAdminColumnDetail(int columnIdx) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다. 다시 로그인해주세요.');
      }

      print('DEBUG: 관리자 칼럼 상세 조회 - URL: ${Config.serverUrl}/api/admin/columns/$columnIdx');

      final response = await http.get(
        Uri.parse('${Config.serverUrl}/api/admin/columns/$columnIdx'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('DEBUG: 관리자 칼럼 상세 응답 상태코드: ${response.statusCode}');
      print('DEBUG: 관리자 칼럼 상세 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return HospitalColumn.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 없습니다.');
      } else if (response.statusCode == 404) {
        throw Exception('칼럼을 찾을 수 없습니다.');
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(
          '관리자 칼럼 조회 실패: ${error['detail'] ?? error['message'] ?? response.body}',
        );
      }
    } catch (e) {
      print('ERROR: 관리자 칼럼 조회 중 오류: $e');
      throw Exception('관리자 칼럼 조회 중 오류 발생: $e');
    }
  }
}