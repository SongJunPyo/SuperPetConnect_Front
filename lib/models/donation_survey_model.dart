// lib/models/donation_survey_model.dart
//
// 헌혈 사전 정보 설문 모델 (2026-05 PR-2).
// 백엔드 GET .../survey/template + POST/PATCH/GET .../survey 응답/요청 페이로드.

import 'applicant_model.dart' show ApplicantPetInfo;
import 'donation_consent_model.dart';

/// 백엔드가 Decimal 컬럼을 `"40.00"` 같은 String으로 직렬화하는 경우가 있어
/// num과 String 양쪽을 모두 수용. 잘못된 형식은 null로 반환.
double? _parseNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

/// `GET /api/applied-donations/{id}/survey/template` 응답.
///
/// 설문 작성 화면 진입 시 호출 → 폼 자동 채움 데이터.
/// 펫/계정 정보는 자동 채움 + 수정 가능 (수정 시 별도 PUT API 호출).
/// 일정/병원 정보는 자동 채움 + 잠금.
class DonationSurveyTemplate {
  // ===== 일정 (잠금) =====
  final String donationDate; // YYYY-MM-DD
  final String donationTime; // HH:MM
  final String hospitalName;
  final String hospitalCode;
  final int postType; // 0=긴급, 1=정기

  // ===== 펫/계정 (자동 채움 + 수정 가능) =====
  final String petName;
  final String? petBreed;
  final int petSex; // 0=암컷, 1=수컷
  final String? petBirthDate; // YYYY-MM-DD
  final String? petBloodType;
  final double? petWeightKg;
  final bool? petIsNeutered;
  final String? petNeuteredDate; // YYYY-MM-DD
  final int petPregnancyBirthStatus; // 0/1/2
  final String? petLastPregnancyEndDate;
  final String ownerName;
  final String? ownerPhoneNumber;
  final String? ownerAddress;

  // ===== 의료 정보 (카페 정책, F-B에서 입력) =====
  final String? lastVaccinationDate;
  final String? lastAntibodyTestDate;
  final String? lastPreventiveMedicationDate;

  // ===== 직전 외부 헌혈 (출처별 분기) =====
  /// "system" / "external" / "none" — `AppConstants.prevDonationSource*` 상수 참조.
  final String prevDonationSource;
  /// 시스템 헌혈 이력 누적 (자동 카운트 + 사용자 자기신고 합산).
  final int totalDonationCount;
  /// effective last donation date — max(prev_donation_date_system, prior_last_donation_date).
  final String? effectiveLastDonationDate;
  /// system이면 자동 채움 (수정 불가), external/none이면 사용자 입력 필요.
  final String? prevDonationHospitalName;
  final double? prevBloodVolumeMl;

  const DonationSurveyTemplate({
    required this.donationDate,
    required this.donationTime,
    required this.hospitalName,
    required this.hospitalCode,
    required this.postType,
    required this.petName,
    this.petBreed,
    required this.petSex,
    this.petBirthDate,
    this.petBloodType,
    this.petWeightKg,
    this.petIsNeutered,
    this.petNeuteredDate,
    required this.petPregnancyBirthStatus,
    this.petLastPregnancyEndDate,
    required this.ownerName,
    this.ownerPhoneNumber,
    this.ownerAddress,
    this.lastVaccinationDate,
    this.lastAntibodyTestDate,
    this.lastPreventiveMedicationDate,
    required this.prevDonationSource,
    required this.totalDonationCount,
    this.effectiveLastDonationDate,
    this.prevDonationHospitalName,
    this.prevBloodVolumeMl,
  });

