// services/applied_donation_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'auth_http_client.dart';
import '../models/applied_donation_model.dart';
import '../utils/config.dart';
import '../utils/api_endpoints.dart';

class AppliedDonationService {

  // ===== 사용자용 API =====

  // 1. 헌혈 신청 생성
  static Future<AppliedDonation> createApplication(
    int petIdx,
    int postTimesIdx,
  ) async {
    debugPrint(
      '[AppliedDonationService] 헌혈 신청 요청 - petIdx: $petIdx, postTimesIdx: $postTimesIdx',
    );

    final response = await AuthHttpClient.post(
      Uri.parse('${Config.serverUrl}${ApiEndpoints.donationApply}'),
      body: jsonEncode({'pet_idx': petIdx, 'post_times_idx': postTimesIdx}),
    );

    debugPrint('[AppliedDonationService] 응답 코드: ${response.statusCode}');
    debugPrint(
      '[AppliedDonationService] 응답 내용: ${utf8.decode(response.bodyBytes)}',
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = response.parseJsonDynamic();
      if (data['applied_donation'] != null) {
        return AppliedDonation.fromJson(data['applied_donation']);
      }
      return AppliedDonation.fromJson(data);
    } else if (response.statusCode == 400) {
      // 중복 신청 등 Bad Request 처리
      debugPrint('[AppliedDonationService] 400 에러: ${response.body}');

      throw response.extractErrorMessage('이미 신청한 시간대입니다.');
    } else {
      throw '헌혈 신청에 실패했습니다. (${response.statusCode})';
    }
  }

