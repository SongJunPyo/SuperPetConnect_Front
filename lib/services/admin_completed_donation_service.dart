import 'dart:convert';
import 'auth_http_client.dart';
import '../utils/config.dart';

class AdminCompletedDonationService {
  // 헌혈 완료 대기 목록 조회 (병원이 1차 처리한 후 관리자 승인 대기)
  static Future<Map<String, dynamic>> getPendingCompletions() async {
    final response = await AuthHttpClient.get(
      Uri.parse('${Config.serverUrl}/api/admin/completed_donation/pending'),
    );

    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('데이터를 불러오는데 실패했습니다.');
    }
  }

  // 헌혈 완료 목록 조회 (최종 승인된 모든 헌혈)
  static Future<Map<String, dynamic>> getCompletedDonations() async {
    final response = await AuthHttpClient.get(
      Uri.parse('${Config.serverUrl}/api/admin/completed_donation/completed'),
    );

    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('데이터를 불러오는데 실패했습니다.');
    }
  }

  // 관리자 최종 헌혈 완료 승인
  static Future<Map<String, dynamic>> finalApprove(int applicationId) async {
    final response = await AuthHttpClient.post(
      Uri.parse('${Config.serverUrl}/api/admin/completed_donation/approve-completion/$applicationId'),
    );

    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
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
    final response = await AuthHttpClient.post(
      Uri.parse('${Config.serverUrl}/api/admin/completed_donation/approve-cancellation/$applicationId'),
      body: json.encode({
        'reason': reason,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else {
      final error = json.decode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? '반려에 실패했습니다.');
    }
  }

  // 관리자 헌혈 취소 최종 승인 (추가 API가 있다면)
  static Future<Map<String, dynamic>> finalApproveCancellation(
    int applicationId,
  ) async {
    final response = await AuthHttpClient.post(
      Uri.parse('${Config.serverUrl}/api/admin/cancelled_donation/final_approve'),
      body: json.encode({
        'application_id': applicationId,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else {
      final error = json.decode(utf8.decode(response.bodyBytes));
      throw Exception(error['message'] ?? '승인에 실패했습니다.');
    }
  }
}
