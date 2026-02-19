import 'package:flutter/foundation.dart';
import '../utils/app_constants.dart';
import 'donation_post_date_model.dart';

class DonationPost {
  final int postIdx;
  final String title;
  final String hospitalName;
  final String? hospitalNickname; // 병원 닉네임 추가 (nullable로 변경)
  final String location;
  final String description; // 설명 추가
  final String? contentDelta; // Delta JSON 리치 텍스트
  final int animalType;
  final String? emergencyBloodType;
  final int status;
  final int types;
  final int viewCount;
  final DateTime createdAt; // 게시글 작성일 (post_created_date)
  final DateTime? donationDate; // 실제 헌혈 예정일 (donation_date)
  final DateTime? donationTime; // 실제 헌혈 시간 (donation_time)
  final DateTime? updatedAt;
  final List<DonationPostDate>? donationDates; // 헌혈 날짜 목록 (기존 호환성)
  final Map<String, List<Map<String, dynamic>>>?
  availableDates; // 서버의 available_dates 구조
  final int applicantCount; // 신청자 수
  final String? userName; // 병원 담당자 이름

  DonationPost({
    required this.postIdx,
    required this.title,
    required this.hospitalName,
    this.hospitalNickname, // 병원 닉네임 추가 (nullable)
    required this.location,
    required this.description, // 설명 추가
    this.contentDelta, // Delta JSON 리치 텍스트
    required this.animalType,
    this.emergencyBloodType,
    required this.status,
    required this.types,
    required this.viewCount,
    required this.createdAt,
    this.donationDate,
    this.donationTime,
    this.updatedAt,
    this.donationDates,
    this.availableDates,
    required this.applicantCount,
    this.userName,
  });

  // 헌혈 예정일을 반환하는 getter (실제 헌혈 예정일 우선, 없으면 게시글 작성일)
  DateTime get date => donationDate ?? createdAt;

  // 게시글 작성일 표시용 getter
  DateTime get postCreatedDate => createdAt;

  // 실제 헌혈 일시 표시용 getter (날짜+시간 통합)
  DateTime? get actualDonationDateTime => donationTime ?? donationDate;

