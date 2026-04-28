// models/applied_donation_model.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';

class AppliedDonation {
  final int? appliedDonationIdx;
  final int petIdx;
  final int postTimesIdx;
  final int status;
  final DateTime? createdAt;

  // 조인된 정보들 (응답에서 포함될 수 있음)
  final Pet? pet;
  final DateTime? donationTime;
  final DateTime? donationDate;
  final String? postTitle;
  final String? hospitalName;
  final String? userNickname;

  AppliedDonation({
    this.appliedDonationIdx,
    required this.petIdx,
    required this.postTimesIdx,
    required this.status,
    this.createdAt,
    this.pet,
    this.donationTime,
    this.donationDate,
    this.postTitle,
    this.hospitalName,
    this.userNickname,
  });

  factory AppliedDonation.fromJson(Map<String, dynamic> json) {
    return AppliedDonation(
      appliedDonationIdx: json['applied_donation_idx'],
      petIdx: json['pet_idx'],
      postTimesIdx: json['post_times_idx'],
      status: json['status'],
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : null,
      pet: json['pet'] != null ? Pet.fromJson(json['pet']) : null,
      donationTime:
          json['donation_time'] != null
              ? DateTime.parse(json['donation_time'])
              : null,
      donationDate:
          json['donation_date'] != null
              ? DateTime.parse(json['donation_date'])
              : null,
      postTitle: json['post_title'],
      hospitalName: json['hospital_name'],
      userNickname: json['user_nickname'] ?? json['nickname'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'applied_donation_idx': appliedDonationIdx,
      'pet_idx': petIdx,
      'post_times_idx': postTimesIdx,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  // 헌혈 신청을 위한 요청 JSON (생성 시)
  Map<String, dynamic> toCreateJson() {
    return {'pet_idx': petIdx, 'post_times_idx': postTimesIdx};
  }

  // 상태 변경을 위한 요청 JSON (병원용)
  Map<String, dynamic> toStatusUpdateJson() {
    return {'status': status};
  }

  // 상태 텍스트 반환
  String get statusText {
    return AppliedDonationStatus.getStatusText(status);
  }

  // 상태 색상 반환 (UI용)
  String get statusColor {
    return AppliedDonationStatus.getStatusColor(status);
  }

  // 신청 가능 여부 확인 (수정/취소)
  bool get canModify {
    return status == AppliedDonationStatus.pending;
  }

  /// 취소 가능 여부 (대기중일 때만 가능)
  bool get canCancel {
    return AppliedDonationStatus.canCancelStatus(status);
  }

  /// 취소 불가 시 메시지
  String get cancelBlockMessage {
    return AppliedDonationStatus.getCancelBlockMessage(status);
  }

  /// 빨간 테두리 표시 여부 (이미 신청한 시간대)
  bool get shouldShowAppliedBorder {
    return AppliedDonationStatus.shouldShowAppliedBorder(status);
  }

  // 포맷된 날짜/시간
  String get formattedDateTime {
    if (donationTime != null) {
      return DateFormat('MM월 dd일 (E) HH:mm', 'ko_KR').format(donationTime!);
    } else if (donationDate != null) {
      return DateFormat('MM월 dd일 (E)', 'ko_KR').format(donationDate!);
    }
    return '';
  }

  String get formattedTime {
    if (donationTime != null) {
      return DateFormat('HH:mm').format(donationTime!);
    }
    return '';
  }

  String get formattedDate {
    if (donationDate != null || donationTime != null) {
      final date = donationDate ?? donationTime!;
      return DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(date);
    }
    return '';
  }

  String get formattedCreatedAt {
    if (createdAt != null) {
      return DateFormat('MM월 dd일 HH:mm', 'ko_KR').format(createdAt!);
    }
    return '';
  }

  // 복사본 생성 (상태 변경 등)
  AppliedDonation copyWith({
    int? appliedDonationIdx,
    int? petIdx,
    int? postTimesIdx,
    int? status,
    DateTime? createdAt,
    Pet? pet,
    DateTime? donationTime,
    DateTime? donationDate,
    String? postTitle,
    String? hospitalName,
    String? userNickname,
  }) {
    return AppliedDonation(
      appliedDonationIdx: appliedDonationIdx ?? this.appliedDonationIdx,
      petIdx: petIdx ?? this.petIdx,
      postTimesIdx: postTimesIdx ?? this.postTimesIdx,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      pet: pet ?? this.pet,
      donationTime: donationTime ?? this.donationTime,
      donationDate: donationDate ?? this.donationDate,
      postTitle: postTitle ?? this.postTitle,
      hospitalName: hospitalName ?? this.hospitalName,
      userNickname: userNickname ?? this.userNickname,
    );
  }
}

// 헌혈 신청 상태 관리 클래스
//
// 라이프사이클:
//   PENDING(0) → APPROVED(1) → PENDING_COMPLETION(2) → COMPLETED(3)
//   PENDING/APPROVED → CLOSED(4)  (게시글 마감 시 자동 일괄 처리 + 관리자 수동 종결)
//   PENDING → hard delete  (사용자 자발 취소, 행 자체 삭제)
class AppliedDonationStatus {
  static const int pending = 0; // 신청 (대기)
  static const int approved = 1; // 선정 (관리자 승인)
  static const int pendingCompletion = 2; // 완료 대기 (병원 1차 완료)
  static const int completed = 3; // 헌혈 완료 (관리자 최종 승인)
  static const int closed = 4; // 종결 (미선정 / 관리자 수동 종결)

  static String getStatusText(int status) {
    switch (status) {
      case pending:
        return '대기중';
      case approved:
        return '선정';
      case pendingCompletion:
        return '완료대기';
      case completed:
        return '헌혈완료';
      case closed:
        return '종결';
      default:
        return '알 수 없음';
    }
  }

  static String getStatusColor(int status) {
    switch (status) {
      case pending:
        return 'orange';
      case approved:
        return 'blue';
      case pendingCompletion:
        return 'amber';
      case completed:
        return 'green';
      case closed:
        return 'grey';
      default:
        return 'grey';
    }
  }

  /// 상태에 따른 Color 객체 반환 (UI에서 직접 사용)
  static Color getStatusColorValue(int status) {
    switch (status) {
      case pending:
        return Colors.orange;
      case approved:
        return AppTheme.primaryBlue;
      case pendingCompletion:
        return Colors.amber;
      case completed:
        return AppTheme.success;
      case closed:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  /// 취소 가능 여부 확인 (대기중일 때만 가능)
  static bool canCancelStatus(int status) {
    return status == pending;
  }

  /// 취소 불가 시 메시지
  static String getCancelBlockMessage(int status) {
    switch (status) {
      case approved:
        return '선정된 신청은 취소할 수 없습니다. 취소가 필요하시면 관리자에게 문의해주세요.';
      case pendingCompletion:
        return '헌혈 진행 중인 신청은 취소할 수 없습니다.';
      case completed:
        return '헌혈 완료된 신청은 취소할 수 없습니다.';
      case closed:
        return '종결된 신청은 취소할 수 없습니다.';
      default:
        return '취소할 수 없습니다.';
    }
  }

  /// 시간대에 빨간 테두리를 표시해야 하는 상태인지 확인
  /// (CLOSED는 다시 신청 가능하므로 제외)
  static bool shouldShowAppliedBorder(int status) {
    return status == pending ||
        status == approved ||
        status == pendingCompletion ||
        status == completed;
  }

  static List<int> getAllStatuses() {
    return [pending, approved, pendingCompletion, completed, closed];
  }

  static List<Map<String, dynamic>> getStatusOptions() {
    return [
      {
        'value': pending,
        'text': getStatusText(pending),
        'color': getStatusColor(pending),
      },
      {
        'value': approved,
        'text': getStatusText(approved),
        'color': getStatusColor(approved),
      },
      {
        'value': pendingCompletion,
        'text': getStatusText(pendingCompletion),
        'color': getStatusColor(pendingCompletion),
      },
      {
        'value': completed,
        'text': getStatusText(completed),
        'color': getStatusColor(completed),
      },
      {
        'value': closed,
        'text': getStatusText(closed),
        'color': getStatusColor(closed),
      },
    ];
  }
}

// Pet 모델 (applied_donation에서 사용하는 간소화된 버전)
class Pet {
  final int? petIdx;
  final String name;
  final String? bloodType;
  final double? weightKg;
  final String? animalType;
  final DateTime? birthDate;
  final String? species;
  final String? breed;
  final String? profileImage;

  Pet({
    this.petIdx,
    required this.name,
    this.bloodType,
    this.weightKg,
    this.animalType,
    this.birthDate,
    this.species,
    this.breed,
    this.profileImage,
  });

  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(
      petIdx: json['pet_idx'],
      name: json['name'] ?? '',
      bloodType: json['blood_type'],
      weightKg: json['weight_kg']?.toDouble(),
      animalType: json['animal_type'],
      birthDate: json['birth_date'] != null
          ? DateTime.tryParse(json['birth_date'])
          : null,
      species: json['species'],
      breed: json['breed'],
      profileImage: json['profile_image'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pet_idx': petIdx,
      'name': name,
      'blood_type': bloodType,
      'weight_kg': weightKg,
      'animal_type': animalType,
      'birth_date': birthDate?.toIso8601String().split('T')[0],
      'species': species,
      'breed': breed,
    };
  }

  String get age {
    if (birthDate == null) return '나이 미상';
    final now = DateTime.now();
    final totalMonths = (now.year - birthDate!.year) * 12 + (now.month - birthDate!.month);
    if (totalMonths < 12) return '$totalMonths개월';
    return '${totalMonths ~/ 12}살';
  }

  String get birthDateWithAge {
    if (birthDate == null) return '나이 미상';
    final dateStr = '${birthDate!.year}.${birthDate!.month.toString().padLeft(2, '0')}.${birthDate!.day.toString().padLeft(2, '0')}';
    return '$dateStr ($age)';
  }

  // 1줄 요약: 종 • 품종 • 혈액형 • 나이 • 체중
  String get summaryLine {
    final speciesText = animalTypeKr;
    final parts = <String>[speciesText];
    if (breed != null && breed!.isNotEmpty) parts.add(breed!);
    if (bloodType != null) parts.add(bloodType!);
    parts.add(age);
    if (weightKg != null) parts.add('${weightKg}kg');
    return parts.join(' • ');
  }

  // 표시용 정보 (이름 + 1줄 요약)
  String get displayInfo {
    return '$name ($summaryLine)';
  }

  String get animalTypeKr {
    // species를 우선 사용 (서버에서 "dog"/"cat"으로 제공)
    String typeSource = species ?? animalType ?? '';
    if (typeSource == 'dog' || typeSource == '강아지' || typeSource == '개') {
      return '강아지';
    }
    if (typeSource == 'cat' || typeSource == '고양이') return '고양이';
    return typeSource.isEmpty ? '정보 없음' : typeSource;
  }

  // species getter - species 필드 우선 사용
  String get speciesKr {
    String sourceType = species ?? animalType ?? '';
    if (sourceType == 'dog' || sourceType == '강아지' || sourceType == '개') {
      return '강아지';
    }
    if (sourceType == 'cat' || sourceType == '고양이') return '고양이';
    return sourceType.isEmpty ? '정보 없음' : sourceType;
  }
}

// 내 반려동물 신청 목록을 위한 복합 모델
class MyPetApplications {
  final int petIdx;
  final String petName;
  final String? animalType;
  final List<AppliedDonation> applications;

  MyPetApplications({
    required this.petIdx,
    required this.petName,
    this.animalType,
    required this.applications,
  });

  factory MyPetApplications.fromJson(Map<String, dynamic> json) {
    return MyPetApplications(
      petIdx: json['pet_idx'],
      petName: json['pet_name'],
      animalType: json['animal_type'],
      applications:
          (json['applications'] as List)
              .map((item) => AppliedDonation.fromJson(item))
              .toList(),
    );
  }

  String get animalTypeKr {
    if (animalType == 'dog') return '강아지';
    if (animalType == 'cat') return '고양이';
    return animalType ?? '';
  }

  // 진행 중인 신청 수
  int get activeApplicationsCount {
    return applications
        .where(
          (app) =>
              app.status == AppliedDonationStatus.pending ||
              app.status == AppliedDonationStatus.approved,
        )
        .length;
  }

  // 최근 신청
  AppliedDonation? get latestApplication {
    if (applications.isEmpty) return null;
    return applications.reduce(
      (a, b) =>
          a.createdAt?.isAfter(b.createdAt ?? DateTime(1900)) == true ? a : b,
    );
  }
}

// 병원용 게시글 신청 목록을 위한 복합 모델
class PostApplications {
  final int postIdx;
  final String postTitle;
  final int totalApplications;
  final List<AppliedDonation> applications;

  PostApplications({
    required this.postIdx,
    required this.postTitle,
    required this.totalApplications,
    required this.applications,
  });

  factory PostApplications.fromJson(Map<String, dynamic> json) {
    return PostApplications(
      postIdx: json['post_idx'],
      postTitle: json['post_title'],
      totalApplications: json['total_applications'] ?? 0,
      applications:
          (json['applications'] as List)
              .map((item) => AppliedDonation.fromJson(item))
              .toList(),
    );
  }

  // 상태별 개수
  int getStatusCount(int status) {
    return applications.where((app) => app.status == status).length;
  }

  int get pendingCount => getStatusCount(AppliedDonationStatus.pending);
  int get approvedCount => getStatusCount(AppliedDonationStatus.approved);
  int get completedCount => getStatusCount(AppliedDonationStatus.completed);
  int get closedCount => getStatusCount(AppliedDonationStatus.closed);
}

// 서버 API 응답용 내 신청 정보 모델 (GET /api/donation/my-applications)
class MyApplicationInfo {
  final int applicationId;
  final int postId;
  final String postTitle;
  final String petName;
  final String petSpecies; // "강아지" 또는 "고양이"
  final String? petBloodType;
  final String donationTime; // "2026-01-15 10:00" 형식
  final String status; // "대기중", "승인됨" 등
  final int statusCode;
  final int postTimesIdx;

  MyApplicationInfo({
    required this.applicationId,
    required this.postId,
    required this.postTitle,
    required this.petName,
    required this.petSpecies,
    this.petBloodType,
    required this.donationTime,
    required this.status,
    required this.statusCode,
    required this.postTimesIdx,
  });

  factory MyApplicationInfo.fromJson(Map<String, dynamic> json) {
    // pet_species 처리: String 또는 int 모두 지원
    String species = '';
    final rawSpecies = json['pet_species'];
    if (rawSpecies is String) {
      species = rawSpecies;
    } else if (rawSpecies is int) {
      species = rawSpecies == 0 ? '강아지' : '고양이';
    }

    return MyApplicationInfo(
      applicationId:
          json['application_id'] ?? json['applied_donation_idx'] ?? 0,
      postId: json['post_id'] ?? json['post_idx'] ?? 0,
      postTitle: json['post_title'] ?? '',
      petName: json['pet_name'] ?? '',
      petSpecies: species,
      petBloodType: json['pet_blood_type'],
      donationTime: json['donation_time'] ?? '',
      status: json['status'] ?? '알 수 없음',
      statusCode: json['status_code'] ?? 0,
      postTimesIdx: json['post_times_idx'] ?? 0,
    );
  }

  /// 취소 가능 여부
  bool get canCancel => AppliedDonationStatus.canCancelStatus(statusCode);

  /// 취소 불가 시 메시지
  String get cancelBlockMessage =>
      AppliedDonationStatus.getCancelBlockMessage(statusCode);

  /// 빨간 테두리 표시 여부
  bool get shouldShowAppliedBorder =>
      AppliedDonationStatus.shouldShowAppliedBorder(statusCode);

  /// 종류 텍스트
  String get speciesText => petSpecies;
}

// 시간대별 신청 현황을 위한 모델
class TimeSlotApplications {
  final int postTimesIdx;
  final DateTime donationTime;
  final int totalApplications;
  final int pendingCount;
  final int approvedCount;
  final List<AppliedDonation> applications;

  TimeSlotApplications({
    required this.postTimesIdx,
    required this.donationTime,
    required this.totalApplications,
    required this.pendingCount,
    required this.approvedCount,
    required this.applications,
  });

  factory TimeSlotApplications.fromJson(Map<String, dynamic> json) {
    return TimeSlotApplications(
      postTimesIdx: json['post_times_idx'],
      donationTime: DateTime.parse(json['donation_time']),
      totalApplications: json['total_applications'] ?? 0,
      pendingCount: json['pending_count'] ?? 0,
      approvedCount: json['approved_count'] ?? 0,
      applications:
          (json['applications'] as List)
              .map((item) => AppliedDonation.fromJson(item))
              .toList(),
    );
  }

  String get formattedTime {
    return DateFormat('HH:mm').format(donationTime);
  }

  String get formattedDateTime {
    return DateFormat('MM월 dd일 HH:mm', 'ko_KR').format(donationTime);
  }

  // 시간대가 꽉 찼는지 확인 (승인된 신청 기준)
  bool isFullyBooked([int? capacity]) {
    if (capacity != null) {
      return approvedCount >= capacity;
    }
    return false;
  }

  // 신청 가능한지 확인
  bool get canApply {
    return totalApplications < 10; // 기본 제한
  }
}
