// services/donation_time_service.dart

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../models/donation_post_time_model.dart';
import '../utils/config.dart';

class DonationTimeService {
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

  // 1. 특정 날짜의 시간들 조회 (GET /api/donation_post_times/date/{post_dates_idx})
  static Future<List<DonationPostTime>> getTimesByDateIdx(int postDatesIdx) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/donation_post_times/date/$postDatesIdx'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((item) => DonationPostTime.fromJson(item)).toList();
      } else {
        throw Exception('헌혈 시간 조회 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('헌혈 시간 조회 중 오류 발생: $e');
    }
  }

  // 2. 특정 시간 조회 (GET /api/donation_post_times/{post_times_idx})
  static Future<DonationPostTime?> getTimeById(int postTimesIdx) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/donation_post_times/$postTimesIdx'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return DonationPostTime.fromJson(data);
      } else {
        throw Exception('헌혈 시간 조회 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('헌혈 시간 조회 중 오류 발생: $e');
    }
  }

  // 3. 단일 시간 등록 (POST /api/donation_post_times/)
  static Future<DonationPostTime> addDonationTime(int postDatesIdx, DateTime donationTime) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/donation_post_times/'),
        headers: headers,
        body: jsonEncode({
          'post_dates_idx': postDatesIdx,
          'donation_time': donationTime.toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return DonationPostTime.fromJson(data);
      } else {
        throw Exception('헌혈 시간 추가 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('헌혈 시간 추가 중 오류 발생: $e');
    }
  }

  // 4. 여러 시간 한번에 등록 (POST /api/donation_post_times/bulk)
  static Future<List<DonationPostTime>> addMultipleDonationTimes(int postDatesIdx, List<DateTime> donationTimes) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/donation_post_times/bulk'),
        headers: headers,
        body: jsonEncode({
          'post_dates_idx': postDatesIdx,
          'donation_times': donationTimes.map((time) => time.toIso8601String()).toList(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> createdTimes = data['created_times'] ?? data;
        return createdTimes.map((item) => DonationPostTime.fromJson(item)).toList();
      } else {
        throw Exception('다중 헌혈 시간 추가 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('다중 헌혈 시간 추가 중 오류 발생: $e');
    }
  }

  // 5. 날짜+시간 함께 생성 (POST /api/donation_post_times/date-time)
  static Future<DonationDateWithTimes> createDateWithTimes(int postIdx, DateTime donationDate, List<DateTime> donationTimes) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/donation_post_times/date-time'),
        headers: headers,
        body: jsonEncode({
          'post_idx': postIdx,
          'donation_date': donationDate.toIso8601String(),
          'donation_times': donationTimes.map((time) => time.toIso8601String()).toList(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return DonationDateWithTimes.fromJson(data);
      } else {
        throw Exception('날짜+시간 생성 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('날짜+시간 생성 중 오류 발생: $e');
    }
  }

  // 6. 시간 수정 (PUT /api/donation_post_times/{post_times_idx})
  static Future<DonationPostTime> updateDonationTime(int postTimesIdx, DateTime newDonationTime) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.put(
        Uri.parse('$baseUrl/donation_post_times/$postTimesIdx'),
        headers: headers,
        body: jsonEncode({
          'donation_time': newDonationTime.toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return DonationPostTime.fromJson(data);
      } else {
        throw Exception('헌혈 시간 수정 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('헌혈 시간 수정 중 오류 발생: $e');
    }
  }

  // 7. 시간 삭제 (DELETE /api/donation_post_times/{post_times_idx})
  static Future<void> deleteDonationTime(int postTimesIdx) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.delete(
        Uri.parse('$baseUrl/donation_post_times/$postTimesIdx'),
        headers: headers,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('헌혈 시간 삭제 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('헌혈 시간 삭제 중 오류 발생: $e');
    }
  }

  // 8. 게시글의 모든 날짜+시간 조회 (GET /api/donation_post_times/post/{post_idx}/dates-with-times)
  static Future<List<DonationDateWithTimes>> getPostDatesWithTimes(int postIdx) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/donation_post_times/post/$postIdx/dates-with-times'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((item) => DonationDateWithTimes.fromJson(item)).toList();
      } else {
        throw Exception('게시글 날짜+시간 조회 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('게시글 날짜+시간 조회 중 오류 발생: $e');
    }
  }

  // 9. 편의 메서드: 특정 날짜에 여러 시간대를 한번에 추가
  static Future<List<DonationPostTime>> addTimesToDate(int postDatesIdx, List<TimeOfDay> times, DateTime baseDate) async {
    final donationTimes = times.map((timeOfDay) {
      return DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        timeOfDay.hour,
        timeOfDay.minute,
      );
    }).toList();

    return await addMultipleDonationTimes(postDatesIdx, donationTimes);
  }

  // 10. 편의 메서드: 시간 범위 생성 (예: 9:00부터 17:00까지 1시간 간격)
  static List<DateTime> generateTimeRange(DateTime baseDate, TimeOfDay startTime, TimeOfDay endTime, int intervalMinutes) {
    final List<DateTime> times = [];
    
    DateTime currentTime = DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      startTime.hour,
      startTime.minute,
    );
    
    final DateTime endDateTime = DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      endTime.hour,
      endTime.minute,
    );

    while (currentTime.isBefore(endDateTime) || currentTime.isAtSameMomentAs(endDateTime)) {
      times.add(currentTime);
      currentTime = currentTime.add(Duration(minutes: intervalMinutes));
    }

    return times;
  }

  // 11. 편의 메서드: 일반적인 진료 시간대 템플릿
  static List<DateTime> getCommonHospitalHours(DateTime baseDate) {
    return generateTimeRange(
      baseDate,
      const TimeOfDay(hour: 9, minute: 0),   // 오전 9시
      const TimeOfDay(hour: 17, minute: 0),  // 오후 5시
      60, // 1시간 간격
    );
  }

  // 12. 편의 메서드: 오전/오후 시간대 템플릿
  static List<DateTime> getMorningHours(DateTime baseDate) {
    return generateTimeRange(
      baseDate,
      const TimeOfDay(hour: 9, minute: 0),   // 오전 9시
      const TimeOfDay(hour: 12, minute: 0),  // 정오 12시
      60, // 1시간 간격
    );
  }

  static List<DateTime> getAfternoonHours(DateTime baseDate) {
    return generateTimeRange(
      baseDate,
      const TimeOfDay(hour: 14, minute: 0),  // 오후 2시
      const TimeOfDay(hour: 17, minute: 0),  // 오후 5시
      60, // 1시간 간격
    );
  }
}