  factory DonationSurveyTemplate.fromJson(Map<String, dynamic> json) {
    return DonationSurveyTemplate(
      donationDate: json['donation_date'] as String,
      donationTime: json['donation_time'] as String,
      hospitalName: json['hospital_name'] as String,
      hospitalCode: json['hospital_code'] as String,
      postType: json['post_type'] as int,
      petName: json['pet_name'] as String,
      petBreed: json['pet_breed'] as String?,
      petSex: json['pet_sex'] as int,
      petBirthDate: json['pet_birth_date'] as String?,
      petBloodType: json['pet_blood_type'] as String?,
      petWeightKg: _parseNullableDouble(json['pet_weight_kg']),
      petIsNeutered: json['pet_is_neutered'] as bool?,
      petNeuteredDate: json['pet_neutered_date'] as String?,
      petPregnancyBirthStatus: json['pet_pregnancy_birth_status'] as int,
      petLastPregnancyEndDate: json['pet_last_pregnancy_end_date'] as String?,
      ownerName: json['owner_name'] as String,
      ownerPhoneNumber: json['owner_phone_number'] as String?,
      ownerAddress: json['owner_address'] as String?,
      lastVaccinationDate: json['last_vaccination_date'] as String?,
      lastAntibodyTestDate: json['last_antibody_test_date'] as String?,
      lastPreventiveMedicationDate:
          json['last_preventive_medication_date'] as String?,
      prevDonationSource: json['prev_donation_source'] as String,
      totalDonationCount: json['total_donation_count'] as int,
      effectiveLastDonationDate:
          json['effective_last_donation_date'] as String?,
      prevDonationHospitalName: json['prev_donation_hospital_name'] as String?,
      prevBloodVolumeMl: _parseNullableDouble(json['prev_blood_volume_ml']),
    );
  }
}

/// `POST/PATCH .../survey` 요청 페이로드.
///
/// PATCH는 모든 필드 optional (exclude_unset 동작). POST는 NOT NULL 4 필드 필수.
/// 사용자가 입력하는 폼 24필드 모두 매핑.
class DonationSurveyPayload {
  // ===== 시점 스냅샷 =====
  final double? weightKgSnapshot;

  // ===== 텍스트 4 (NOT NULL × 3 + nullable × 1) =====
  final String? hospitalChoiceReason; // 카페 5번 — 필수
  final String? medicalHistory; // 카페 19번 — 필수
  final String? preventiveMedicationDetail; // 카페 20번 — 필수
  final String? hospitalSpecialNote; // 카페 22번 — 선택

  // ===== 펫 시점성 2 (NOT NULL × 2) =====
  final String? personality; // 카페 12번
  final int? livingEnvironment; // 0=실내, 1=실외, 카페 13번

  // ===== 기타 3 =====
  final String? snsAccount; // 카페 23번
  final int? companionPetCount; // 카페 24번
  final String? lastMenstruationDate; // 카페 14-2번 (암컷만)

  // ===== 직전 외부 헌혈 6 (모두 nullable) =====
  final String? prevDonationHospitalName;
  final double? prevBloodVolumeMl;
  final bool? prevSedationUsed;
  final bool? prevOwnerObserved;
  final int? prevBloodCollectionSite; // BloodCollectionSite enum
  final String? prevBloodCollectionSiteEtc;

  // ===== 동의 5개 (POST 시 모두 true 필수) =====
  final DonationConsentPayload? consent;

  const DonationSurveyPayload({
    this.weightKgSnapshot,
    this.hospitalChoiceReason,
    this.medicalHistory,
    this.preventiveMedicationDetail,
    this.hospitalSpecialNote,
    this.personality,
    this.livingEnvironment,
    this.snsAccount,
    this.companionPetCount,
    this.lastMenstruationDate,
    this.prevDonationHospitalName,
    this.prevBloodVolumeMl,
    this.prevSedationUsed,
    this.prevOwnerObserved,
    this.prevBloodCollectionSite,
    this.prevBloodCollectionSiteEtc,
    this.consent,
  });

  /// PATCH용 — null 필드는 본문에서 제외 (백엔드 exclude_unset 동작 준수).
  /// POST에도 동일 본문 사용 가능 (NOT NULL 필드를 호출 측에서 보장).
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    void add(String key, Object? value) {
      if (value != null) map[key] = value;
    }

