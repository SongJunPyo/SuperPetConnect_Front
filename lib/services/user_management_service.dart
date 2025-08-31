import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/config.dart';
import '../models/user_model.dart';

class UserManagementService {
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<UserListResponse> getUsers({
    int page = 1,
    int pageSize = 10,
    String? search,
    int? userType,
    int? status,
  }) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('로그인이 필요합니다');
    }

    final queryParams = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };

    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (userType != null) {
      queryParams['user_type'] = userType.toString();
    }
    if (status != null) {
      queryParams['status'] = status.toString();
    }

    final uri = Uri.parse(
      '${Config.serverUrl}/api/admin/users',
    ).replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      return UserListResponse.fromJson(data);
    } else {
      throw Exception('사용자 목록 조회 실패: ${response.statusCode}');
    }
  }

  static Future<UserStats> getUserStats() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('로그인이 필요합니다');
    }

    final response = await http.get(
      Uri.parse('${Config.serverUrl}/api/admin/users/stats'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      return UserStats.fromJson(data);
    } else {
      throw Exception('통계 조회 실패: ${response.statusCode}');
    }
  }

  static Future<void> blacklistUser(BlacklistRequest request) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('로그인이 필요합니다');
    }

    final response = await http.post(
      Uri.parse('${Config.serverUrl}/api/admin/users/blacklist'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(request.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception('블랙리스트 지정 실패: ${response.statusCode}');
    }
  }

  static Future<void> updateUserStatus(int userId, int status) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('로그인이 필요합니다');
    }

    final response = await http.patch(
      Uri.parse('${Config.serverUrl}/api/admin/users/$userId/status'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'status': status}),
    );

    if (response.statusCode != 200) {
      throw Exception('사용자 상태 변경 실패: ${response.statusCode}');
    }
  }
}
