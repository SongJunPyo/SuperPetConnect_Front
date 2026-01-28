// lib/models/donation_history_model.dart
// 반려동물 헌혈 이력 모델

/// 개별 헌혈 이력
class DonationHistory {
  final int historyIdx;
  final int petIdx;
  final DateTime donationDate;
  final String? hospitalName;
  final int? bloodVolumeMl;
  final String? notes;
  final bool isSystemRecord; // true: 시스템 자동 기록, false: 수동 입력
  final int? completedDonationIdx;
  final DateTime createdAt;

  DonationHistory({
    required this.historyIdx,
    required this.petIdx,
    required this.donationDate,
    this.hospitalName,
    this.bloodVolumeMl,
    this.notes,
    required this.isSystemRecord,
    this.completedDonationIdx,
    required this.createdAt,
  });

  factory DonationHistory.fromJson(Map<String, dynamic> json) {
    return DonationHistory(
      historyIdx: json['history_idx'],
      petIdx: json['pet_idx'],
      donationDate: DateTime.parse(json['donation_date']),
      hospitalName: json['hospital_name'],
      bloodVolumeMl: json['blood_volume_ml'],
      notes: json['notes'],
      isSystemRecord: json['is_system_record'] ?? false,
      completedDonationIdx: json['completed_donation_idx'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'history_idx': historyIdx,
      'pet_idx': petIdx,
      'donation_date': donationDate.toIso8601String().split('T')[0],
      'hospital_name': hospitalName,
      'blood_volume_ml': bloodVolumeMl,
      'notes': notes,
      'is_system_record': isSystemRecord,
      'completed_donation_idx': completedDonationIdx,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// 수정/삭제 가능 여부 (수동 입력만 가능)
  bool get canEdit => !isSystemRecord;
  bool get canDelete => !isSystemRecord;

  /// 헌혈량 표시 텍스트
  String get bloodVolumeText => bloodVolumeMl != null ? '${bloodVolumeMl}ml' : '';

  /// 날짜 표시 텍스트
  String get dateText {
    return '${donationDate.year}.${donationDate.month.toString().padLeft(2, '0')}.${donationDate.day.toString().padLeft(2, '0')}';
  }
}

/// 헌혈 이력 조회 응답 (페이지네이션 포함)
class DonationHistoryResponse {
  final int petIdx;
  final String petName;
  final int page;
  final int limit;
  final int totalPages;
  final int totalCount;
  final int systemRecordCount;
  final int manualRecordCount;
  final int? totalBloodVolumeMl;
  final DateTime? firstDonationDate;
  final DateTime? lastDonationDate;
  final List<DonationHistory> histories;

  DonationHistoryResponse({
    required this.petIdx,
    required this.petName,
    required this.page,
    required this.limit,
    required this.totalPages,
    required this.totalCount,
    required this.systemRecordCount,
    required this.manualRecordCount,
    this.totalBloodVolumeMl,
    this.firstDonationDate,
    this.lastDonationDate,
    required this.histories,
  });

  factory DonationHistoryResponse.fromJson(Map<String, dynamic> json) {
    return DonationHistoryResponse(
      petIdx: json['pet_idx'],
      petName: json['pet_name'] ?? '',
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 10,
      totalPages: json['total_pages'] ?? 1,
      totalCount: json['total_count'] ?? 0,
      systemRecordCount: json['system_record_count'] ?? 0,
      manualRecordCount: json['manual_record_count'] ?? 0,
      totalBloodVolumeMl: json['total_blood_volume_ml'],
      firstDonationDate: json['first_donation_date'] != null
          ? DateTime.parse(json['first_donation_date'])
          : null,
      lastDonationDate: json['last_donation_date'] != null
          ? DateTime.parse(json['last_donation_date'])
          : null,
      histories: (json['histories'] as List<dynamic>?)
              ?.map((e) => DonationHistory.fromJson(e))
              .toList() ??
          [],
    );
  }

  /// 이력이 있는지 여부
  bool get hasHistory => totalCount > 0;

  /// 다음 페이지 존재 여부
  bool get hasNextPage => page < totalPages;

  /// 이전 페이지 존재 여부
  bool get hasPrevPage => page > 1;

  /// 총 헌혈량 표시 텍스트
  String get totalBloodVolumeText =>
      totalBloodVolumeMl != null ? '${totalBloodVolumeMl}ml' : '-';

  /// 첫 헌혈일 표시 텍스트
  String get firstDonationDateText {
    if (firstDonationDate == null) return '-';
    return '${firstDonationDate!.year}.${firstDonationDate!.month.toString().padLeft(2, '0')}.${firstDonationDate!.day.toString().padLeft(2, '0')}';
  }

  /// 마지막 헌혈일 표시 텍스트
  String get lastDonationDateText {
    if (lastDonationDate == null) return '-';
    return '${lastDonationDate!.year}.${lastDonationDate!.month.toString().padLeft(2, '0')}.${lastDonationDate!.day.toString().padLeft(2, '0')}';
  }
}

/// 헌혈 이력 추가 요청 데이터
class DonationHistoryCreateRequest {
  final String donationDate; // YYYY-MM-DD 형식
  final String? hospitalName;
  final int? bloodVolumeMl;
  final String? notes;

  DonationHistoryCreateRequest({
    required this.donationDate,
    this.hospitalName,
    this.bloodVolumeMl,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'donation_date': donationDate,
    };
    if (hospitalName != null && hospitalName!.isNotEmpty) {
      map['hospital_name'] = hospitalName;
    }
    if (bloodVolumeMl != null) {
      map['blood_volume_ml'] = bloodVolumeMl;
    }
    if (notes != null && notes!.isNotEmpty) {
      map['notes'] = notes;
    }
    return map;
  }
}

/// 헌혈 이력 수정 요청 데이터
class DonationHistoryUpdateRequest {
  final String? donationDate;
  final String? hospitalName;
  final int? bloodVolumeMl;
  final String? notes;

  DonationHistoryUpdateRequest({
    this.donationDate,
    this.hospitalName,
    this.bloodVolumeMl,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (donationDate != null) {
      map['donation_date'] = donationDate;
    }
    if (hospitalName != null) {
      map['hospital_name'] = hospitalName;
    }
    if (bloodVolumeMl != null) {
      map['blood_volume_ml'] = bloodVolumeMl;
    }
    if (notes != null) {
      map['notes'] = notes;
    }
    return map;
  }
}
