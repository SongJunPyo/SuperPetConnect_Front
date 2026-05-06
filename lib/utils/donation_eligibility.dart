// lib/utils/donation_eligibility.dart
// 헌혈 자격 조건 설정 및 검증 로직
// 유지보수 시 이 파일의 조건 값만 수정하면 전체 앱에 적용됩니다.
//
// 백엔드 services/donation_eligibility_service.py와 1:1 동기화 필요.
// CLAUDE.md "Pet 모델 / 헌혈 자격 검증 contract" 섹션 참조.

import '../models/pet_model.dart';
import 'blood_types.dart';

/// 헌혈 자격 거부 사유 키 (백엔드 constants/donation_eligibility.py::EligibilityReason 미러).
/// 모든 condition에 부여 (2026-05-01 백엔드 contract 확장).
///
/// 와이어 포맷 안정성: 기존 값 변경 금지. 추가만 허용.
class EligibilityReason {
  EligibilityReason._();

  // === pregnancyBirth + neutered 공유 ===
  static const String pregnant = 'pregnant'; // 현재 임신중 (status=1)
  static const String cooldown = 'cooldown'; // 출산/중성화 12개월(혹은 6개월) 미경과
  static const String dateMissing = 'date_missing'; // 종료일/수술일 NULL

  // === 일반 missing ===
  /// 정보 미입력 — 사용자가 채우면 통과 가능. UI에서 "정보 입력 필요" 표시.
  /// (생년월일 / 예방접종 / 예방약 / 질병 / 중성화 / 혈액형 등)
  static const String missing = 'missing';

  // === age ===
  static const String tooYoung = 'too_young';
  static const String tooOld = 'too_old';

  // === weight ===
  static const String underMin = 'under_min';

  // === vaccination ===
  static const String notVaccinated = 'not_vaccinated';

  /// 종합백신 24개월 초과 + 항체검사 NULL — 카페 정책 (2026-05 PR-1).
  /// 백엔드 EligibilityReason.VACCINATION_EXPIRED 미러.
  static const String vaccinationExpired = 'vaccination_expired';

  /// 백신 24개월 초과 + 항체검사 12개월 초과 — 카페 정책 (2026-05 PR-1).
  /// 백엔드 EligibilityReason.ANTIBODY_TEST_EXPIRED 미러.
  static const String antibodyTestExpired = 'antibody_test_expired';

  // === preventive medication ===
  static const String notTaken = 'not_taken';

  /// 예방약 복용 후 3개월 초과 — 카페 정책 (2026-05 PR-1).
  /// 백엔드 EligibilityReason.PREVENTIVE_MEDICATION_EXPIRED 미러.
  static const String preventiveMedicationExpired =
      'preventive_medication_expired';

  // === disease ===
  static const String hasDisease = 'has_disease';

  // === donationInterval ===
  static const String intervalTooShort = 'interval_too_short';

  // === animalType ===
  static const String mismatch = 'mismatch';
}

/// 헌혈 자격 상태
///
/// 우선순위 (overall 결과 계산 시): ineligible > infoIncomplete > needsConsultation > eligible
/// - `ineligible`: 고정 사실로 차단 (나이 초과, 질병, 임신 중 등). 데이터 입력으로 풀 수 없음.
/// - `infoIncomplete`: 정보 미입력으로 차단. 사용자가 펫 수정 화면에서 채우면 풀림.
/// - `needsConsultation`: 협의 필요 (현재 체중 협의 zone 폐기로 사실상 미사용).
/// - `eligible`: 통과.
enum EligibilityStatus {
  eligible, // 헌혈 가능
  needsConsultation, // 협의 필요 (현재 미사용)
  ineligible, // 헌혈 불가 (고정 사실)
  infoIncomplete, // 정보 입력 필요 (사용자가 채우면 풀 수 있음)
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
  bool get isInfoIncomplete => status == EligibilityStatus.infoIncomplete;
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

  /// 실패한 조건 목록 (고정 사실로 차단된 것만)
  List<ConditionResult> get failedConditions =>
      allConditions.where((c) => c.isFailed).toList();

  /// 협의 필요 조건 목록
  List<ConditionResult> get consultConditions =>
      allConditions.where((c) => c.needsConsultation).toList();

  /// 정보 미입력 조건 목록 (사용자가 채우면 풀 수 있는 것들)
  List<ConditionResult> get incompleteConditions =>
      allConditions.where((c) => c.isInfoIncomplete).toList();

