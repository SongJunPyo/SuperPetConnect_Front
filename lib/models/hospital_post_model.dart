class HospitalPost {
  final int postIdx;
  final String title;
  final String nickname; // 병원 닉네임
  final String name; // 담당자 실명
  final String location;
  final List<TimeRange> timeRanges;
  final int types; // 0: 긴급, 1: 정기
  final String? bloodType; // 혈액형 정보
  final String content; // 게시글 내용
  final int status; // 0: 대기, 1: 승인, 2: 거절, 3: 마감
  final String createdDate;
  final int applicantCount;
  final String? description;
  final int animalType; // 0: 강아지, 1: 고양이
  final int? viewCount;

  HospitalPost({
    required this.postIdx,
    required this.title,
    required this.nickname,
    required this.name,
    required this.location,
    required this.timeRanges,
    required this.types,
    this.bloodType,
    required this.content,
    required this.status,
    required this.createdDate,
    required this.applicantCount,
    this.description,
    required this.animalType,
    this.viewCount,
  });

  factory HospitalPost.fromJson(Map<String, dynamic> json) {
    try {

      // 각 필드를 개별적으로 파싱하여 어디서 에러가 발생하는지 확인
      final postIdx = json['postIdx'] ?? json['id'] ?? 0;

      final title = json['title'] ?? '';
      final createdDate = json['createdDate'] ?? json['date'] ?? '';

      // timeRanges 파싱 시 타입 확인
      final List<TimeRange> timeRanges =
          json['timeRanges'] != null
              ? (json['timeRanges'] as List).map((e) {
                return TimeRange.fromJson(e);
              }).toList()
              : <TimeRange>[];

      final typesRaw = json['types'] ?? 1; // 기본값을 정기(1)로 변경
      final types =
          typesRaw is int ? typesRaw : int.tryParse(typesRaw.toString()) ?? 1;

      final statusRaw = json['status'] ?? 0; // 기본값 대기(0)
      final status =
          statusRaw is int
              ? statusRaw
              : int.tryParse(statusRaw.toString()) ?? 0;
      // animal_type이 문자열로 올 수 있으므로 변환 처리
      final animalTypeRaw = json['animalType'] ?? json['animal_type'] ?? 0;
      int animalType;
      if (animalTypeRaw is String) {
        animalType = (animalTypeRaw == 'dog') ? 0 : 1;
      } else if (animalTypeRaw is int) {
        animalType = animalTypeRaw;
      } else {
        animalType = 0; // 기본값: 강아지
      }
      final applicantCountRaw =
          json['applicantCount'] ?? json['applicant_count'] ?? 0;
      final applicantCount =
          applicantCountRaw is int
              ? applicantCountRaw
              : int.tryParse(applicantCountRaw.toString()) ?? 0;

      // ID 처리 - 병원 API는 string, 공개 API는 number
      int finalPostIdx;
      if (postIdx is String) {
        finalPostIdx = int.tryParse(postIdx) ?? 0;
      } else if (postIdx is int) {
        finalPostIdx = postIdx;
      } else {
        finalPostIdx = 0;
      }

      return HospitalPost(
        postIdx: finalPostIdx,
        title: title,
        nickname: json['nickname'] ?? json['hospitalNickname'] ?? '',
        name: json['userName'] ?? json['name'] ?? '', // userName 필드 추가
        createdDate: createdDate,
        timeRanges: timeRanges,
        types: types,
        bloodType: json['blood_type'] ?? json['bloodType'],
        location: json['location'] ?? '',
        content: json['content'] ?? '',
        status: status,
        applicantCount: applicantCount,
        description: json['description'] ?? json['descriptions'],
        animalType: animalType,
        viewCount: json['viewCount'] ?? json['view_count'],
      );
    } catch (e) {
      rethrow;
    }
  }

  bool get isUrgent => types == 0;

  String get typeText => types == 0 ? '긴급' : '정기';

  String get statusText {
    switch (status) {
      case 0:
        return '대기';
      case 1:
        return '승인';
      case 2:
        return '거절';
      case 3:
        return '마감';
      default:
        return '알 수 없음';
    }
  }

  String get animalTypeText => animalType == 0 ? '강아지' : '고양이';

  // API에서 사용하는 문자열 형태로 반환
  String get animalTypeString => animalType == 0 ? 'dog' : 'cat';

  String get displayBloodType {
    if (types == 0 && bloodType != null) {
      return bloodType!;
    }
    return '혈액형 무관';
  }
}

class TimeRange {
  final String? id;
  final String time;
  final String team; // 팀 필드를 String으로 변경 (A, B 형태)
  final String? date; // 날짜 필드 추가

  TimeRange({this.id, required this.time, required this.team, this.date});

  factory TimeRange.fromJson(Map<String, dynamic> json) {
    try {

      final id = json['id'];

      final time = json['time'] ?? '';

      final teamRaw = json['team'];
      final team = teamRaw != null ? teamRaw.toString() : 'A';

      final date = json['date'];

      return TimeRange(id: id?.toString(), time: time, team: team, date: date);
    } catch (e) {
      rethrow;
    }
  }
}

class DonationApplicant {
  final String id;
  final String userId;
  final String name;
  final String contact;
  final PetInfo petInfo;
  final String? lastDonationDate;
  final int donationCount;
  final String status;
  final String appliedDate;

  DonationApplicant({
    required this.id,
    required this.userId,
    required this.name,
    required this.contact,
    required this.petInfo,
    this.lastDonationDate,
    required this.donationCount,
    required this.status,
    required this.appliedDate,
  });

  factory DonationApplicant.fromJson(Map<String, dynamic> json) {
    return DonationApplicant(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      name: json['name'] ?? '',
      contact: json['contact'] ?? '',
      petInfo: PetInfo.fromJson(json['petInfo'] ?? {}),
      lastDonationDate: json['lastDonationDate'],
      donationCount: json['donationCount'] ?? 0,
      status: json['status'] ?? '',
      appliedDate: json['appliedDate'] ?? '',
    );
  }
}

class PetInfo {
  final String name;
  final String bloodType;
  final String species;

  PetInfo({required this.name, required this.bloodType, required this.species});

  factory PetInfo.fromJson(Map<String, dynamic> json) {
    return PetInfo(
      name: json['name'],
      bloodType: json['bloodType'],
      species: json['species'],
    );
  }

  String get displayText => '$name ($bloodType)';
}
