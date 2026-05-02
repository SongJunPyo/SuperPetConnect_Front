// lib/models/post_time_item_model.dart

import '../utils/app_constants.dart';
import 'applied_donation_model.dart';

/// 시간대별로 분해된 게시글 아이템
/// 서버 API /api/hospital/post-times의 응답을 파싱하는 모델
class PostTimeItem {
  final int postTimesIdx;
  final int postIdx;
  final String postTitle;
  final String? postDescription;
  final String? contentDelta; // Delta JSON 리치 텍스트
  final int postTypes; // 0: 긴급, 1: 정기
  final int postStatus;
  final String date;
  final String time;
  final String team;
  final int? applicantIdx;
  final int? applicantStatus;
  final String? applicantNickname;
  final String? applicantName;
  final String? applicantPhone; // 보호자 연락처 (모집마감 선정자 시트용, 2026-05-02 BE 추가)
  final int? petIdx;
  final String? petName;
  final String? petBirthDate;
  final String? petBreed;
  final double? petWeightKg;
  final int? petSex; // 0=암컷, 1=수컷 (PetSex enum)
  final bool? petIsNeutered;
  final String? petNeuteredDate; // YYYY-MM-DD
  final bool? petVaccinated;
  final bool? petHasPreventiveMedication;
  final bool? petHasDisease;
  final String? petPrevDonationDate; // YYYY-MM-DD
  final int? petPregnancyBirthStatus; // 0=NONE, 1=PREGNANT, 2=POST_BIRTH
  final String? petLastPregnancyEndDate; // YYYY-MM-DD
  final String? bloodType;
  final int? animalType;
  final String location;
  final String hospitalNickname;
  final String hospitalName;
  final double? bloodVolumeMl; // 헌혈량 (mL) - 헌혈완료 시간대에서만 사용
  final String? hospitalProfileImage;
  final String? petProfileImage;
  final String? applicantProfileImage; // 신청자 프로필 (대표 반려동물 사진)
  final String createdDate;
  final String updatedDate;

  PostTimeItem({
    required this.postTimesIdx,
    required this.postIdx,
    required this.postTitle,
    this.postDescription,
    this.contentDelta,
    required this.postTypes,
    required this.postStatus,
    required this.date,
    required this.time,
    required this.team,
    this.applicantIdx,
    this.applicantStatus,
    this.applicantNickname,
    this.applicantName,
    this.applicantPhone,
    this.petIdx,
    this.petName,
    this.petBirthDate,
    this.petBreed,
    this.petWeightKg,
    this.petSex,
    this.petIsNeutered,
    this.petNeuteredDate,
    this.petVaccinated,
    this.petHasPreventiveMedication,
    this.petHasDisease,
    this.petPrevDonationDate,
    this.petPregnancyBirthStatus,
    this.petLastPregnancyEndDate,
    this.bloodType,
    this.animalType,
    this.bloodVolumeMl,
    required this.location,
    required this.hospitalNickname,
    required this.hospitalName,
    this.hospitalProfileImage,
    this.petProfileImage,
    this.applicantProfileImage,
    required this.createdDate,
    required this.updatedDate,
  });

