// models/cancelled_donation_model.dart

import 'package:intl/intl.dart';
import 'applied_donation_model.dart';

class CancelledDonation {
  final int? cancelledDonationIdx;
  final int appliedDonationIdx;
  final int cancelledSubject; // 0:사용자, 1:병원, 2:시스템, 3:관리자
  final String cancelledReason;
  final DateTime cancelledAt;

  // 조인된 정보들 (응답에서 포함될 수 있음)
  final String? petName;
  final String? petBloodType;
  final double? petWeight;
  final DateTime? donationTime;
  final String? postTitle;
  final String? hospitalName;
  final String? userName;
  final AppliedDonation? appliedDonation;

  CancelledDonation({
    this.cancelledDonationIdx,
    required this.appliedDonationIdx,
    required this.cancelledSubject,
    required this.cancelledReason,
    required this.cancelledAt,
    this.petName,
    this.petBloodType,
    this.petWeight,
    this.donationTime,
    this.postTitle,
    this.hospitalName,
    this.userName,
    this.appliedDonation,
  });

  factory CancelledDonation.fromJson(Map<String, dynamic> json) {
    return CancelledDonation(
      cancelledDonationIdx: json['cancelled_donation_idx'],
      appliedDonationIdx: json['applied_donation_idx'],
      cancelledSubject: json['cancelled_subject'],
      cancelledReason: json['cancelled_reason'] ?? '',
      cancelledAt: DateTime.parse(json['cancelled_at']),
      petName: json['pet_name'],
      petBloodType: json['pet_blood_type'],
      petWeight: json['pet_weight']?.toDouble(),
      donationTime: json['donation_time'] != null
          ? DateTime.parse(json['donation_time'])
          : null,
      postTitle: json['post_title'],
      hospitalName: json['hospital_name'],
      userName: json['user_name'],
      appliedDonation: json['applied_donation'] != null
          ? AppliedDonation.fromJson(json['applied_donation'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cancelled_donation_idx': cancelledDonationIdx,
      'applied_donation_idx': appliedDonationIdx,
      'cancelled_subject': cancelledSubject,
      'cancelled_reason': cancelledReason,
      'cancelled_at': cancelledAt.toIso8601String(),
    };
  }

  // 헌혈 취소를 위한 요청 JSON (생성 시)
  Map<String, dynamic> toCreateJson() {
    return {
      'applied_donation_idx': appliedDonationIdx,
      'cancelled_subject': cancelledSubject,
      'cancelled_reason': cancelledReason,
      'cancelled_at': cancelledAt.toIso8601String(),
    };
  }

  // 취소 기록 수정을 위한 요청 JSON
  Map<String, dynamic> toUpdateJson() {
    return {
      'cancelled_reason': cancelledReason,
      'cancelled_at': cancelledAt.toIso8601String(),
    };
  }

  // 취소 주체 텍스트
  String get cancelledSubjectText {
    switch (cancelledSubject) {
      case CancelledSubject.user:
        return '사용자';
      case CancelledSubject.hospital:
        return '병원';
      case CancelledSubject.system:
        return '시스템';
      case CancelledSubject.admin:
        return '관리자';
      default:
        return '알 수 없음';
    }
  }

  // 취소 주체 아이콘
  String get cancelledSubjectIcon {
    switch (cancelledSubject) {
      case CancelledSubject.user:
        return '👤';
      case CancelledSubject.hospital:
        return '🏥';
      case CancelledSubject.system:
        return '⚙️';
      case CancelledSubject.admin:
        return '👨‍💼';
      default:
        return '❓';
    }
  }

  // 포맷된 취소 시간
  String get formattedCancelledTime {
    return DateFormat('MM월 dd일 HH:mm', 'ko_KR').format(cancelledAt);
  }

  String get formattedCancelledDate {
    return DateFormat('yyyy년 MM월 dd일', 'ko_KR').format(cancelledAt);
  }

  String get formattedCancelledDateTime {
    return DateFormat('MM월 dd일 (E) HH:mm', 'ko_KR').format(cancelledAt);
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

  // 취소 정보 요약
  String get cancellationSummary {
    return '$cancelledSubjectText · $formattedCancelledTime';
  }

  // 복사본 생성 (수정 등)
  CancelledDonation copyWith({
    int? cancelledDonationIdx,
    int? appliedDonationIdx,
    int? cancelledSubject,
    String? cancelledReason,
    DateTime? cancelledAt,
    String? petName,
    String? petBloodType,
    double? petWeight,
    DateTime? donationTime,
    String? postTitle,
    String? hospitalName,
    String? userName,
    AppliedDonation? appliedDonation,
  }) {
    return CancelledDonation(
      cancelledDonationIdx: cancelledDonationIdx ?? this.cancelledDonationIdx,
      appliedDonationIdx: appliedDonationIdx ?? this.appliedDonationIdx,
      cancelledSubject: cancelledSubject ?? this.cancelledSubject,
      cancelledReason: cancelledReason ?? this.cancelledReason,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      petName: petName ?? this.petName,
      petBloodType: petBloodType ?? this.petBloodType,
      petWeight: petWeight ?? this.petWeight,
      donationTime: donationTime ?? this.donationTime,
      postTitle: postTitle ?? this.postTitle,
      hospitalName: hospitalName ?? this.hospitalName,
      userName: userName ?? this.userName,
      appliedDonation: appliedDonation ?? this.appliedDonation,
    );
  }

  // 취소 사유 유효성 검사
  static bool isValidCancelledReason(String reason) {
    return reason.trim().isNotEmpty && reason.trim().length >= 2;
  }
}

// 취소 주체 상수
class CancelledSubject {
  static const int user = 0;     // 사용자
  static const int hospital = 1; // 병원
  static const int system = 2;   // 시스템
  static const int admin = 3;    // 관리자
}

// 병원별 취소 통계를 위한 모델
class HospitalCancellationStats {
  final int hospitalIdx;
  final String hospitalName;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int totalCancelled;
  final int userCancelled;
  final int hospitalCancelled;
  final int systemCancelled;
  final int adminCancelled;
  final List<CancelledDonation> cancelledDonations;

  HospitalCancellationStats({
    required this.hospitalIdx,
    required this.hospitalName,
    required this.periodStart,
    required this.periodEnd,
    required this.totalCancelled,
    required this.userCancelled,
    required this.hospitalCancelled,
    required this.systemCancelled,
    required this.adminCancelled,
    required this.cancelledDonations,
  });

  factory HospitalCancellationStats.fromJson(Map<String, dynamic> json) {
    return HospitalCancellationStats(
      hospitalIdx: json['hospital_idx'],
      hospitalName: json['hospital_name'],
      periodStart: DateTime.parse(json['period_start']),
      periodEnd: DateTime.parse(json['period_end']),
      totalCancelled: json['total_cancelled'] ?? 0,
      userCancelled: json['cancelled_by_user'] ?? 0,
      hospitalCancelled: json['cancelled_by_hospital'] ?? 0,
      systemCancelled: json['cancelled_by_system'] ?? 0,
      adminCancelled: json['cancelled_by_admin'] ?? 0,
      cancelledDonations: (json['cancelled_donations'] as List? ?? [])
          .map((item) => CancelledDonation.fromJson(item))
          .toList(),
    );
  }

  String get formattedPeriod {
    return '${DateFormat('yyyy.MM.dd').format(periodStart)} - ${DateFormat('yyyy.MM.dd').format(periodEnd)}';
  }

  String get cancellationStats {
    return '$totalCancelled건 취소 (사용자: $userCancelled, 병원: $hospitalCancelled, 시스템: $systemCancelled, 관리자: $adminCancelled)';
  }
}

// 게시글별 취소 현황을 위한 모델
class PostCancellationStatus {
  final int postIdx;
  final String postTitle;
  final int totalApplications;
  final int cancelledCount;
  final double cancellationRate;
  final Map<int, int> cancellationBySubject; // subject별 취소 건수
  final List<CancelledDonation> cancelledDonations;

  PostCancellationStatus({
    required this.postIdx,
    required this.postTitle,
    required this.totalApplications,
    required this.cancelledCount,
    required this.cancellationRate,
    required this.cancellationBySubject,
    required this.cancelledDonations,
  });

  factory PostCancellationStatus.fromJson(Map<String, dynamic> json) {
    return PostCancellationStatus(
      postIdx: json['post_idx'],
      postTitle: json['post_title'],
      totalApplications: json['total_applications'] ?? 0,
      cancelledCount: json['cancelled_count'] ?? 0,
      cancellationRate: (json['cancellation_rate'] ?? 0).toDouble(),
      cancellationBySubject: Map<int, int>.from(json['cancellation_by_subject'] ?? {}),
      cancelledDonations: (json['cancelled_donations'] as List? ?? [])
          .map((item) => CancelledDonation.fromJson(item))
          .toList(),
    );
  }

  String get formattedCancellationRate {
    return '${cancellationRate.toStringAsFixed(1)}%';
  }

  String get cancellationStatusSummary {
    return '$cancelledCount/$totalApplications건 취소 ($formattedCancellationRate)';
  }
}

// 월별 취소 통계를 위한 모델
class MonthlyCancellationStats {
  final int year;
  final int month;
  final int totalCancellations;
  final int userCancellations;
  final int hospitalCancellations;
  final int systemCancellations;
  final int adminCancellations;

  MonthlyCancellationStats({
    required this.year,
    required this.month,
    required this.totalCancellations,
    required this.userCancellations,
    required this.hospitalCancellations,
    required this.systemCancellations,
    required this.adminCancellations,
  });

  factory MonthlyCancellationStats.fromJson(Map<String, dynamic> json) {
    return MonthlyCancellationStats(
      year: json['year'],
      month: json['month'],
      totalCancellations: json['total_cancelled'] ?? 0,
      userCancellations: json['cancelled_by_user'] ?? 0,
      hospitalCancellations: json['cancelled_by_hospital'] ?? 0,
      systemCancellations: json['cancelled_by_system'] ?? 0,
      adminCancellations: json['cancelled_by_admin'] ?? 0,
    );
  }

  String get formattedMonth {
    return '$year년 $month월';
  }

  String get monthlyCancellationStats {
    return '$totalCancellations건 취소 (사용자: $userCancellations, 병원: $hospitalCancellations, 시스템: $systemCancellations, 관리자: $adminCancellations)';
  }
}

// 헌혈 취소 처리 요청을 위한 모델
class CancelDonationRequest {
  final int appliedDonationIdx;
  final int cancelledSubject;
  final String cancelledReason;
  final DateTime? cancelledAt; // null이면 현재 시간 사용

  CancelDonationRequest({
    required this.appliedDonationIdx,
    required this.cancelledSubject,
    required this.cancelledReason,
    this.cancelledAt,
  });

  Map<String, dynamic> toJson() {
    final json = {
      'applied_donation_idx': appliedDonationIdx,
      'cancelled_subject': cancelledSubject,
      'cancelled_reason': cancelledReason,
    };
    
    if (cancelledAt != null) {
      json['cancelled_at'] = cancelledAt!.toIso8601String();
    }
    
    return json;
  }

  // 유효성 검사
  bool isValid() {
    return appliedDonationIdx > 0 && 
           CancelledDonation.isValidCancelledReason(cancelledReason) &&
           [CancelledSubject.user, CancelledSubject.hospital, CancelledSubject.system, CancelledSubject.admin]
               .contains(cancelledSubject);
  }

  String? getValidationError() {
    if (appliedDonationIdx <= 0) {
      return '올바르지 않은 신청 정보입니다.';
    }
    if (!CancelledDonation.isValidCancelledReason(cancelledReason)) {
      return '취소 사유를 2글자 이상 입력해주세요.';
    }
    if (![CancelledSubject.user, CancelledSubject.hospital, CancelledSubject.system, CancelledSubject.admin]
            .contains(cancelledSubject)) {
      return '올바르지 않은 취소 주체입니다.';
    }
    return null;
  }
}

// 관리자용 헌혈 완료/취소 대기 목록을 위한 모델
class AdminPendingDonation {
  final int appliedDonationIdx;
  final String status; // 'pending_completion', 'pending_cancellation'
  final String? petName;
  final String? petBloodType;
  final double? petWeight;
  final String? postTitle;
  final String? hospitalName;
  final String? userName;
  final DateTime? donationTime;
  final DateTime createdAt;
  
  // 완료 관련 정보 (pending_completion인 경우)
  final double? bloodVolume;
  final DateTime? completedAt;
  
  // 취소 관련 정보 (pending_cancellation인 경우)
  final int? cancelledSubject;
  final String? cancelledReason;
  final DateTime? cancelledAt;

  AdminPendingDonation({
    required this.appliedDonationIdx,
    required this.status,
    this.petName,
    this.petBloodType,
    this.petWeight,
    this.postTitle,
    this.hospitalName,
    this.userName,
    this.donationTime,
    required this.createdAt,
    this.bloodVolume,
    this.completedAt,
    this.cancelledSubject,
    this.cancelledReason,
    this.cancelledAt,
  });

  factory AdminPendingDonation.fromJson(Map<String, dynamic> json) {
    return AdminPendingDonation(
      appliedDonationIdx: json['applied_donation_idx'],
      status: json['status'],
      petName: json['pet_name'],
      petBloodType: json['pet_blood_type'],
      petWeight: json['pet_weight']?.toDouble(),
      postTitle: json['post_title'],
      hospitalName: json['hospital_name'],
      userName: json['user_name'],
      donationTime: json['donation_time'] != null
          ? DateTime.parse(json['donation_time'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      bloodVolume: json['blood_volume']?.toDouble(),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      cancelledSubject: json['cancelled_subject'],
      cancelledReason: json['cancelled_reason'],
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'])
          : null,
    );
  }

  String get statusText {
    switch (status) {
      case 'pending_completion':
        return '완료 대기';
      case 'pending_cancellation':
        return '취소 대기';
      default:
        return '알 수 없음';
    }
  }

  String get petSummary {
    List<String> info = [];
    if (petName != null) info.add(petName!);
    if (petBloodType != null) info.add(petBloodType!);
    if (petWeight != null) info.add('${petWeight}kg');
    return info.join(' · ');
  }

  String get formattedDonationTime {
    if (donationTime != null) {
      return DateFormat('MM월 dd일 (E) HH:mm', 'ko_KR').format(donationTime!);
    }
    return '';
  }

  String get formattedCreatedAt {
    return DateFormat('MM월 dd일 HH:mm', 'ko_KR').format(createdAt);
  }

  bool get isPendingCompletion => status == 'pending_completion';
  bool get isPendingCancellation => status == 'pending_cancellation';

  // AppliedDonation에서 AdminPendingDonation으로 변환하는 팩토리 메서드
  static AdminPendingDonation fromAppliedDonation(dynamic application, String status) {
    return AdminPendingDonation(
      appliedDonationIdx: application.appliedDonationIdx ?? 0,
      status: status,
      petName: application.pet?.name,
      petBloodType: application.pet?.bloodType,
      petWeight: application.pet?.weightKg,
      postTitle: application.postTitle,
      hospitalName: application.hospitalName,
      userName: application.userName,
      donationTime: application.donationTime,
      createdAt: application.appliedAt ?? DateTime.now(),
      bloodVolume: null, // 실제로는 별도 조회 필요
      completedAt: null,
      cancelledSubject: null,
      cancelledReason: null,
      cancelledAt: null,
    );
  }
}