// lib/utils/donation_eligibility.dart
// 헌혈 자격 조건 설정 및 검증 로직
// 유지보수 시 이 파일의 조건 값만 수정하면 전체 앱에 적용됩니다.
//
// 백엔드 services/donation_eligibility_service.py와 1:1 동기화 필요.
// CLAUDE.md "Pet 모델 / 헌혈 자격 검증 contract" 섹션 참조.

import '../models/pet_model.dart';

/// 헌혈 자격 거부 사유 키 (백엔드 constants/donation_eligibility.py::EligibilityReason 미러).
/// `pregnancyBirth` condition에만 부여되는 reason 값.
class EligibilityReason {
  EligibilityReason._();
  static const String pregnant = 'pregnant'; // 현재 임신중 (status=1)
  static const String cooldown = 'cooldown'; // 출산 12개월 미경과
  static const String dateMissing = 'date_missing'; // status=2인데 종료일 NULL
}

/// 헌혈 자격 상태
enum EligibilityStatus {
  eligible, // 헌혈 가능
  needsConsultation, // 협의 필요 (체중 등)
  ineligible, // 헌혈 불가
  unknown, // 정보 부족 (생년월일 미입력 등)
}

/// 개별 조건 검증 결과
class ConditionResult {
  final String conditionName; // 조건 이름
  final String description; // 조건 설명
  final EligibilityStatus status;
  final String? message; // 상세 메시지
  /// 거부 사유 키. `pregnancyBirth` 조건에서만 부여 (백엔드 wire format 미러).
  /// CLAUDE.md "헌혈 자격 거부 사유" 섹션 참조.
  final String? reason;

  const ConditionResult({
    required this.conditionName,
    required this.description,
    required this.status,
    this.message,
    this.reason,
  });

  bool get isPassed => status == EligibilityStatus.eligible;
  bool get needsConsultation => status == EligibilityStatus.needsConsultation;
  bool get isFailed => status == EligibilityStatus.ineligible;
}

/// 전체 헌혈 자격 검증 결과
class EligibilityResult {
  final EligibilityStatus overallStatus;
  final List<ConditionResult> allConditions;
  final String summaryMessage;

  const EligibilityResult({
    required this.overallStatus,
    required this.allConditions,
    required this.summaryMessage,
  });

  /// 통과한 조건 목록
  List<ConditionResult> get passedConditions =>
      allConditions.where((c) => c.isPassed).toList();

  /// 실패한 조건 목록
  List<ConditionResult> get failedConditions =>
      allConditions.where((c) => c.isFailed).toList();

  /// 협의 필요 조건 목록
  List<ConditionResult> get consultConditions =>
      allConditions.where((c) => c.needsConsultation).toList();

  /// 헌혈 가능 여부
  bool get isEligible => overallStatus == EligibilityStatus.eligible;

  /// 협의 필요 여부
  bool get needsConsultation =>
      overallStatus == EligibilityStatus.needsConsultation;

  /// 헌혈 불가 여부
  bool get isIneligible => overallStatus == EligibilityStatus.ineligible;
}

// ============================================================================
// 강아지 헌혈 조건 설정
// ============================================================================
class DogEligibilityConditions {
  /// 최소 나이 (개월)
  final int minAgeMonths;

  /// 최소 나이 (년) - 표시용
  final int minAgeYears;

  /// 최대 나이 (년)
  final int maxAgeYears;

  /// 최소 체중 (kg) - 이 이상이면 헌혈 가능 (협의 zone 폐기, 단일 기준)
  final double minWeightKg;

  /// 중성화 수술 후 필요 경과 개월 수
  final int neuteredMonthsRequired;

  /// 임신/출산 후 쿨다운 (개월)
  final int pregnancyCooldownMonths;

  /// 헌혈 간격 (일)
  final int donationIntervalDays;

  const DogEligibilityConditions({
    this.minAgeMonths = 18,
    this.minAgeYears = 2,
    this.maxAgeYears = 8,
    this.minWeightKg = 20.0,
    this.neuteredMonthsRequired = 6,
    this.pregnancyCooldownMonths = 12,
    this.donationIntervalDays = 180,
  });

