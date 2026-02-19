import 'dart:convert';
import 'auth_http_client.dart';
import '../utils/config.dart';
import '../models/user_model.dart';

class UserManagementService {
  static Future<UserListResponse> getUsers({
    int page = 1,
    int pageSize = 10,
    String? search,
    int? userType,
    int? status,
  }) async {
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

    final response = await AuthHttpClient.get(uri);

    if (response.statusCode == 200) {
      final data = response.parseJson();
      return UserListResponse.fromJson(data);
    } else {
      throw Exception('사용자 목록 조회 실패: ${response.statusCode}');
    }
  }

  static Future<UserStats> getUserStats() async {
    final response = await AuthHttpClient.get(
      Uri.parse('${Config.serverUrl}/api/admin/users/stats'),
    );

    if (response.statusCode == 200) {
      final data = response.parseJson();
      return UserStats.fromJson(data);
    } else {
      throw Exception('통계 조회 실패: ${response.statusCode}');
    }
  }

  static Future<void> blacklistUser(BlacklistRequest request) async {
    final response = await AuthHttpClient.post(
      Uri.parse('${Config.serverUrl}/api/admin/users/blacklist'),
      body: json.encode(request.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception('블랙리스트 지정 실패: ${response.statusCode}');
    }
  }

  static Future<void> updateUserStatus(int userId, int status) async {
    final response = await AuthHttpClient.patch(
      Uri.parse('${Config.serverUrl}/api/admin/users/$userId/status'),
      body: json.encode({'status': status}),
    );

    if (response.statusCode != 200) {
      throw Exception('사용자 상태 변경 실패: ${response.statusCode}');
    }
  }
}
