import 'package:flutter/foundation.dart';
import '../utils/app_constants.dart';

/// 통합 헌혈 게시글 모델 (UnifiedPostResponse 기반)
///
/// 서버 API 통일 작업 2단계부터 사용될 통합 모델입니다.
/// 모든 헌혈 게시글 API(/public/posts, /hospital/posts, /posts, /api/admin/posts)가
/// 동일한 응답 형식으로 통합됩니다.
///
/// 주요 변경사항 (기존 DonationPost, HospitalPost, Post 대비):
/// - id: int 타입으로 통일 (기존: int 또는 String)
/// - status: int + statusLabel(한글) 추가
/// - animalType: "dog"/"cat" 문자열 (기존: int 0/1)
/// - 수혈환자 정보: camelCase 통일 (patientName, breed, age, diagnosis)
/// - contentDelta: camelCase 통일 (기존: content_delta)
/// - 병원 정보: flat + camelCase (hospitalName, hospitalNickname, location)
class UnifiedPostModel {
  // ===== 식별 정보 =====
  final int id; // 게시글 ID (모든 API에서 int 통일)
  final String title; // 제목
  final int types; // 0: 긴급, 1: 정기
  final int status; // 0: 대기, 1: 모집중, 2: 거절, 3: 모집마감, 4: 완료

  // ===== 한글 라벨 (서버에서 제공, 2단계부터) =====
  final String? statusLabel; // status의 한글 표현 (예: "모집중")
  final String? typesLabel; // types의 한글 표현 (예: "긴급")

  // ===== 동물/혈액 정보 =====
  final String animalType; // "dog" 또는 "cat" (camelCase 통일)
  final String? bloodType; // 긴급 헌혈 혈액형 (null 가능)

  // ===== 수혈환자 정보 (긴급일 때만, camelCase 통일) =====
  final String? patientName; // 환자 이름 (기존: patient_name)
  final String? breed; // 견종/묘종
  final int? age; // 나이
  final String? diagnosis; // 병명/증상

  // ===== 본문 =====
  final String description; // 본문 텍스트 (plain text)
  final String? contentDelta; // 리치 텍스트 Delta JSON (기존: content_delta)

  // ===== 이미지 =====
  final List<PostImage>? images; // 게시글 이미지 목록

  // ===== 시간 정보 =====
  final List<TimeRange>? timeRanges; // 시간대 목록 (legacy 호환)
  final Map<String, List<Map<String, dynamic>>>?
      availableDates; // 날짜별 그룹화

  // ===== 통계 =====
  final int viewCount; // 조회수
  final int applicantCount; // 신청자 수

  // ===== 날짜 =====
  final DateTime createdDate; // 게시글 작성일 (ISO 8601)
  final DateTime? donationDate; // 첫 번째 헌혈 예정일

  // ===== 병원 정보 (flat, camelCase 통일) =====
  final String hospitalName; // 병원 표시이름
  final String? hospitalNickname; // 병원 닉네임
  final String? hospitalCode; // 병원 코드
  final String location; // 병원 주소

  UnifiedPostModel({
    required this.id,
    required this.title,
    required this.types,
    required this.status,
    this.statusLabel,
    this.typesLabel,
    required this.animalType,
    this.bloodType,
    this.patientName,
    this.breed,
    this.age,
    this.diagnosis,
    required this.description,
    this.contentDelta,
    this.images,
    this.timeRanges,
    this.availableDates,
    required this.viewCount,
    required this.applicantCount,
    required this.createdDate,
    this.donationDate,
    required this.hospitalName,
    this.hospitalNickname,
    this.hospitalCode,
    required this.location,
  });

