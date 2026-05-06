// models/pet_model.dart

class Pet {
  final int? petIdx; // pet_id → pet_idx로 변경
  final int? accountIdx; // guardian_idx → account_idx로 변경
  final String ownerEmail; // 보호자 이메일 (이메일 기반 관계로 변경)
  final String name;
  final String species;
  final int? animalType; // 0=강아지, 1=고양이
  final String? breed;
  final DateTime? birthDate; // 생년월일
  final String? bloodType;
  final double weightKg;
  // 성별 (CLAUDE.md 데이터 타입 → 반려동물 성별): 0=암컷, 1=수컷. NOT NULL 보장.
  final int sex;
  // 임신/출산 상태 (CLAUDE.md 데이터 타입 → 임신/출산 상태): 0=해당없음, 1=임신중, 2=출산이력. NOT NULL, default 0.
  final int pregnancyBirthStatus;
  // 출산 종료일. status=2일 때만 값 존재. status=1/0이면 NULL.
  final DateTime? lastPregnancyEndDate;
  final bool? vaccinated; // 백신 접종 여부 (DB에서 NULL 허용)
  final bool? hasDisease; // 질병 이력 여부 (DB에서 NULL 허용)
  // 헌혈 일자는 컬럼 분리됨 (2026-05 PR-1):
  // - prev_donation_date_system: 시스템 자동 갱신 (admin 최종 승인 시). 사용자 PUT 차단.
  // - prior_last_donation_date: 사용자 자기신고 (외부 헌혈). 사용자 입력 가능.
  // 자격 검증/표시는 effectiveLastDonationDate getter (max) 사용.
  final DateTime? prevDonationDateSystem;
  final DateTime? priorLastDonationDate;
  final int priorDonationCount; // 외부 헌혈 누적 횟수 (사용자 입력, default 0, NOT NULL)
  // 카페 정책 의료 정보 (2026-05 PR-1)
  final DateTime? lastVaccinationDate; // 종합백신 접종일
  final DateTime? lastAntibodyTestDate; // 항체검사 일자
  final DateTime? lastPreventiveMedicationDate; // 예방약 복용일
  final bool? isNeutered; // 중성화 수술 여부
  final DateTime? neuteredDate; // 중성화 수술 일자
  final bool? hasPreventiveMedication; // 예방약 복용 여부
  final bool isPrimary; // 대표 반려동물 여부
  final int approvalStatus; // 0=승인대기, 1=헌혈가능, 2=헌혈불가
  final String? rejectionReason; // 거절 사유
  final bool isReview; // 재심사 여부
  final String? profileImage; // 프로필 사진 경로 (검토 통과한 사진)

  // 프로필 사진 검토 워크플로우 (2026-04 신규)
  // APPROVED 펫의 사진 변경 시에만 사용. PENDING/REJECTED 펫은 즉시 반영되어 사용 안 함.
  final String? pendingProfileImage; // 검토 대기 중인 신규 사진 경로
  final int? pendingImageStatus; // null=없음, 0=대기. 거절 시 즉시 정리되어 2는 거의 안 옴
  final String? pendingImageRejectionReason; // 거절 시 즉시 NULL로 정리되어 거의 안 옴 (사유는 푸시 body)

  Pet({
    this.petIdx,
    this.accountIdx,
    required this.ownerEmail,
    required this.name,
    required this.species,
    this.animalType,
    this.breed,
    this.birthDate,
    this.bloodType,
    required this.weightKg,
    required this.sex,
    this.pregnancyBirthStatus = 0,
    this.lastPregnancyEndDate,
    this.vaccinated,
    this.hasDisease,
    this.prevDonationDateSystem,
    this.priorLastDonationDate,
    this.priorDonationCount = 0,
    this.lastVaccinationDate,
    this.lastAntibodyTestDate,
    this.lastPreventiveMedicationDate,
    this.isNeutered,
    this.neuteredDate,
    this.hasPreventiveMedication,
    this.isPrimary = false,
    this.approvalStatus = 0,
    this.rejectionReason,
    this.isReview = false,
    this.profileImage,
    this.pendingProfileImage,
    this.pendingImageStatus,
    this.pendingImageRejectionReason,
  });

  // 나이를 문자열로 반환하는 getter (birthDate 기반 계산)
  String get age {
    if (birthDate == null) return '나이 미상';
    final now = DateTime.now();
    final totalMonths = (now.year - birthDate!.year) * 12 + (now.month - birthDate!.month);
    if (totalMonths < 0) return '나이 미상';
    if (totalMonths < 12) return '$totalMonths개월';
    return '${totalMonths ~/ 12}살';
  }

