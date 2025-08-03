class HospitalPost {
  final String id;
  final String title;
  final String date;
  final List<TimeRange> timeRanges;
  final int types; // 1: 긴급, 2: 정기
  final String? bloodType;
  final String location;
  final String status;
  final String registrationDate;
  final int applicantCount;
  final String? description;

  HospitalPost({
    required this.id,
    required this.title,
    required this.date,
    required this.timeRanges,
    required this.types,
    this.bloodType,
    required this.location,
    required this.status,
    required this.registrationDate,
    required this.applicantCount,
    this.description,
  });

  factory HospitalPost.fromJson(Map<String, dynamic> json) {
    try {
      print('Parsing HospitalPost from JSON: $json');
      
      // 각 필드를 개별적으로 파싱하여 어디서 에러가 발생하는지 확인
      final id = json['id'] ?? '';
      print('id: $id (type: ${id.runtimeType})');
      
      final title = json['title'] ?? '';
      final date = json['date'] ?? '';
      
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
      
      final types = json['types'] ?? 2;
      print('types: $types (type: ${types.runtimeType})');
      
      final applicantCount = json['applicantCount'] ?? 0;
      print('applicantCount: $applicantCount (type: ${applicantCount.runtimeType})');
      
      return HospitalPost(
        id: id,
        title: title,
        date: date,
        timeRanges: timeRanges,
        types: types,
        bloodType: json['bloodType'],
        location: json['location'] ?? '',
        status: json['status'] ?? '',
        registrationDate: json['registrationDate'] ?? '',
        applicantCount: applicantCount,
        description: json['description'],
      );
    } catch (e, stackTrace) {
      print('Error parsing HospitalPost: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  bool get isUrgent => types == 1;
}

class TimeRange {
  final String? id;
  final String time;
  final int team;

  TimeRange({
    this.id,
    required this.time,
    required this.team,
  });

  factory TimeRange.fromJson(Map<String, dynamic> json) {
    try {
      print('Parsing TimeRange from JSON: $json');
      
      final id = json['id'];
      print('TimeRange id: $id (type: ${id?.runtimeType})');
      
      final time = json['time'] ?? '';
      print('TimeRange time: $time (type: ${time.runtimeType})');
      
      final team = json['team'] ?? 0;
      print('TimeRange team: $team (type: ${team.runtimeType})');
      
      return TimeRange(
        id: id,
        time: time,
        team: team,
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