  /// 조건 요약 텍스트 (UI 표시용)
  String get summaryText => '''
• 나이: $minAgeYears세 ~ $maxAgeYears세 ($minAgeMonths개월 이상)
• 체중: ${minWeightKg}kg 이상
• 예방접종 완료
• 예방약 복용 완료
• 질병 이력 없음
• 임신/출산 이력 없음 (출산 후 $pregnancyCooldownMonths개월 경과 시 가능)
• 중성화 시 수술 후 $neuteredMonthsRequired개월 이후 (수술일 입력 필수)
• 이전 헌혈 후 6개월 이상 경과''';
}

// ============================================================================
// 고양이 헌혈 조건 설정
// ============================================================================
class CatEligibilityConditions {
  /// 최소 나이 (년)
  final int minAgeYears;

  /// 최대 나이 (년)
  final int maxAgeYears;

  /// 최소 체중 (kg)
  final double minWeightKg;

  /// 임신/출산 후 쿨다운 (개월)
  final int pregnancyCooldownMonths;

  /// 헌혈 간격 (일)
  final int donationIntervalDays;

  const CatEligibilityConditions({
    this.minAgeYears = 1,
    this.maxAgeYears = 8,
    this.minWeightKg = 4.0,
    this.pregnancyCooldownMonths = 12,
    this.donationIntervalDays = 180,
  });

  /// 조건 요약 텍스트 (UI 표시용)
  String get summaryText => '''
• 나이: $minAgeYears세 ~ $maxAgeYears세
• 체중: ${minWeightKg}kg 이상
• 예방접종 완료
• 질병 이력 없음
• 임신/출산 이력 없음 (출산 후 $pregnancyCooldownMonths개월 경과 시 가능)
• 이전 헌혈 후 6개월 이상 경과''';
}

// ============================================================================
// 헌혈 자격 검증 메인 클래스
// ============================================================================
class DonationEligibility {
  // ========== 조건 설정 (여기서 값만 변경하면 전체 앱에 적용) ==========

  /// 강아지 헌혈 조건
  static const dogConditions = DogEligibilityConditions(
    minAgeMonths: 18, // 최소 18개월
    minAgeYears: 2, // 최소 2살
    maxAgeYears: 8, // 최대 8살
    minWeightKg: 20.0, // 최소 20kg (협의 zone 폐기, 단일 기준)
    neuteredMonthsRequired: 6, // 중성화 후 6개월
    pregnancyCooldownMonths: 12, // 출산 후 12개월
    donationIntervalDays: 180, // 헌혈 간격 180일(6개월) — 백엔드 동기화 2026-04-29
  );

  /// 고양이 헌혈 조건
  static const catConditions = CatEligibilityConditions(
    minAgeYears: 1,
    maxAgeYears: 8,
    minWeightKg: 4.0,
    pregnancyCooldownMonths: 12,
    donationIntervalDays: 180,
  );

  // ========== 검증 메서드 ==========

  /// 반려동물의 헌혈 자격을 검증합니다.
  /// [pet] 검증할 반려동물
  /// [animalType] 0=강아지, 1=고양이 (게시글에서 요구하는 동물 종류)
  static EligibilityResult checkEligibility(Pet pet, {int? animalType}) {
    // 동물 종류 결정
    final petAnimalType = pet.animalType ?? (pet.species == '강아지' ? 0 : 1);

    if (petAnimalType == 0) {
      return _checkDogEligibility(pet);
    } else {
      return _checkCatEligibility(pet);
    }
  }

