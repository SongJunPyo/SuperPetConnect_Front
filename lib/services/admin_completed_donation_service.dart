import 'dart:convert';
import 'auth_http_client.dart';
import '../utils/config.dart';
import '../utils/api_endpoints.dart';

class AdminCompletedDonationService {
  // 헌혈 완료 대기 목록 조회 (병원이 1차 처리한 후 관리자 승인 대기)
  static Future<Map<String, dynamic>> getPendingCompletions() async {
    final response = await AuthHttpClient.get(
      Uri.parse('${Config.serverUrl}${ApiEndpoints.adminCompletedDonationPending}'),
    );

    if (response.statusCode == 200) {
      return response.parseJson();
    } else {
      throw Exception('데이터를 불러오는데 실패했습니다.');
    }
  }

  // 헌혈 완료 목록 조회 (최종 승인된 모든 헌혈)
  static Future<Map<String, dynamic>> getCompletedDonations() async {
    final response = await AuthHttpClient.get(
      Uri.parse('${Config.serverUrl}${ApiEndpoints.adminCompletedDonationCompleted}'),
    );

    if (response.statusCode == 200) {
      return response.parseJson();
    } else {
      throw Exception('데이터를 불러오는데 실패했습니다.');
    }
  }

  // 관리자 최종 헌혈 완료 승인
  static Future<Map<String, dynamic>> finalApprove(int applicationId) async {
    final response = await AuthHttpClient.post(
      Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.adminCompletedDonationApprove(applicationId)}',
      ),
    );

    if (response.statusCode == 200) {
      return response.parseJson();
    } else {
      throw response.toException('승인에 실패했습니다.');
    }
  }

  // 관리자 헌혈 중단 승인 (중단대기 → 헌혈취소)
  static Future<Map<String, dynamic>> rejectCompletion(
    int applicationId,
    String reason,
  ) async {
    final response = await AuthHttpClient.post(
      Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.adminCompletedDonationApproveCancellation(applicationId)}',
      ),
      body: json.encode({'reason': reason}),
    );

    if (response.statusCode == 200) {
      return response.parseJson();
    } else {
      throw response.toException('반려에 실패했습니다.');
    }
  }

  // 관리자 헌혈 취소 최종 승인 (추가 API가 있다면)
  static Future<Map<String, dynamic>> finalApproveCancellation(
    int applicationId,
  ) async {
    final response = await AuthHttpClient.post(
      Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.adminCancelledDonationFinalApprove}',
      ),
      body: json.encode({'application_id': applicationId}),
    );

    if (response.statusCode == 200) {
      return response.parseJson();
    } else {
      throw response.toException('승인에 실패했습니다.');
    }
  }
}
