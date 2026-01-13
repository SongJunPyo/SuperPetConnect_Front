// services/cancelled_donation_service.dart

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cancelled_donation_model.dart';
import '../utils/config.dart';

class CancelledDonationService {
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

  // ===== 공통 API =====

  // 1. 병원용 - 1차 헌혈 중단 처리
  static Future<Map<String, dynamic>> hospitalCancelBloodDonation(CancelDonationRequest request) async {
    try {
      final headers = await _getHeaders();
      
      // 디버깅용 로그
      print('=== 헌혈 중단 요청 ===');
      print('URL: $baseUrl/cancelled_donation/hospital_cancel');
      print('Headers: $headers');
      print('Body: ${jsonEncode({
        'applied_donation_idx': request.appliedDonationIdx,
        'cancelled_reason': request.cancelledReason,
      })}');
      
      final response = await http.post(
        Uri.parse('$baseUrl/cancelled_donation/hospital_cancel'),
        headers: headers,
        body: jsonEncode({
          'applied_donation_idx': request.appliedDonationIdx,
          'cancelled_reason': request.cancelledReason,
        }),
      );

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return {
          'message': data['message'] ?? '1차 중단 처리되었습니다. 관리자 승인 대기 중입니다.',
          'status': data['status'] ?? 'pendingCancellation',
          'applied_donation_idx': data['applied_donation_idx'],
          'cancelled_reason': data['cancelled_reason'],
          'cancelled_at': data['cancelled_at'],
        };
      } else {
        throw Exception('헌혈 중단 처리 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('헌혈 중단 처리 중 오류 발생: $e');
    }
  }

  // 1-1. 기존 메서드 유지 (하위 호환성)
  static Future<Map<String, dynamic>> cancelBloodDonation(CancelDonationRequest request) async {
    return hospitalCancelBloodDonation(request);
  }

  // 2. 특정 취소 기록 조회
  static Future<CancelledDonation?> getCancelledDonation(int cancelledDonationIdx) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/cancelled_donation/$cancelledDonationIdx'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return CancelledDonation.fromJson(data);
      } else {
        throw Exception('취소 기록 조회 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('취소 기록 조회 중 오류 발생: $e');
    }
  }

  // 3. 취소 사유 템플릿 조회
  static Future<List<Map<String, dynamic>>> getReasonTemplates() async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/cancelled_donation/templates/reasons'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.cast<Map<String, dynamic>>();
      } else {
        // 서버 API 실패 시 기본 템플릿 반환
        return [
          {
            'subject': CancelledSubject.hospital,
            'template_reasons': [
              '충분한 헌혈량 확보',
              '응급상황 해결',
              '헌혈 조건 미충족',
              '병원 사정으로 인한 취소',
              '의료진 부재',
              '기타 병원 사유',
            ]
          }
        ];
      }
    } catch (e) {
      // 오류 발생 시 기본 템플릿 반환
      return [
        {
          'subject': CancelledSubject.hospital,
          'template_reasons': [
            '충분한 헌혈량 확보',
            '응급상황 해결',
            '헌혈 조건 미충족',
            '병원 사정으로 인한 취소',
            '의료진 부재',
            '기타 병원 사유',
          ]
        }
      ];
    }
  }

  // ===== 사용자용 API =====

  // 4. 내 반려동물들의 취소 이력 조회
  static Future<List<Map<String, dynamic>>> getMyPetsCancellationHistory() async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/cancelled_donation/my-pets/history'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('내 반려동물 취소 이력 조회 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('내 반려동물 취소 이력 조회 중 오류 발생: $e');
    }
  }

  // ===== 병원용 API =====

  // 5. 병원 취소 통계 조회
  static Future<HospitalCancellationStats> getHospitalCancellationStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final headers = await _getHeaders();
      
      String url = '$baseUrl/cancelled_donation/hospital/stats';
      List<String> queryParams = [];
      
      if (startDate != null) {
        queryParams.add('start_date=${startDate.toIso8601String()}');
      }
      if (endDate != null) {
        queryParams.add('end_date=${endDate.toIso8601String()}');
      }
      
      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return HospitalCancellationStats.fromJson(data);
      } else {
        throw Exception('병원 취소 통계 조회 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('병원 취소 통계 조회 중 오류 발생: $e');
    }
  }

  // 6. 게시글별 취소 현황 조회
  static Future<PostCancellationStatus> getPostCancellations(int postIdx) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/cancelled_donation/post/$postIdx/cancellations'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return PostCancellationStatus.fromJson(data);
      } else {
        throw Exception('게시글별 취소 현황 조회 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('게시글별 취소 현황 조회 중 오류 발생: $e');
    }
  }

  // 7. 취소 기록 수정 (병원용)
  static Future<CancelledDonation> updateCancelledDonation(
      int cancelledDonationIdx, String cancelledReason, DateTime cancelledAt) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.put(
        Uri.parse('$baseUrl/cancelled_donation/$cancelledDonationIdx'),
        headers: headers,
        body: jsonEncode({
          'cancelled_reason': cancelledReason,
          'cancelled_at': cancelledAt.toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return CancelledDonation.fromJson(data);
      } else {
        throw Exception('취소 기록 수정 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('취소 기록 수정 중 오류 발생: $e');
    }
  }

  // ===== 관리자용 API =====

  // 8. 월별 취소 통계 조회
  static Future<MonthlyCancellationStats> getMonthlyCancellationStats(int year, int month) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/cancelled_donation/stats/monthly/$year/$month'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return MonthlyCancellationStats.fromJson(data);
      } else {
        throw Exception('월별 취소 통계 조회 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('월별 취소 통계 조회 중 오류 발생: $e');
    }
  }

  // ===== 편의 메서드 =====

  // 9. 간편 헌혈 취소 처리 (현재 시간 사용)
  static Future<Map<String, dynamic>> cancelBloodDonationNow(
      int appliedDonationIdx, int cancelledSubject, String cancelledReason) async {
    final request = CancelDonationRequest(
      appliedDonationIdx: appliedDonationIdx,
      cancelledSubject: cancelledSubject,
      cancelledReason: cancelledReason,
      cancelledAt: DateTime.now(),
    );
    
    return await cancelBloodDonation(request);
  }

  // 10. 사용자용 헌혈 취소 처리
  static Future<Map<String, dynamic>> cancelByUser(
      int appliedDonationIdx, String cancelledReason) async {
    return await cancelBloodDonationNow(
      appliedDonationIdx, 
      CancelledSubject.user, 
      cancelledReason
    );
  }

  // 11. 병원용 헌혈 취소 처리
  static Future<Map<String, dynamic>> cancelByHospital(
      int appliedDonationIdx, String cancelledReason) async {
    final request = CancelDonationRequest(
      appliedDonationIdx: appliedDonationIdx,
      cancelledSubject: CancelledSubject.hospital,
      cancelledReason: cancelledReason,
    );
    return await hospitalCancelBloodDonation(request);
  }

  // 12. 관리자용 헌혈 취소 처리
  static Future<Map<String, dynamic>> cancelByAdmin(
      int appliedDonationIdx, String cancelledReason) async {
    return await cancelBloodDonationNow(
      appliedDonationIdx, 
      CancelledSubject.admin, 
      cancelledReason
    );
  }

  // 13. 취소 사유 유효성 검사 (로컬)
  static Map<String, dynamic> validateCancellationReason(String reason) {
    if (reason.trim().isEmpty) {
      return {
        'isValid': false,
        'message': '취소 사유를 입력해주세요.',
        'level': 'error',
      };
    }
    
    if (reason.trim().length < 2) {
      return {
        'isValid': false,
        'message': '취소 사유를 2글자 이상 입력해주세요.',
        'level': 'error',
      };
    }
    
    if (reason.trim().length > 500) {
      return {
        'isValid': false,
        'message': '취소 사유는 500글자를 초과할 수 없습니다.',
        'level': 'error',
      };
    }
    
    return {
      'isValid': true,
      'message': '올바른 취소 사유입니다.',
      'level': 'success',
    };
  }

  // 14. 취소 주체별 템플릿 가져오기
  static Future<List<String>> getReasonTemplatesForSubject(int subject) async {
    try {
      final templates = await getReasonTemplates();
      final subjectTemplate = templates.firstWhere(
        (template) => template['subject'] == subject,
        orElse: () => <String, dynamic>{},
      );
      
      if (subjectTemplate.isNotEmpty && subjectTemplate['template_reasons'] != null) {
        return List<String>.from(subjectTemplate['template_reasons']);
      }
      
      return _getDefaultReasonTemplates(subject);
    } catch (e) {
      return _getDefaultReasonTemplates(subject);
    }
  }

  // 15. 기본 취소 사유 템플릿 (서버 실패 시 사용)
  static List<String> _getDefaultReasonTemplates(int subject) {
    switch (subject) {
      case CancelledSubject.user:
        return [
          '개인 사정으로 인한 취소',
          '반려동물 건강상 문제',
          '시간 변경 불가',
          '거리상 문제',
          '다른 병원에서 헌혈 진행',
          '기타 개인적 사유',
        ];
      case CancelledSubject.hospital:
        return [
          '충분한 헌혈량 확보',
          '응급상황 해결',
          '헌혈 조건 미충족',
          '병원 사정으로 인한 취소',
          '의료진 부재',
          '기타 병원 사유',
        ];
      case CancelledSubject.system:
        return [
          '시간 만료',
          '중복 신청',
          '자동 취소',
        ];
      case CancelledSubject.admin:
        return [
          '정책 위반',
          '부적절한 신청',
          '관리자 판단',
          '시스템 오류',
          '기타 관리자 사유',
        ];
      default:
        return ['기타 사유'];
    }
  }

  // 16. 최근 취소 기록 조회 (제한된 개수)
  static Future<List<CancelledDonation>> getRecentCancellations({
    int limit = 10,
    int? days,
  }) async {
    try {
      final endDate = DateTime.now();
      final startDate = days != null 
          ? endDate.subtract(Duration(days: days))
          : endDate.subtract(const Duration(days: 30)); // 기본 30일
      
      final hospitalStats = await getHospitalCancellationStats(
        startDate: startDate,
        endDate: endDate,
      );
      
      final recentCancellations = hospitalStats.cancelledDonations.take(limit).toList();
      
      // 최신순으로 정렬
      recentCancellations.sort((a, b) => b.cancelledAt.compareTo(a.cancelledAt));
      
      return recentCancellations;
    } catch (e) {
      return [];
    }
  }
}