  /// JSON에서 UnifiedPostModel 생성
  ///
  /// 서버 API 통일 2단계 이후 응답 형식:
  /// - camelCase 필드명 사용
  /// - int 타입 통일
  /// - 한글 라벨 제공
  ///
  /// 하위 호환성을 위해 snake_case 및 기존 필드명도 fallback으로 지원합니다.
  factory UnifiedPostModel.fromJson(Map<String, dynamic> json) {
    try {
      // ===== ID 파싱 (int 통일, 기존 String도 지원) =====
      final idRaw = json['id'];
      int postId;
      if (idRaw is int) {
        postId = idRaw;
      } else if (idRaw is String) {
        postId = int.tryParse(idRaw) ?? 0;
      } else {
        postId = 0;
      }

      // ===== status 파싱 (int 또는 String) =====
      int statusValue = _parseStatus(json['status']);

      // ===== types 파싱 (int) =====
      int typesValue = json['types'] ?? 1; // 기본값: 정기(1)

      // ===== animalType 파싱 (String 통일) =====
      String animalTypeValue = _parseAnimalType(json['animalType']);

      // ===== 날짜 파싱 =====
      DateTime createdAt = _parseCreatedDate(json);
      DateTime? donationDate = _parseDonationDate(json);

      // ===== 병원 정보 파싱 (flat 우선, nested 지원) =====
      String hospitalName = '';
      String? hospitalNickname;
      String location = '';
      String? hospitalCode;

      // 1. flat 구조 (통합 API)
      if (json['hospitalName'] != null &&
          json['hospitalName'].toString().trim().isNotEmpty) {
        hospitalName = json['hospitalName'].toString().trim();
      }
      if (json['location'] != null &&
          json['location'].toString().trim().isNotEmpty) {
        location = json['location'].toString().trim();
      }
      if (json['hospitalNickname'] != null &&
          json['hospitalNickname'].toString().trim().isNotEmpty) {
        hospitalNickname = json['hospitalNickname'].toString().trim();
      }
      if (json['hospitalCode'] != null) {
        hospitalCode = json['hospitalCode'].toString().trim();
      }

      // 2. nested 구조 fallback (기존 API 호환)
      if (json['hospital'] != null && json['hospital'] is Map) {
        final hospital = json['hospital'] as Map<String, dynamic>;
        if (hospitalName.isEmpty) {
          hospitalName = hospital['name']?.toString() ?? '';
        }
        if (location.isEmpty) {
          location = hospital['address']?.toString() ?? '';
        }
        if (hospitalNickname == null && hospital['nickname'] != null) {
          hospitalNickname = hospital['nickname'].toString().trim();
        }
        if (hospitalCode == null && hospital['hospitalCode'] != null) {
          hospitalCode = hospital['hospitalCode'].toString().trim();
        }
      }

      // 3. snake_case fallback
      hospitalName = hospitalName.isEmpty
          ? (json['hospital_name']?.toString() ?? '병원')
          : hospitalName;
      location = location.isEmpty
          ? (json['location']?.toString() ?? '주소 정보 없음')
          : location;

      // ===== 이미지 파싱 =====
      List<PostImage>? imageList;
      if (json['images'] != null && json['images'] is List) {
        imageList = (json['images'] as List)
            .map((img) => PostImage.fromJson(img))
            .toList();
      }

      // ===== timeRanges 파싱 (legacy) =====
      List<TimeRange>? timeRangeList;
      if (json['timeRanges'] != null && json['timeRanges'] is List) {
        timeRangeList = (json['timeRanges'] as List)
            .map((tr) => TimeRange.fromJson(tr))
            .toList();
      }

      // ===== availableDates 파싱 =====
      Map<String, List<Map<String, dynamic>>>? availableDatesMap;
      final availableDatesField =
          json['availableDates'] ?? json['available_dates'];
      if (availableDatesField != null && availableDatesField is Map) {
        availableDatesMap = <String, List<Map<String, dynamic>>>{};
        final datesMap = availableDatesField as Map<String, dynamic>;

        for (final dateEntry in datesMap.entries) {
          final dateStr = dateEntry.key;
          final timeList = dateEntry.value as List<dynamic>;

          final timeSlots = timeList.map((timeJson) {
            return {
              'post_times_idx': timeJson['post_times_idx'] ?? 0,
              'time': timeJson['time'] ?? '',
              'datetime': timeJson['datetime'] ?? '',
            };
          }).toList();

          availableDatesMap[dateStr] = timeSlots;
        }
      }

      return UnifiedPostModel(
        id: postId,
        title: json['title']?.toString() ?? '',
        types: typesValue,
        status: statusValue,
        statusLabel: json['statusLabel']?.toString(),
        typesLabel: json['typesLabel']?.toString(),
        animalType: animalTypeValue,
        bloodType: json['bloodType']?.toString() ??
            json['blood_type']?.toString() ??
            json['emergencyBloodType']?.toString() ??
            json['emergency_blood_type']?.toString(),
        patientName: json['patientName']?.toString() ??
            json['patient_name']?.toString(),
        breed: json['breed']?.toString(),
        age: _parseIntSafely(json['age']),
        diagnosis: json['diagnosis']?.toString(),
        description: json['description']?.toString() ??
            json['descriptions']?.toString() ??
            '',
        contentDelta: json['contentDelta']?.toString() ??
            json['content_delta']?.toString(),
        images: imageList,
        timeRanges: timeRangeList,
        availableDates: availableDatesMap,
        viewCount: _parseIntSafely(json['viewCount'] ?? json['view_count']) ?? 0,
        applicantCount:
            _parseIntSafely(json['applicantCount'] ?? json['applicant_count']) ??
                0,
        createdDate: createdAt,
        donationDate: donationDate,
        hospitalName: hospitalName,
        hospitalNickname: hospitalNickname,
        hospitalCode: hospitalCode,
        location: location,
      );
    } catch (e) {
      debugPrint('UnifiedPostModel.fromJson error: $e');
      rethrow;
    }
  }

  // ===== 파싱 헬퍼 메서드 =====