  /// 신청을 막는 모든 조건 (failed + incomplete). UI에서 "왜 신청 못 하는지"를
  /// 한 번에 보여줄 때 사용.
  List<ConditionResult> get blockingConditions =>
      allConditions.where((c) => c.isFailed || c.isInfoIncomplete).toList();

  /// 헌혈 가능 여부
  bool get isEligible => overallStatus == EligibilityStatus.eligible;

  /// 협의 필요 여부
  bool get needsConsultation =>
      overallStatus == EligibilityStatus.needsConsultation;

  /// 헌혈 불가 여부 (고정 사실로 차단)
  bool get isIneligible => overallStatus == EligibilityStatus.ineligible;

  /// 정보 입력 필요 여부 (사용자가 펫 정보 보완하면 풀림)
  bool get isInfoIncomplete =>
      overallStatus == EligibilityStatus.infoIncomplete;
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

  /// 종합백신 유효 기간 (개월) — 카페 정책: 최소 2년 이내 접종 필수.
  /// 24개월 초과 시 항체검사 양성 확인 없이 헌혈 신청 불가.
  /// 백엔드 constants/donation_eligibility.py::VACCINATION_MAX_MONTHS와 1:1 동기화.
  static const int vaccinationMaxMonths = 24;

  /// 항체검사 유효 기간 (개월) — 카페 정책: 종합백신 2년 초과 시 12개월 이내 항체검사 필수.
  /// 백엔드 constants/donation_eligibility.py::ANTIBODY_TEST_MAX_MONTHS와 1:1 동기화.
  static const int antibodyTestMaxMonths = 12;

  /// 예방약 복용 기간 (개월) — 카페 정책: 헌혈 예정일 최소 3개월 전부터 복용 필수.
  /// 백엔드 constants/donation_eligibility.py::PREVENTIVE_MEDICATION_MAX_MONTHS와 1:1 동기화.
  static const int preventiveMedicationMaxMonths = 3;

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

  // ========== 헬퍼 ==========

  /// 두 날짜 사이의 캘린더 월 차이.
  ///
  /// 백엔드 services/donation_eligibility_service.py::_months_since_date 미러.
  /// 일자(day) 비교 없이 (year, month) 차이만 계산. 한국 의료 운영에서 일 단위 정확도 불필요.
  /// `later`가 `earlier` 이전이면 음수.
  static int monthsBetween(DateTime earlier, DateTime later) {
    return (later.year - earlier.year) * 12 + (later.month - earlier.month);
  }

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

    // 3. 백신 접종 검증 (카페 정책 — 2026-05 PR-1)
    final vaccinatedResult = _checkVaccinated(
      pet.vaccinated,
      pet.lastVaccinationDate,
      pet.lastAntibodyTestDate,
    );
    results.add(vaccinatedResult);

    // 4. 예방약 복용 검증 (강아지 한정 — 2026-05 PR-1)
    final preventiveResult = _checkPreventiveMedication(
      pet.hasPreventiveMedication,
      pet.lastPreventiveMedicationDate,
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

    // 8. 헌혈 간격 (effective date = max(system, prior). 우회 차단 — 2026-05 PR-1)
    final intervalResult = _checkDonationInterval(
      pet.effectiveLastDonationDate,
      conditions.donationIntervalDays,
    );
    results.add(intervalResult);

    // 9. 혈액형 (sentinel "Unknown" 게이트 — 백엔드 _check_blood_type 미러)
    final bloodTypeResult = _checkBloodType(pet.bloodType);
    results.add(bloodTypeResult);

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

    // 3. 백신 접종 검증 (카페 정책 — 2026-05 PR-1, 강아지·고양이 공통)
    final vaccinatedResult = _checkVaccinated(
      pet.vaccinated,
      pet.lastVaccinationDate,
      pet.lastAntibodyTestDate,
    );
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

    // 6. 헌혈 간격 (effective date = max(system, prior). 우회 차단 — 2026-05 PR-1)
    final intervalResult = _checkDonationInterval(
      pet.effectiveLastDonationDate,
      conditions.donationIntervalDays,
    );
    results.add(intervalResult);

    // 7. 혈액형 (sentinel "Unknown" 게이트 — 백엔드 _check_blood_type 미러)
    final bloodTypeResult = _checkBloodType(pet.bloodType);
    results.add(bloodTypeResult);

    // 전체 결과 판정
    return _calculateOverallResult(results, '고양이');
  }

