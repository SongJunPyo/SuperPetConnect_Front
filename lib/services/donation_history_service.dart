// lib/services/donation_history_service.dart
// 반려동물 헌혈 이력 API 서비스

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../utils/config.dart';
import '../models/donation_history_model.dart';
import 'auth_http_client.dart';

class DonationHistoryService {
  static const String _baseUrl = '/api/pet-donation-history';

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
      final url = '${Config.serverUrl}$_baseUrl/$petIdx?page=$page&limit=$limit';

      final response = await AuthHttpClient.get(
        Uri.parse(url),
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
      final url = '${Config.serverUrl}$_baseUrl/$petIdx';

      if (kDebugMode) {
        print('[DonationHistoryService] addHistory 요청');
        print('[DonationHistoryService] URL: $url');
        print('[DonationHistoryService] Body: ${jsonEncode(request.toJson())}');
      }

      final response = await AuthHttpClient.post(
        Uri.parse(url),
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
      final url = '${Config.serverUrl}$_baseUrl/$petIdx/bulk';

      final body = requests.map((r) => r.toJson()).toList();

      final response = await AuthHttpClient.post(
        Uri.parse(url),
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
      final url = '${Config.serverUrl}$_baseUrl/$historyIdx';

      final response = await AuthHttpClient.put(
        Uri.parse(url),
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
      final url = '${Config.serverUrl}$_baseUrl/$historyIdx';

      final response = await AuthHttpClient.delete(
        Uri.parse(url),
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