  /// status 파싱 (int 또는 String 지원)
  static int _parseStatus(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      // 한글 string을 int로 변환
      switch (value.toLowerCase()) {
        case '대기':
          return AppConstants.postStatusRecruiting;
        case '모집중':
        case '승인':
          return AppConstants.postStatusApproved;
        case '거절':
          return AppConstants.postStatusCancelled;
        case '모집마감':
        case '마감':
          return AppConstants.postStatusClosed;
        case '완료':
          return AppConstants.postStatusClosed;
        case '취소':
          return 4; // 취소 상태 (확장)
        default:
          return int.tryParse(value) ?? 0;
      }
    }
    return 0;
  }

  /// animalType 파싱 (String 통일)
  static String _parseAnimalType(dynamic value) {
    if (value == null) return 'dog'; // 기본값

    // String인 경우 그대로 반환
    if (value is String) {
      return value.toLowerCase() == 'cat' ? 'cat' : 'dog';
    }

    // int인 경우 변환 (기존 API 호환)
    if (value is int) {
      return value == AppConstants.animalTypeCatNum ? 'cat' : 'dog';
    }

    return 'dog';
  }

  /// 안전한 int 파싱
  static int? _parseIntSafely(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return int.tryParse(value.toString());
  }

  /// 게시글 작성일 파싱
  static DateTime _parseCreatedDate(Map<String, dynamic> json) {
    // 우선순위: createdDate > created_at > post_created_date > registrationDate
    final candidates = [
      json['createdDate'],
      json['created_at'],
      json['post_created_date'],
      json['registrationDate'],
    ];

    for (final candidate in candidates) {
      if (candidate != null &&
          candidate.toString().isNotEmpty &&
          candidate.toString() != 'null') {
        try {
          return DateTime.parse(candidate.toString());
        } catch (e) {
          continue;
        }
      }
    }

    return DateTime.now(); // fallback
  }

  /// 헌혈 예정일 파싱
  static DateTime? _parseDonationDate(Map<String, dynamic> json) {
    // 우선순위: donationDate > donation_date > donation_time
    final candidates = [
      json['donationDate'],
      json['donation_date'],
      json['donation_time'],
    ];

    for (final candidate in candidates) {
      if (candidate != null &&
          candidate.toString().isNotEmpty &&
          candidate.toString() != 'null') {
        try {
          return DateTime.parse(candidate.toString());
        } catch (e) {
          continue;
        }
      }
    }

    return null;
  }

  // ===== Getter 헬퍼 메서드 =====

  /// 긴급 헌혈 여부
  bool get isUrgent => types == AppConstants.postTypeUrgent;

  /// 정기 헌혈 여부
  bool get isRegular => types == AppConstants.postTypeRegular;

  /// 긴급도 텍스트 (서버 제공 우선, 없으면 로컬 변환)
  String get typeText =>
      typesLabel ?? AppConstants.getPostTypeText(types);

  /// 상태 텍스트 (서버 제공 우선, 없으면 로컬 변환)
  String get statusText =>
      statusLabel ?? AppConstants.getPostStatusText(status);

  /// 동물 타입 한글 텍스트
  String get animalTypeKorean =>
      animalType == 'cat'
          ? AppConstants.animalTypeCatKr
          : AppConstants.animalTypeDogKr;

  /// 동물 타입 int 값 (기존 API 호환용)
  int get animalTypeInt =>
      animalType == 'cat'
          ? AppConstants.animalTypeCatNum
          : AppConstants.animalTypeDogNum;

  /// 혈액형 표시 (긴급일 때만 표시, 아니면 "혈액형 무관")
  String get displayBloodType {
    if (isUrgent && bloodType != null && bloodType!.isNotEmpty) {
      return bloodType!;
    }
    return '혈액형 무관';
  }

  /// 병원 표시명 (닉네임 우선, 없으면 병원명)
  String get hospitalDisplayName => hospitalNickname ?? hospitalName;

  /// 가장 빠른 헌혈 날짜 반환
  DateTime? get earliestDonationDate {
    if (donationDate != null) return donationDate;

    // availableDates에서 가장 빠른 날짜 찾기
    if (availableDates != null && availableDates!.isNotEmpty) {
      try {
        final dates = availableDates!.keys.toList()..sort();
        return DateTime.parse(dates.first);
      } catch (e) {
        return null;
      }
    }

    return null;
  }
}

/// 게시글 이미지 모델
class PostImage {
  final int id;
  final String imageUrl;
  final int order;

  PostImage({
    required this.id,
    required this.imageUrl,
    required this.order,
  });

  factory PostImage.fromJson(Map<String, dynamic> json) {
    return PostImage(
      id: json['id'] ?? 0,
      imageUrl: json['imageUrl'] ?? json['image_url'] ?? '',
      order: json['order'] ?? 0,
    );
  }
}

/// 시간대 모델
class TimeRange {
  final dynamic id; // int 또는 String
  final String? date;
  final String time;
  final dynamic team; // int 또는 String

  TimeRange({
    this.id,
    this.date,
    required this.time,
    this.team,
  });

  factory TimeRange.fromJson(Map<String, dynamic> json) {
    return TimeRange(
      id: json['id'],
      date: json['date'],
      time: json['time'] ?? '',
      team: json['team'],
    );
  }
}