    add('weight_kg_snapshot', weightKgSnapshot);
    add('hospital_choice_reason', hospitalChoiceReason);
    add('medical_history', medicalHistory);
    add('preventive_medication_detail', preventiveMedicationDetail);
    add('hospital_special_note', hospitalSpecialNote);
    add('personality', personality);
    add('living_environment', livingEnvironment);
    add('sns_account', snsAccount);
    add('companion_pet_count', companionPetCount);
    add('last_menstruation_date', lastMenstruationDate);
    add('prev_donation_hospital_name', prevDonationHospitalName);
    add('prev_blood_volume_ml', prevBloodVolumeMl);
    add('prev_sedation_used', prevSedationUsed);
    add('prev_owner_observed', prevOwnerObserved);
    add('prev_blood_collection_site', prevBloodCollectionSite);
    add('prev_blood_collection_site_etc', prevBloodCollectionSiteEtc);
    if (consent != null) {
      map['consent'] = consent!.toJson();
    }
    return map;
  }
}

/// `GET/POST/PATCH .../survey` 응답.
///
/// 저장된 설문 본문 + 메타. 잠금 상태(`lockedAt != null`) 시 read-only.
class DonationSurveyResponse {
  final int surveyIdx;
  final int appliedDonationIdx;
  final double? weightKgSnapshot;

  // 텍스트 4
  final String hospitalChoiceReason;
  final String medicalHistory;
  final String preventiveMedicationDetail;
  final String? hospitalSpecialNote;

  // 펫 시점성 2
  final String personality;
  final int livingEnvironment;

  // 기타 3
  final String? snsAccount;
  final int companionPetCount;
  final String? lastMenstruationDate;

  // 직전 외부 헌혈 6
  final String? prevDonationHospitalName;
  final double? prevBloodVolumeMl;
  final bool? prevSedationUsed;
  final bool? prevOwnerObserved;
  final int? prevBloodCollectionSite;
  final String? prevBloodCollectionSiteEtc;

  // 검토 추적
  final String? adminReviewedAt; // ISO datetime
  final int? adminReviewedBy;

  // 잠금/타임스탬프
  /// 헌혈 D-2 23:55 이후 채워짐. 채워지면 PATCH 차단 (read-only).
  final String? lockedAt;
  final String submittedAt;
  final String updatedAt;

  /// 펫 메타데이터 — 백엔드 `GET /api/hospital/donation-surveys/{idx}` 옵션 A로 추가
  /// (2026-05-08 round 4). admin endpoint 응답에는 없을 수 있음 (nullable).
  /// 의료진이 설문 답변과 펫 의료 정보를 한 화면에서 교차 검증할 때 사용.
  final ApplicantPetInfo? petInfo;

  const DonationSurveyResponse({
    required this.surveyIdx,
    required this.appliedDonationIdx,
    this.weightKgSnapshot,
    required this.hospitalChoiceReason,
    required this.medicalHistory,
    required this.preventiveMedicationDetail,
    this.hospitalSpecialNote,
    required this.personality,
    required this.livingEnvironment,
    this.snsAccount,
    required this.companionPetCount,
    this.lastMenstruationDate,
    this.prevDonationHospitalName,
    this.prevBloodVolumeMl,
    this.prevSedationUsed,
    this.prevOwnerObserved,
    this.prevBloodCollectionSite,
    this.prevBloodCollectionSiteEtc,
    this.adminReviewedAt,
    this.adminReviewedBy,
    this.lockedAt,
    required this.submittedAt,
    required this.updatedAt,
    this.petInfo,
  });

