// models/donation_post_time_model.dart

import '../utils/app_constants.dart';
import '../utils/time_format_util.dart';

class DonationPostTime {
  final int? postTimesId; // PK
  final int postDatesIdx; // FK to donation_post_dates table
  final DateTime donationTime; // 헌혈 시간
  final int status; // 시간대 상태 (0: 모집중, 1: 마감)

  DonationPostTime({
    this.postTimesId,
    required this.postDatesIdx,
    required this.donationTime,
    this.status = 0, // 기본값: 모집중
  });

  factory DonationPostTime.fromJson(Map<String, dynamic> json) {
    return DonationPostTime(
      postTimesId: json['post_times_id'] ?? json['post_times_idx'],
      postDatesIdx: json['post_dates_idx'],
      donationTime: DateTime.parse(json['donation_time']),
      status: json['status'] ?? 0, // API 응답에서 status 파싱
    );
  }

  // 시간대가 마감되었는지 확인
  bool get isClosed => status == AppConstants.timeSlotClosed;

  // 시간대가 모집중인지 확인
  bool get isOpen => status == AppConstants.timeSlotOpen;

  Map<String, dynamic> toJson() {
    return {
      if (postTimesId != null) 'post_times_id': postTimesId,
      'post_dates_idx': postDatesIdx,
      'donation_time': donationTime.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      if (postTimesId != null) 'post_times_id': postTimesId,
      'post_dates_idx': postDatesIdx,
      'donation_time': donationTime.toIso8601String(),
    };
  }

  // 시간을 포맷된 문자열로 반환 (HH:mm)
  String get formattedTime {
    return '${donationTime.hour.toString().padLeft(2, '0')}:${donationTime.minute.toString().padLeft(2, '0')}';
  }

  // 전체 날짜와 시간을 포맷된 문자열로 반환
  String get formattedDateTime {
    return '${donationTime.year}년 ${donationTime.month}월 ${donationTime.day}일 $formattedTime';
  }

  // 날짜만 반환 (yyyy-MM-dd)
  String get dateOnly {
    return '${donationTime.year}-${donationTime.month.toString().padLeft(2, '0')}-${donationTime.day.toString().padLeft(2, '0')}';
  }

  /// 헌혈 시간 표시 (오전/오후 + 24시간 — TimeFormatUtils.formatTime 단일 진실).
  /// getter 이름은 호환성 유지를 위해 그대로 두되, 내부는 24시간 포맷.
  String get formatted12Hour {
    return TimeFormatUtils.formatTimeOfDate(donationTime);
  }
}

// 날짜와 시간을 함께 관리하는 복합 모델
class DonationDateWithTimes {
  final int postDatesId;
  final int postIdx;
  final DateTime donationDate;
  final List<DonationPostTime> times;

  DonationDateWithTimes({
    required this.postDatesId,
    required this.postIdx,
    required this.donationDate,
    required this.times,
  });

  factory DonationDateWithTimes.fromJson(Map<String, dynamic> json) {
    return DonationDateWithTimes(
      postDatesId: json['post_dates_id'],
      postIdx: json['post_idx'],
      donationDate: DateTime.parse(json['donation_date']),
      times:
          (json['times'] as List<dynamic>? ?? [])
              .map((timeJson) => DonationPostTime.fromJson(timeJson))
              .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'post_dates_id': postDatesId,
      'post_idx': postIdx,
      'donation_date': donationDate.toIso8601String(),
      'times': times.map((time) => time.toJson()).toList(),
    };
  }

  // 날짜를 포맷된 문자열로 반환
  String get formattedDate {
    return '${donationDate.year}년 ${donationDate.month}월 ${donationDate.day}일';
  }

  // 날짜만 반환 (yyyy-MM-dd)
  String get dateOnly {
    return '${donationDate.year}-${donationDate.month.toString().padLeft(2, '0')}-${donationDate.day.toString().padLeft(2, '0')}';
  }

  // 시간들을 정렬된 상태로 반환
  List<DonationPostTime> get sortedTimes {
    final sortedList = List<DonationPostTime>.from(times);
    sortedList.sort((a, b) => a.donationTime.compareTo(b.donationTime));
    return sortedList;
  }

  // 시간 개수
  int get timeCount => times.length;

  // 시간대 요약 (예: "09:00 - 17:00 (5개 시간)")
  String get timeSummary {
    if (times.isEmpty) {
      return '설정된 시간이 없습니다';
    }

    final sortedList = sortedTimes;
    if (sortedList.length == 1) {
      return sortedList.first.formattedTime;
    }

    final firstTime = sortedList.first.formattedTime;
    final lastTime = sortedList.last.formattedTime;
    return '$firstTime - $lastTime (${times.length}개 시간)';
  }
}

// 벌크 생성을 위한 요청 모델
class BulkDonationTimeRequest {
  final int postDatesIdx;
  final List<DateTime> donationTimes;

  BulkDonationTimeRequest({
    required this.postDatesIdx,
    required this.donationTimes,
  });

  Map<String, dynamic> toJson() {
    return {
      'post_dates_idx': postDatesIdx,
      'donation_times':
          donationTimes.map((time) => time.toIso8601String()).toList(),
    };
  }
}

// 날짜+시간 함께 생성을 위한 요청 모델
class DateTimeCreateRequest {
  final int postIdx;
  final DateTime donationDate;
  final List<DateTime> donationTimes;

  DateTimeCreateRequest({
    required this.postIdx,
    required this.donationDate,
    required this.donationTimes,
  });

  Map<String, dynamic> toJson() {
    return {
      'post_idx': postIdx,
      'donation_date': donationDate.toIso8601String(),
      'donation_times':
          donationTimes.map((time) => time.toIso8601String()).toList(),
    };
  }
}
