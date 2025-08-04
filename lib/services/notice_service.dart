import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notice_model.dart';
import '../utils/config.dart';

class NoticeService {
  static String get baseUrl => '${Config.serverUrl}/api/notices';

  // 토큰 가져오기
  static Future<String> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ?? '';
  }

  // 공지글 작성 (관리자만)
  static Future<Notice> createNotice(NoticeCreateRequest request) async {
    try {
      final token = await _getAuthToken();
      
      final response = await http.post(
        Uri.parse('$baseUrl/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Notice.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw Exception('공지글 작성 실패: ${error['detail'] ?? response.body}');
      }
    } catch (e) {
      throw Exception('공지글 작성 중 오류 발생: $e');
    }
  }

  // 공지글 목록 조회 (모든 사용자)
  static Future<NoticeListResponse> getNotices({
    int page = 1,
    int pageSize = 10,
    bool activeOnly = true,
    bool importantOnly = false,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'page_size': pageSize.toString(),
        'active_only': activeOnly.toString(),
        'important_only': importantOnly.toString(),
      };

      final uri = Uri.parse(baseUrl).replace(
        path: '$baseUrl/',
        queryParameters: queryParams,
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return NoticeListResponse.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw Exception('공지글 목록 조회 실패: ${error['detail'] ?? response.body}');
      }
    } catch (e) {
      throw Exception('공지글 목록 조회 중 오류 발생: $e');
    }
  }

  // 특정 공지글 상세 조회 (모든 사용자)
  static Future<Notice> getNoticeDetail(int noticeIdx) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$noticeIdx'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Notice.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('공지글을 찾을 수 없습니다.');
      } else {
        final error = jsonDecode(response.body);
        throw Exception('공지글 조회 실패: ${error['detail'] ?? response.body}');
      }
    } catch (e) {
      throw Exception('공지글 조회 중 오류 발생: $e');
    }
  }

  // 공지글 수정 (관리자만)
  static Future<Notice> updateNotice(int noticeIdx, NoticeUpdateRequest request) async {
    try {
      final token = await _getAuthToken();
      
      final response = await http.put(
        Uri.parse('$baseUrl/$noticeIdx'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Notice.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('공지글을 찾을 수 없습니다.');
      } else {
        final error = jsonDecode(response.body);
        throw Exception('공지글 수정 실패: ${error['detail'] ?? response.body}');
      }
    } catch (e) {
      throw Exception('공지글 수정 중 오류 발생: $e');
    }
  }

  // 공지글 삭제 (관리자만)
  static Future<void> deleteNotice(int noticeIdx) async {
    try {
      final token = await _getAuthToken();
      
      final response = await http.delete(
        Uri.parse('$baseUrl/$noticeIdx'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 204) {
        return; // 성공적으로 삭제됨
      } else if (response.statusCode == 404) {
        throw Exception('공지글을 찾을 수 없습니다.');
      } else {
        final error = jsonDecode(response.body);
        throw Exception('공지글 삭제 실패: ${error['detail'] ?? response.body}');
      }
    } catch (e) {
      throw Exception('공지글 삭제 중 오류 발생: $e');
    }
  }

  // 중요 공지글만 조회 (홈 화면 등에서 사용)
  static Future<List<Notice>> getImportantNotices({int limit = 5}) async {
    try {
      final response = await getNotices(
        page: 1,
        pageSize: limit,
        activeOnly: true,
        importantOnly: true,
      );
      return response.notices;
    } catch (e) {
      throw Exception('중요 공지글 조회 중 오류 발생: $e');
    }
  }
}