/// 백엔드 contract와 동기화된 혈액형 sentinel 값.
///
/// `Pet.bloodType`은 백엔드에서 `String NOT NULL`이며 enum 컬럼이 아닌 자유
/// 텍스트(`Column(String(50))`). 다음 sentinel 문자열만 양측 코드 contract로
/// 합의되어 있음:
///
/// - `"Unknown"` (대문자 U, 나머지 소문자) — 사용자가 검사 전인 케이스. 헌혈
///   자격 검증 시 `bloodType` condition이 `reason: "missing"`으로 fail.
///
/// 일반 혈액형 값(개: `DEA1.1+` / `DEA1.1-`, 고양이: `A` / `B` / `AB`)은
/// CLAUDE.md "반려동물 혈액형" 섹션 참조.
///
/// 백엔드 미러: `constants/donation_eligibility.py::BLOOD_TYPE_UNKNOWN`.
class BloodType {
  BloodType._();

  /// 사용자가 혈액형을 모르는/검사 전인 경우의 sentinel.
  /// 정확한 문자열 매칭이 필수 — 대소문자 다르면 백엔드가 일반 혈액형으로 오인.
  static const String unknown = 'Unknown';
}
