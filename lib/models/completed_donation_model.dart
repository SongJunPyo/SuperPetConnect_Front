// models/completed_donation_model.dart

import 'package:intl/intl.dart';
import 'applied_donation_model.dart';

class CompletedDonation {
  final int? completedDonationIdx;
  final int appliedDonationIdx;
  final double bloodVolume; // mL 단위
  final DateTime completedAt;

  // 조인된 정보들 (응답에서 포함될 수 있음)
  final String? petName;
  final String? petBloodType;
  final double? petWeight;
  final DateTime? donationTime;
  final String? postTitle;
  final String? hospitalName;
  final AppliedDonation? appliedDonation;

  CompletedDonation({
    this.completedDonationIdx,
    required this.appliedDonationIdx,
    required this.bloodVolume,
    required this.completedAt,
    this.petName,
    this.petBloodType,
    this.petWeight,
    this.donationTime,
    this.postTitle,
    this.hospitalName,
    this.appliedDonation,
  });

  factory CompletedDonation.fromJson(Map<String, dynamic> json) {
    return CompletedDonation(
      completedDonationIdx: json['completed_donation_idx'],
      appliedDonationIdx: json['applied_donation_idx'],
      bloodVolume: (json['blood_volume'] ?? 0).toDouble(),
      completedAt: DateTime.parse(json['completed_at']),
      petName: json['pet_name'],
      petBloodType: json['pet_blood_type'],
      petWeight: json['pet_weight']?.toDouble(),
      donationTime: json['donation_time'] != null
          ? DateTime.parse(json['donation_time'])
          : null,
      postTitle: json['post_title'],
      hospitalName: json['hospital_name'],
      appliedDonation: json['applied_donation'] != null
          ? AppliedDonation.fromJson(json['applied_donation'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'completed_donation_idx': completedDonationIdx,
      'applied_donation_idx': appliedDonationIdx,
      'blood_volume': bloodVolume,
      'completed_at': completedAt.toIso8601String(),
    };
  }

  // 헌혈 완료를 위한 요청 JSON (생성 시)
  Map<String, dynamic> toCreateJson() {
    return {
      'applied_donation_idx': appliedDonationIdx,
      'blood_volume': bloodVolume,
      'completed_at': completedAt.toIso8601String(),
    };
  }

  // 완료 기록 수정을 위한 요청 JSON
  Map<String, dynamic> toUpdateJson() {
    return {
      'blood_volume': bloodVolume,
      'completed_at': completedAt.toIso8601String(),
    };
  }

  // 포맷된 혈액량
  String get formattedBloodVolume {
    return '${bloodVolume.toStringAsFixed(1)}mL';
  }

  // 포맷된 완료 시간
  String get formattedCompletedTime {
    return DateFormat('MM월 dd일 HH:mm', 'ko_KR').format(completedAt);
  }

  String get formattedCompletedDate {
    return DateFormat('yyyy년 MM월 dd일', 'ko_KR').format(completedAt);
  }

  String get formattedCompletedDateTime {
    return DateFormat('MM월 dd일 (E) HH:mm', 'ko_KR').format(completedAt);
  }

  // 포맷된 헌혈 예정 시간 (원래 신청한 시간)
  String get formattedDonationTime {
    if (donationTime != null) {
      return DateFormat('MM월 dd일 (E) HH:mm', 'ko_KR').format(donationTime!);
    }
    return '';
  }

  // 반려동물 정보 요약
  String get petSummary {
    List<String> info = [];
    if (petName != null) info.add(petName!);
    if (petBloodType != null) info.add(petBloodType!);
    if (petWeight != null) info.add('${petWeight}kg');
    return info.join(' · ');
  }

  // 헌혈 정보 요약
  String get donationSummary {
    return '$formattedBloodVolume · $formattedCompletedTime';
  }

  // 복사본 생성 (수정 등)
  CompletedDonation copyWith({
    int? completedDonationIdx,
    int? appliedDonationIdx,
    double? bloodVolume,
    DateTime? completedAt,
    String? petName,
    String? petBloodType,
    double? petWeight,
    DateTime? donationTime,
    String? postTitle,
    String? hospitalName,
    AppliedDonation? appliedDonation,
  }) {
    return CompletedDonation(
      completedDonationIdx: completedDonationIdx ?? this.completedDonationIdx,
      appliedDonationIdx: appliedDonationIdx ?? this.appliedDonationIdx,
      bloodVolume: bloodVolume ?? this.bloodVolume,
      completedAt: completedAt ?? this.completedAt,
      petName: petName ?? this.petName,
      petBloodType: petBloodType ?? this.petBloodType,
      petWeight: petWeight ?? this.petWeight,
      donationTime: donationTime ?? this.donationTime,
      postTitle: postTitle ?? this.postTitle,
      hospitalName: hospitalName ?? this.hospitalName,
      appliedDonation: appliedDonation ?? this.appliedDonation,
    );
  }

  // 헌혈량 유효성 검사
  static bool isValidBloodVolume(double volume) {
    return volume > 0 && volume <= 1000; // 최대 1000mL
  }

  // 반려동물 체중 대비 적정 헌혈량 확인
  static double getRecommendedBloodVolume(double petWeightKg) {
    // 일반적으로 체중 1kg당 10-15mL 헌혈 가능 (수의학적 기준)
    return petWeightKg * 12; // 중간값 사용
  }

  static double getMaxSafeBloodVolume(double petWeightKg) {
    return petWeightKg * 15; // 최대 안전 헌혈량
  }
}

// 반려동물별 헌혈 이력을 위한 복합 모델
class PetDonationHistory {
  final int petIdx;
  final String petName;
  final String? petBloodType;
  final double? petWeight;
  final String? animalType;
  final DateTime? firstDonationDate;
  final DateTime? lastDonationDate;
  final int totalDonations;
  final double totalBloodVolume;
  final double averageBloodVolume;
  final List<CompletedDonation> donations;

  PetDonationHistory({
    required this.petIdx,
    required this.petName,
    this.petBloodType,
    this.petWeight,
    this.animalType,
    this.firstDonationDate,
    this.lastDonationDate,
    required this.totalDonations,
    required this.totalBloodVolume,
    required this.averageBloodVolume,
    required this.donations,
  });

  factory PetDonationHistory.fromJson(Map<String, dynamic> json) {
    return PetDonationHistory(
      petIdx: json['pet_idx'],
      petName: json['pet_name'],
      petBloodType: json['pet_blood_type'],
      petWeight: json['pet_weight']?.toDouble(),
      animalType: json['animal_type'],
      firstDonationDate: json['first_donation_date'] != null
          ? DateTime.parse(json['first_donation_date'])
          : null,
      lastDonationDate: json['last_donation_date'] != null
          ? DateTime.parse(json['last_donation_date'])
          : null,
      totalDonations: json['total_donations'] ?? 0,
      totalBloodVolume: (json['total_blood_volume'] ?? 0).toDouble(),
      averageBloodVolume: (json['average_blood_volume'] ?? 0).toDouble(),
      donations: (json['donations'] as List? ?? [])
          .map((item) => CompletedDonation.fromJson(item))
          .toList(),
    );
  }

  // 포맷된 총 헌혈량
  String get formattedTotalBloodVolume {
    return '${totalBloodVolume.toStringAsFixed(1)}mL';
  }

  // 포맷된 평균 헌혈량
  String get formattedAverageBloodVolume {
    return '${averageBloodVolume.toStringAsFixed(1)}mL';
  }

  // 포맷된 첫 헌혈 날짜
  String get formattedFirstDonationDate {
    if (firstDonationDate != null) {
      return DateFormat('yyyy년 MM월 dd일').format(firstDonationDate!);
    }
    return '';
  }

  // 포맷된 마지막 헌혈 날짜
  String get formattedLastDonationDate {
    if (lastDonationDate != null) {
      return DateFormat('yyyy년 MM월 dd일').format(lastDonationDate!);
    }
    return '';
  }

  // 반려동물 기본 정보
  String get petInfo {
    List<String> info = [petName];
    if (animalType != null) {
      String animalTypeKr = animalType == 'dog' ? '강아지' : '고양이';
      info.add(animalTypeKr);
    }
    if (petBloodType != null) info.add(petBloodType!);
    if (petWeight != null) info.add('${petWeight}kg');
    return info.join(' · ');
  }

  // 헌혈 통계 요약
  String get donationStats {
    return '$totalDonations회 · $formattedTotalBloodVolume';
  }

  // 마지막 헌혈로부터 경과일수
  int? get daysSinceLastDonation {
    if (lastDonationDate != null) {
      return DateTime.now().difference(lastDonationDate!).inDays;
    }
    return null;
  }

  // 헌혈 가능 여부 (마지막 헌혈로부터 8주 경과)
  bool get canDonateAgain {
    final daysSince = daysSinceLastDonation;
    return daysSince == null || daysSince >= 56; // 8주 = 56일
  }

  // 다음 헌혈 가능 날짜
  DateTime? get nextAvailableDonationDate {
    if (lastDonationDate != null && !canDonateAgain) {
      return lastDonationDate!.add(const Duration(days: 56));
    }
    return null;
  }
}

// 병원별 헌혈 통계를 위한 모델
class HospitalDonationStats {
  final int hospitalIdx;
  final String hospitalName;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int totalCompleted;
  final double totalBloodVolume;
  final double averageBloodVolume;
  final List<CompletedDonation> completedDonations;

  HospitalDonationStats({
    required this.hospitalIdx,
    required this.hospitalName,
    required this.periodStart,
    required this.periodEnd,
    required this.totalCompleted,
    required this.totalBloodVolume,
    required this.averageBloodVolume,
    required this.completedDonations,
  });

  factory HospitalDonationStats.fromJson(Map<String, dynamic> json) {
    return HospitalDonationStats(
      hospitalIdx: json['hospital_idx'],
      hospitalName: json['hospital_name'],
      periodStart: DateTime.parse(json['period_start']),
      periodEnd: DateTime.parse(json['period_end']),
      totalCompleted: json['total_completed'] ?? 0,
      totalBloodVolume: (json['total_blood_volume'] ?? 0).toDouble(),
      averageBloodVolume: (json['average_blood_volume'] ?? 0).toDouble(),
      completedDonations: (json['completed_donations'] as List? ?? [])
          .map((item) => CompletedDonation.fromJson(item))
          .toList(),
    );
  }

  String get formattedTotalBloodVolume {
    return '${totalBloodVolume.toStringAsFixed(1)}mL';
  }

  String get formattedAverageBloodVolume {
    return '${averageBloodVolume.toStringAsFixed(1)}mL';
  }

  String get formattedPeriod {
    return '${DateFormat('yyyy.MM.dd').format(periodStart)} - ${DateFormat('yyyy.MM.dd').format(periodEnd)}';
  }
}

// 게시글별 헌혈 완료 현황을 위한 모델
class PostDonationCompletions {
  final int postIdx;
  final String postTitle;
  final int totalApplications;
  final int completedCount;
  final double totalBloodVolume;
  final double completionRate;
  final List<CompletedDonation> completedDonations;

  PostDonationCompletions({
    required this.postIdx,
    required this.postTitle,
    required this.totalApplications,
    required this.completedCount,
    required this.totalBloodVolume,
    required this.completionRate,
    required this.completedDonations,
  });

  factory PostDonationCompletions.fromJson(Map<String, dynamic> json) {
    return PostDonationCompletions(
      postIdx: json['post_idx'],
      postTitle: json['post_title'],
      totalApplications: json['total_applications'] ?? 0,
      completedCount: json['completed_count'] ?? 0,
      totalBloodVolume: (json['total_blood_volume'] ?? 0).toDouble(),
      completionRate: (json['completion_rate'] ?? 0).toDouble(),
      completedDonations: (json['completed_donations'] as List? ?? [])
          .map((item) => CompletedDonation.fromJson(item))
          .toList(),
    );
  }

  String get formattedTotalBloodVolume {
    return '${totalBloodVolume.toStringAsFixed(1)}mL';
  }

  String get formattedCompletionRate {
    return '${completionRate.toStringAsFixed(1)}%';
  }

  String get completionStats {
    return '$completedCount/$totalApplications건 완료 ($formattedCompletionRate)';
  }
}

// 월별 헌혈 통계를 위한 모델
class MonthlyDonationStats {
  final int year;
  final int month;
  final int completedCount;
  final double totalBloodVolume;
  final int uniquePetsCount;
  final int uniqueHospitalsCount;

  MonthlyDonationStats({
    required this.year,
    required this.month,
    required this.completedCount,
    required this.totalBloodVolume,
    required this.uniquePetsCount,
    required this.uniqueHospitalsCount,
  });

  factory MonthlyDonationStats.fromJson(Map<String, dynamic> json) {
    return MonthlyDonationStats(
      year: json['year'],
      month: json['month'],
      completedCount: json['completed_count'] ?? 0,
      totalBloodVolume: (json['total_blood_volume'] ?? 0).toDouble(),
      uniquePetsCount: json['unique_pets_count'] ?? 0,
      uniqueHospitalsCount: json['unique_hospitals_count'] ?? 0,
    );
  }

  String get formattedTotalBloodVolume {
    return '${totalBloodVolume.toStringAsFixed(1)}mL';
  }

  String get formattedMonth {
    return '$year년 $month월';
  }

  String get monthlyStats {
    return '$completedCount건 · $formattedTotalBloodVolume';
  }
}

// 헌혈 완료 처리 요청을 위한 모델
class CompleteDonationRequest {
  final int appliedDonationIdx;
  final double bloodVolume;
  final DateTime? completedAt; // null이면 현재 시간 사용

  CompleteDonationRequest({
    required this.appliedDonationIdx,
    required this.bloodVolume,
    this.completedAt,
  });

  Map<String, dynamic> toJson() {
    final json = {
      'applied_donation_idx': appliedDonationIdx,
      'blood_volume': bloodVolume,
    };
    
    if (completedAt != null) {
      json['completed_at'] = completedAt!.millisecondsSinceEpoch;
    }
    
    return json;
  }

  // 유효성 검사
  bool isValid() {
    return appliedDonationIdx > 0 && 
           CompletedDonation.isValidBloodVolume(bloodVolume);
  }

  String? getValidationError() {
    if (appliedDonationIdx <= 0) {
      return '올바르지 않은 신청 정보입니다.';
    }
    if (!CompletedDonation.isValidBloodVolume(bloodVolume)) {
      return '헌혈량은 0mL보다 크고 1000mL 이하여야 합니다.';
    }
    return null;
  }
}