  // ========== 개별 조건 검증 메서드 ==========

  /// 강아지 나이 검증 (birthDate 기반 개월 수)
  static ConditionResult _checkDogAge(
    int? ageMonths,
    DogEligibilityConditions conditions,
  ) {
    // 생년월일 미입력 — 정보 입력 시 풀림
    if (ageMonths == null) {
      return ConditionResult(
        conditionName: '나이',
        description: '${conditions.minAgeMonths}개월 ~ ${conditions.maxAgeYears}세',
        status: EligibilityStatus.infoIncomplete,
        message: '생년월일 미입력',
        reason: EligibilityReason.missing,
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

    final isTooYoung = ageMonths < conditions.minAgeMonths;
    return ConditionResult(
      conditionName: '나이',
      description: '${conditions.minAgeMonths}개월 ~ ${conditions.maxAgeYears}세',
      status: EligibilityStatus.ineligible,
      message:
          '현재 $ageMonths개월 (${isTooYoung ? "최소 ${conditions.minAgeMonths}개월 이상 필요" : "최대 ${conditions.maxAgeYears}세 이하"})',
      reason:
          isTooYoung ? EligibilityReason.tooYoung : EligibilityReason.tooOld,
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
      reason: EligibilityReason.underMin,
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
        status: EligibilityStatus.infoIncomplete,
        message: '생년월일 미입력',
        reason: EligibilityReason.missing,
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

    final isTooYoung = ageYears < conditions.minAgeYears;
    return ConditionResult(
      conditionName: '나이',
      description: '${conditions.minAgeYears}세 ~ ${conditions.maxAgeYears}세',
      status: EligibilityStatus.ineligible,
      message: '현재 약 $ageYears세 (${isTooYoung ? "너무 어림" : "너무 많음"})',
      reason:
          isTooYoung ? EligibilityReason.tooYoung : EligibilityReason.tooOld,
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
      reason: EligibilityReason.underMin,
    );
  }

  /// 백신 접종 검증 (카페 정책 — 2026-05 PR-1)
  ///
  /// 백엔드 services/donation_eligibility_service.py::_check_vaccinated 미러.
  /// 판정 순서:
  ///   1. vaccinated == null → missing
  ///   2. vaccinated == false → not_vaccinated
  ///   3. last_vaccination_date == null → missing
  ///   4. 백신 24개월 초과 + 항체검사 == null → vaccination_expired
  ///   5. 백신 24개월 초과 + 항체검사 12개월 초과 → antibody_test_expired
  ///   6. 그 외 → 통과
  static ConditionResult _checkVaccinated(
    bool? vaccinated,
    DateTime? lastVaccinationDate,
    DateTime? lastAntibodyTestDate,
  ) {
    if (vaccinated == null) {
      return const ConditionResult(
        conditionName: '예방접종',
        description: '예방접종 완료 (24개월 이내 또는 항체검사 12개월 이내)',
        status: EligibilityStatus.infoIncomplete,
        message: '예방접종 여부 미입력',
        reason: EligibilityReason.missing,
      );
    }

    if (vaccinated == false) {
      return const ConditionResult(
        conditionName: '예방접종',
        description: '예방접종 완료',
        status: EligibilityStatus.ineligible,
        message: '예방접종이 필요합니다',
        reason: EligibilityReason.notVaccinated,
      );
    }

    // vaccinated == true
    if (lastVaccinationDate == null) {
      return const ConditionResult(
        conditionName: '예방접종',
        description: '종합백신 접종일 입력',
        status: EligibilityStatus.infoIncomplete,
        // 백엔드 messages.py::ELIGIBILITY_VACCINATION_DATE_MISSING 미러
        message: '종합백신 접종일을 펫 프로필에 입력해주세요',
        reason: EligibilityReason.missing,
      );
    }

    final now = DateTime.now();
    final monthsSinceVaccination = monthsBetween(lastVaccinationDate, now);

    if (monthsSinceVaccination <= vaccinationMaxMonths) {
      return ConditionResult(
        conditionName: '예방접종',
        description: '종합백신 $vaccinationMaxMonths개월 이내',
        status: EligibilityStatus.eligible,
        message: '백신 접종 후 $monthsSinceVaccination개월 경과',
      );
    }

    // 백신 24개월 초과 — 항체검사로 대체 가능 여부 확인
    if (lastAntibodyTestDate == null) {
      return const ConditionResult(
        conditionName: '예방접종',
        description: '종합백신 24개월 이내 또는 항체검사',
        status: EligibilityStatus.ineligible,
        // 백엔드 messages.py::ELIGIBILITY_VACCINATION_EXPIRED 미러
        message: '종합백신 2년 경과 - 추가 접종 또는 항체검사 필수',
        reason: EligibilityReason.vaccinationExpired,
      );
    }

    final monthsSinceAntibody = monthsBetween(lastAntibodyTestDate, now);
    if (monthsSinceAntibody <= antibodyTestMaxMonths) {
      return ConditionResult(
        conditionName: '예방접종',
        description: '항체검사 $antibodyTestMaxMonths개월 이내',
        status: EligibilityStatus.eligible,
        message: '항체검사 후 $monthsSinceAntibody개월 경과',
      );
    }

    return const ConditionResult(
      conditionName: '예방접종',
      description: '항체검사 12개월 이내',
      status: EligibilityStatus.ineligible,
      // 백엔드 messages.py::ELIGIBILITY_ANTIBODY_TEST_EXPIRED 미러
      message: '항체검사 12개월 경과 - 재검사 필요',
      reason: EligibilityReason.antibodyTestExpired,
    );
  }

  /// 예방약 복용 검증 (카페 정책 — 2026-05 PR-1, 강아지 한정)
  ///
  /// 백엔드 services/donation_eligibility_service.py::_check_preventive_medication 미러.
  /// 판정 순서:
  ///   1. has_preventive_medication == null → missing
  ///   2. has_preventive_medication == false → not_taken
  ///   3. last_preventive_medication_date == null → missing
  ///   4. 예방약 3개월 초과 → preventive_medication_expired
  ///   5. 그 외 → 통과
  static ConditionResult _checkPreventiveMedication(
    bool? hasTakenPreventive,
    DateTime? lastPreventiveMedicationDate,
  ) {
    if (hasTakenPreventive == null) {
      return const ConditionResult(
        conditionName: '예방약',
        description: '예방약 복용 (3개월 이내)',
        status: EligibilityStatus.infoIncomplete,
        // 백엔드 messages.py::ELIGIBILITY_PREVENTIVE_MEDICATION_UNKNOWN 미러
        message: '예방약 복용 여부 미입력',
        reason: EligibilityReason.missing,
      );
    }

    if (hasTakenPreventive == false) {
      return const ConditionResult(
        conditionName: '예방약',
        description: '예방약 복용',
        status: EligibilityStatus.ineligible,
        message: '예방약 복용이 필요합니다',
        reason: EligibilityReason.notTaken,
      );
    }

    // hasTakenPreventive == true
    if (lastPreventiveMedicationDate == null) {
      return const ConditionResult(
        conditionName: '예방약',
        description: '예방약 복용일 입력',
        status: EligibilityStatus.infoIncomplete,
        // 백엔드 messages.py::ELIGIBILITY_PREVENTIVE_MEDICATION_DATE_MISSING 미러
        message: '예방약 복용일을 펫 프로필에 입력해주세요',
        reason: EligibilityReason.missing,
      );
    }

    final now = DateTime.now();
    final monthsSinceMedication = monthsBetween(
      lastPreventiveMedicationDate,
      now,
    );

    if (monthsSinceMedication <= preventiveMedicationMaxMonths) {
      return ConditionResult(
        conditionName: '예방약',
        description: '예방약 $preventiveMedicationMaxMonths개월 이내 복용',
        status: EligibilityStatus.eligible,
        message: '예방약 복용 후 $monthsSinceMedication개월 경과',
      );
    }

    return const ConditionResult(
      conditionName: '예방약',
      description: '예방약 3개월 이내 복용',
      status: EligibilityStatus.ineligible,
      // 백엔드 messages.py::ELIGIBILITY_PREVENTIVE_MEDICATION_EXPIRED 미러
      message: '헌혈 예정일 최소 3개월 전부터 예방약 복용 필수',
      reason: EligibilityReason.preventiveMedicationExpired,
    );
  }

  /// 질병 이력 검증
  ///
  /// null → infoIncomplete (사용자가 채우면 풀림)
  /// true → ineligible + has_disease reason (고정 사실)
  static ConditionResult _checkDisease(bool? hasDisease) {
    if (hasDisease == null) {
      return const ConditionResult(
        conditionName: '질병 이력',
        description: '질병 이력 없음',
        status: EligibilityStatus.infoIncomplete,
        message: '질병 이력 정보를 입력해주세요',
        reason: EligibilityReason.missing,
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
      reason: EligibilityReason.hasDisease,
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

    // 1: 임신중 (PREGNANT) → fail (reason: pregnant) — 고정 사실
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
    // 종료일 NULL → infoIncomplete (사용자가 종료일 입력하면 cooldown/eligible로 풀림)
    if (endDate == null) {
      return const ConditionResult(
        conditionName: '임신/출산',
        description: '출산 후 12개월 경과',
        status: EligibilityStatus.infoIncomplete,
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
  ///
  /// is_neutered=null → infoIncomplete + missing
  /// is_neutered=true & neutered_date=null → infoIncomplete + date_missing
  /// 수술 후 cooldown 미경과 → ineligible + cooldown
  static ConditionResult _checkNeutered(
    bool? isNeutered,
    DateTime? neuteredDate,
    int requiredMonths,
  ) {
    if (isNeutered == null) {
      return ConditionResult(
        conditionName: '중성화 수술',
        description: '중성화 수술 $requiredMonths개월 이후',
        status: EligibilityStatus.infoIncomplete,
        // 백엔드 messages.py::ELIGIBILITY_NEUTERED_UNKNOWN 미러
        message: '중성화 여부 미입력',
        reason: EligibilityReason.missing,
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
        status: EligibilityStatus.infoIncomplete,
        message: '중성화 수술일을 입력해주세요',
        reason: EligibilityReason.dateMissing,
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
      reason: EligibilityReason.cooldown,
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
      reason: EligibilityReason.intervalTooShort,
    );
  }

  /// 혈액형 검증 — sentinel `BloodType.unknown` ("Unknown") 게이트.
  ///
  /// 백엔드 services/donation_eligibility_service.py::_check_blood_type 미러.
  /// `pet.blood_type == "Unknown"`이면 fail, 그 외(일반 혈액형 값) 통과.
  /// 게시글의 요구 혈액형과 매칭은 별도 로직(`matchesBloodType`)이 담당.
  static ConditionResult _checkBloodType(String? bloodType) {
    if (bloodType == BloodType.unknown) {
      return const ConditionResult(
        conditionName: '혈액형',
        description: '혈액형 입력 필요',
        status: EligibilityStatus.infoIncomplete,
        // 백엔드 messages.py::ELIGIBILITY_BLOOD_TYPE_MISSING 미러
        message: '혈액형 미입력',
        reason: EligibilityReason.missing,
      );
    }

    return ConditionResult(
      conditionName: '혈액형',
      description: '혈액형 입력 완료',
      status: EligibilityStatus.eligible,
      message: bloodType ?? '',
    );
  }

  // ========== 결과 계산 ==========

  /// 전체 결과 계산
  ///
  /// 우선순위: ineligible > infoIncomplete > needsConsultation > eligible
  /// - ineligible 하나라도 있으면 ineligible (고정 사실 우선)
  /// - 그 외 infoIncomplete 있으면 infoIncomplete (사용자가 채울 수 있음)
  /// - 그 외 consultation 있으면 needsConsultation
  /// - 모두 통과면 eligible
  static EligibilityResult _calculateOverallResult(
    List<ConditionResult> results,
    String animalType,
  ) {
    final hasIneligible = results.any((r) => r.isFailed);
    final hasIncomplete = results.any((r) => r.isInfoIncomplete);
    final hasConsultation = results.any((r) => r.needsConsultation);

    EligibilityStatus overallStatus;
    String summaryMessage;

    if (hasIneligible) {
      overallStatus = EligibilityStatus.ineligible;
      final failedCount = results.where((r) => r.isFailed).length;
      summaryMessage = '헌혈 불가 ($failedCount개 조건 미충족)';
    } else if (hasIncomplete) {
      overallStatus = EligibilityStatus.infoIncomplete;
      final incompleteNames = results
          .where((r) => r.isInfoIncomplete)
          .map((r) => r.conditionName)
          .toList();
      // 필드명을 직접 노출해 어떤 항목을 채워야 하는지 명확하게 안내.
      // 항목이 많아지면 한 줄이 길어질 수 있으나, 펫 1마리당 최대 4-5개라 실용적 한계 내.
      summaryMessage = '정보 입력 필요 — ${incompleteNames.join(', ')}';
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
