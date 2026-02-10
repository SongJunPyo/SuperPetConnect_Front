// services/completed_donation_service.dart

import 'dart:convert';
import 'auth_http_client.dart';
import '../models/completed_donation_model.dart';
import '../utils/config.dart';

class CompletedDonationService {
  static String get baseUrl => '${Config.serverUrl}/api';

  // ===== 병원용 API =====

  // 1. 병원용 - 1차 헌혈 완료 처리
  static Future<Map<String, dynamic>> hospitalCompleteBloodDonation(CompleteDonationRequest request) async {
    try {
      // 디버깅용 로그
      print('=== 헌혈 완료 요청 ===');
      print('URL: $baseUrl/completed_donation/hospital_complete');
      print('Body: ${jsonEncode(request.toJson())}');

      final response = await AuthHttpClient.post(
        Uri.parse('$baseUrl/completed_donation/hospital_complete'),
        body: jsonEncode(request.toJson()),
      );

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return {
          'message': data['message'] ?? '1차 완료 처리되었습니다. 관리자 승인 대기 중입니다.',
          'status': data['status'] ?? 'pendingCompletion',
          'applied_donation_idx': data['applied_donation_idx'],
          'blood_volume': data['blood_volume'],
          'completed_at': data['completed_at'],
        };
      } else {
        throw Exception('헌혈 완료 처리 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('헌혈 완료 처리 중 오류 발생: $e');
    }
  }

  // 1-1. 기존 메서드 유지 (하위 호환성)
  static Future<Map<String, dynamic>> completeBloodDonation(CompleteDonationRequest request) async {
    return hospitalCompleteBloodDonation(request);
  }

  // 2. 병원 헌혈 통계 조회
  static Future<HospitalDonationStats> getHospitalStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      String url = '$baseUrl/completed_donation/hospital/stats';
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

      final response = await AuthHttpClient.get(
        Uri.parse(url),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return HospitalDonationStats.fromJson(data);
      } else {
        throw Exception('병원 통계 조회 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('병원 통계 조회 중 오류 발생: $e');
    }
  }

  // 3. 게시글별 완료 현황 조회
  static Future<PostDonationCompletions> getPostCompletions(int postIdx) async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse('$baseUrl/completed_donation/post/$postIdx/completions'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return PostDonationCompletions.fromJson(data);
      } else {
        throw Exception('게시글별 완료 현황 조회 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('게시글별 완료 현황 조회 중 오류 발생: $e');
    }
  }

  // 4. 완료 기록 수정
  static Future<CompletedDonation> updateCompletedDonation(
      int completedDonationIdx, double bloodVolume, DateTime completedAt) async {
    try {
      final response = await AuthHttpClient.put(
        Uri.parse('$baseUrl/completed_donation/$completedDonationIdx'),
        body: jsonEncode({
          'blood_volume': bloodVolume,
          'completed_at': completedAt.toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return CompletedDonation.fromJson(data);
      } else {
        throw Exception('완료 기록 수정 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('완료 기록 수정 중 오류 발생: $e');
    }
  }

  // 5. 완료 기록 삭제
  static Future<void> deleteCompletedDonation(int completedDonationIdx) async {
    try {
      final response = await AuthHttpClient.delete(
        Uri.parse('$baseUrl/completed_donation/$completedDonationIdx'),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('완료 기록 삭제 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('완료 기록 삭제 중 오류 발생: $e');
    }
  }

  // ===== 사용자용 API =====

  // 6. 내 반려동물들의 헌혈 이력 조회
  static Future<List<PetDonationHistory>> getMyPetsDonationHistory() async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse('$baseUrl/completed_donation/my-pets/history'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((item) => PetDonationHistory.fromJson(item)).toList();
      } else {
        throw Exception('내 반려동물 헌혈 이력 조회 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('내 반려동물 헌혈 이력 조회 중 오류 발생: $e');
    }
  }

  // 7. 특정 반려동물의 상세 헌혈 이력 조회
  static Future<PetDonationHistory> getPetDonationHistory(int petIdx) async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse('$baseUrl/completed_donation/pet/$petIdx/history'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return PetDonationHistory.fromJson(data);
      } else {
        throw Exception('반려동물 헌혈 이력 조회 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('반려동물 헌혈 이력 조회 중 오류 발생: $e');
    }
  }

  // ===== 공통 API =====

  // 8. 특정 완료 기록 조회
  static Future<CompletedDonation?> getCompletedDonation(int completedDonationIdx) async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse('$baseUrl/completed_donation/$completedDonationIdx'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return CompletedDonation.fromJson(data);
      } else {
        throw Exception('완료 기록 조회 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('완료 기록 조회 중 오류 발생: $e');
    }
  }

  // 9. 월별 헌혈 통계 조회
  static Future<MonthlyDonationStats> getMonthlyStats(int year, int month) async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse('$baseUrl/completed_donation/stats/monthly/$year/$month'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return MonthlyDonationStats.fromJson(data);
      } else {
        throw Exception('월별 통계 조회 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('월별 통계 조회 중 오류 발생: $e');
    }
  }

  // ===== 편의 메서드 =====

  // 10. 간편 헌혈 완료 처리 (현재 시간 사용)
  static Future<Map<String, dynamic>> completeBloodDonationNow(
      int appliedDonationIdx, double bloodVolume) async {
    final request = CompleteDonationRequest(
      appliedDonationIdx: appliedDonationIdx,
      bloodVolume: bloodVolume,
      completedAt: DateTime.now(),
    );

    return await hospitalCompleteBloodDonation(request);
  }

  // 11. 반려동물의 최근 헌혈 이력 조회 (제한된 개수)
  static Future<List<CompletedDonation>> getRecentPetDonations(
      int petIdx, {int limit = 5}) async {
    try {
      final petHistory = await getPetDonationHistory(petIdx);
      final recentDonations = petHistory.donations.take(limit).toList();

      // 최신순으로 정렬
      recentDonations.sort((a, b) => b.completedAt.compareTo(a.completedAt));

      return recentDonations;
    } catch (e) {
      return [];
    }
  }

  // 12. 병원의 최근 완료 기록 조회
  static Future<List<CompletedDonation>> getRecentHospitalDonations({
    int limit = 10,
    int? days,
  }) async {
    try {
      final endDate = DateTime.now();
      final startDate = days != null
          ? endDate.subtract(Duration(days: days))
          : endDate.subtract(const Duration(days: 30)); // 기본 30일

      final hospitalStats = await getHospitalStats(
        startDate: startDate,
        endDate: endDate,
      );

      final recentDonations = hospitalStats.completedDonations.take(limit).toList();

      // 최신순으로 정렬
      recentDonations.sort((a, b) => b.completedAt.compareTo(a.completedAt));

      return recentDonations;
    } catch (e) {
      return [];
    }
  }

  // 13. 헌혈량 유효성 검사 (반려동물 체중 고려)
  static Map<String, dynamic> validateBloodVolume(
      double bloodVolume, double? petWeight) {
    if (!CompletedDonation.isValidBloodVolume(bloodVolume)) {
      return {
        'isValid': false,
        'message': '헌혈량은 0mL보다 크고 1000mL 이하여야 합니다.',
        'level': 'error',
      };
    }

    if (petWeight != null && petWeight > 0) {
      final recommended = CompletedDonation.getRecommendedBloodVolume(petWeight);
      final maxSafe = CompletedDonation.getMaxSafeBloodVolume(petWeight);

      if (bloodVolume > maxSafe) {
        return {
          'isValid': false,
          'message': '체중 ${petWeight}kg 반려동물의 최대 안전 헌혈량(${maxSafe.toStringAsFixed(1)}mL)을 초과했습니다.',
          'level': 'error',
          'recommended': recommended,
          'maxSafe': maxSafe,
        };
      } else if (bloodVolume > recommended * 1.2) {
        return {
          'isValid': true,
          'message': '권장 헌혈량(${recommended.toStringAsFixed(1)}mL)보다 많습니다. 주의해주세요.',
          'level': 'warning',
          'recommended': recommended,
          'maxSafe': maxSafe,
        };
      }
    }

    return {
      'isValid': true,
      'message': '적절한 헌혈량입니다.',
      'level': 'success',
    };
  }

  // 14. 전체 헌혈 통계 조회 (사용자용 - 내 모든 반려동물 통합)
  static Future<Map<String, dynamic>> getMyTotalDonationStats() async {
    try {
      final petHistories = await getMyPetsDonationHistory();

      int totalDonations = 0;
      double totalBloodVolume = 0.0;
      DateTime? firstDonationDate;
      DateTime? lastDonationDate;
      int activePetsCount = 0;

      for (final petHistory in petHistories) {
        totalDonations += petHistory.totalDonations;
        totalBloodVolume += petHistory.totalBloodVolume;

        if (petHistory.totalDonations > 0) {
          activePetsCount++;
        }

        if (petHistory.firstDonationDate != null) {
          if (firstDonationDate == null ||
              petHistory.firstDonationDate!.isBefore(firstDonationDate)) {
            firstDonationDate = petHistory.firstDonationDate;
          }
        }

        if (petHistory.lastDonationDate != null) {
          if (lastDonationDate == null ||
              petHistory.lastDonationDate!.isAfter(lastDonationDate)) {
            lastDonationDate = petHistory.lastDonationDate;
          }
        }
      }

      return {
        'totalPets': petHistories.length,
        'activePetsCount': activePetsCount,
        'totalDonations': totalDonations,
        'totalBloodVolume': totalBloodVolume,
        'formattedTotalBloodVolume': '${totalBloodVolume.toStringAsFixed(1)}mL',
        'averageBloodVolume': totalDonations > 0 ? totalBloodVolume / totalDonations : 0.0,
        'firstDonationDate': firstDonationDate,
        'lastDonationDate': lastDonationDate,
        'petHistories': petHistories,
      };
    } catch (e) {
      throw Exception('통합 헌혈 통계 조회 중 오류 발생: $e');
    }
  }

  // 15. 연간 통계 조회 (여러 월의 데이터 통합)
  static Future<Map<String, dynamic>> getYearlyStats(int year) async {
    try {
      final List<MonthlyDonationStats> monthlyStats = [];

      for (int month = 1; month <= 12; month++) {
        try {
          final monthStat = await getMonthlyStats(year, month);
          monthlyStats.add(monthStat);
        } catch (e) {
          // 해당 월 데이터가 없어도 계속 진행
        }
      }

      // 연간 통계 계산
      int totalCompletedCount = 0;
      double totalBloodVolume = 0.0;
      int totalUniquePets = 0;
      int totalUniqueHospitals = 0;

      for (final monthStat in monthlyStats) {
        totalCompletedCount += monthStat.completedCount;
        totalBloodVolume += monthStat.totalBloodVolume;
        // 중복 제거는 서버에서 해야 함 (여기서는 최대값으로 추정)
        if (monthStat.uniquePetsCount > totalUniquePets) {
          totalUniquePets = monthStat.uniquePetsCount;
        }
        if (monthStat.uniqueHospitalsCount > totalUniqueHospitals) {
          totalUniqueHospitals = monthStat.uniqueHospitalsCount;
        }
      }

      return {
        'year': year,
        'totalCompletedCount': totalCompletedCount,
        'totalBloodVolume': totalBloodVolume,
        'formattedTotalBloodVolume': '${totalBloodVolume.toStringAsFixed(1)}mL',
        'averageBloodVolume': totalCompletedCount > 0
            ? totalBloodVolume / totalCompletedCount
            : 0.0,
        'estimatedUniquePets': totalUniquePets,
        'estimatedUniqueHospitals': totalUniqueHospitals,
        'monthlyData': monthlyStats,
      };
    } catch (e) {
      throw Exception('연간 통계 조회 중 오류 발생: $e');
    }
  }
}