  factory DonationPost.fromJson(Map<String, dynamic> json) {
    // types 필드로 긴급/정기 판단: 0=긴급, 1=정기
    int typesValue = json['types'] ?? 1; // 기본값 정기(1)

    // 병원 정보 처리 - 여러 API 응답 구조 지원
    String hospitalName = '';
    String? hospitalNickname;
    String location = '';

    // 1. 최상위 레벨에서 직접 가져오기 (새로운 API 응답 방식)
    if (json['hospitalName'] != null &&
        json['hospitalName'].toString().trim().isNotEmpty) {
      hospitalName = json['hospitalName'].toString().trim();
    }

    if (json['location'] != null &&
        json['location'].toString().trim().isNotEmpty) {
      location = json['location'].toString().trim();
    }

    // 2. hospital 객체에서 가져오기 (기존 방식)
    if (json['hospital'] != null) {
      final hospital = json['hospital'] as Map<String, dynamic>;

      if (hospitalName.isEmpty) {
        hospitalName = hospital['name']?.toString() ?? '';
      }

      final nicknameValue = hospital['nickname'];
      if (nicknameValue != null &&
          nicknameValue.toString().trim().isNotEmpty &&
          nicknameValue.toString().toLowerCase() != 'null') {
        hospitalNickname = nicknameValue.toString().trim();
      }

      if (location.isEmpty) {
        location = hospital['address']?.toString() ?? '';
      }
    }

    // 3. 최상위 nickname, hospital_nickname 또는 hospitalNickname 필드 확인
    final topLevelNickname =
        json['nickname'] ??
        json['hospital_nickname'] ??
        json['hospitalNickname'];
    if (topLevelNickname != null &&
        topLevelNickname.toString().trim().isNotEmpty &&
        topLevelNickname.toString().toLowerCase() != 'null') {
      hospitalNickname = topLevelNickname.toString().trim();
    }

    // 닉네임이 없다면 hospitalName을 닉네임으로 사용 (임시 해결책)
    if (hospitalNickname == null &&
        hospitalName.isNotEmpty &&
        hospitalName != '병원') {
      hospitalNickname = hospitalName;
    }

    // 4. 기본값 설정
    if (hospitalName.isEmpty) {
      hospitalName = '병원';
    }
    if (location.isEmpty) {
      location = '주소 정보 없음';
    }

    // 새로운 서버 API 응답 구조에 따른 날짜 파싱
    DateTime? donationDate;
    DateTime? donationTime;

    // 1. 실제 헌혈 예정일 파싱 (donation_date - DATETIME 타입)
    if (json['donation_date'] != null &&
        json['donation_date'].toString().isNotEmpty &&
        json['donation_date'] != 'null') {
      try {
        donationDate = DateTime.parse(json['donation_date'].toString());
      } catch (e) {
        donationDate = null;
      }
    } else if (json['donationDate'] != null) {
      // 기존 호환성
      try {
        donationDate = DateTime.parse(json['donationDate'].toString());
      } catch (e) {
        donationDate = null;
      }
    }

    // 2. 실제 헌혈 시간 파싱 (donation_time - DATETIME 타입)
    if (json['donation_time'] != null &&
        json['donation_time'].toString().isNotEmpty &&
        json['donation_time'] != 'null') {
      try {
        donationTime = DateTime.parse(json['donation_time'].toString());
      } catch (e) {
        donationTime = null;
      }
    }

    // 3. 새로운 available_dates 구조 파싱 (단순한 Map 구조로 보관)
    Map<String, List<Map<String, dynamic>>>? availableDates;

    // camelCase (availableDates) 또는 snake_case (available_dates) 둘 다 확인
    final availableDatesField =
        json['availableDates'] ?? json['available_dates'];

    if (availableDatesField != null && availableDatesField is Map) {
      try {
        availableDates = <String, List<Map<String, dynamic>>>{};
        final datesMap = availableDatesField as Map<String, dynamic>;

        for (final dateEntry in datesMap.entries) {
          final dateStr = dateEntry.key; // "2025-09-16"
          final timeList = dateEntry.value as List<dynamic>;

          final timeSlots =
              timeList.map((timeJson) {
                return {
                  'post_times_idx': timeJson['post_times_idx'] ?? 0,
                  'time': timeJson['time'] ?? '',
                  'datetime': timeJson['datetime'] ?? '',
                };
              }).toList();

          availableDates[dateStr] = timeSlots;
        }
      } catch (e) {
        availableDates = null;
      }
    } else {
      // Fallback: timeRanges 배열을 available_dates로 변환
      if (json['timeRanges'] != null && json['timeRanges'] is List) {
        try {
          final timeRanges = json['timeRanges'] as List<dynamic>;
          if (timeRanges.isNotEmpty && donationDate != null) {
            // donationDate를 기준으로 단일 날짜 구조 생성
            final dateStr = donationDate.toIso8601String().split('T')[0];
            availableDates = <String, List<Map<String, dynamic>>>{};

            final timeSlots =
                timeRanges.map((timeRange) {
                  return {
                    'post_times_idx': timeRange['id'] ?? 0,
                    'time': timeRange['time'] ?? '',
                    'datetime':
                        '$dateStr${timeRange['time'] != null ? 'T${timeRange['time']}:00' : 'T00:00:00'}',
                  };
                }).toList();

            availableDates[dateStr] = timeSlots;
          }
        } catch (e) {
          // timeRanges 변환 실패 시 로그 출력
          debugPrint('Failed to convert timeRanges: $e');
        }
      }

      // 테스트용 임시 데이터 제거됨 - 서버 데이터만 사용
      availableDates = null;
    }

    // ID를 정수로 안전하게 변환
    int postIdx = 0;
    try {
      if (json['id'] != null) {
        if (json['id'] is String) {
          postIdx = int.tryParse(json['id']) ?? 0;
        } else if (json['id'] is int) {
          postIdx = json['id'];
        } else {
          postIdx = int.tryParse(json['id'].toString()) ?? 0;
        }
      }
    } catch (e) {
      postIdx = 0;
    }

    return DonationPost(
      postIdx: postIdx,
      title: json['title'] ?? '',
      hospitalName: hospitalName.isNotEmpty ? hospitalName : '병원',
      hospitalNickname: hospitalNickname, // 병원 닉네임 추가
      location: location,
      description:
          json['descriptions']?.toString() ??
          json['description']?.toString() ??
          '',
      contentDelta:
          json['content_delta']?.toString() ?? json['contentDelta']?.toString(),
      animalType:
          json['animalType'] is String
              ? (json['animalType'] == AppConstants.animalTypeDog
                  ? AppConstants.animalTypeDogNum
                  : AppConstants.animalTypeCatNum)
              : (json['animalType'] ?? AppConstants.animalTypeDogNum),
      emergencyBloodType:
          json['emergency_blood_type']?.toString() ??
          json['bloodType']?.toString(),
      status: _parseStatus(json['status']),
      types: typesValue,
      viewCount: _parseIntSafely(json['viewCount']) ?? 0,
      createdAt: _parseCreatedAt(json),
      donationDate: donationDate,
      donationTime: donationTime,
      updatedAt: null,
      availableDates: availableDates,
      donationDates: null,
      applicantCount:
          _parseIntSafely(json['applicantCount'] ?? json['applicant_count']) ??
          0,
      userName: json['userName']?.toString() ?? json['user_name']?.toString(),
    );
  }

