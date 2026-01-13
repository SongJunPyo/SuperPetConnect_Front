import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notice_model.dart';
import '../utils/config.dart';

class NoticeService {
  static String get baseUrl => '${Config.serverUrl}/api/notices';
  static String get adminBaseUrl => '${Config.serverUrl}/api/admin/notices';

  // 토큰 가져오기
  static Future<String> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ?? '';
  }

  // 공지글 작성 (관리자만)
  static Future<Notice> createNotice(NoticeCreateRequest request) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다. 다시 로그인해주세요.');
      }


      final response = await http.post(
        Uri.parse('$baseUrl/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(request.toJson()),
      );


      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return Notice.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('권한이 없습니다. 관리자 계정으로 로그인해주세요.');
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(
          '공지글 작성 실패: ${error['detail'] ?? error['message'] ?? response.body}',
        );
      }
    } catch (e) {
      throw Exception('공지글 작성 중 오류 발생: $e');
    }
  }

  // 관리자용 공지글 목록 조회 (모든 공지글 포함)
  static Future<List<Notice>> getAdminNotices({
    bool activeOnly = false,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다. 다시 로그인해주세요.');
      }

      final queryParams = <String, String>{};
      if (activeOnly) {
        queryParams['active_only'] = 'true';
      }

      final uri = Uri.parse(
        '$adminBaseUrl/',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);


      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );


      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        // 새로운 API는 직접 배열을 반환
        if (data is List) {
          return data.map((notice) => Notice.fromJson(notice)).toList();
        } else {
          throw Exception('예상치 못한 응답 형식');
        }
      } else if (response.statusCode == 401) {
        throw Exception('권한이 없습니다. 관리자 계정으로 로그인해주세요.');
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(
          '공지글 목록 조회 실패: ${error['detail'] ?? error['message'] ?? response.body}',
        );
      }
    } catch (e) {
      throw Exception('공지글 목록 조회 중 오류 발생: $e');
    }
  }

  // 공지글 목록 조회 (모든 사용자)
  static Future<List<Notice>> getNotices({
    bool activeOnly = true,
    String? userRole, // "admin", "hospital", "user" - 역할별 필터링용
  }) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다. 다시 로그인해주세요.');
      }

      final queryParams = <String, String>{};
      if (activeOnly) {
        queryParams['active_only'] = 'true';
      }
      if (userRole != null) {
        queryParams['user_role'] = userRole;
      }

      final uri = Uri.parse(
        '$baseUrl/',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);


      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );


      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        // 새로운 API는 직접 배열을 반환
        if (data is List) {
          return data.map((notice) => Notice.fromJson(notice)).toList();
        } else {
          throw Exception('예상치 못한 응답 형식');
        }
      } else if (response.statusCode == 401) {
        throw Exception('권한이 없습니다. 관리자 계정으로 로그인해주세요.');
      } else if (response.statusCode == 403) {
        throw Exception('접근 권한이 없습니다.');
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(
          '공지글 목록 조회 실패: ${error['detail'] ?? error['message'] ?? response.body}',
        );
      }
    } catch (e) {
      throw Exception('공지글 목록 조회 중 오류 발생: $e');
    }
  }

  // 특정 공지글 상세 조회 (모든 사용자)
  static Future<Notice> getNoticeDetail(int noticeIdx) async {
    try {

      final response = await http.get(Uri.parse('$baseUrl/$noticeIdx'));


      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return Notice.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('공지글을 찾을 수 없습니다.');
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(
          '공지글 조회 실패: ${error['detail'] ?? error['message'] ?? response.body}',
        );
      }
    } catch (e) {
      throw Exception('공지글 조회 중 오류 발생: $e');
    }
  }

  // 공지글 수정 (관리자만)
  static Future<Notice> updateNotice(
    int noticeIdx,
    NoticeUpdateRequest request,
  ) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다. 다시 로그인해주세요.');
      }


      final response = await http.put(
        Uri.parse('$baseUrl/$noticeIdx'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(request.toJson()),
      );


      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return Notice.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('권한이 없습니다. 관리자 계정으로 로그인해주세요.');
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else if (response.statusCode == 404) {
        throw Exception('공지글을 찾을 수 없습니다.');
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(
          '공지글 수정 실패: ${error['detail'] ?? error['message'] ?? response.body}',
        );
      }
    } catch (e) {
      throw Exception('공지글 수정 중 오류 발생: $e');
    }
  }

  // 공지글 활성화/비활성화 토글 (관리자만)
  static Future<Notice> toggleNoticeActive(int noticeIdx) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다. 다시 로그인해주세요.');
      }
      
      
      final response = await http.patch(
        Uri.parse('$baseUrl/$noticeIdx/toggle'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );


      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return Notice.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('권한이 없습니다. 관리자 계정으로 로그인해주세요.');
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else if (response.statusCode == 404) {
        throw Exception('공지글을 찾을 수 없습니다.');
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception('상태 변경 실패: ${error['detail'] ?? error['message'] ?? response.body}');
      }
    } catch (e) {
      throw Exception('공지글 상태 변경 중 오류 발생: $e');
    }
  }

  // 공지글 삭제 (관리자만) - 소프트 삭제 (is_active = false)
  static Future<void> deleteNotice(int noticeIdx) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다. 다시 로그인해주세요.');
      }


      final response = await http.delete(
        Uri.parse('$baseUrl/$noticeIdx'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );


      if (response.statusCode == 204 || response.statusCode == 200) {
        return; // 성공적으로 삭제됨
      } else if (response.statusCode == 401) {
        throw Exception('권한이 없습니다. 관리자 계정으로 로그인해주세요.');
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else if (response.statusCode == 404) {
        throw Exception('공지글을 찾을 수 없습니다.');
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(
          '공지글 삭제 실패: ${error['detail'] ?? error['message'] ?? response.body}',
        );
      }
    } catch (e) {
      throw Exception('공지글 삭제 중 오류 발생: $e');
    }
  }

  // 공개 공지글 조회 (사용자 화면용, 인증 불필요)
  static Future<List<Notice>> getPublicNotices() async {
    try {

      final response = await http.get(
        Uri.parse('$baseUrl/public'),
        headers: {
          'Content-Type': 'application/json',
        },
      );


      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        // API는 직접 배열을 반환
        if (data is List) {
          return data.map((notice) => Notice.fromJson(notice)).toList();
        } else {
          throw Exception('예상치 못한 응답 형식');
        }
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(
          '공개 공지글 목록 조회 실패: ${error['detail'] ?? error['message'] ?? response.body}',
        );
      }
    } catch (e) {
      // 인증이 필요한 경우 일반 getNotices로 fallback
      try {
        return await getNotices(activeOnly: true, userRole: 'user');
      } catch (fallbackError) {
        throw Exception('공지글 목록 조회 중 오류 발생: $e');
      }
    }
  }

  // 중요 공지글만 조회 (홈 화면 등에서 사용)
  static Future<List<Notice>> getImportantNotices() async {
    try {
      final allNotices = await getNotices(activeOnly: true);

      // 뱃지가 있는 공지글만 필터링하고 최신순으로 정렬
      final importantNotices =
          allNotices.where((notice) => notice.showBadge).toList();

      // 생성일 기준 최신순 정렬
      importantNotices.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return importantNotices.take(5).toList(); // 최대 5개만 반환
    } catch (e) {
      throw Exception('중요 공지글 조회 중 오류 발생: $e');
    }
  }
}