  /// 강아지 헌혈 자격 검증
  static EligibilityResult _checkDogEligibility(Pet pet) {
    final conditions = dogConditions;
    final results = <ConditionResult>[];

    // 1. 나이 검증 (birthDate 기반)
    final ageResult = _checkDogAge(pet.ageInMonths, conditions);
    results.add(ageResult);

    // 2. 체중 검증
    final weightResult = _checkDogWeight(pet.weightKg, conditions);
    results.add(weightResult);

    // 3. 백신 접종 여부
    final vaccinatedResult = _checkVaccinated(pet.vaccinated);
    results.add(vaccinatedResult);

    // 4. 예방약 복용 여부
    final preventiveResult = _checkPreventiveMedication(
      pet.hasPreventiveMedication,
    );
    results.add(preventiveResult);

    // 5. 질병 이력
    final diseaseResult = _checkDisease(pet.hasDisease);
    results.add(diseaseResult);

    // 6. 임신/출산 (이전 pregnant + has_birth_experience 통합 — CLAUDE.md Pet contract)
    final pregnancyBirthResult = _checkPregnancyBirth(
      pet.pregnancyBirthStatus,
      pet.lastPregnancyEndDate,
      conditions.pregnancyCooldownMonths,
    );
    results.add(pregnancyBirthResult);

    // 7. 중성화 수술
    final neuteredResult = _checkNeutered(
      pet.isNeutered,
      pet.neuteredDate,
      conditions.neuteredMonthsRequired,
    );
    results.add(neuteredResult);

    // 8. 헌혈 간격
    final intervalResult = _checkDonationInterval(
      pet.prevDonationDate,
      conditions.donationIntervalDays,
    );
    results.add(intervalResult);

    // 전체 결과 판정
    final result = _calculateOverallResult(results, '강아지');

    return result;
  }

  /// 고양이 헌혈 자격 검증
  static EligibilityResult _checkCatEligibility(Pet pet) {
    final conditions = catConditions;
    final results = <ConditionResult>[];

    // 1. 나이 검증 (birthDate 기반)
    final ageResult = _checkCatAge(pet.ageInMonths, conditions);
    results.add(ageResult);

    // 2. 체중 검증
    final weightResult = _checkCatWeight(pet.weightKg, conditions);
    results.add(weightResult);

    // 3. 백신 접종 여부
    final vaccinatedResult = _checkVaccinated(pet.vaccinated);
    results.add(vaccinatedResult);

    // 4. 질병 이력
    final diseaseResult = _checkDisease(pet.hasDisease);
    results.add(diseaseResult);

    // 5. 임신/출산 (이전 pregnant 단일 → 통합 — CLAUDE.md Pet contract)
    final pregnancyBirthResult = _checkPregnancyBirth(
      pet.pregnancyBirthStatus,
      pet.lastPregnancyEndDate,
      conditions.pregnancyCooldownMonths,
    );
    results.add(pregnancyBirthResult);

    // 6. 헌혈 간격
    final intervalResult = _checkDonationInterval(
      pet.prevDonationDate,
      conditions.donationIntervalDays,
    );
    results.add(intervalResult);

    // 전체 결과 판정
    return _calculateOverallResult(results, '고양이');
  }

  // ========== 개별 조건 검증 메서드 ==========

  /// 강아지 나이 검증 (birthDate 기반 개월 수)
  static ConditionResult _checkDogAge(
    int? ageMonths,
    DogEligibilityConditions conditions,
  ) {
    // 생년월일 미입력 시 검증 스킵
    if (ageMonths == null) {
      return ConditionResult(
        conditionName: '나이',
        description: '${conditions.minAgeMonths}개월 ~ ${conditions.maxAgeYears}세',
        status: EligibilityStatus.unknown,
        message: '생년월일 미입력 (나이 검증 불가)',
      );
    }

    final maxAgeMonths = conditions.maxAgeYears * 12;

    if (ageMonths >= conditions.minAgeMonths && ageMonths <= maxAgeMonths) {
      return ConditionResult(
        conditionName: '나이',
        description: '${conditions.minAgeMonths}개월 ~ ${conditions.maxAgeYears}세',
        status: EligibilityStatus.eligible,
        message: '현재 $ageMonths개월 (약 ${ageMonths ~/ 12}세 ${ageMonths % 12}개월)',
      );
    }

    return ConditionResult(
      conditionName: '나이',
      description: '${conditions.minAgeMonths}개월 ~ ${conditions.maxAgeYears}세',
      status: EligibilityStatus.ineligible,
      message:
          '현재 $ageMonths개월 (${ageMonths < conditions.minAgeMonths ? "최소 ${conditions.minAgeMonths}개월 이상 필요" : "최대 ${conditions.maxAgeYears}세 이하"})',
    );
  }

