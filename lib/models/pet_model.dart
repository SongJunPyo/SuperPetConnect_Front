// models/pet_model.dart

class Pet {
  final int? petId; // 등록 전에는 null일 수 있음
  final int guardianIdx; // 보호자 ID
  final String name;
  final String species;
  final String? breed;
  final int ageNumber; // DB의 age_number 필드
  final String? bloodType;
  final double weightKg;
  final bool pregnant;
  final bool? vaccinated; // 백신 접종 여부 (DB에서 NULL 허용)
  final bool? hasDisease; // 질병 이력 여부 (DB에서 NULL 허용)
  final bool? hasBirthExperience; // 출산 경험 여부 (DB에서 NULL 허용)

  Pet({
    this.petId,
    required this.guardianIdx,
    required this.name,
    required this.species,
    this.breed,
    required this.ageNumber,
    this.bloodType,
    required this.weightKg,
    required this.pregnant,
    this.vaccinated,
    this.hasDisease,
    this.hasBirthExperience,
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
      petId: json['pet_id'],
      guardianIdx: json['guardian_idx'] ?? 0,
      name: json['name'] ?? '',
      species: json['species'] ?? '',
      breed: json['breed'],
      ageNumber: parseAge(json['age_number']),
      bloodType: json['blood_type'],
      weightKg: parseWeight(json['weight_kg']),
      pregnant: json['pregnant'] == null ? false : (json['pregnant'] == 1),
      vaccinated: json['vaccinated'] == null ? null : (json['vaccinated'] == 1),
      hasDisease: json['has_disease'] == null ? null : (json['has_disease'] == 1),
      hasBirthExperience: json['has_birth_experience'] == null ? null : (json['has_birth_experience'] == 1),
    );
  }

  // API 통신을 위한 Map 변환
  Map<String, dynamic> toMap() {
    return {
      'pet_id': petId,
      'guardian_idx': guardianIdx,
      'name': name,
      'species': species,
      'breed': breed,
      'age_number': ageNumber,
      'blood_type': bloodType,
      'weight_kg': weightKg,
      'pregnant': pregnant ? 1 : 0,
      'vaccinated': vaccinated == null ? null : (vaccinated! ? 1 : 0),
      'has_disease': hasDisease == null ? null : (hasDisease! ? 1 : 0),
      'has_birth_experience': hasBirthExperience == null ? null : (hasBirthExperience! ? 1 : 0),
    };
  }
}
