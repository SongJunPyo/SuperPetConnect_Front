// lib/utils/blood_type_constants.dart
// 반려동물 혈액형 상수 정의
// 유지보수 시 이 파일의 값만 수정하면 전체 앱에 적용됩니다.

/// 반려동물 혈액형 관리 클래스
class BloodTypeConstants {
  // ========== 강아지 혈액형 (Dog Erythrocyte Antigen - DEA) ==========

  /// 강아지 혈액형 목록
  static const List<String> dogBloodTypes = [
    'DEA1+',
    'DEA1-',
    '기타',
  ];

  // ========== 고양이 혈액형 ==========

  /// 고양이 혈액형 목록
  static const List<String> catBloodTypes = [
    'A형',
    'B형',
    'AB형',
    '기타',
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

}