  /// 강아지 체중 검증 (협의 zone 폐기, 단일 기준 — CLAUDE.md Pet contract)
  static ConditionResult _checkDogWeight(
    double weightKg,
    DogEligibilityConditions conditions,
  ) {
    if (weightKg >= conditions.minWeightKg) {
      return ConditionResult(
        conditionName: '체중',
        description: '${conditions.minWeightKg}kg 이상',
        status: EligibilityStatus.eligible,
        message: '현재 ${weightKg}kg',
      );
    }

    return ConditionResult(
      conditionName: '체중',
      description: '${conditions.minWeightKg}kg 이상',
      status: EligibilityStatus.ineligible,
      message: '현재 ${weightKg}kg (최소 ${conditions.minWeightKg}kg 이상 필요)',
    );
  }

  /// 고양이 나이 검증 (birthDate 기반 개월 수)
  static ConditionResult _checkCatAge(
    int? ageMonths,
    CatEligibilityConditions conditions,
  ) {
    if (ageMonths == null) {
      return ConditionResult(
        conditionName: '나이',
        description: '${conditions.minAgeYears}세 ~ ${conditions.maxAgeYears}세',
        status: EligibilityStatus.unknown,
        message: '생년월일 미입력 (나이 검증 불가)',
      );
    }

    final ageYears = ageMonths ~/ 12;
    if (ageYears >= conditions.minAgeYears &&
        ageYears <= conditions.maxAgeYears) {
      return ConditionResult(
        conditionName: '나이',
        description: '${conditions.minAgeYears}세 ~ ${conditions.maxAgeYears}세',
        status: EligibilityStatus.eligible,
        message: '현재 $ageMonths개월 (약 $ageYears세)',
      );
    }

    return ConditionResult(
      conditionName: '나이',
      description: '${conditions.minAgeYears}세 ~ ${conditions.maxAgeYears}세',
      status: EligibilityStatus.ineligible,
      message:
          '현재 약 $ageYears세 (${ageYears < conditions.minAgeYears ? "너무 어림" : "너무 많음"})',
    );
  }

  /// 고양이 체중 검증
  static ConditionResult _checkCatWeight(
    double weightKg,
    CatEligibilityConditions conditions,
  ) {
    if (weightKg >= conditions.minWeightKg) {
      return ConditionResult(
        conditionName: '체중',
        description: '${conditions.minWeightKg}kg 이상',
        status: EligibilityStatus.eligible,
        message: '현재 ${weightKg}kg',
      );
    }

    return ConditionResult(
      conditionName: '체중',
      description: '${conditions.minWeightKg}kg 이상',
      status: EligibilityStatus.ineligible,
      message: '현재 ${weightKg}kg (최소 ${conditions.minWeightKg}kg 이상 필요)',
    );
  }

  /// 백신 접종 여부 검증
  static ConditionResult _checkVaccinated(bool? vaccinated) {
    // null인 경우 정보 없음 - 헌혈 불가
    if (vaccinated == null) {
      return const ConditionResult(
        conditionName: '예방접종',
        description: '예방접종 완료',
        status: EligibilityStatus.ineligible,
        message: '예방접종 정보를 입력해주세요',
      );
    }

    if (vaccinated == true) {
      return const ConditionResult(
        conditionName: '예방접종',
        description: '예방접종 완료',
        status: EligibilityStatus.eligible,
        message: '접종 완료',
      );
    }

    // vaccinated == false
    return const ConditionResult(
      conditionName: '예방접종',
      description: '예방접종 완료',
      status: EligibilityStatus.ineligible,
      message: '예방접종이 필요합니다',
    );
  }

  /// 예방약 복용 여부 검증
  static ConditionResult _checkPreventiveMedication(bool? hasTakenPreventive) {
    // null인 경우 정보 없음 - 헌혈 불가
    if (hasTakenPreventive == null) {
      return const ConditionResult(
        conditionName: '예방약',
        description: '예방약 복용',
        status: EligibilityStatus.ineligible,
        message: '예방약 복용 정보를 입력해주세요',
      );
    }

    if (hasTakenPreventive) {
      return const ConditionResult(
        conditionName: '예방약',
        description: '예방약 복용',
        status: EligibilityStatus.eligible,
        message: '복용 완료',
      );
    }

    return const ConditionResult(
      conditionName: '예방약',
      description: '예방약 복용',
      status: EligibilityStatus.ineligible,
      message: '예방약 복용이 필요합니다',
    );
  }

