// services/donation_date_service.dart

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/donation_post_date_model.dart';
import '../utils/config.dart';

class DonationDateService {
  static String get baseUrl => '${Config.serverUrl}/api';

  // 인증 토큰 가져오기
  static Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // 공통 헤더 생성
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getAuthToken();
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    };
  }

  // 1. 단일 헌혈 날짜 추가 (POST /api/donation-dates/)
  static Future<DonationPostDate> addDonationDate(int postIdx, DateTime donationDate) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/donation-dates/'),
        headers: headers,
        body: jsonEncode({
          'post_idx': postIdx,
          'donation_date': donationDate.toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return DonationPostDate.fromJson(data);
      } else {
        throw Exception('헌혈 날짜 추가 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('헌혈 날짜 추가 중 오류 발생: $e');
    }
  }

  // 2. 여러 헌혈 날짜 한번에 추가 (POST /api/donation-dates/bulk)
  static Future<List<DonationPostDate>> addMultipleDonationDates(int postIdx, List<DateTime> donationDates) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/donation-dates/bulk'),
        headers: headers,
        body: jsonEncode({
          'post_idx': postIdx,
          'donation_dates': donationDates.map((date) => date.toIso8601String()).toList(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> createdDates = data['created_dates'];
        return createdDates.map((item) => DonationPostDate.fromJson(item)).toList();
      } else {
        throw Exception('다중 헌혈 날짜 추가 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('다중 헌혈 날짜 추가 중 오류 발생: $e');
    }
  }

  // 3. 특정 게시글의 헌혈 날짜 조회 (GET /api/donation-dates/post/{post_idx})
  static Future<List<DonationPostDate>> getDonationDatesByPostIdx(int postIdx) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/donation-dates/post/$postIdx'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((item) => DonationPostDate.fromJson(item)).toList();
      } else {
        throw Exception('헌혈 날짜 조회 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('헌혈 날짜 조회 중 오류 발생: $e');
    }
  }

  // 4. 헌혈 날짜 수정 (PUT /api/donation-dates/{post_dates_id})
  static Future<DonationPostDate> updateDonationDate(int postDatesId, DateTime newDonationDate) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.put(
        Uri.parse('$baseUrl/donation-dates/$postDatesId'),
        headers: headers,
        body: jsonEncode({
          'donation_date': newDonationDate.toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
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
      final headers = await _getHeaders();
      
      final response = await http.delete(
        Uri.parse('$baseUrl/donation-dates/$postDatesId'),
        headers: headers,
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
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/donation-dates/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((item) => DonationPostDate.fromJson(item)).toList();
      } else {
        throw Exception('전체 헌혈 날짜 조회 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('전체 헌혈 날짜 조회 중 오류 발생: $e');
    }
  }

  // 추가: 날짜 범위로 헌혈 날짜 조회
  static Future<List<DonationPostDate>> getDonationDatesByRange(DateTime startDate, DateTime endDate) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/donation-dates/?start_date=${startDate.toIso8601String()}&end_date=${endDate.toIso8601String()}'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((item) => DonationPostDate.fromJson(item)).toList();
      } else {
        throw Exception('날짜 범위 헌혈 날짜 조회 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('날짜 범위 헌혈 날짜 조회 중 오류 발생: $e');
    }
  }
}