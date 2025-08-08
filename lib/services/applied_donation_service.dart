// services/applied_donation_service.dart

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/applied_donation_model.dart';
import '../utils/config.dart';

class AppliedDonationService {
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

  // ===== 사용자용 API =====

  // 1. 헌혈 신청 생성
  static Future<AppliedDonation> createApplication(int petIdx, int postTimesIdx) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/applied_donation/'),
        headers: headers,
        body: jsonEncode({
          'pet_idx': petIdx,
          'post_times_idx': postTimesIdx,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return AppliedDonation.fromJson(data['applied_donation']);
      } else {
        throw Exception('헌혈 신청 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('헌혈 신청 중 오류 발생: $e');
    }
  }

  // 2. 특정 신청 조회
  static Future<AppliedDonation?> getApplication(int appliedDonationIdx) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/applied_donation/$appliedDonationIdx'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return AppliedDonation.fromJson(data);
      } else {
        throw Exception('신청 조회 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('신청 조회 중 오류 발생: $e');
    }
  }

  // 3. 내 반려동물들의 신청 목록 조회
  static Future<List<MyPetApplications>> getMyApplications() async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/applied_donation/my-pets/applications'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((item) => MyPetApplications.fromJson(item)).toList();
      } else {
        throw Exception('내 신청 목록 조회 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('내 신청 목록 조회 중 오류 발생: $e');
    }
  }

  // 4. 신청 삭제 (사용자)
  static Future<void> deleteApplication(int appliedDonationIdx) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.delete(
        Uri.parse('$baseUrl/applied_donation/$appliedDonationIdx'),
        headers: headers,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('신청 삭제 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('신청 삭제 중 오류 발생: $e');
    }
  }

  // ===== 병원용 API =====

  // 5. 특정 게시글의 모든 신청 조회
  static Future<PostApplications> getPostApplications(int postIdx) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/applied_donation/post/$postIdx/applications'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return PostApplications.fromJson(data);
      } else {
        throw Exception('게시글 신청 목록 조회 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('게시글 신청 목록 조회 중 오류 발생: $e');
    }
  }

  // 6. 특정 시간대 신청 현황 조회
  static Future<TimeSlotApplications> getTimeSlotApplications(int postTimesIdx) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/applied_donation/time-slot/$postTimesIdx/applications'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return TimeSlotApplications.fromJson(data);
      } else {
        throw Exception('시간대 신청 현황 조회 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('시간대 신청 현황 조회 중 오류 발생: $e');
    }
  }

  // 7. 신청 상태 변경 (병원용)
  static Future<AppliedDonation> updateApplicationStatus(
      int appliedDonationIdx, int newStatus) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.put(
        Uri.parse('$baseUrl/applied_donation/$appliedDonationIdx/status'),
        headers: headers,
        body: jsonEncode({
          'status': newStatus,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        // 응답에서 업데이트된 신청 정보 반환
        return AppliedDonation.fromJson({
          'applied_donation_idx': appliedDonationIdx,
          'status': data['new_status'],
        });
      } else {
        throw Exception('신청 상태 변경 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('신청 상태 변경 중 오류 발생: $e');
    }
  }

  // 8. 게시글 신청 통계 조회 (병원용)
  static Future<Map<String, dynamic>> getPostStats(int postIdx) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/applied_donation/post/$postIdx/stats'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('게시글 통계 조회 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('게시글 통계 조회 중 오류 발생: $e');
    }
  }

  // ===== 편의 메서드 =====

  // 9. 사용자가 특정 시간대에 이미 신청했는지 확인
  static Future<bool> hasUserAppliedToTimeSlot(int postTimesIdx) async {
    try {
      final myApplications = await getMyApplications();
      
      for (final petApps in myApplications) {
        for (final application in petApps.applications) {
          if (application.postTimesIdx == postTimesIdx && 
              (application.status == AppliedDonationStatus.pending || 
               application.status == AppliedDonationStatus.approved)) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      print('신청 중복 확인 실패: $e');
      return false;
    }
  }

  // 10. 사용자의 진행 중인 신청 목록 조회
  static Future<List<AppliedDonation>> getActiveApplications() async {
    try {
      final myApplications = await getMyApplications();
      final activeApplications = <AppliedDonation>[];
      
      for (final petApps in myApplications) {
        for (final application in petApps.applications) {
          if (application.status == AppliedDonationStatus.pending || 
              application.status == AppliedDonationStatus.approved) {
            activeApplications.add(application);
          }
        }
      }
      
      // 날짜순 정렬 (가까운 날짜 먼저)
      activeApplications.sort((a, b) {
        if (a.donationTime != null && b.donationTime != null) {
          return a.donationTime!.compareTo(b.donationTime!);
        }
        return 0;
      });
      
      return activeApplications;
    } catch (e) {
      throw Exception('진행 중인 신청 조회 중 오류 발생: $e');
    }
  }

  // 11. 병원의 승인 대기 중인 신청 개수 조회
  static Future<int> getPendingApplicationsCount(int postIdx) async {
    try {
      final postApps = await getPostApplications(postIdx);
      return postApps.pendingCount;
    } catch (e) {
      print('대기 중인 신청 개수 조회 실패: $e');
      return 0;
    }
  }

  // 12. 일괄 상태 변경 (병원용 - 여러 신청을 한번에 처리)
  static Future<List<AppliedDonation>> updateMultipleApplicationStatus(
      List<int> appliedDonationIds, int newStatus) async {
    try {
      final results = <AppliedDonation>[];
      
      for (final id in appliedDonationIds) {
        try {
          final result = await updateApplicationStatus(id, newStatus);
          results.add(result);
        } catch (e) {
          print('신청 $id 상태 변경 실패: $e');
        }
      }
      
      return results;
    } catch (e) {
      throw Exception('일괄 상태 변경 중 오류 발생: $e');
    }
  }

  // 13. 사용자 신청 가능 여부 검증
  static Future<Map<String, dynamic>> validateApplicationEligibility(
      int petIdx, int postTimesIdx) async {
    try {
      // 이미 해당 시간대에 신청했는지 확인
      final hasApplied = await hasUserAppliedToTimeSlot(postTimesIdx);
      if (hasApplied) {
        return {
          'canApply': false,
          'reason': '이미 해당 시간대에 신청하셨습니다.',
        };
      }

      // 시간대 신청 현황 확인
      final timeSlotApps = await getTimeSlotApplications(postTimesIdx);
      if (timeSlotApps.isFullyBooked(5)) { // 기본 수용 인원 5명으로 가정
        return {
          'canApply': false,
          'reason': '해당 시간대는 마감되었습니다.',
        };
      }

      return {
        'canApply': true,
        'reason': '',
        'currentApplications': timeSlotApps.totalApplications,
        'availableSlots': 5 - timeSlotApps.approvedCount, // 승인된 수 기준
      };
    } catch (e) {
      return {
        'canApply': false,
        'reason': '신청 가능 여부 확인 중 오류가 발생했습니다.',
      };
    }
  }

  // 14. 신청 취소 (사용자용)
  static Future<AppliedDonation> cancelApplication(int appliedDonationIdx) async {
    return await updateApplicationStatus(appliedDonationIdx, AppliedDonationStatus.cancelled);
  }

  // 15. 신청 완료 처리 (병원용)
  static Future<AppliedDonation> completeApplication(int appliedDonationIdx) async {
    return await updateApplicationStatus(appliedDonationIdx, AppliedDonationStatus.completed);
  }

  // 16. 사용자의 헌혈 이력 통계
  static Future<Map<String, dynamic>> getUserDonationStats() async {
    try {
      final myApplications = await getMyApplications();
      
      int totalApplications = 0;
      int completedDonations = 0;
      int pendingApplications = 0;
      int approvedApplications = 0;
      
      for (final petApps in myApplications) {
        for (final application in petApps.applications) {
          totalApplications++;
          
          switch (application.status) {
            case AppliedDonationStatus.completed:
              completedDonations++;
              break;
            case AppliedDonationStatus.pending:
              pendingApplications++;
              break;
            case AppliedDonationStatus.approved:
              approvedApplications++;
              break;
          }
        }
      }
      
      return {
        'totalApplications': totalApplications,
        'completedDonations': completedDonations,
        'pendingApplications': pendingApplications,
        'approvedApplications': approvedApplications,
        'pets': myApplications,
      };
    } catch (e) {
      throw Exception('헌혈 이력 통계 조회 중 오류 발생: $e');
    }
  }

  // 16. 특정 상태의 신청 목록 조회 (관리자용)
  static Future<List<AppliedDonation>> getApplicationsByStatus(int status) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/applied_donation/admin/by-status/$status'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((item) => AppliedDonation.fromJson(item)).toList();
      } else {
        throw Exception('상태별 신청 목록 조회 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('상태별 신청 목록 조회 중 오류 발생: $e');
    }
  }
}