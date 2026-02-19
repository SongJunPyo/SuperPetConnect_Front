// lib/utils/blood_type_constants.dart
// 반려동물 혈액형 상수 정의
// 유지보수 시 이 파일의 값만 수정하면 전체 앱에 적용됩니다.

/// 반려동물 혈액형 관리 클래스
class BloodTypeConstants {
  // ========== 강아지 혈액형 (Dog Erythrocyte Antigen - DEA) ==========

  /// 강아지 혈액형 목록
  /// 국제적으로 인정된 DEA 혈액형: DEA1.1, DEA1.2, DEA3, DEA4, DEA5, DEA7
  ///
  /// 참고:
  /// - DEA1.1과 DEA1.2는 양성(+) / 음성(-) 구분
  /// - DEA1-형은 만능 공혈견 (Universal Donor)
  /// - 강아지는 총 13개 혈액형이 있지만, 임상적으로 중요한 것은 DEA1형
  static const List<String> dogBloodTypes = [
    'DEA 1.1+',  // DEA 1.1 양성
    'DEA 1.1-',  // DEA 1.1 음성
    'DEA 1.2+',  // DEA 1.2 양성
    'DEA 1.2-',  // DEA 1.2 음성
    'DEA 3',     // DEA 3형
    'DEA 4',     // DEA 4형
    'DEA 5',     // DEA 5형
    'DEA 7',     // DEA 7형
    '기타',       // 혈액형 모름 또는 기타
  ];

  /// 만능 공혈견 혈액형 (DEA1- = DEA 1.1-, DEA 1.2-)
  static const List<String> universalDonorDogTypes = [
    'DEA 1.1-',
    'DEA 1.2-',
  ];

  // ========== 고양이 혈액형 ==========

  /// 고양이 혈액형 목록
  /// A형, B형, AB형 3가지
  ///
  /// 참고:
  /// - 한국 고양이의 96% 이상이 A형
  /// - B형은 약 4%
  /// - AB형은 전 세계적으로 1% 미만으로 매우 희귀
  /// - A형은 A형과 AB형에게 헌혈 가능
  /// - B형과 AB형은 각각 자기 혈액형에게만 헌혈 가능
  static const List<String> catBloodTypes = [
    'A형',   // A형 (가장 흔함)
    'B형',   // B형 (희귀)
    'AB형',  // AB형 (매우 희귀)
    '기타',   // 혈액형 모름 또는 기타
  ];

  // ========== 헬퍼 메서드 ==========

  /// 동물 종류에 따른 혈액형 목록 반환
  /// [species] '강아지' 또는 '고양이'
  /// [animalType] 0=강아지, 1=고양이 (species가 null일 때 사용)
  static List<String> getBloodTypes({
    String? species,
    int? animalType,
  }) {
    // species 우선 사용
    if (species != null) {
      return species == '강아지' ? dogBloodTypes : catBloodTypes;
    }

    // species가 null이면 animalType 사용
    if (animalType != null) {
      return animalType == 0 ? dogBloodTypes : catBloodTypes;
    }

    // 둘 다 null이면 기타만 반환
    return ['기타'];
  }

  /// 혈액형 유효성 검사
  /// 해당 동물 종류에 유효한 혈액형인지 확인
  static bool isValidBloodType({
    required String bloodType,
    String? species,
    int? animalType,
  }) {
    final validTypes = getBloodTypes(species: species, animalType: animalType);
    return validTypes.contains(bloodType);
  }

  /// 잘못된 혈액형을 '기타'로 변환
  /// 이전 버전 호환성을 위해 유효하지 않은 혈액형은 '기타'로 처리
  static String normalizeBloodType({
    required String? bloodType,
    String? species,
    int? animalType,
  }) {
    if (bloodType == null) return '기타';

    final isValid = isValidBloodType(
      bloodType: bloodType,
      species: species,
      animalType: animalType,
    );

    return isValid ? bloodType : '기타';
  }

  /// 만능 공혈견 여부 확인
  /// DEA 1.1- 또는 DEA 1.2-인 경우 true
  static bool isUniversalDonorDog(String? bloodType) {
    if (bloodType == null) return false;
    return universalDonorDogTypes.contains(bloodType);
  }

  /// 혈액형 한글 설명 반환
  static String getBloodTypeDescription(String bloodType) {
    switch (bloodType) {
      // 강아지
      case 'DEA 1.1+':
        return 'DEA 1.1 양성 - DEA 1.1+형과 DEA 1-형에게 수혈 가능';
      case 'DEA 1.1-':
        return 'DEA 1.1 음성 - 만능 공혈견 (모든 혈액형에게 수혈 가능)';
      case 'DEA 1.2+':
        return 'DEA 1.2 양성 - DEA 1.2+형과 DEA 1-형에게 수혈 가능';
      case 'DEA 1.2-':
        return 'DEA 1.2 음성 - 만능 공혈견 (모든 혈액형에게 수혈 가능)';
      case 'DEA 3':
      case 'DEA 4':
      case 'DEA 5':
      case 'DEA 7':
        return '$bloodType - 임상적으로 중요도가 낮은 혈액형';

      // 고양이
      case 'A형':
        return 'A형 - A형과 AB형에게 헌혈 가능 (한국 고양이의 96% 이상)';
      case 'B형':
        return 'B형 - B형에게만 헌혈 가능 (희귀, 약 4%)';
      case 'AB형':
        return 'AB형 - AB형에게만 헌혈 가능 (매우 희귀, 1% 미만)';

      case '기타':
        return '혈액형 모름 - 헌혈 전 혈액형 검사 필요';

      default:
        return bloodType;
    }
  }
}
