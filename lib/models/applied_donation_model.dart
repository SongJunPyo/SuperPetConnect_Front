// models/applied_donation_model.dart

import 'package:intl/intl.dart';

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
  });

  factory AppliedDonation.fromJson(Map<String, dynamic> json) {
    return AppliedDonation(
      appliedDonationIdx: json['applied_donation_idx'],
      petIdx: json['pet_idx'],
      postTimesIdx: json['post_times_idx'],
      status: json['status'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      pet: json['pet'] != null ? Pet.fromJson(json['pet']) : null,
      donationTime: json['donation_time'] != null
          ? DateTime.parse(json['donation_time'])
          : null,
      donationDate: json['donation_date'] != null
          ? DateTime.parse(json['donation_date'])
          : null,
      postTitle: json['post_title'],
      hospitalName: json['hospital_name'],
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
    return {
      'pet_idx': petIdx,
      'post_times_idx': postTimesIdx,
    };
  }

  // 상태 변경을 위한 요청 JSON (병원용)
  Map<String, dynamic> toStatusUpdateJson() {
    return {
      'status': status,
    };
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

  bool get canCancel {
    return status == AppliedDonationStatus.pending || 
           status == AppliedDonationStatus.approved;
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
    );
  }
}

// 헌혈 신청 상태 관리 클래스
class AppliedDonationStatus {
  static const int pending = 0;             // 대기중
  static const int approved = 1;            // 승인됨
  static const int rejected = 2;            // 거절됨
  static const int completed = 3;           // 완료됨
  static const int cancelled = 4;           // 취소됨
  static const int pendingCompletion = 5;   // 완료 대기 (병원에서 1차 완료 처리됨)
  static const int pendingCancellation = 6; // 취소 대기 (병원에서 중지 처리됨)

  static String getStatusText(int status) {
    switch (status) {
      case pending:
        return '대기중';
      case approved:
        return '승인됨';
      case rejected:
        return '거절됨';
      case completed:
        return '완료됨';
      case cancelled:
        return '취소됨';
      case pendingCompletion:
        return '완료대기';
      case pendingCancellation:
        return '취소대기';
      default:
        return '알 수 없음';
    }
  }

  static String getStatusColor(int status) {
    switch (status) {
      case pending:
        return 'orange';
      case approved:
        return 'green';
      case rejected:
        return 'red';
      case completed:
        return 'blue';
      case cancelled:
        return 'grey';
      case pendingCompletion:
        return 'lightblue';
      case pendingCancellation:
        return 'lightorange';
      default:
        return 'grey';
    }
  }

  static List<int> getAllStatuses() {
    return [pending, approved, rejected, completed, cancelled, pendingCompletion, pendingCancellation];
  }

  static List<Map<String, dynamic>> getStatusOptions() {
    return [
      {'value': pending, 'text': getStatusText(pending), 'color': getStatusColor(pending)},
      {'value': approved, 'text': getStatusText(approved), 'color': getStatusColor(approved)},
      {'value': rejected, 'text': getStatusText(rejected), 'color': getStatusColor(rejected)},
      {'value': completed, 'text': getStatusText(completed), 'color': getStatusColor(completed)},
      {'value': cancelled, 'text': getStatusText(cancelled), 'color': getStatusColor(cancelled)},
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
  final int? age;

  Pet({
    this.petIdx,
    required this.name,
    this.bloodType,
    this.weightKg,
    this.animalType,
    this.age,
  });

  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(
      petIdx: json['pet_idx'],
      name: json['name'] ?? '',
      bloodType: json['blood_type'],
      weightKg: json['weight_kg']?.toDouble(),
      animalType: json['animal_type'],
      age: json['age'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pet_idx': petIdx,
      'name': name,
      'blood_type': bloodType,
      'weight_kg': weightKg,
      'animal_type': animalType,
      'age': age,
    };
  }

  // 표시용 정보
  String get displayInfo {
    List<String> info = [name];
    if (animalType != null) {
      String animalTypeKr = animalType == 'dog' ? '강아지' : '고양이';
      info.add(animalTypeKr);
    }
    if (bloodType != null) info.add(bloodType!);
    if (weightKg != null) info.add('${weightKg}kg');
    if (age != null) info.add('${age}세');
    return info.join(' · ');
  }

  String get animalTypeKr {
    if (animalType == 'dog') return '강아지';
    if (animalType == 'cat') return '고양이';
    return animalType ?? '';
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
      applications: (json['applications'] as List)
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
    return applications.where((app) => 
        app.status == AppliedDonationStatus.pending || 
        app.status == AppliedDonationStatus.approved
    ).length;
  }

  // 최근 신청
  AppliedDonation? get latestApplication {
    if (applications.isEmpty) return null;
    return applications.reduce((a, b) => 
        a.createdAt?.isAfter(b.createdAt ?? DateTime(1900)) == true ? a : b
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
      applications: (json['applications'] as List)
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
  int get rejectedCount => getStatusCount(AppliedDonationStatus.rejected);
  int get completedCount => getStatusCount(AppliedDonationStatus.completed);
  int get cancelledCount => getStatusCount(AppliedDonationStatus.cancelled);
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
      applications: (json['applications'] as List)
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