  /// 질병 이력 검증
  static ConditionResult _checkDisease(bool? hasDisease) {
    // null인 경우 정보 없음 - 헌혈 불가
    if (hasDisease == null) {
      return const ConditionResult(
        conditionName: '질병 이력',
        description: '질병 이력 없음',
        status: EligibilityStatus.ineligible,
        message: '질병 이력 정보를 입력해주세요',
      );
    }

    if (hasDisease == false) {
      return const ConditionResult(
        conditionName: '질병 이력',
        description: '질병 이력 없음',
        status: EligibilityStatus.eligible,
        message: '질병 이력 없음',
      );
    }

    // hasDisease == true
    return const ConditionResult(
      conditionName: '질병 이력',
      description: '질병 이력 없음',
      status: EligibilityStatus.ineligible,
      message: '질병 이력이 있어 헌혈이 어렵습니다',
    );
  }

  /// 임신/출산 통합 검증 (CLAUDE.md Pet contract - PregnancyBirthStatus + last_pregnancy_end_date)
  ///
  /// 백엔드 services/donation_eligibility_service.py의 pregnancyBirth condition과 동일 결과.
  /// reason 매핑: pregnant / cooldown / date_missing.
  static ConditionResult _checkPregnancyBirth(
    int status,
    DateTime? endDate,
    int cooldownMonths,
  ) {
    // 0: 해당없음 (NONE)
    if (status == 0) {
      return const ConditionResult(
        conditionName: '임신/출산',
        description: '임신중이 아니며 출산 이력 없음',
        status: EligibilityStatus.eligible,
        message: '해당 없음',
      );
    }

    // 1: 임신중 (PREGNANT) → fail (reason: pregnant)
    if (status == 1) {
      return const ConditionResult(
        conditionName: '임신/출산',
        description: '임신중이 아니며 출산 이력 없음',
        status: EligibilityStatus.ineligible,
        message: '현재 임신 중에는 헌혈이 어렵습니다',
        reason: EligibilityReason.pregnant,
      );
    }

    // 2: 출산 이력 (POST_BIRTH)
    // 종료일 NULL → fail (reason: date_missing)
    if (endDate == null) {
      return const ConditionResult(
        conditionName: '임신/출산',
        description: '출산 후 12개월 경과',
        status: EligibilityStatus.ineligible,
        message: '출산 종료일을 입력해주세요',
        reason: EligibilityReason.dateMissing,
      );
    }

    final monthsSinceEnd = DateTime.now().difference(endDate).inDays ~/ 30;
    if (monthsSinceEnd >= cooldownMonths) {
      return ConditionResult(
        conditionName: '임신/출산',
        description: '출산 후 $cooldownMonths개월 경과',
        status: EligibilityStatus.eligible,
        message: '출산 후 $monthsSinceEnd개월 경과',
      );
    }

    // cooldown 미경과 → fail (reason: cooldown)
    final remaining = cooldownMonths - monthsSinceEnd;
    return ConditionResult(
      conditionName: '임신/출산',
      description: '출산 후 $cooldownMonths개월 경과',
      status: EligibilityStatus.ineligible,
      message: '출산 후 $monthsSinceEnd개월 경과 ($remaining개월 후 가능)',
      reason: EligibilityReason.cooldown,
    );
  }

  /// 중성화 수술 검증 (CLAUDE.md Pet contract: is_neutered=true이면 neutered_date 필수)
  static ConditionResult _checkNeutered(
    bool? isNeutered,
    DateTime? neuteredDate,
    int requiredMonths,
  ) {
    // None 보수적 fail (백엔드 정책 동기화)
    if (isNeutered == null) {
      return ConditionResult(
        conditionName: '중성화 수술',
        description: '중성화 수술 $requiredMonths개월 이후',
        status: EligibilityStatus.ineligible,
        message: '중성화 수술 정보를 입력해주세요',
      );
    }

    if (!isNeutered) {
      // 중성화하지 않은 경우 - 헌혈 가능 (중성화 필수가 아님)
      return ConditionResult(
        conditionName: '중성화 수술',
        description: '중성화 수술 $requiredMonths개월 이후',
        status: EligibilityStatus.eligible,
        message: '중성화하지 않음',
      );
    }

    // 중성화한 경우 - 수술일 필수
    if (neuteredDate == null) {
      return ConditionResult(
        conditionName: '중성화 수술',
        description: '중성화 수술 $requiredMonths개월 이후',
        status: EligibilityStatus.ineligible,
        message: '중성화 수술일을 입력해주세요',
      );
    }

    final monthsSinceNeutered =
        DateTime.now().difference(neuteredDate).inDays ~/ 30;
    if (monthsSinceNeutered >= requiredMonths) {
      return ConditionResult(
        conditionName: '중성화 수술',
        description: '중성화 수술 $requiredMonths개월 이후',
        status: EligibilityStatus.eligible,
        message: '수술 후 $monthsSinceNeutered개월 경과',
      );
    }

    return ConditionResult(
      conditionName: '중성화 수술',
      description: '중성화 수술 $requiredMonths개월 이후',
      status: EligibilityStatus.ineligible,
      message:
          '수술 후 $monthsSinceNeutered개월 경과 (${requiredMonths - monthsSinceNeutered}개월 후 가능)',
    );
  }

