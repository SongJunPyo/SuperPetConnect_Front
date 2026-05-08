// 병원 계정(accounts 테이블 account_type=2) 관련 모델.
//
// 구성:
// - [HospitalInfo]            : 관리자 화면에서 다루는 병원 계정 상세 정보
// - [HospitalListResponse]    : 목록 조회 응답 (pagination 포함)
// - [HospitalUpdateRequest]   : 병원 계정 부분 수정 요청 body
// - [HospitalSearchRequest]   : 병원 검색 API 요청 body
//
// 병원 **마스터** 데이터(hospital_master 테이블)는 별도 파일
// `hospital_master_model.dart`를 참조.

class HospitalInfo {
  final int accountIdx;
  final String name;
  final String? nickname;
  final String email;
  final String? address;
  final String? phoneNumber;
  final String? hospitalCode;
  final bool isActive;
  final bool columnActive;
  final bool approved;
  final DateTime createdAt;
  final String? managerName;
  final int donationCount;

  HospitalInfo({
    required this.accountIdx,
    required this.name,
    this.nickname,
    required this.email,
    this.address,
    this.phoneNumber,
    this.hospitalCode,
    required this.isActive,
    required this.columnActive,
    required this.approved,
    required this.createdAt,
    this.managerName,
    required this.donationCount,
  });

  factory HospitalInfo.fromJson(Map<String, dynamic> json) {
    return HospitalInfo(
      accountIdx: json['account_idx'] ?? 0,
      name: json['name'] ?? '',
      nickname: json['nickname'],
      email: json['email'] ?? '',
      address: json['address'],
      phoneNumber: json['phone_number'],
      hospitalCode: json['hospital_code'],
      isActive: json['is_active'] ?? json['approved'] ?? false,
      columnActive: json['column_active'] ?? false,
      approved: json['approved'] ?? false,
      createdAt:
          DateTime.tryParse(json['created_time'] ?? json['created_at'] ?? '') ??
          DateTime.now(),
      managerName: json['manager_name'],
      donationCount: json['donation_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'account_idx': accountIdx,
      'name': name,
      'nickname': nickname,
      'email': email,
      'address': address,
      'phone_number': phoneNumber,
      'hospital_code': hospitalCode,
      'is_active': isActive,
      'column_active': columnActive,
      'approved': approved,
      'created_time': createdAt.toIso8601String(),
      'manager_name': managerName,
      'donation_count': donationCount,
    };
  }
}

class HospitalListResponse {
  final List<HospitalInfo> hospitals;
  final int totalCount;
  final int page;
  final int pageSize;

  HospitalListResponse({
    required this.hospitals,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  factory HospitalListResponse.fromJson(dynamic jsonData) {
    // API 응답이 직접 배열인 경우와 객체 안에 배열이 있는 경우 모두 처리
    List<dynamic> hospitalsData = [];
    Map<String, dynamic> json = {};

    if (jsonData is List) {
      // API가 직접 배열을 반환하는 경우
      hospitalsData = jsonData;
    } else if (jsonData is Map<String, dynamic>) {
      json = jsonData;
      if (json['hospitals'] != null) {
        // API가 객체 안에 hospitals 배열을 반환하는 경우
        hospitalsData = json['hospitals'] as List;
      } else if (json['data'] != null) {
        // API가 data 필드 안에 배열을 반환하는 경우
        hospitalsData = json['data'] as List;
      }
    }

    final hospitalsList =
        hospitalsData
            .map(
              (hospital) =>
                  HospitalInfo.fromJson(hospital as Map<String, dynamic>),
            )
            .toList();

    return HospitalListResponse(
      hospitals: hospitalsList,
      totalCount:
          json['total_count'] ?? json['totalCount'] ?? hospitalsList.length,
      page: json['page'] ?? 1,
      pageSize: json['page_size'] ?? json['pageSize'] ?? hospitalsList.length,
    );
  }
}

class HospitalUpdateRequest {
  final bool? isActive;
  final bool? columnActive;

  HospitalUpdateRequest({this.isActive, this.columnActive});

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (isActive != null) data['is_active'] = isActive;
    if (columnActive != null) data['column_active'] = columnActive;
    return data;
  }
}

class HospitalSearchRequest {
  final String searchQuery;
  final bool? isActive;
  final bool? approved;
  final int page;
  final int pageSize;

  HospitalSearchRequest({
    required this.searchQuery,
    this.isActive,
    this.approved,
    this.page = 1,
    this.pageSize = 10,
  });

  Map<String, dynamic> toJson() {
    return {
      'search_query': searchQuery,
      'is_active': isActive,
      'approved': approved,
      'page': page,
      'page_size': pageSize,
    };
  }
}
