// services/admin_donation_approval_service.dart

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/config.dart';

class AdminDonationApprovalService {
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

  // 관리자용 - 헌혈 최종 승인 처리
  static Future<Map<String, dynamic>> finalApproval({
    required int postTimesIdx,
    required String action, // "complete" 또는 "cancel"
  }) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/admin/donation_final_approval'),
        headers: headers,
        body: jsonEncode({
          'post_times_idx': postTimesIdx,
          'action': action,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return {
          'success': true,
          'message': data['message'] ?? '해당 시간대가 최종 $action 처리되었습니다.',
          'action': data['action'],
          'post_times_idx': data['post_times_idx'],
          'affected_applications': data['affected_applications'] ?? 0,
          'post_status': data['post_status'] ?? 'unknown',
          'post_idx': data['post_idx'],
          'processed_at': data['processed_at'],
        };
      } else {
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        return {
          'success': false,
          'message': errorData['message'] ?? '최종 승인 처리 실패',
          'error': response.body,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '최종 승인 처리 중 오류 발생',
        'error': e.toString(),
      };
    }
  }

  // 해당 시간대의 대기중인 헌혈 신청 조회
  static Future<Map<String, dynamic>> getPendingApplications(int postTimesIdx) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/admin/pending_applications/$postTimesIdx'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return {
          'success': true,
          'pendingCompletions': data['pending_completions'] ?? [],
          'pendingCancellations': data['pending_cancellations'] ?? [],
          'totalPending': data['total_pending'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'message': '대기중인 신청 조회 실패',
          'error': response.body,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '대기중인 신청 조회 중 오류 발생',
        'error': e.toString(),
      };
    }
  }

  // 여러 시간대 일괄 승인
  static Future<Map<String, dynamic>> batchFinalApproval({
    required List<int> postTimesIdxList,
    required String action,
  }) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/admin/donation_batch_approval'),
        headers: headers,
        body: jsonEncode({
          'post_times_idx_list': postTimesIdxList,
          'action': action,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return {
          'success': true,
          'message': data['message'] ?? '일괄 처리 완료',
          'processed_count': data['processed_count'] ?? 0,
          'failed_count': data['failed_count'] ?? 0,
          'results': data['results'] ?? [],
        };
      } else {
        return {
          'success': false,
          'message': '일괄 처리 실패',
          'error': response.body,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '일괄 처리 중 오류 발생',
        'error': e.toString(),
      };
    }
  }

  // 헌혈 완료 대기 목록 조회 (날짜별)
  static Future<Map<String, dynamic>> getPendingByDate(DateTime date) async {
    try {
      final headers = await _getHeaders();
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      final response = await http.get(
        Uri.parse('$baseUrl/admin/pending_donations?date=$dateStr'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return {
          'success': true,
          'date': dateStr,
          'pendingByTimeSlot': data['pending_by_time_slot'] ?? [],
          'totalPendingCompletions': data['total_pending_completions'] ?? 0,
          'totalPendingCancellations': data['total_pending_cancellations'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'message': '날짜별 대기 목록 조회 실패',
          'error': response.body,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '날짜별 대기 목록 조회 중 오류 발생',
        'error': e.toString(),
      };
    }
  }

  // 통계 조회 - 승인 대기 현황
  static Future<Map<String, dynamic>> getApprovalStats() async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/admin/donation_approval_stats'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return {
          'success': true,
          'totalPendingCompletions': data['total_pending_completions'] ?? 0,
          'totalPendingCancellations': data['total_pending_cancellations'] ?? 0,
          'todayPendingCompletions': data['today_pending_completions'] ?? 0,
          'todayPendingCancellations': data['today_pending_cancellations'] ?? 0,
          'weekStats': data['week_stats'] ?? [],
        };
      } else {
        return {
          'success': false,
          'message': '승인 통계 조회 실패',
          'error': response.body,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '승인 통계 조회 중 오류 발생',
        'error': e.toString(),
      };
    }
  }
}