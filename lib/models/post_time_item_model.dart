// lib/models/post_time_item_model.dart

/// 시간대별로 분해된 게시글 아이템
/// 서버 API /api/hospital/post-times의 응답을 파싱하는 모델
class PostTimeItem {
  final int postTimesIdx;
  final int postIdx;
  final String postTitle;
  final String? postDescription;
  final int postTypes; // 0: 긴급, 1: 정기
  final int postStatus;
  final String date;
  final String time;
  final String team;
  final int? applicantIdx;
  final int? applicantStatus;
  final String? applicantNickname;
  final int? petIdx;
  final String? petName;
  final String? bloodType;
  final int? animalType;
  final String location;
  final String hospitalNickname;
  final String hospitalName;
  final String createdDate;
  final String updatedDate;

  PostTimeItem({
    required this.postTimesIdx,
    required this.postIdx,
    required this.postTitle,
    this.postDescription,
    required this.postTypes,
    required this.postStatus,
    required this.date,
    required this.time,
    required this.team,
    this.applicantIdx,
    this.applicantStatus,
    this.applicantNickname,
    this.petIdx,
    this.petName,
    this.bloodType,
    this.animalType,
    required this.location,
    required this.hospitalNickname,
    required this.hospitalName,
    required this.createdDate,
    required this.updatedDate,
  });

  factory PostTimeItem.fromJson(Map<String, dynamic> json) {
    return PostTimeItem(
      postTimesIdx: json['post_times_idx'] as int,
      postIdx: json['post_idx'] as int,
      postTitle: json['post_title'] as String,
      postDescription: json['post_description'] as String?,
      postTypes: json['post_types'] as int,
      postStatus: json['post_status'] as int,
      date: json['date'] as String,
      time: json['time'] as String,
      team: json['team'] as String,
      applicantIdx: json['applicant_idx'] as int?,
      applicantStatus: json['applicant_status'] as int?,
      applicantNickname: json['applicant_nickname'] as String?,
      petIdx: json['pet_idx'] as int?,
      petName: json['pet_name'] as String?,
      bloodType: json['blood_type'] as String?,
      animalType: json['animal_type'] as int?,
      location: json['location'] as String,
      hospitalNickname: json['hospital_nickname'] as String,
      hospitalName: json['hospital_name'] as String,
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
      'location': location,
      'hospital_nickname': hospitalNickname,
      'hospital_name': hospitalName,
      'created_date': createdDate,
      'updated_date': updatedDate,
    };
  }

  // 긴급 여부
  bool get isUrgent => postTypes == 0;

  // 타입 텍스트
  String get typeText => isUrgent ? '긴급' : '정기';

  // 동물 타입 텍스트
  String? get animalTypeText {
    if (animalType == null) return null;
    return animalType == 0 ? '강아지' : '고양이';
  }

  // 날짜와 시간을 합친 표시 문자열
  String get dateTimeDisplay => '$date $time';

  // 신청자 상태 텍스트
  String? get applicantStatusText {
    if (applicantStatus == null) return null;
    switch (applicantStatus) {
      case 0:
        return '대기';
      case 1:
        return '승인';
      case 2:
        return '거절';
      case 3:
        return '마감';
      case 4:
        return '취소';
      case 5:
        return '완료대기';
      case 6:
        return '중단대기';
      case 7:
        return '완료';
      default:
        return '알 수 없음';
    }
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
