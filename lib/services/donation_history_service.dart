// lib/services/donation_history_service.dart
// 반려동물 헌혈 이력 API 서비스

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/config.dart';
import '../models/donation_history_model.dart';

class DonationHistoryService {
  static const String _baseUrl = '/api/pet-donation-history';

  /// JWT 토큰 가져오기
  static Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    if (kDebugMode) {
      print('[DonationHistoryService] 토큰 존재 여부: ${token.isNotEmpty}, 토큰 길이: ${token.length}');
    }
    return token;
  }

  /// 공통 헤더 생성
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    final headers = {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    };
    if (kDebugMode) {
      print('[DonationHistoryService] 헤더: $headers');
      print('[DonationHistoryService] Authorization 헤더 길이: ${headers['Authorization']?.length}');
    }
    return headers;
  }

  /// 헌혈 이력 조회 (페이지네이션)
  /// [petIdx] 반려동물 ID
  /// [page] 페이지 번호 (기본값: 1)
  /// [limit] 페이지당 항목 수 (기본값: 10)
  static Future<DonationHistoryResponse?> getHistory({
    required int petIdx,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final headers = await _getHeaders();
      final url = '${Config.serverUrl}$_baseUrl/$petIdx?page=$page&limit=$limit';

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return DonationHistoryResponse.fromJson(data);
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(error['detail'] ?? '헌혈 이력을 불러오는데 실패했습니다.');
      }
    } catch (e) {
      throw Exception('헌혈 이력 조회 오류: $e');
    }
  }

  /// 헌혈 이력 단건 추가
  /// [petIdx] 반려동물 ID
  /// [request] 추가할 이력 데이터
  static Future<int?> addHistory({
    required int petIdx,
    required DonationHistoryCreateRequest request,
  }) async {
    try {
      final headers = await _getHeaders();
      final url = '${Config.serverUrl}$_baseUrl/$petIdx';

      if (kDebugMode) {
        print('[DonationHistoryService] addHistory 요청');
        print('[DonationHistoryService] URL: $url');
        print('[DonationHistoryService] Headers: $headers');
        print('[DonationHistoryService] Body: ${jsonEncode(request.toJson())}');
      }

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(request.toJson()),
      );

      if (kDebugMode) {
        print('[DonationHistoryService] 응답 상태: ${response.statusCode}');
        print('[DonationHistoryService] 응답 본문: ${utf8.decode(response.bodyBytes)}');
      }

      if (response.statusCode == 201) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['data']?['history_idx'];
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(error['detail'] ?? '헌혈 이력 추가에 실패했습니다.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[DonationHistoryService] 오류: $e');
      }
      throw Exception('헌혈 이력 추가 오류: $e');
    }
  }

  /// 헌혈 이력 여러 건 추가
  /// [petIdx] 반려동물 ID
  /// [requests] 추가할 이력 데이터 목록
  static Future<int> addHistoryBulk({
    required int petIdx,
    required List<DonationHistoryCreateRequest> requests,
  }) async {
    try {
      final headers = await _getHeaders();
      final url = '${Config.serverUrl}$_baseUrl/$petIdx/bulk';

      final body = requests.map((r) => r.toJson()).toList();

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['data']?['count'] ?? 0;
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(error['detail'] ?? '헌혈 이력 일괄 추가에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('헌혈 이력 일괄 추가 오류: $e');
    }
  }

  /// 헌혈 이력 수정 (수동 입력만 가능)
  /// [historyIdx] 이력 ID
  /// [request] 수정할 데이터
  static Future<DonationHistory?> updateHistory({
    required int historyIdx,
    required DonationHistoryUpdateRequest request,
  }) async {
    try {
      final headers = await _getHeaders();
      final url = '${Config.serverUrl}$_baseUrl/$historyIdx';

      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return DonationHistory.fromJson(data);
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(error['detail'] ?? '헌혈 이력 수정에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('헌혈 이력 수정 오류: $e');
    }
  }

  /// 헌혈 이력 삭제 (수동 입력만 가능)
  /// [historyIdx] 이력 ID
  static Future<bool> deleteHistory({
    required int historyIdx,
  }) async {
    try {
      final headers = await _getHeaders();
      final url = '${Config.serverUrl}$_baseUrl/$historyIdx';

      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 204) {
        return true;
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(error['detail'] ?? '헌혈 이력 삭제에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('헌혈 이력 삭제 오류: $e');
    }
  }
}