  factory PostTimeItem.fromJson(Map<String, dynamic> json) {
    return PostTimeItem(
      postTimesIdx: json['post_times_idx'] as int,
      postIdx: json['post_idx'] as int,
      postTitle: json['post_title'] as String,
      postDescription: json['post_description'] as String?,
      contentDelta: json['content_delta'] as String?,
      postTypes: json['post_types'] as int,
      postStatus: json['post_status'] as int,
      date: json['date'] as String,
      time: json['time'] as String,
      team: json['team'] as String,
      applicantIdx: json['applicant_idx'] as int?,
      applicantStatus: json['applicant_status'] as int?,
      applicantNickname: json['applicant_nickname'] as String?,
      applicantName: json['applicant_name'] as String?,
      applicantPhone: json['applicant_phone'] as String?,
      petIdx: json['pet_idx'] as int?,
      petName: json['pet_name'] as String?,
      petBirthDate: json['pet_birth_date'] as String?,
      petBreed: json['pet_breed'] as String?,
      petWeightKg: (json['pet_weight_kg'] as num?)?.toDouble(),
      petSex: json['pet_sex'] as int?,
      petIsNeutered: json['pet_is_neutered'] as bool?,
      petNeuteredDate: json['pet_neutered_date'] as String?,
      petVaccinated: json['pet_vaccinated'] as bool?,
      petHasPreventiveMedication: json['pet_has_preventive_medication'] as bool?,
      petHasDisease: json['pet_has_disease'] as bool?,
      petPrevDonationDate: json['pet_prev_donation_date'] as String?,
      petPregnancyBirthStatus: json['pet_pregnancy_birth_status'] as int?,
      petLastPregnancyEndDate: json['pet_last_pregnancy_end_date'] as String?,
      bloodType: json['blood_type'] as String?,
      animalType: json['animal_type'] as int?,
      bloodVolumeMl: (json['blood_volume_ml'] ?? json['blood_volume'])?.toDouble(),
      location: json['location'] as String,
      hospitalNickname: json['hospital_nickname'] as String,
      hospitalName: json['hospital_name'] as String,
      hospitalProfileImage: json['hospital_profile_image'] as String?,
      petProfileImage: json['pet_profile_image'] as String?,
      applicantProfileImage: json['applicant_profile_image'] as String?,
      createdDate: json['created_date'] as String,
      updatedDate: json['updated_date'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'post_times_idx': postTimesIdx,
      'post_idx': postIdx,
      'post_title': postTitle,
      'post_description': postDescription,
      'content_delta': contentDelta,
      'post_types': postTypes,
      'post_status': postStatus,
      'date': date,
      'time': time,
      'team': team,
      'applicant_idx': applicantIdx,
      'applicant_status': applicantStatus,
      'applicant_nickname': applicantNickname,
      'pet_idx': petIdx,
      'pet_name': petName,
      'blood_type': bloodType,
      'animal_type': animalType,
      'blood_volume_ml': bloodVolumeMl,
      'location': location,
      'hospital_nickname': hospitalNickname,
      'hospital_name': hospitalName,
      'created_date': createdDate,
      'updated_date': updatedDate,
    };
  }

  // 긴급 여부
  bool get isUrgent => postTypes == AppConstants.postTypeUrgent;

  // 타입 텍스트
  String get typeText => AppConstants.getPostTypeText(postTypes);

  // 동물 타입 텍스트
  String? get animalTypeText {
    if (animalType == null) return null;
    return AppConstants.getAnimalTypeText(animalType!);
  }

  // 날짜와 시간을 합친 표시 문자열
  String get dateTimeDisplay => '$date $time';

  // 신청자 상태 텍스트
  String? get applicantStatusText {
    if (applicantStatus == null) return null;
    return AppliedDonationStatus.getStatusText(applicantStatus!);
  }
}

/// 모집거절 게시글 모델
class RejectedPost {
  final int postIdx;
  final String title;
  final String? description;
  final String? contentDelta; // Delta JSON 리치 텍스트
  final int types;
  final int status;
  final String? rejectionReason;
  final String createdDate;
  final String? rejectedDate;

  RejectedPost({
    required this.postIdx,
    required this.title,
    this.description,
    this.contentDelta,
    required this.types,
    required this.status,
    this.rejectionReason,
    required this.createdDate,
    this.rejectedDate,
  });

  factory RejectedPost.fromJson(Map<String, dynamic> json) {
    return RejectedPost(
      postIdx: json['post_idx'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      contentDelta: json['content_delta'] as String?,
      types: json['types'] as int,
      status: json['status'] as int,
      rejectionReason: json['rejection_reason'] as String?,
      createdDate: json['created_date'] as String,
      rejectedDate: json['rejected_date'] as String?,
    );
  }

  // 긴급 여부
  bool get isUrgent => types == 0;

  // 타입 텍스트
  String get typeText => isUrgent ? '긴급' : '정기';
}
