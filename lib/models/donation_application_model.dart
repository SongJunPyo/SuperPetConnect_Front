// 헌혈 신청 관련 모델 클래스들

class DonationApplication {
  final int applicationId;
  final int postId;
  final String applicantEmail;
  final String applicantName;
  final String applicantPhone;
  final DonationPet pet;
  final ApplicationStatus status;
  final DateTime appliedDate;
  final DateTime? updatedDate;
  final String? hospitalNotes;
  final int donationCount;
  final String? lastDonationDate;

  DonationApplication({
    required this.applicationId,
    required this.postId,
    required this.applicantEmail,
    required this.applicantName,
    required this.applicantPhone,
    required this.pet,
    required this.status,
    required this.appliedDate,
    this.updatedDate,
    this.hospitalNotes,
    required this.donationCount,
    this.lastDonationDate,
  });

  factory DonationApplication.fromJson(Map<String, dynamic> json) {
    return DonationApplication(
      applicationId: json['application_id'],
      postId: json['post_id'] ?? 0,
      applicantEmail: json['applicant_email'] ?? '',
      applicantName: json['applicant_name'] ?? '',
      applicantPhone: json['applicant_phone'] ?? '',
      pet: DonationPet.fromJson(json['pet'] ?? {}),
      status: ApplicationStatus.fromString(json['status'] ?? 'pending'),
      appliedDate: DateTime.parse(json['applied_date']),
      updatedDate: json['updated_date'] != null 
          ? DateTime.parse(json['updated_date']) 
          : null,
      hospitalNotes: json['hospital_notes'],
      donationCount: json['donation_count'] ?? 0,
      lastDonationDate: json['last_donation_date'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'application_id': applicationId,
      'post_id': postId,
      'applicant_email': applicantEmail,
      'applicant_name': applicantName,
      'applicant_phone': applicantPhone,
      'pet': pet.toJson(),
      'status': status.value,
      'applied_date': appliedDate.toIso8601String(),
      'updated_date': updatedDate?.toIso8601String(),
      'hospital_notes': hospitalNotes,
      'donation_count': donationCount,
      'last_donation_date': lastDonationDate,
    };
  }
}

class DonationPet {
  final int petId;
  final String name;
  final String species;
  final String? breed;
  final String? bloodType;
  final double weightKg;
  final int ageNumber;

  DonationPet({
    required this.petId,
    required this.name,
    required this.species,
    this.breed,
    this.bloodType,
    required this.weightKg,
    required this.ageNumber,
  });

  factory DonationPet.fromJson(Map<String, dynamic> json) {
    return DonationPet(
      petId: json['pet_id'] ?? 0,
      name: json['name'] ?? '',
      species: json['species'] ?? '',
      breed: json['breed'],
      bloodType: json['blood_type'],
      weightKg: (json['weight_kg'] ?? 0.0).toDouble(),
      ageNumber: json['age_number'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pet_id': petId,
      'name': name,
      'species': species,
      'breed': breed,
      'blood_type': bloodType,
      'weight_kg': weightKg,
      'age_number': ageNumber,
    };
  }

  String get displayText => '$name ($bloodType)';
  String get speciesKorean => species == 'dog' ? '반려견' : '반려묘';
  String get age => ageNumber <= 0 ? '1살 미만' : '$ageNumber살';
}

enum ApplicationStatus {
  pending('pending', '대기'),
  approved('approved', '승인'),
  rejected('rejected', '거절'),
  completed('completed', '완료');

  const ApplicationStatus(this.value, this.displayName);

  final String value;
  final String displayName;

  static ApplicationStatus fromString(String value) {
    return ApplicationStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => ApplicationStatus.pending,
    );
  }
}

// 헌혈 신청 요청 모델
class CreateApplicationRequest {
  final int postId;
  final int petId;

  CreateApplicationRequest({
    required this.postId,
    required this.petId,
  });

  Map<String, dynamic> toJson() {
    return {
      'post_id': postId,
      'pet_id': petId,
    };
  }
}

// 신청 상태 업데이트 요청 모델
class UpdateApplicationRequest {
  final ApplicationStatus status;
  final String? hospitalNotes;

  UpdateApplicationRequest({
    required this.status,
    this.hospitalNotes,
  });

  Map<String, dynamic> toJson() {
    return {
      'status': status.value,
      if (hospitalNotes != null) 'hospital_notes': hospitalNotes,
    };
  }
}

// 신청자 목록 응답 모델
class ApplicationListResponse {
  final List<DonationApplication> applications;
  final int totalCount;

  ApplicationListResponse({
    required this.applications,
    required this.totalCount,
  });

  factory ApplicationListResponse.fromJson(Map<String, dynamic> json) {
    return ApplicationListResponse(
      applications: (json['applications'] as List)
          .map((app) => DonationApplication.fromJson(app))
          .toList(),
      totalCount: json['total_count'] ?? 0,
    );
  }
}

// 헌혈 이력 모델
class DonationHistory {
  final int historyId;
  final int applicationId;
  final int petId;
  final DateTime donationDate;
  final String hospitalEmail;
  final String hospitalName;
  final int? amountMl;
  final String? notes;
  final DateTime createdDate;

  DonationHistory({
    required this.historyId,
    required this.applicationId,
    required this.petId,
    required this.donationDate,
    required this.hospitalEmail,
    required this.hospitalName,
    this.amountMl,
    this.notes,
    required this.createdDate,
  });

  factory DonationHistory.fromJson(Map<String, dynamic> json) {
    return DonationHistory(
      historyId: json['history_id'],
      applicationId: json['application_id'],
      petId: json['pet_id'],
      donationDate: DateTime.parse(json['donation_date']),
      hospitalEmail: json['hospital_email'] ?? '',
      hospitalName: json['hospital_name'] ?? '',
      amountMl: json['amount_ml'],
      notes: json['notes'],
      createdDate: DateTime.parse(json['created_date']),
    );
  }
}