  factory DonationSurveyResponse.fromJson(Map<String, dynamic> json) {
    return DonationSurveyResponse(
      surveyIdx: json['survey_idx'] as int,
      appliedDonationIdx: json['applied_donation_idx'] as int,
      weightKgSnapshot: _parseNullableDouble(json['weight_kg_snapshot']),
      hospitalChoiceReason: json['hospital_choice_reason'] as String,
      medicalHistory: json['medical_history'] as String,
      preventiveMedicationDetail: json['preventive_medication_detail'] as String,
      hospitalSpecialNote: json['hospital_special_note'] as String?,
      personality: json['personality'] as String,
      livingEnvironment: json['living_environment'] as int,
      snsAccount: json['sns_account'] as String?,
      companionPetCount: json['companion_pet_count'] as int,
      lastMenstruationDate: json['last_menstruation_date'] as String?,
      prevDonationHospitalName: json['prev_donation_hospital_name'] as String?,
      prevBloodVolumeMl: _parseNullableDouble(json['prev_blood_volume_ml']),
      prevSedationUsed: json['prev_sedation_used'] as bool?,
      prevOwnerObserved: json['prev_owner_observed'] as bool?,
      prevBloodCollectionSite: json['prev_blood_collection_site'] as int?,
      prevBloodCollectionSiteEtc:
          json['prev_blood_collection_site_etc'] as String?,
      adminReviewedAt: json['admin_reviewed_at'] as String?,
      adminReviewedBy: json['admin_reviewed_by'] as int?,
      lockedAt: json['locked_at'] as String?,
      submittedAt: json['submitted_at'] as String,
      updatedAt: json['updated_at'] as String,
      petInfo: json['pet_info'] is Map<String, dynamic>
          ? ApplicantPetInfo.fromJson(json['pet_info'] as Map<String, dynamic>)
          : null,
    );
  }

  /// 잠금 여부 — true이면 PATCH 차단, GET만 가능.
  bool get isLocked => lockedAt != null;

  /// 관리자가 검토했는지 여부 — 옵션 a 자동 PATCH로 첫 GET 시 NOW로 채워짐.
  /// false면 "검토 대기" 배지 노출.
  bool get isReviewed => adminReviewedAt != null;
}

/// `GET /api/admin/donation-surveys` 목록 응답의 단건 아이템.
///
/// 백엔드가 list 효율성을 위해 본문 텍스트 4 + 동의 5 등은 제외하고 메타 위주로 반환.
/// 상세는 `adminDonationSurvey(surveyIdx)` 단건 GET으로 별도 조회 (옵션 a 자동 PATCH).
class DonationSurveyListItem {
  final int surveyIdx;
  final int appliedDonationIdx;
  final int postIdx;
  final String postTitle;
  final String hospitalName;
  final String donationDate; // YYYY-MM-DD
  final String donationTime; // HH:MM
  final String petName;
  final String? ownerName;
  /// `applied_donation.status` (0~4). PR-3 contract: 0=PENDING / 1=APPROVED 등.
  final int applicationStatus;
  /// null이면 검토 대기 (배지). 옵션 A+C로 admin 열람 후 사용자 재제출 시 NULL 복귀.
  final String? adminReviewedAt;
  /// D-2 23:55 이후 채워짐 — 잠금 표시용.
  final String? lockedAt;
  final String submittedAt;
  final String updatedAt;

  const DonationSurveyListItem({
    required this.surveyIdx,
    required this.appliedDonationIdx,
    required this.postIdx,
    required this.postTitle,
    required this.hospitalName,
    required this.donationDate,
    required this.donationTime,
    required this.petName,
    this.ownerName,
    required this.applicationStatus,
    this.adminReviewedAt,
    this.lockedAt,
    required this.submittedAt,
    required this.updatedAt,
  });

  factory DonationSurveyListItem.fromJson(Map<String, dynamic> json) {
    return DonationSurveyListItem(
      surveyIdx: json['survey_idx'] as int,
      appliedDonationIdx: json['applied_donation_idx'] as int,
      postIdx: json['post_idx'] as int,
      postTitle: (json['post_title'] ?? '') as String,
      hospitalName: (json['hospital_name'] ?? '') as String,
      donationDate: (json['donation_date'] ?? '') as String,
      donationTime: (json['donation_time'] ?? '') as String,
      petName: (json['pet_name'] ?? '') as String,
      ownerName: json['owner_name'] as String?,
      applicationStatus: (json['application_status'] as num?)?.toInt() ?? 0,
      adminReviewedAt: json['admin_reviewed_at'] as String?,
      lockedAt: json['locked_at'] as String?,
      submittedAt: (json['submitted_at'] ?? '') as String,
      updatedAt: (json['updated_at'] ?? '') as String,
    );
  }

