import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/config.dart';

class AdminCompletedDonationService {
  // 헌혈 완료 대기 목록 조회 (병원이 1차 처리한 후 관리자 승인 대기)
  static Future<Map<String, dynamic>> getPendingCompletions() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      throw Exception('로그인이 필요합니다.');
    }

    final response = await http.get(
      Uri.parse('${Config.serverUrl}/api/admin/completed_donation/pending'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else if (response.statusCode == 401) {
      throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
    } else {
      throw Exception('데이터를 불러오는데 실패했습니다.');
    }
  }

  // 헌혈 완료 목록 조회 (최종 승인된 모든 헌혈)
  static Future<Map<String, dynamic>> getCompletedDonations() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      throw Exception('로그인이 필요합니다.');
    }

    final response = await http.get(
      Uri.parse('${Config.serverUrl}/api/admin/completed_donation/completed'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else if (response.statusCode == 401) {
      throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
    } else {
      throw Exception('데이터를 불러오는데 실패했습니다.');
    }
  }

  // 관리자 최종 헌혈 완료 승인
  static Future<Map<String, dynamic>> finalApprove(int applicationId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      throw Exception('로그인이 필요합니다.');
    }

    final response = await http.post(
      Uri.parse('${Config.serverUrl}/api/admin/completed_donation/approve-completion/$applicationId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else if (response.statusCode == 401) {
      throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
    } else {
      final error = json.decode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? '승인에 실패했습니다.');
    }
  }

  // 관리자 헌혈 중단 승인 (중단대기 → 헌혈취소)
  static Future<Map<String, dynamic>> rejectCompletion(
    int applicationId,
    String reason,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      throw Exception('로그인이 필요합니다.');
    }

    final response = await http.post(
      Uri.parse('${Config.serverUrl}/api/admin/completed_donation/approve-cancellation/$applicationId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'reason': reason,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else if (response.statusCode == 401) {
      throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
    } else {
      final error = json.decode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? '반려에 실패했습니다.');
    }
  }

  // 관리자 헌혈 취소 최종 승인 (추가 API가 있다면)
  static Future<Map<String, dynamic>> finalApproveCancellation(
    int applicationId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      throw Exception('로그인이 필요합니다.');
    }

    final response = await http.post(
      Uri.parse('${Config.serverUrl}/api/admin/cancelled_donation/final_approve'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'application_id': applicationId,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else if (response.statusCode == 401) {
      throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
    } else {
      final error = json.decode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? '승인에 실패했습니다.');
    }
  }
}