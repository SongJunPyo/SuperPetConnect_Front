import 'package:flutter/material.dart';

/// 정보 행 라벨 아이콘 단일 진실 (single source of truth).
///
/// 펫/사용자/게시글 정보를 표시하는 모든 화면이 이 파일을 import해서 사용.
/// 직접 `Icons.xxx`를 쓰지 말고 `PetFieldIcons.xxx`를 쓸 것 — 매핑이 한 군데
/// 모여 있어야 다음 디자인 변경 시 한 번에 갱신 가능.
///
/// 규칙 (CLAUDE.md "아이콘 시스템" 섹션 참조):
/// - 정보 표시(read-only): `_outlined` 변형 사용
/// - 입력 affordance(date picker 등): `_outlined`로 통일 (2026-05-01 결정)
/// - 도메인 특수(종 구분): FontAwesomeIcons (예외 — 게시글 동물 종류만)
class PetFieldIcons {
  PetFieldIcons._();

  // ===== 펫 도메인 =====
  /// 반려동물 이름.
  static const IconData name = Icons.badge_outlined;

  /// 종 (강아지/고양이). Material에 outlined 변형 없음.
  static const IconData species = Icons.pets;

  /// 품종.
  static const IconData breed = Icons.category_outlined;

  /// 생년월일 (정보 표시).
  static const IconData birthDate = Icons.cake_outlined;

  /// 혈액형.
  static const IconData bloodType = Icons.bloodtype_outlined;

  /// 체중. Material에 outlined 변형 없음 (`fitness_center` 단일 변형).
  static const IconData weight = Icons.fitness_center;

  /// 백신 / 예방접종.
  static const IconData vaccinated = Icons.vaccines_outlined;

  /// 질병 유무.
  static const IconData hasDisease = Icons.local_hospital_outlined;

  /// 중성화 (방패 + 체크 — "처치 완료" 메타포).
  static const IconData isNeutered = Icons.verified_user_outlined;

  /// 중성화 일자.
  static const IconData neuteredDate = Icons.event_outlined;

  /// 예방약 복용.
  static const IconData medication = Icons.medication_outlined;

  /// 임신/출산 상태.
  static const IconData pregnancyBirth = Icons.favorite_outline;

  /// 출산 종료일.
  static const IconData lastPregnancyEndDate = Icons.event_outlined;

  /// 최근 헌혈일.
  static const IconData prevDonationDate = Icons.history_outlined;

  /// 성별 — 펫 sex 값(0=암컷, 1=수컷)에 따라 동적으로 다른 아이콘.
  /// 라벨 아이콘이 펫마다 달라져 시각적 정보 풍부함.
  static IconData sex(int sexValue) =>
      sexValue == 0 ? Icons.female : Icons.male;

  /// 변경 내역(previous_values) 행에서 sex 필드용 정적 아이콘.
  /// 특정 펫이 아닌 "필드 자체"를 가리키는 컨텍스트에서 사용.
  static const IconData sexField = Icons.transgender;

  // ===== 사용자 도메인 =====
  /// 사용자 이름 (펫 이름과 구분).
  static const IconData userName = Icons.person_outline;

  /// 닉네임.
  static const IconData nickname = Icons.badge_outlined;

  /// 이메일.
  static const IconData email = Icons.email_outlined;

  /// 전화번호 / 연락처.
  static const IconData phone = Icons.phone_outlined;

  /// 주소.
  static const IconData address = Icons.location_on_outlined;

  /// 가입일.
  static const IconData userCreatedAt = Icons.event_outlined;

  /// 사용자 상태 표시.
  static const IconData userStatus = Icons.info_outline;

  // ===== 게시글 도메인 =====
  /// 병원명.
  static const IconData hospital = Icons.business_outlined;

  /// 게시글 위치/주소.
  static const IconData postLocation = Icons.location_on_outlined;

  /// 게시일.
  static const IconData postedAt = Icons.calendar_today_outlined;

  /// 헌혈 일정/날짜.
  static const IconData donationDate = Icons.event_outlined;

  /// 환자명 (긴급 헌혈 게시글).
  static const IconData patientName = Icons.badge_outlined;

  /// 진단명 / 병명·증상.
  static const IconData diagnosis = Icons.local_hospital_outlined;

  // ===== 변경 내역 (admin_pet_management 호환) =====
  /// 백엔드 필드 키 → 라벨 아이콘. previous_values 행에서 사용.
  /// 신규 필드 추가 시 케이스 추가.
  static IconData forField(String key) {
    switch (key) {
      case 'name':
        return name;
      case 'species':
        return species;
      case 'breed':
        return breed;
      case 'birth_date':
        return birthDate;
      case 'blood_type':
        return bloodType;
      case 'weight_kg':
        return weight;
      case 'sex':
        return sexField;
      case 'pregnancy_birth_status':
        return pregnancyBirth;
      case 'last_pregnancy_end_date':
        return lastPregnancyEndDate;
      case 'vaccinated':
        return vaccinated;
      case 'has_disease':
        return hasDisease;
      case 'is_neutered':
        return isNeutered;
      case 'neutered_date':
        return neuteredDate;
      case 'has_preventive_medication':
        return medication;
      default:
        return Icons.edit_outlined;
    }
  }
}
