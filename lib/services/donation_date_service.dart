// services/donation_date_service.dart

import 'dart:convert';
import '../models/donation_post_date_model.dart';
import '../utils/config.dart';
import '../utils/api_endpoints.dart';
import 'auth_http_client.dart';

class DonationDateService {

  // 1. 단일 헌혈 날짜 추가 (POST /api/donation-dates/)
  static Future<DonationPostDate> addDonationDate(
    int postIdx,
    DateTime donationDate,
  ) async {
    try {
      final response = await AuthHttpClient.post(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.donationDates}'),
        body: jsonEncode({
          'post_idx': postIdx,
          'donation_date': donationDate.toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.parseJson();
        return DonationPostDate.fromJson(data);
      } else {
        throw Exception('헌혈 날짜 추가 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('헌혈 날짜 추가 중 오류 발생: $e');
    }
  }

  // 2. 여러 헌혈 날짜 한번에 추가 (POST /api/donation-dates/bulk)
  static Future<List<DonationPostDate>> addMultipleDonationDates(
    int postIdx,
    List<DateTime> donationDates,
  ) async {
    try {
      final response = await AuthHttpClient.post(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.donationDatesBulk}'),
        body: jsonEncode({
          'post_idx': postIdx,
          'donation_dates':
              donationDates.map((date) => date.toIso8601String()).toList(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.parseJson();
        final List<dynamic> createdDates = data['created_dates'];
        return createdDates
            .map((item) => DonationPostDate.fromJson(item))
            .toList();
      } else {
        throw Exception('다중 헌혈 날짜 추가 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('다중 헌혈 날짜 추가 중 오류 발생: $e');
    }
  }

  // 3. 특정 게시글의 헌혈 날짜 조회 (GET /api/donation-dates/post/{post_idx})
  static Future<List<DonationPostDate>> getDonationDatesByPostIdx(
    int postIdx,
  ) async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.donationDatesByPost(postIdx)}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.parseJsonList();
        return data.map((item) => DonationPostDate.fromJson(item)).toList();
      } else {
        throw Exception('헌혈 날짜 조회 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('헌혈 날짜 조회 중 오류 발생: $e');
    }
  }

  // 4. 헌혈 날짜 수정 (PUT /api/donation-dates/{post_dates_id})
  static Future<DonationPostDate> updateDonationDate(
    int postDatesId,
    DateTime newDonationDate,
  ) async {
    try {
      final response = await AuthHttpClient.put(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.donationDate(postDatesId)}'),
        body: jsonEncode({'donation_date': newDonationDate.toIso8601String()}),
      );

      if (response.statusCode == 200) {
        final data = response.parseJson();
        return DonationPostDate.fromJson(data);
      } else {
        throw Exception('헌혈 날짜 수정 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('헌혈 날짜 수정 중 오류 발생: $e');
    }
  }

  // 5. 헌혈 날짜 삭제 (DELETE /api/donation-dates/{post_dates_id})
  static Future<void> deleteDonationDate(int postDatesId) async {
    try {
      final response = await AuthHttpClient.delete(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.donationDate(postDatesId)}'),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('헌혈 날짜 삭제 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('헌혈 날짜 삭제 중 오류 발생: $e');
    }
  }

  // 추가: 모든 헌혈 날짜 조회 (관리자용)
  static Future<List<DonationPostDate>> getAllDonationDates() async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.donationDates}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.parseJsonList();
        return data.map((item) => DonationPostDate.fromJson(item)).toList();
      } else {
        throw Exception('전체 헌혈 날짜 조회 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('전체 헌혈 날짜 조회 중 오류 발생: $e');
    }
  }

  // 추가: 날짜 범위로 헌혈 날짜 조회
  static Future<List<DonationPostDate>> getDonationDatesByRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse(
          '${Config.serverUrl}${ApiEndpoints.donationDates}?start_date=${startDate.toIso8601String()}&end_date=${endDate.toIso8601String()}',
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.parseJsonList();
        return data.map((item) => DonationPostDate.fromJson(item)).toList();
      } else {
        throw Exception('날짜 범위 헌혈 날짜 조회 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('날짜 범위 헌혈 날짜 조회 중 오류 발생: $e');
    }
  }
}