  /// 헌혈 간격 검증
  static ConditionResult _checkDonationInterval(
    DateTime? prevDonationDate,
    int intervalDays,
  ) {
    final intervalWeeks = intervalDays ~/ 7;

    if (prevDonationDate == null) {
      return ConditionResult(
        conditionName: '헌혈 간격',
        description: '이전 헌혈 후 $intervalWeeks주 이상',
        status: EligibilityStatus.eligible,
        message: '첫 헌혈',
      );
    }

    final daysSince = DateTime.now().difference(prevDonationDate).inDays;
    if (daysSince >= intervalDays) {
      return ConditionResult(
        conditionName: '헌혈 간격',
        description: '이전 헌혈 후 $intervalWeeks주 이상',
        status: EligibilityStatus.eligible,
        message: '이전 헌혈 후 $daysSince일 경과',
      );
    }

    final remainingDays = intervalDays - daysSince;
    return ConditionResult(
      conditionName: '헌혈 간격',
      description: '이전 헌혈 후 $intervalWeeks주 이상',
      status: EligibilityStatus.ineligible,
      // 백엔드 messages.py::ELIGIBILITY_INTERVAL_TOO_SHORT와 1:1 동기화 (2026-04-29)
      message:
          '$remainingDays일 후 가능 (현재 $daysSince일 경과, 최소 $intervalDays일 필요)',
    );
  }

  // ========== 결과 계산 ==========

  /// 전체 결과 계산
  static EligibilityResult _calculateOverallResult(
    List<ConditionResult> results,
    String animalType,
  ) {
    final hasIneligible = results.any((r) => r.isFailed);
    final hasConsultation = results.any((r) => r.needsConsultation);

    EligibilityStatus overallStatus;
    String summaryMessage;

    if (hasIneligible) {
      overallStatus = EligibilityStatus.ineligible;
      final failedCount = results.where((r) => r.isFailed).length;
      summaryMessage = '헌혈 불가 ($failedCount개 조건 미충족)';
    } else if (hasConsultation) {
      overallStatus = EligibilityStatus.needsConsultation;
      summaryMessage = '병원 협의 필요';
    } else {
      overallStatus = EligibilityStatus.eligible;
      summaryMessage = '헌혈 가능';
    }

    return EligibilityResult(
      overallStatus: overallStatus,
      allConditions: results,
      summaryMessage: summaryMessage,
    );
  }

  // ========== 유틸리티 메서드 ==========

  /// 동물 종류에 따른 조건 요약 텍스트 반환
  static String getConditionsSummary(int animalType) {
    if (animalType == 0) {
      return dogConditions.summaryText;
    } else {
      return catConditions.summaryText;
    }
  }

  /// 동물 종류에 해당하는지 확인
  static bool matchesAnimalType(Pet pet, int requiredAnimalType) {
    final petAnimalType = pet.animalType ?? (pet.species == '강아지' ? 0 : 1);
    return petAnimalType == requiredAnimalType;
  }

  /// 혈액형이 일치하는지 확인
  static bool matchesBloodType(Pet pet, String? requiredBloodType) {
    if (requiredBloodType == null ||
        requiredBloodType.isEmpty ||
        requiredBloodType.toLowerCase() == 'all') {
      return true;
    }
    return pet.bloodType == requiredBloodType;
  }
}
