class HospitalPost {
  final int postIdx;
  final String title;
  final String createdDate;
  final List<TimeRange> timeRanges;
  final int types; // 0: 긴급, 1: 정기
  final String? emergencyBloodType;
  final String location;
  final int status; // 0: 대기, 1: 승인, 2: 거절, 3: 마감
  final String registrationDate;
  final int applicantCount;
  final String? descriptions;
  final int animalType; // 0: 강아지, 1: 고양이
  final int? viewCount;
  // 새로운 필드들 추가
  final String? hospitalNickname;
  final String? hospitalName;
  final String? content;

  HospitalPost({
    required this.postIdx,
    required this.title,
    required this.createdDate,
    required this.timeRanges,
    required this.types,
    this.emergencyBloodType,
    required this.location,
    required this.status,
    required this.registrationDate,
    required this.applicantCount,
    this.descriptions,
    required this.animalType,
    this.viewCount,
    this.hospitalNickname,
    this.hospitalName,
    this.content,
  });

  factory HospitalPost.fromJson(Map<String, dynamic> json) {
    try {
      print('Parsing HospitalPost from JSON: $json');
      
      // 각 필드를 개별적으로 파싱하여 어디서 에러가 발생하는지 확인
      final postIdx = json['postIdx'] ?? json['id'] ?? 0;
      print('postIdx: $postIdx (type: ${postIdx.runtimeType})');
      
      final title = json['title'] ?? '';
      final createdDate = json['createdDate'] ?? json['date'] ?? '';
      
      // timeRanges 파싱 시 타입 확인
      print('timeRanges raw: ${json['timeRanges']} (type: ${json['timeRanges'].runtimeType})');
      final List<TimeRange> timeRanges = json['timeRanges'] != null 
          ? (json['timeRanges'] as List)
              .map((e) {
                print('Parsing timeRange: $e');
                return TimeRange.fromJson(e);
              })
              .toList()
          : <TimeRange>[];
      
      final typesRaw = json['types'] ?? 1; // 기본값을 정기(1)로 변경
      final types = typesRaw is int ? typesRaw : int.tryParse(typesRaw.toString()) ?? 1;
      print('types: $types (type: ${types.runtimeType})');
      
      final statusRaw = json['status'] ?? 0; // 기본값 대기(0)
      final status = statusRaw is int ? statusRaw : int.tryParse(statusRaw.toString()) ?? 0;
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
      final applicantCountRaw = json['applicantCount'] ?? json['applicant_count'] ?? 0;
      final applicantCount = applicantCountRaw is int ? applicantCountRaw : int.tryParse(applicantCountRaw.toString()) ?? 0;
      print('applicantCount: $applicantCount (type: ${applicantCount.runtimeType})');
      
      return HospitalPost(
        postIdx: postIdx is int ? postIdx : int.tryParse(postIdx.toString()) ?? 0,
        title: title,
        createdDate: createdDate,
        timeRanges: timeRanges,
        types: types,
        emergencyBloodType: json['emergencyBloodType'] ?? json['emergency_blood_type'] ?? json['bloodType'],
        location: json['location'] ?? '',
        status: status,
        registrationDate: json['registrationDate'] ?? '',
        applicantCount: applicantCount,
        descriptions: json['descriptions'] ?? json['description'],
        animalType: animalType,
        viewCount: json['viewCount'] ?? json['view_count'],
        hospitalNickname: json['hospital_nickname'],
        hospitalName: json['hospital_name'],
        content: json['content'],
      );
    } catch (e, stackTrace) {
      print('Error parsing HospitalPost: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  bool get isUrgent => types == 0;
  
  String get typeText => types == 0 ? '긴급' : '정기';
  
  String get statusText {
    switch (status) {
      case 0: return '대기';
      case 1: return '승인';
      case 2: return '거절';
      case 3: return '마감';
      default: return '알 수 없음';
    }
  }
  
  String get animalTypeText => animalType == 0 ? '강아지' : '고양이';
  
  // API에서 사용하는 문자열 형태로 반환
  String get animalTypeString => animalType == 0 ? 'dog' : 'cat';
  
  String get displayBloodType {
    if (types == 0 && emergencyBloodType != null) {
      return emergencyBloodType!;
    }
    return '혈액형 무관';
  }
}

class TimeRange {
  final String? id;
  final String time;
  final String team; // 팀 필드를 String으로 변경 (A, B 형태)
  final String? date; // 날짜 필드 추가

  TimeRange({
    this.id,
    required this.time,
    required this.team,
    this.date,
  });

  factory TimeRange.fromJson(Map<String, dynamic> json) {
    try {
      print('Parsing TimeRange from JSON: $json');
      
      final id = json['id'];
      print('TimeRange id: $id (type: ${id?.runtimeType})');
      
      final time = json['time'] ?? '';
      print('TimeRange time: $time (type: ${time.runtimeType})');
      
      final teamRaw = json['team'];
      final team = teamRaw != null ? teamRaw.toString() : 'A';
      print('TimeRange team: $team (type: ${team.runtimeType})');
      
      final date = json['date'];
      print('TimeRange date: $date (type: ${date?.runtimeType})');
      
      return TimeRange(
        id: id?.toString(),
        time: time,
        team: team,
        date: date,
      );
    } catch (e, stackTrace) {
      print('Error parsing TimeRange: $e');
      print('Stack trace: $stackTrace');
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

  PetInfo({
    required this.name,
    required this.bloodType,
    required this.species,
  });

  factory PetInfo.fromJson(Map<String, dynamic> json) {
    return PetInfo(
      name: json['name'],
      bloodType: json['bloodType'],
      species: json['species'],
    );
  }

  String get displayText => '$name ($bloodType)';
}