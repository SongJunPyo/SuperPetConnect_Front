// models/pet_model.dart

class Pet {
  final int? petId; // 등록 전에는 null일 수 있음
  final int guardianIdx; // 보호자 ID
  final String name;
  final String species;
  final String breed;
  final DateTime birthDate;
  final String bloodType;
  final double weightKg;
  final bool? pregnant;

  Pet({
    this.petId,
    required this.guardianIdx,
    required this.name,
    required this.species,
    required this.breed,
    required this.birthDate,
    required this.bloodType,
    required this.weightKg,
    this.pregnant,
  });

  // 생년월일로부터 나이를 계산하는 getter
  String get age {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age <= 0 ? '1살 미만' : '$age살';
  }

  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(
      petId: json['pet_id'],
      guardianIdx: json['guardian_idx'],
      name: json['name'],
      species: json['species'],
      breed: json['breed'],
      birthDate: DateTime.parse(json['birth_date']),
      bloodType: json['blood_type'],
      weightKg: (json['weight_kg'] as num).toDouble(),
      pregnant: json['pregnant'] == null ? null : (json['pregnant'] == 1),
    );
  }

  // API 통신을 위한 Map 변환 (나중에 사용)
  Map<String, dynamic> toMap() {
    return {
      'pet_id': petId,
      'guardian_idx': guardianIdx,
      'name': name,
      'species': species,
      'breed': breed,
      'birth_date':
          birthDate.toIso8601String().split('T')[0], // 'YYYY-MM-DD' 형식으로 전송
      'blood_type': bloodType,
      'weight_kg': weightKg,
      'pregnant': pregnant == null ? null : (pregnant! ? 1 : 0),
    };
  }
}
