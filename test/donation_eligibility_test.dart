// 헌혈 간격 정책 단위 테스트.
//
// 백엔드 동기화 (2026-04-29): DONATION_INTERVAL_DAYS 56 → 180.
// CLAUDE.md "Pet 모델 / 헌혈 자격 검증 contract" 섹션과 1:1 동기화.
// 백엔드 services/donation_eligibility_service.py와 같은 결과를 내야 함.

import 'package:flutter_test/flutter_test.dart';
import 'package:connect/models/pet_model.dart';
import 'package:connect/utils/donation_eligibility.dart';

void main() {
  group('헌혈 간격 정책 (백엔드 동기화: 180일/6개월)', () {
    // 헌혈 간격 외의 모든 조건은 통과시키는 강아지 (3살, 25kg, 백신/예방약 OK).
    Pet buildEligibleDog({DateTime? prevDonationDate}) {
      return Pet(
        ownerEmail: 'test@test.com',
        name: '초코',
        species: '강아지',
        animalType: 0,
        birthDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
        bloodType: 'DEA1.1+',
        weightKg: 25.0,
        sex: 1,
        pregnancyBirthStatus: 0,
        vaccinated: true,
        hasDisease: false,
        prevDonationDate: prevDonationDate,
        isNeutered: false,
        hasPreventiveMedication: true,
      );
    }

    // 고양이 (3살, 5kg, 백신 OK).
    Pet buildEligibleCat({DateTime? prevDonationDate}) {
      return Pet(
        ownerEmail: 'test@test.com',
        name: '나비',
        species: '고양이',
        animalType: 1,
        birthDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
        bloodType: 'A',
        weightKg: 5.0,
        sex: 1,
        pregnancyBirthStatus: 0,
        vaccinated: true,
        hasDisease: false,
        prevDonationDate: prevDonationDate,
        isNeutered: false,
        hasPreventiveMedication: true,
      );
    }

    ConditionResult intervalConditionOf(Pet pet) {
      final result = DonationEligibility.checkEligibility(pet);
      return result.allConditions
          .firstWhere((c) => c.conditionName == '헌혈 간격');
    }

    test('강아지 첫 헌혈은 가능 (prev=null)', () {
      final cond = intervalConditionOf(buildEligibleDog(prevDonationDate: null));
      expect(cond.isPassed, true);
      expect(cond.message, '첫 헌혈');
    });

    test('고양이 첫 헌혈은 가능 (prev=null)', () {
      final cond = intervalConditionOf(buildEligibleCat(prevDonationDate: null));
      expect(cond.isPassed, true);
    });

    test('강아지 100일 경과 시 헌혈 불가 (이전 56일 정책에선 통과했던 회귀 케이스)', () {
      final pet = buildEligibleDog(
        prevDonationDate: DateTime.now().subtract(const Duration(days: 100)),
      );
      final cond = intervalConditionOf(pet);
      expect(cond.isFailed, true);
      expect(cond.message, contains('80일 후 가능'));
      expect(cond.message, contains('100일 경과'));
    });

    test('고양이 100일 경과 시 헌혈 불가', () {
      final pet = buildEligibleCat(
        prevDonationDate: DateTime.now().subtract(const Duration(days: 100)),
      );
      final cond = intervalConditionOf(pet);
      expect(cond.isFailed, true);
      expect(cond.message, contains('80일 후 가능'));
    });

    test('강아지 179일 경과 시 헌혈 불가 (경계값 직전)', () {
      final pet = buildEligibleDog(
        prevDonationDate: DateTime.now().subtract(const Duration(days: 179)),
      );
      final cond = intervalConditionOf(pet);
      expect(cond.isFailed, true);
      expect(cond.message, contains('1일 후 가능'));
    });

    test('강아지 정확히 180일 경과 시 헌혈 가능 (경계값)', () {
      final pet = buildEligibleDog(
        prevDonationDate: DateTime.now().subtract(const Duration(days: 180)),
      );
      final cond = intervalConditionOf(pet);
      expect(cond.isPassed, true);
    });

    test('강아지 200일 경과 시 헌혈 가능', () {
      final pet = buildEligibleDog(
        prevDonationDate: DateTime.now().subtract(const Duration(days: 200)),
      );
      final cond = intervalConditionOf(pet);
      expect(cond.isPassed, true);
      expect(cond.message, contains('200일 경과'));
    });

    test('상수 검증: 강아지/고양이 donationIntervalDays는 180', () {
      expect(DonationEligibility.dogConditions.donationIntervalDays, 180);
      expect(DonationEligibility.catConditions.donationIntervalDays, 180);
    });
  });

  group('Pet.canDonate getter (180일 정책)', () {
    Pet buildPet({DateTime? prevDonationDate}) {
      return Pet(
        ownerEmail: 't@t.com',
        name: '초코',
        species: '강아지',
        weightKg: 25.0,
        sex: 1,
        prevDonationDate: prevDonationDate,
      );
    }

    test('첫 헌혈은 canDonate true', () {
      expect(buildPet(prevDonationDate: null).canDonate, true);
    });

    test('100일 경과 시 canDonate false (회귀 방어)', () {
      final pet = buildPet(
        prevDonationDate: DateTime.now().subtract(const Duration(days: 100)),
      );
      expect(pet.canDonate, false);
    });

    test('179일 경과 시 canDonate false', () {
      final pet = buildPet(
        prevDonationDate: DateTime.now().subtract(const Duration(days: 179)),
      );
      expect(pet.canDonate, false);
    });

    test('180일 경과 시 canDonate true (경계값)', () {
      final pet = buildPet(
        prevDonationDate: DateTime.now().subtract(const Duration(days: 180)),
      );
      expect(pet.canDonate, true);
    });

    test('nextDonationDate는 prev + 180일', () {
      final prev = DateTime(2026, 1, 1);
      final pet = buildPet(prevDonationDate: prev);
      expect(pet.nextDonationDate, prev.add(const Duration(days: 180)));
    });
  });
}
