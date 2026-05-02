// 헌혈 신청 관련 모델 클래스들

class DonationApplication {
  final int appliedDonationIdx; // applied_donation_idx
  final int petIdx; // pet_idx
  final int postTimesIdx; // post_times_idx
  final int status; // status (0=대기, 1=승인, 2=미승인)
  final DonationPet pet;
  final DateTime donationTime; // donation_time
  final String donationDate; // donation_date
  final String postTitle; // post_title
  final String statusKr; // status_kr
  // 서버에서 추가 제공되는 시간대 정보
  final String? selectedDate; // selected_date
  final String? selectedTime; // selected_time
  final String? selectedTeam; // selected_team
  final String? appliedDate; // applied_date
  final String? userName; // user_name - 신청자 이름
  final String? userNickname; // user_nickname - 신청자 닉네임
  final String? userProfileImage; // 신청자 프로필 (대표 반려동물 사진)

  DonationApplication({
    required this.appliedDonationIdx,
    required this.petIdx,
    required this.postTimesIdx,
    required this.status,
    required this.pet,
    required this.donationTime,
    required this.donationDate,
    required this.postTitle,
    required this.statusKr,
    this.selectedDate,
    this.selectedTime,
    this.selectedTeam,
    this.appliedDate,
    this.userName,
    this.userNickname,
    this.userProfileImage,
  });

  factory DonationApplication.fromJson(Map<String, dynamic> json) {
    return DonationApplication(
      appliedDonationIdx: json['applied_donation_idx'] ?? 0,
      petIdx: json['pet_idx'] ?? 0,
      postTimesIdx: json['post_times_idx'] ?? 0,
      status: json['status'] ?? 0,
      pet: DonationPet.fromJson(json['pet'] ?? {}),
      donationTime: DateTime.parse(
        json['donation_time'] ?? DateTime.now().toIso8601String(),
      ),
      donationDate: json['donation_date'] ?? '',
      postTitle: json['post_title'] ?? '',
      statusKr: json['status_kr'] ?? '',
      selectedDate: json['selected_date'],
      selectedTime: json['selected_time'],
      selectedTeam: json['selected_team'],
      appliedDate: json['applied_date'],
      userName: json['user_name'] ?? json['name'],
      userNickname: json['user_nickname'] ?? json['nickname'],
      userProfileImage: json['user_profile_image'] ?? json['applicant_profile_image'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'applied_donation_idx': appliedDonationIdx,
      'pet_idx': petIdx,
      'post_times_idx': postTimesIdx,
      'status': status,
      'pet': pet.toJson(),
      'donation_time': donationTime.toIso8601String(),
      'donation_date': donationDate,
      'post_title': postTitle,
      'status_kr': statusKr,
      'selected_date': selectedDate,
      'selected_time': selectedTime,
      'selected_team': selectedTeam,
      'applied_date': appliedDate,
      'user_name': userName,
      'user_nickname': userNickname,
    };
  }
}

class DonationPet {
  final int petIdx; // pet_idx
  final String name;
  final String species;
  final String? breed;
  final String? bloodType;
  final double weightKg;
  final DateTime? birthDate;
  final String? profileImage;

  DonationPet({
    required this.petIdx,
    required this.name,
    required this.species,
    this.breed,
    this.bloodType,
    required this.weightKg,
    this.birthDate,
    this.profileImage,
  });

  factory DonationPet.fromJson(Map<String, dynamic> json) {
    return DonationPet(
      petIdx: int.tryParse((json['pet_idx'] ?? 0).toString()) ?? 0,
      name: json['name'] ?? '',
      species: json['species'] ?? '',
      breed: json['breed'],
      bloodType: json['blood_type'],
      weightKg: double.tryParse((json['weight_kg'] ?? 0.0).toString()) ?? 0.0,
      birthDate: json['birth_date'] != null
          ? DateTime.tryParse(json['birth_date'])
          : null,
      profileImage: json['profile_image'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pet_idx': petIdx,
      'name': name,
      'species': species,
      'breed': breed,
      'blood_type': bloodType,
      'weight_kg': weightKg,
      'birth_date': birthDate?.toIso8601String().split('T')[0],
    };
  }

  String get displayText => '$name ($bloodType)';
  String get speciesKorean =>
      (species == 'dog' || species == '강아지' || species == '개') ? '반려견' : '반려묘';
  String get age {
    if (birthDate == null) return '나이 미상';
    final now = DateTime.now();
    final totalMonths = (now.year - birthDate!.year) * 12 + (now.month - birthDate!.month);
    if (totalMonths < 12) return '$totalMonths개월';
    return '${totalMonths ~/ 12}살';
  }

  String get birthDateWithAge {
    if (birthDate == null) return '나이 미상';
    final dateStr = '${birthDate!.year}.${birthDate!.month.toString().padLeft(2, '0')}.${birthDate!.day.toString().padLeft(2, '0')}';
    return '$dateStr ($age)';
  }

  String get summaryLine {
    final parts = <String>[species];
    if (breed != null && breed!.isNotEmpty) parts.add(breed!);
    if (bloodType != null) parts.add(bloodType!);
    parts.add(age);
    parts.add('${weightKg}kg');
    return parts.join(' • ');
  }
}

enum ApplicationStatus {
  pending('pending', '대기'),
  approved('approved', '승인'),
  rejected('rejected', '미승인'),
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

  CreateApplicationRequest({required this.postId, required this.petId});

  Map<String, dynamic> toJson() {
    return {'post_idx': postId, 'pet_id': petId};
  }
}

// 신청 상태 업데이트 요청 모델
class UpdateApplicationRequest {
  final ApplicationStatus status;
  final String? hospitalNotes;

  UpdateApplicationRequest({required this.status, this.hospitalNotes});

  Map<String, dynamic> toJson() {
    return {
      'status': status.value,
      if (hospitalNotes != null) 'hospital_notes': hospitalNotes,
    };
  }
}

// 신청자 목록 응답 모델 - 새로운 API 구조
class ApplicationListResponse {
  final int postIdx;
  final String postTitle;
  final int totalApplications;
  final List<DonationApplication> applications;

  ApplicationListResponse({
    required this.postIdx,
    required this.postTitle,
    required this.totalApplications,
    required this.applications,
  });

  factory ApplicationListResponse.fromJson(Map<String, dynamic> json) {
    return ApplicationListResponse(
      postIdx: json['post_idx'] ?? 0,
      postTitle: json['post_title'] ?? '',
      totalApplications: json['total_applications'] ?? 0,
      applications:
          (json['applications'] as List? ?? [])
              .map((app) => DonationApplication.fromJson(app))
              .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'post_idx': postIdx,
      'post_title': postTitle,
      'total_applications': totalApplications,
      'applications': applications.map((app) => app.toJson()).toList(),
    };
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