  // 나이를 개월 수로 반환 (헌혈 자격 검증용)
  int? get ageInMonths {
    if (birthDate == null) return null;
    final now = DateTime.now();
    return (now.year - birthDate!.year) * 12 + (now.month - birthDate!.month);
  }

  // 생년월일 + 나이 표시 (예: "2023.03.20 (3살)")
  String get birthDateWithAge {
    if (birthDate == null) return '나이 미상';
    final dateStr = '${birthDate!.year}.${birthDate!.month.toString().padLeft(2, '0')}.${birthDate!.day.toString().padLeft(2, '0')}';
    return '$dateStr ($age)';
  }

  // 1줄 요약: 종 • 품종 • 혈액형 • 나이 • 체중
  String get summaryLine {
    final parts = <String>[species];
    if (breed != null && breed!.isNotEmpty) parts.add(breed!);
    if (bloodType != null) parts.add(bloodType!);
    parts.add(age);
    parts.add('${weightKg}kg');
    return parts.join(' • ');
  }

  factory Pet.fromJson(Map<String, dynamic> json) {
    // weight_kg 안전하게 파싱
    double parseWeight(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return Pet(
      petIdx: json['pet_idx'] ?? json['pet_id'], // 하위 호환성 지원
      accountIdx: json['account_idx'] ?? json['guardian_idx'], // 하위 호환성 지원
      ownerEmail: json['owner_email'] ?? '',
      name: json['name'] ?? '',
      species: json['species'] ?? '',
      animalType: json['animal_type'], // 0=강아지, 1=고양이
      breed: json['breed'],
      birthDate: json['birth_date'] != null
          ? DateTime.tryParse(json['birth_date'])
          : null,
      bloodType: json['blood_type'],
      weightKg: parseWeight(json['weight_kg']),
      // sex/pregnancy_birth_status는 백엔드 NOT NULL 보장 (CLAUDE.md Pet contract).
      // 다만 폼 미전송 단계에서 받을 수도 있어 안전 기본값 (수컷/해당없음).
      sex: json['sex'] is int ? json['sex'] as int : 1,
      pregnancyBirthStatus: json['pregnancy_birth_status'] is int
          ? json['pregnancy_birth_status'] as int
          : 0,
      lastPregnancyEndDate: json['last_pregnancy_end_date'] != null
          ? DateTime.tryParse(json['last_pregnancy_end_date'])
          : null,
      vaccinated:
          json['vaccinated'] == null
              ? null
              : (json['vaccinated'] == 1 || json['vaccinated'] == true),
      hasDisease:
          json['has_disease'] == null
              ? null
              : (json['has_disease'] == 1 || json['has_disease'] == true),
      // 헌혈 일자 컬럼 분리 (2026-05 PR-1)
      prevDonationDateSystem: json['prev_donation_date_system'] != null
          ? DateTime.tryParse(json['prev_donation_date_system'])
          : null,
      priorLastDonationDate: json['prior_last_donation_date'] != null
          ? DateTime.tryParse(json['prior_last_donation_date'])
          : null,
      priorDonationCount: json['prior_donation_count'] is int
          ? json['prior_donation_count'] as int
          : 0,
      lastVaccinationDate: json['last_vaccination_date'] != null
          ? DateTime.tryParse(json['last_vaccination_date'])
          : null,
      lastAntibodyTestDate: json['last_antibody_test_date'] != null
          ? DateTime.tryParse(json['last_antibody_test_date'])
          : null,
      lastPreventiveMedicationDate:
          json['last_preventive_medication_date'] != null
              ? DateTime.tryParse(json['last_preventive_medication_date'])
              : null,
      isNeutered:
          json['is_neutered'] == null
              ? null
              : (json['is_neutered'] == 1 || json['is_neutered'] == true),
      neuteredDate:
          json['neutered_date'] != null
              ? DateTime.tryParse(json['neutered_date'])
              : null,
      hasPreventiveMedication:
          json['has_preventive_medication'] == null
              ? null
              : (json['has_preventive_medication'] == 1 ||
                  json['has_preventive_medication'] == true),
      isPrimary: json['is_primary'] == true || json['is_primary'] == 1,
      approvalStatus: json['approval_status'] ?? 0,
      rejectionReason: json['rejection_reason'],
      isReview: json['is_review'] == true,
      profileImage: json['profile_image'],
      pendingProfileImage: json['pending_profile_image'],
      pendingImageStatus: json['pending_image_status'],
      pendingImageRejectionReason: json['pending_image_rejection_reason'],
    );
  }

  // 프로필 사진이 관리자 검토 대기 중인지 여부
  bool get hasPendingProfileImage =>
      pendingProfileImage != null && pendingImageStatus == 0;

  // 임신/출산 상태 헬퍼 (CLAUDE.md PregnancyBirthStatus 미러)
  bool get isPregnant => pregnancyBirthStatus == 1;
  bool get hasBirthHistory => pregnancyBirthStatus == 2;

  // API 통신을 위한 Map 변환
  Map<String, dynamic> toMap() {
    return {
      'pet_idx': petIdx,
      'account_idx': accountIdx,
      'owner_email': ownerEmail,
      'name': name,
      'species': species,
      'animal_type': animalType, // 0=강아지, 1=고양이
      'breed': breed,
      'birth_date': birthDate?.toIso8601String().split('T')[0],
      'blood_type': bloodType,
      'weight_kg': weightKg,
      'sex': sex,
      'pregnancy_birth_status': pregnancyBirthStatus,
      'last_pregnancy_end_date':
          lastPregnancyEndDate?.toIso8601String().split('T')[0],
      'vaccinated': vaccinated == null ? null : (vaccinated! ? 1 : 0),
      'has_disease': hasDisease == null ? null : (hasDisease! ? 1 : 0),
      // prev_donation_date_system은 시스템 자동 갱신 컬럼 (PUT 차단). toMap에서 제외.
      'prior_last_donation_date':
          priorLastDonationDate?.toIso8601String().split('T')[0],
      'prior_donation_count': priorDonationCount,
      'last_vaccination_date':
          lastVaccinationDate?.toIso8601String().split('T')[0],
      'last_antibody_test_date':
          lastAntibodyTestDate?.toIso8601String().split('T')[0],
      'last_preventive_medication_date':
          lastPreventiveMedicationDate?.toIso8601String().split('T')[0],
      'is_neutered': isNeutered == null ? null : (isNeutered! ? 1 : 0),
      'neutered_date': neuteredDate?.toIso8601String().split('T')[0],
      'has_preventive_medication':
          hasPreventiveMedication == null
              ? null
              : (hasPreventiveMedication! ? 1 : 0),
      'is_primary': isPrimary ? 1 : 0,
      'profile_image': profileImage,
    };
  }

  /// 자격 검증/표시용 마지막 헌혈일 — `max(prev_donation_date_system, prior_last_donation_date)`.
  ///
  /// 백엔드 `utils/pet_helpers.py::get_effective_last_donation_date()` 미러.
  /// 컬럼 분리 정책 (2026-05 PR-1):
  /// - 시스템 자동 갱신값(`prevDonationDateSystem`)과 사용자 자기신고(`priorLastDonationDate`)
  ///   둘 다 후보. 더 늦은 날짜를 채택해 우회 시나리오 차단.
  DateTime? get effectiveLastDonationDate {
    if (prevDonationDateSystem == null) return priorLastDonationDate;
    if (priorLastDonationDate == null) return prevDonationDateSystem;
    return prevDonationDateSystem!.isAfter(priorLastDonationDate!)
        ? prevDonationDateSystem
        : priorLastDonationDate;
  }

  // 헌혈 가능 여부 판단 (6개월 간격, 백엔드 동기화 2026-04-29)
  bool get canDonate {
    final lastDate = effectiveLastDonationDate;
    if (lastDate == null) return true; // 첫 헌혈

    final now = DateTime.now();
    final daysSince = now.difference(lastDate).inDays;

    return daysSince >= 180; // 6개월(180일) 이상 경과
  }

  // 다음 헌혈 가능일
  DateTime? get nextDonationDate {
    final lastDate = effectiveLastDonationDate;
    if (lastDate == null) return null; // 첫 헌혈인 경우

    return lastDate.add(const Duration(days: 180));
  }

  // 헌혈 상태 텍스트
  String get donationStatusText {
    if (effectiveLastDonationDate == null) {
      return '첫 헌혈 예정';
    }

    if (canDonate) {
      return '헌혈 가능';
    } else {
      final nextDate = nextDonationDate!;
      final remainingDays = nextDate.difference(DateTime.now()).inDays;
      return '헌혈 대기 중 ($remainingDays일 후 가능)';
    }
  }

  // 승인 상태 텍스트
  String get approvalStatusText {
    switch (approvalStatus) {
      case 0:
        return '승인 대기';
      case 1:
        return '헌혈 가능';
      case 2:
        return '헌혈 불가';
      default:
        return '알 수 없음';
    }
  }

  // 승인 완료 여부
  bool get isApproved => approvalStatus == 1;

  // 반려동물 정보 표시용 getter (이름 + 1줄 요약)
  String get displayInfo {
    return '$name ($summaryLine)';
  }
}
