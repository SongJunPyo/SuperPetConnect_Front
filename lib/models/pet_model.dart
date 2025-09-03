// models/pet_model.dart

class Pet {
  final int? petIdx; // pet_id → pet_idx로 변경
  final int? accountIdx; // guardian_idx → account_idx로 변경
  final String ownerEmail; // 보호자 이메일 (이메일 기반 관계로 변경)
  final String name;
  final String species;
  final int? animalType; // 0=강아지, 1=고양이
  final String? breed;
  final int ageNumber; // DB의 age_number 필드
  final String? bloodType;
  final double weightKg;
  final bool pregnant;
  final bool? vaccinated; // 백신 접종 여부 (DB에서 NULL 허용)
  final bool? hasDisease; // 질병 이력 여부 (DB에서 NULL 허용)
  final bool? hasBirthExperience; // 출산 경험 여부 (DB에서 NULL 허용)
  final DateTime? prevDonationDate; // 이전 헌혈 일자

  Pet({
    this.petIdx,
    this.accountIdx,
    required this.ownerEmail,
    required this.name,
    required this.species,
    this.animalType,
    this.breed,
    required this.ageNumber,
    this.bloodType,
    required this.weightKg,
    required this.pregnant,
    this.vaccinated,
    this.hasDisease,
    this.hasBirthExperience,
    this.prevDonationDate,
  });

  // 나이를 문자열로 반환하는 getter
  String get age {
    return ageNumber <= 0 ? '1살 미만' : '$ageNumber살';
  }

  factory Pet.fromJson(Map<String, dynamic> json) {
    // weight_kg 안전하게 파싱
    double parseWeight(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }
    
    // age_number 안전하게 파싱
    int parseAge(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      if (value is double) return value.toInt();
      return 0;
    }
    
    return Pet(
      petIdx: json['pet_idx'] ?? json['pet_id'], // 하위 호환성 지원
      accountIdx: json['account_idx'] ?? json['guardian_idx'], // 하위 호환성 지원
      ownerEmail: json['owner_email'] ?? '',
      name: json['name'] ?? '',
      species: json['species'] ?? '',
      animalType: json['animal_type'], // 0=강아지, 1=고양이
      breed: json['breed'],
      ageNumber: parseAge(json['age_number']),
      bloodType: json['blood_type'],
      weightKg: parseWeight(json['weight_kg']),
      pregnant: json['pregnant'] == null ? false : (json['pregnant'] == 1),
      vaccinated: json['vaccinated'] == null ? null : (json['vaccinated'] == 1),
      hasDisease: json['has_disease'] == null ? null : (json['has_disease'] == 1),
      hasBirthExperience: json['has_birth_experience'] == null ? null : (json['has_birth_experience'] == 1),
      prevDonationDate: json['prev_donation_date'] != null ? DateTime.tryParse(json['prev_donation_date']) : null,
    );
  }

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
      'age_number': ageNumber,
      'blood_type': bloodType,
      'weight_kg': weightKg,
      'pregnant': pregnant ? 1 : 0,
      'vaccinated': vaccinated == null ? null : (vaccinated! ? 1 : 0),
      'has_disease': hasDisease == null ? null : (hasDisease! ? 1 : 0),
      'has_birth_experience': hasBirthExperience == null ? null : (hasBirthExperience! ? 1 : 0),
      'prev_donation_date': prevDonationDate?.toIso8601String(),
    };
  }
  
  // 헌혈 가능 여부 판단 (8주 간격)
  bool get canDonate {
    if (prevDonationDate == null) return true; // 첫 헌혈
    
    final now = DateTime.now();
    final daysSince = now.difference(prevDonationDate!).inDays;
    
    return daysSince >= 56; // 8주(56일) 이상 경과
  }
  
  // 다음 헌혈 가능일
  DateTime? get nextDonationDate {
    if (prevDonationDate == null) return null; // 첫 헌혈인 경우
    
    return prevDonationDate!.add(const Duration(days: 56));
  }
  
  // 헌혈 상태 텍스트
  String get donationStatusText {
    if (prevDonationDate == null) {
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

  // 반려동물 정보 표시용 getter
  String get displayInfo {
    final speciesText = species == 'dog' ? '반려견' : species == 'cat' ? '반려묘' : species;
    final breedText = breed != null ? ' • $breed' : '';
    final bloodText = bloodType != null ? ' • $bloodType형' : '';
    return '$name ($speciesText • $age • ${weightKg}kg$breedText$bloodText)';
  }
}