  bool get isReviewed => adminReviewedAt != null;
  bool get isLocked => lockedAt != null;
}

/// `GET /api/admin/donation-surveys` 응답.
class DonationSurveyListResponse {
  final List<DonationSurveyListItem> items;
  final int totalCount;
  /// `admin_reviewed_at IS NULL` 전역 카운트 (필터 무관, 배지용).
  final int pendingCount;
  final int page;
  final int pageSize;

  const DonationSurveyListResponse({
    required this.items,
    required this.totalCount,
    required this.pendingCount,
    required this.page,
    required this.pageSize,
  });

  factory DonationSurveyListResponse.fromJson(Map<String, dynamic> json) {
    return DonationSurveyListResponse(
      items: ((json['items'] as List<dynamic>?) ?? [])
          .map((e) =>
              DonationSurveyListItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
      pendingCount: (json['pending_count'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? 20,
    );
  }
}

/// 관리자 설문 목록 필터 (정렬/페이지네이션 포함).
class AdminSurveyListFilter {
  /// "pending" / "reviewed" / "all" — null이면 전체.
  final String? reviewStatus;
  final int? postIdx;
  final String? hospitalCode;
  /// YYYY-MM-DD
  final String? donationDateFrom;
  final String? donationDateTo;
  /// applied_donation.status 값.
  final int? applicationStatus;
  /// "submitted_at_desc" / "submitted_at_asc" / "donation_date_asc" / "donation_date_desc"
  final String? sort;
  final int page;
  final int pageSize;

  const AdminSurveyListFilter({
    this.reviewStatus,
    this.postIdx,
    this.hospitalCode,
    this.donationDateFrom,
    this.donationDateTo,
    this.applicationStatus,
    this.sort,
    this.page = 1,
    this.pageSize = 20,
  });

  /// query string 파라미터로 변환. null 필드는 제외.
  Map<String, String> toQueryParameters() {
    final map = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (reviewStatus != null) map['review_status'] = reviewStatus!;
    if (postIdx != null) map['post_idx'] = postIdx.toString();
    if (hospitalCode != null) map['hospital_code'] = hospitalCode!;
    if (donationDateFrom != null) {
      map['donation_date_from'] = donationDateFrom!;
    }
    if (donationDateTo != null) map['donation_date_to'] = donationDateTo!;
    if (applicationStatus != null) {
      map['application_status'] = applicationStatus.toString();
    }
    if (sort != null) map['sort'] = sort!;
    return map;
  }

  AdminSurveyListFilter copyWith({
    String? reviewStatus,
    bool clearReviewStatus = false,
    int? postIdx,
    bool clearPostIdx = false,
    String? hospitalCode,
    bool clearHospitalCode = false,
    String? donationDateFrom,
    bool clearDonationDateFrom = false,
    String? donationDateTo,
    bool clearDonationDateTo = false,
    int? applicationStatus,
    bool clearApplicationStatus = false,
    String? sort,
    int? page,
    int? pageSize,
  }) {
    return AdminSurveyListFilter(
      reviewStatus:
          clearReviewStatus ? null : (reviewStatus ?? this.reviewStatus),
      postIdx: clearPostIdx ? null : (postIdx ?? this.postIdx),
      hospitalCode:
          clearHospitalCode ? null : (hospitalCode ?? this.hospitalCode),
      donationDateFrom: clearDonationDateFrom
          ? null
          : (donationDateFrom ?? this.donationDateFrom),
      donationDateTo: clearDonationDateTo
          ? null
          : (donationDateTo ?? this.donationDateTo),
      applicationStatus: clearApplicationStatus
          ? null
          : (applicationStatus ?? this.applicationStatus),
      sort: sort ?? this.sort,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }
}