  // 안전한 정수 파싱 헬퍼 메서드
  static int? _parseIntSafely(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return int.tryParse(value.toString());
  }

  // status 파싱 헬퍼 메서드 (string과 int 모두 처리)
  static int _parseStatus(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      // 공개 API의 string status를 int로 변환
      switch (value.toLowerCase()) {
        case '대기':
          return 0;
        case '모집중':
        case '승인':
          return 1;
        case '거절':
          return 2;
        case '모집마감':
        case '마감':
          return 3;
        case '완료':
          return 3;
        case '취소':
          return 4;
        default:
          return int.tryParse(value) ?? 0;
      }
    }
    return 0;
  }

  // 게시글 작성일자 파싱 헬퍼 메서드 (새로운 서버 구조 적용)
  static DateTime _parseCreatedAt(Map<String, dynamic> json) {
    // 작성일자 파싱 우선순위: post_created_date > created_at > createdAt > registrationDate
    if (json['post_created_date'] != null &&
        json['post_created_date'].toString().isNotEmpty &&
        json['post_created_date'] != 'null') {
      try {
        final parsedDate = DateTime.parse(json['post_created_date'].toString());
        return parsedDate;
      } catch (e) {
        // 날짜 파싱 실패 시 다음 필드 시도
        debugPrint('Failed to parse date: $e');
      }
    }

    if (json['created_at'] != null &&
        json['created_at'].toString().isNotEmpty &&
        json['created_at'] != 'null') {
      try {
        final parsedDate = DateTime.parse(json['created_at'].toString());
        return parsedDate;
      } catch (e) {
        // 날짜 파싱 실패 시 다음 필드 시도
        debugPrint('Failed to parse date: $e');
      }
    }

    if (json['createdAt'] != null &&
        json['createdAt'].toString().isNotEmpty &&
        json['createdAt'] != 'null') {
      try {
        final parsedDate = DateTime.parse(json['createdAt'].toString());
        return parsedDate;
      } catch (e) {
        // 날짜 파싱 실패 시 다음 필드 시도
        debugPrint('Failed to parse date: $e');
      }
    }

    if (json['registrationDate'] != null &&
        json['registrationDate'].toString().isNotEmpty &&
        json['registrationDate'] != 'null') {
      try {
        final parsedDate = DateTime.parse(json['registrationDate'].toString());
        return parsedDate;
      } catch (e) {
        // 날짜 파싱 실패 시 다음 필드 시도
        debugPrint('Failed to parse date: $e');
      }
    }

    return DateTime.now(); // fallback
  }

  // 혈액형 표시용 헬퍼 메서드
  String get displayBloodType {
    if (types == AppConstants.postTypeUrgent &&
        emergencyBloodType != null &&
        emergencyBloodType!.isNotEmpty) {
      return emergencyBloodType!;
    }
    return '혈액형 무관';
  }

  bool get isUrgent => types == AppConstants.postTypeUrgent;

  // 헌혈 유형 확인 (긴급/정기)
  bool get isRegular => !isUrgent;

  String get typeText => AppConstants.getPostTypeText(types);

  String get statusText => AppConstants.getPostStatusText(status);

  String get animalTypeText => AppConstants.getAnimalTypeText(animalType);

  // 헌혈 날짜 표시용 헬퍼 메서드
  String get donationDatesText {
    if (donationDates == null || donationDates!.isEmpty) {
      return '예정된 헌혈 날짜가 없습니다.';
    }

    final sortedDates = List<DonationPostDate>.from(donationDates!)
      ..sort((a, b) => a.donationDate.compareTo(b.donationDate));
    final dateTexts = sortedDates.map((date) => date.formattedDate).toList();

    if (dateTexts.length == 1) {
      return '헌혈 날짜: ${dateTexts.first}';
    } else if (dateTexts.length <= 3) {
      return '헌혈날짜: ${dateTexts.join(', ')}';
    } else {
      return '헌혈날짜: ${dateTexts.take(2).join(', ')} 외 ${dateTexts.length - 2}개';
    }
  }

  // 가장 빠른 헌혈 날짜 반환
  DateTime? get earliestDonationDate {
    if (donationDates == null || donationDates!.isEmpty) {
      return donationDate; // fallback으로 기존 donationDate 사용
    }

    final sortedDates = List<DonationPostDate>.from(donationDates!)
      ..sort((a, b) => a.donationDate.compareTo(b.donationDate));
    return sortedDates.first.donationDate;
  }
}
