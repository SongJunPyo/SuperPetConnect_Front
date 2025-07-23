class Post {
  final int id;
  final String date;
  final String location;
  final String type;
  final String bloodType;
  final String? description;
  final List<TimeRange> timeRanges;
  final Hospital hospital;
  final bool isUrgent;

  Post({
    required this.id,
    required this.date,
    required this.location,
    required this.type,
    required this.bloodType,
    this.description,
    required this.timeRanges,
    required this.hospital,
    required this.isUrgent,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    List<TimeRange> timeRanges = [];
    if (json['timeRanges'] != null) {
      timeRanges = List<TimeRange>.from(
        json['timeRanges'].map((x) => TimeRange.fromJson(x)),
      );
    }

    return Post(
      id: json['id'],
      date: json['date'],
      location: json['location'],
      type: json['type'],
      bloodType: json['bloodType'],
      description: json['description'],
      timeRanges: timeRanges,
      hospital: Hospital.fromJson(json['user']),
      isUrgent: json['type'] == '긴급',
    );
  }
}

class TimeRange {
  final int id;
  final String time;
  final int team;
  final int approved;

  TimeRange({
    required this.id,
    required this.time,
    required this.team,
    required this.approved,
  });

  factory TimeRange.fromJson(Map<String, dynamic> json) {
    return TimeRange(
      id: json['id'],
      time: json['time'],
      team: json['team'],
      approved: json['approved'],
    );
  }
}

class Hospital {
  final int id;
  final String name;
  final String email;
  final String phoneNumber;
  final String address;

  Hospital({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.address,
  });

  factory Hospital.fromJson(Map<String, dynamic> json) {
    return Hospital(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      phoneNumber: json['phone_number'],
      address: json['address'],
    );
  }
}
