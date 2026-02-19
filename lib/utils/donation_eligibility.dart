// lib/utils/donation_eligibility.dart
// 헌혈 자격 조건 설정 및 검증 로직
// 유지보수 시 이 파일의 조건 값만 수정하면 전체 앱에 적용됩니다.

import 'package:flutter/foundation.dart';
import '../models/pet_model.dart';

/// 헌혈 자격 상태
enum EligibilityStatus {
  eligible, // 헌혈 가능
  needsConsultation, // 협의 필요 (체중 등)
  ineligible, // 헌혈 불가
}

/// 개별 조건 검증 결과
class ConditionResult {
  final String conditionName; // 조건 이름
  final String description; // 조건 설명
  final EligibilityStatus status;
  final String? message; // 상세 메시지

  const ConditionResult({
    required this.conditionName,
    required this.description,
    required this.status,
    this.message,
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

  /// 최소 체중 (kg) - 이 이상이면 헌혈 가능
  final double minWeightKg;

  /// 협의 필요 체중 최소값 (kg)
  final double consultWeightMinKg;

  /// 협의 필요 체중 최대값 (kg)
  final double consultWeightMaxKg;

  /// 중성화 수술 후 필요 경과 개월 수
  final int neuteredMonthsRequired;

  /// 헌혈 간격 (일)
  final int donationIntervalDays;

  const DogEligibilityConditions({
    this.minAgeMonths = 18,
    this.minAgeYears = 2,
    this.maxAgeYears = 8,
    this.minWeightKg = 25.0,
    this.consultWeightMinKg = 20.0,
    this.consultWeightMaxKg = 24.9,
    this.neuteredMonthsRequired = 6,
    this.donationIntervalDays = 56,
  });

  /// 조건 요약 텍스트 (UI 표시용)
  String get summaryText => '''
• 나이: $minAgeYears세 ~ $maxAgeYears세 ($minAgeMonths개월 이상)
• 체중: ${minWeightKg}kg 이상 ($consultWeightMinKg~${consultWeightMaxKg}kg 협의)
• 예방접종 완료
• 예방약 복용 완료
• 질병 이력 없음
• 출산 경험 없음
• 중성화 수술 $neuteredMonthsRequired개월 이후
• 이전 헌혈 후 ${donationIntervalDays ~/ 7}주 이상 경과''';
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

  /// 헌혈 간격 (일)
  final int donationIntervalDays;

  const CatEligibilityConditions({
    this.minAgeYears = 1,
    this.maxAgeYears = 8,
    this.minWeightKg = 4.0,
    this.donationIntervalDays = 56,
  });

  /// 조건 요약 텍스트 (UI 표시용)
  /// TODO: 고양이 조건이 확정되면 업데이트
  String get summaryText => '''
• 나이: $minAgeYears세 ~ $maxAgeYears세
• 체중: ${minWeightKg}kg 이상
• 예방접종 완료
• 질병 이력 없음
• 이전 헌혈 후 ${donationIntervalDays ~/ 7}주 이상 경과''';
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
    minWeightKg: 25.0, // 최소 25kg
    consultWeightMinKg: 20.0, // 협의 필요: 20kg 이상
    consultWeightMaxKg: 24.9, // 협의 필요: 24.9kg 이하
    neuteredMonthsRequired: 6, // 중성화 후 6개월
    donationIntervalDays: 56, // 헌혈 간격 56일(8주)
  );

  /// 고양이 헌혈 조건
  /// TODO: 고양이 조건이 확정되면 업데이트
  static const catConditions = CatEligibilityConditions(
    minAgeYears: 1,
    maxAgeYears: 8,
    minWeightKg: 4.0,
    donationIntervalDays: 56,
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

    // 디버그 로그: Pet 데이터 확인
    debugPrint('[DonationEligibility] 강아지 헌혈 자격 검증 시작: ${pet.name}');
    debugPrint(
      '[DonationEligibility] - 나이: ${pet.ageNumber}세 (${pet.ageMonths}개월)',
    );
    debugPrint('[DonationEligibility] - 체중: ${pet.weightKg}kg');
    debugPrint('[DonationEligibility] - 백신접종: ${pet.vaccinated}');
    debugPrint('[DonationEligibility] - 예방약: ${pet.hasPreventiveMedication}');
    debugPrint('[DonationEligibility] - 질병이력: ${pet.hasDisease}');
    debugPrint('[DonationEligibility] - 출산경험: ${pet.hasBirthExperience}');
    debugPrint('[DonationEligibility] - 임신여부: ${pet.pregnant}');
    debugPrint(
      '[DonationEligibility] - 중성화: ${pet.isNeutered} (${pet.neuteredDate})',
    );

    // 1. 나이 검증 (월 단위 우선, 없으면 년 단위 사용)
    final ageResult = _checkDogAge(pet.ageNumber, pet.ageMonths, conditions);
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

    // 6. 출산 경험
    final birthResult = _checkBirthExperience(pet.hasBirthExperience);
    results.add(birthResult);

    // 7. 임신 여부
    final pregnantResult = _checkPregnant(pet.pregnant);
    results.add(pregnantResult);

    // 8. 중성화 수술
    final neuteredResult = _checkNeutered(
      pet.isNeutered,
      pet.neuteredDate,
      conditions.neuteredMonthsRequired,
    );
    results.add(neuteredResult);

    // 9. 헌혈 간격
    final intervalResult = _checkDonationInterval(
      pet.prevDonationDate,
      conditions.donationIntervalDays,
    );
    results.add(intervalResult);

    // 전체 결과 판정
    final result = _calculateOverallResult(results, '강아지');

    // 디버그 로그: 검증 결과
    debugPrint(
      '[DonationEligibility] 검증 결과: ${result.overallStatus} - ${result.summaryMessage}',
    );
    for (final condition in result.failedConditions) {
      debugPrint(
        '[DonationEligibility] ❌ 실패: ${condition.conditionName} - ${condition.message}',
      );
    }

    return result;
  }

  /// 고양이 헌혈 자격 검증
  static EligibilityResult _checkCatEligibility(Pet pet) {
    final conditions = catConditions;
    final results = <ConditionResult>[];

    // 1. 나이 검증
    final ageResult = _checkCatAge(pet.ageNumber, conditions);
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

    // 5. 임신 여부
    final pregnantResult = _checkPregnant(pet.pregnant);
    results.add(pregnantResult);

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

  /// 강아지 나이 검증 (월 단위가 있으면 우선 사용)
  static ConditionResult _checkDogAge(
    int ageYears,
    int? ageMonths,
    DogEligibilityConditions conditions,
  ) {
    // 월 단위 나이가 있으면 더 정밀한 검증
    if (ageMonths != null) {
      final maxAgeMonths = conditions.maxAgeYears * 12;

      if (ageMonths >= conditions.minAgeMonths && ageMonths <= maxAgeMonths) {
        return ConditionResult(
          conditionName: '나이',
          description:
              '${conditions.minAgeMonths}개월 ~ ${conditions.maxAgeYears}세',
          status: EligibilityStatus.eligible,
          message:
              '현재 $ageMonths개월 (약 ${ageMonths ~/ 12}세 ${ageMonths % 12}개월)',
        );
      }

      return ConditionResult(
        conditionName: '나이',
        description:
            '${conditions.minAgeMonths}개월 ~ ${conditions.maxAgeYears}세',
        status: EligibilityStatus.ineligible,
        message:
            '현재 $ageMonths개월 (${ageMonths < conditions.minAgeMonths ? "최소 ${conditions.minAgeMonths}개월 이상 필요" : "최대 ${conditions.maxAgeYears}세 이하"})',
      );
    }

    // 월 단위 없으면 년 단위로 검증
    if (ageYears >= conditions.minAgeYears &&
        ageYears <= conditions.maxAgeYears) {
      return ConditionResult(
        conditionName: '나이',
        description: '${conditions.minAgeYears}세 ~ ${conditions.maxAgeYears}세',
        status: EligibilityStatus.eligible,
        message: '현재 $ageYears세',
      );
    }

    return ConditionResult(
      conditionName: '나이',
      description: '${conditions.minAgeYears}세 ~ ${conditions.maxAgeYears}세',
      status: EligibilityStatus.ineligible,
      message:
          '현재 $ageYears세 (${ageYears < conditions.minAgeYears ? "너무 어림" : "너무 많음"})',
    );
  }

  /// 강아지 체중 검증
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

    if (weightKg >= conditions.consultWeightMinKg &&
        weightKg <= conditions.consultWeightMaxKg) {
      return ConditionResult(
        conditionName: '체중',
        description: '${conditions.minWeightKg}kg 이상',
        status: EligibilityStatus.needsConsultation,
        message:
            '현재 ${weightKg}kg (${conditions.consultWeightMinKg}~${conditions.consultWeightMaxKg}kg은 병원 협의 필요)',
      );
    }

    return ConditionResult(
      conditionName: '체중',
      description: '${conditions.minWeightKg}kg 이상',
      status: EligibilityStatus.ineligible,
      message: '현재 ${weightKg}kg (최소 ${conditions.consultWeightMinKg}kg 이상 필요)',
    );
  }

  /// 고양이 나이 검증
  static ConditionResult _checkCatAge(
    int ageYears,
    CatEligibilityConditions conditions,
  ) {
    if (ageYears >= conditions.minAgeYears &&
        ageYears <= conditions.maxAgeYears) {
      return ConditionResult(
        conditionName: '나이',
        description: '${conditions.minAgeYears}세 ~ ${conditions.maxAgeYears}세',
        status: EligibilityStatus.eligible,
        message: '현재 $ageYears세',
      );
    }

    return ConditionResult(
      conditionName: '나이',
      description: '${conditions.minAgeYears}세 ~ ${conditions.maxAgeYears}세',
      status: EligibilityStatus.ineligible,
      message:
          '현재 $ageYears세 (${ageYears < conditions.minAgeYears ? "너무 어림" : "너무 많음"})',
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

  /// 출산 경험 검증 (강아지만)
  static ConditionResult _checkBirthExperience(bool? hasBirthExperience) {
    // null인 경우 정보 없음 - 헌혈 불가
    if (hasBirthExperience == null) {
      return const ConditionResult(
        conditionName: '출산 경험',
        description: '출산 경험 없음',
        status: EligibilityStatus.ineligible,
        message: '출산 경험 정보를 입력해주세요',
      );
    }

    if (hasBirthExperience == false) {
      return const ConditionResult(
        conditionName: '출산 경험',
        description: '출산 경험 없음',
        status: EligibilityStatus.eligible,
        message: '출산 경험 없음',
      );
    }

    // hasBirthExperience == true
    return const ConditionResult(
      conditionName: '출산 경험',
      description: '출산 경험 없음',
      status: EligibilityStatus.ineligible,
      message: '출산 경험이 있어 헌혈이 어렵습니다',
    );
  }

  /// 임신 여부 검증
  static ConditionResult _checkPregnant(bool pregnant) {
    if (!pregnant) {
      return const ConditionResult(
        conditionName: '임신 상태',
        description: '임신하지 않은 상태',
        status: EligibilityStatus.eligible,
        message: '임신하지 않음',
      );
    }

    return const ConditionResult(
      conditionName: '임신 상태',
      description: '임신하지 않은 상태',
      status: EligibilityStatus.ineligible,
      message: '임신 중에는 헌혈이 어렵습니다',
    );
  }

  /// 중성화 수술 검증
  /// TODO: Pet 모델에 isNeutered, neuteredDate 필드 추가 후 구현
  static ConditionResult _checkNeutered(
    bool? isNeutered,
    DateTime? neuteredDate,
    int requiredMonths,
  ) {
    // 필드가 없으면 검증 건너뜀 (통과 처리)
    if (isNeutered == null) {
      return ConditionResult(
        conditionName: '중성화 수술',
        description: '중성화 수술 $requiredMonths개월 이후',
        status: EligibilityStatus.eligible,
        message: '(정보 없음 - 병원에서 확인)',
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

    // 중성화한 경우 - 수술 후 경과 기간 확인
    if (neuteredDate == null) {
      return ConditionResult(
        conditionName: '중성화 수술',
        description: '중성화 수술 $requiredMonths개월 이후',
        status: EligibilityStatus.needsConsultation,
        message: '중성화 수술일 확인 필요',
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
      message: '$remainingDays일 후 가능 (현재 $daysSince일 경과)',
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
