class Post {
  final int postIdx;
  final String createdDate;
  final String location;
  final int types;
  final String? emergencyBloodType;
  final String? descriptions;
  final List<TimeRange> timeRanges;
  final Hospital hospital;
  final int status;
  final int animalType;
  final int? viewCount;

  Post({
    required this.postIdx,
    required this.createdDate,
    required this.location,
    required this.types,
    this.emergencyBloodType,
    this.descriptions,
    required this.timeRanges,
    required this.hospital,
    required this.status,
    required this.animalType,
    this.viewCount,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    List<TimeRange> timeRanges = [];
    if (json['timeRanges'] != null) {
      timeRanges = List<TimeRange>.from(
        json['timeRanges'].map((x) => TimeRange.fromJson(x)),
      );
    }

    return Post(
      postIdx: json['postIdx'] ?? json['id'] ?? 0,
      createdDate: json['createdDate'] ?? json['date'] ?? '',
      location: json['location'] ?? '',
      types: json['types'] ?? (json['type'] == '긴급' ? 0 : 1),
      emergencyBloodType: json['emergencyBloodType'] ?? json['bloodType'],
      descriptions: json['descriptions'] ?? json['description'],
      timeRanges: timeRanges,
      hospital: Hospital.fromJson(json['user'] ?? json['hospital'] ?? {}),
      status: json['status'] ?? 0,
      animalType: json['animalType'] ?? json['animal_type'] ?? 0,
      viewCount: json['viewCount'] ?? json['view_count'],
    );
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
  
  String get displayBloodType {
    if (types == 0 && emergencyBloodType != null) {
      return emergencyBloodType!;
    }
    return '혈액형 무관';
  }
}

class TimeRange {
  final int id;
  final String? date;
  final String time;
  final int team;
  final int approved;

  TimeRange({
    required this.id,
    this.date,
    required this.time,
    required this.team,
    required this.approved,
  });

  factory TimeRange.fromJson(Map<String, dynamic> json) {
    return TimeRange(
      id: json['id'],
      date: json['date'],
      time: json['time'],
      team: json['team'],
      approved: json['approved'],
    );
  }
}

class Hospital {
  final int id;
  final int? hospitalIdx;
  final String? hospitalCode;
  final String name;
  final String email;
  final String phoneNumber;
  final String address;
  final bool? columnActive;

  Hospital({
    required this.id,
    this.hospitalIdx,
    this.hospitalCode,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.address,
    this.columnActive,
  });

  factory Hospital.fromJson(Map<String, dynamic> json) {
    return Hospital(
      id: json['id'],
      hospitalIdx: json['hospitalIdx'],
      hospitalCode: json['hospitalCode'],
      name: json['name'],
      email: json['email'],
      phoneNumber: json['phone_number'],
      address: json['address'],
      columnActive: json['column_active'],
    );
  }
}
