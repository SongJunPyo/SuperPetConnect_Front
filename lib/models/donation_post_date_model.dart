// models/donation_post_date_model.dart

class DonationPostDate {
  final int? postDatesId; // PK
  final int postIdx; // FK to donation_posts table
  final DateTime donationDate; // 헌혈 예정 날짜

  DonationPostDate({
    this.postDatesId,
    required this.postIdx,
    required this.donationDate,
  });

  factory DonationPostDate.fromJson(Map<String, dynamic> json) {
    return DonationPostDate(
      postDatesId: json['post_dates_id'],
      postIdx: json['post_idx'],
      donationDate: DateTime.parse(json['donation_date']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (postDatesId != null) 'post_dates_id': postDatesId,
      'post_idx': postIdx,
      'donation_date': donationDate.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      if (postDatesId != null) 'post_dates_id': postDatesId,
      'post_idx': postIdx,
      'donation_date': donationDate.toIso8601String(),
    };
  }

  // 날짜를 포맷된 문자열로 반환
  String get formattedDate {
    return '${donationDate.year}년 ${donationDate.month}월 ${donationDate.day}일 ${donationDate.hour.toString().padLeft(2, '0')}:${donationDate.minute.toString().padLeft(2, '0')}';
  }

  // 시간만 반환
  String get timeOnly {
    return '${donationDate.hour.toString().padLeft(2, '0')}:${donationDate.minute.toString().padLeft(2, '0')}';
  }

  // 날짜만 반환 (년-월-일)
  String get dateOnly {
    return '${donationDate.year}-${donationDate.month.toString().padLeft(2, '0')}-${donationDate.day.toString().padLeft(2, '0')}';
  }
}