  // 2. 특정 신청 조회
  static Future<AppliedDonation?> getApplication(int appliedDonationIdx) async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.appliedDonationDetail(appliedDonationIdx)}'),
      );

      if (response.statusCode == 200) {
        final data = response.parseJsonDynamic();
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
      final response = await AuthHttpClient.get(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.appliedDonationMyPets}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.parseJsonList();
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
      final response = await AuthHttpClient.delete(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.appliedDonationDetail(appliedDonationIdx)}'),
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
      final response = await AuthHttpClient.get(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.appliedDonationByPost(postIdx)}'),
      );

      if (response.statusCode == 200) {
        final data = response.parseJsonDynamic();
        return PostApplications.fromJson(data);
      } else {
        throw Exception('게시글 신청 목록 조회 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('게시글 신청 목록 조회 중 오류 발생: $e');
    }
  }

  // 6. 특정 시간대 신청 현황 조회
  static Future<TimeSlotApplications> getTimeSlotApplications(
    int postTimesIdx,
  ) async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse(
          '${Config.serverUrl}${ApiEndpoints.appliedDonationByTimeSlot(postTimesIdx)}',
        ),
      );

      if (response.statusCode == 200) {
        final data = response.parseJsonDynamic();
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
    int appliedDonationIdx,
    int newStatus,
  ) async {
    try {
      final response = await AuthHttpClient.put(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.appliedDonationStatus(appliedDonationIdx)}'),
        body: jsonEncode({'status': newStatus}),
      );

      if (response.statusCode == 200) {
        final data = response.parseJsonDynamic();
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
      final response = await AuthHttpClient.get(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.appliedDonationPostStats(postIdx)}'),
      );

      if (response.statusCode == 200) {
        return response.parseJson();
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
      return 0;
    }
  }

  // 12. 일괄 상태 변경 (병원용 - 여러 신청을 한번에 처리)
  static Future<List<AppliedDonation>> updateMultipleApplicationStatus(
    List<int> appliedDonationIds,
    int newStatus,
  ) async {
    try {
      final results = <AppliedDonation>[];

      for (final id in appliedDonationIds) {
        try {
          final result = await updateApplicationStatus(id, newStatus);
          results.add(result);
        } catch (e) {
          // 개별 신청 상태 변경 실패 시 로그 출력하고 계속 진행
          debugPrint('Failed to update application $id: $e');
        }
      }

      return results;
    } catch (e) {
      throw Exception('일괄 상태 변경 중 오류 발생: $e');
    }
  }

  // 13. 사용자 신청 가능 여부 검증
  static Future<Map<String, dynamic>> validateApplicationEligibility(
    int petIdx,
    int postTimesIdx,
  ) async {
    try {
      // 이미 해당 시간대에 신청했는지 확인
      final hasApplied = await hasUserAppliedToTimeSlot(postTimesIdx);
      if (hasApplied) {
        return {'canApply': false, 'reason': '이미 해당 시간대에 신청하셨습니다.'};
      }

      // 시간대 신청 현황 확인
      final timeSlotApps = await getTimeSlotApplications(postTimesIdx);
      if (timeSlotApps.isFullyBooked(5)) {
        // 기본 수용 인원 5명으로 가정
        return {'canApply': false, 'reason': '해당 시간대는 마감되었습니다.'};
      }

      return {
        'canApply': true,
        'reason': '',
        'currentApplications': timeSlotApps.totalApplications,
        'availableSlots': 5 - timeSlotApps.approvedCount, // 승인된 수 기준
      };
    } catch (e) {
      return {'canApply': false, 'reason': '신청 가능 여부 확인 중 오류가 발생했습니다.'};
    }
  }

  // 14. 신청 취소 (사용자용)
  static Future<AppliedDonation> cancelApplication(
    int appliedDonationIdx,
  ) async {
    return await updateApplicationStatus(
      appliedDonationIdx,
      AppliedDonationStatus.cancelled,
    );
  }

  // 15. 신청 완료 처리 (병원용)
  static Future<AppliedDonation> completeApplication(
    int appliedDonationIdx,
  ) async {
    return await updateApplicationStatus(
      appliedDonationIdx,
      AppliedDonationStatus.completed,
    );
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

  // ===== 서버 API에 맞춘 새 메서드들 =====

  /// 17. 내 신청 목록 조회 (GET /api/donation/my-applications)
  /// 서버 API 응답 형식에 맞춤
  static Future<List<MyApplicationInfo>> getMyApplicationsFromServer() async {
    try {
      debugPrint('[AppliedDonationService] 내 신청 목록 조회 요청');

      final response = await AuthHttpClient.get(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.donationMyApplications}'),
      );

      debugPrint('[AppliedDonationService] 응답 코드: ${response.statusCode}');
      debugPrint(
        '[AppliedDonationService] 응답 내용: ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = response.parseJsonDynamic();

        if (data['success'] == true && data['applications'] != null) {
          final List<dynamic> applications = data['applications'];
          return applications
              .map((item) => MyApplicationInfo.fromJson(item))
              .toList();
        }

        // 응답이 리스트인 경우
        if (data is List) {
          return data.map((item) => MyApplicationInfo.fromJson(item)).toList();
        }

        return [];
      } else {
        throw Exception('내 신청 목록 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[AppliedDonationService] 내 신청 목록 조회 오류: $e');
      throw Exception('내 신청 목록 조회 중 오류 발생: $e');
    }
  }

  /// 18. 헌혈 신청 취소 (DELETE /api/donation/applications/{id})
  /// 대기중(status=0) 상태일 때만 취소 가능
  static Future<bool> cancelApplicationToServer(int applicationId) async {
    try {
      debugPrint(
        '[AppliedDonationService] 신청 취소 요청 - applicationId: $applicationId',
      );

      final response = await AuthHttpClient.delete(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.donationApplication(applicationId)}'),
      );

      debugPrint('[AppliedDonationService] 응답 코드: ${response.statusCode}');
      debugPrint(
        '[AppliedDonationService] 응답 내용: ${response.body}',
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else if (response.statusCode == 400) {
        // 취소 불가능한 상태
        throw response.extractErrorMessage('신청을 취소할 수 없습니다.');
      } else {
        throw '신청 취소에 실패했습니다. (${response.statusCode})';
      }
    } catch (e) {
      debugPrint('[AppliedDonationService] 신청 취소 오류: $e');
      if (e is String) rethrow;
      throw '신청 취소 중 오류 발생: $e';
    }
  }

  /// 19. 특정 게시글에 대한 내 신청 목록 필터링
  static Future<List<MyApplicationInfo>> getMyApplicationsForPost(
    int postIdx,
  ) async {
    try {
      final allApplications = await getMyApplicationsFromServer();
      return allApplications.where((app) => app.postId == postIdx).toList();
    } catch (e) {
      debugPrint('[AppliedDonationService] 게시글별 신청 조회 오류: $e');
      return [];
    }
  }

  /// 20. 특정 시간대에 대한 내 신청 조회
  static Future<MyApplicationInfo?> getMyApplicationForTimeSlot(
    int postTimesIdx,
  ) async {
    try {
      final allApplications = await getMyApplicationsFromServer();

      for (final app in allApplications) {
        if (app.postTimesIdx == postTimesIdx && app.shouldShowAppliedBorder) {
          return app;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[AppliedDonationService] 시간대별 신청 조회 오류: $e');
      return null;
    }
  }

  // 16. 특정 상태의 신청 목록 조회 (관리자용)
  static Future<List<AppliedDonation>> getApplicationsByStatus(
    int status,
  ) async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.appliedDonationAdminByStatus(status)}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.parseJsonList();
        return data.map((item) => AppliedDonation.fromJson(item)).toList();
      } else {
        throw Exception('상태별 신청 목록 조회 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('상태별 신청 목록 조회 중 오류 발생: $e');
    }
  }
}
