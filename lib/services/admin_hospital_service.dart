import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/config.dart';

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
  final String? hospitalCode;
  final bool? isActive;
  final bool? columnActive;

  HospitalUpdateRequest({this.hospitalCode, this.isActive, this.columnActive});

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (hospitalCode != null) data['hospital_code'] = hospitalCode;
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

class AdminHospitalService {
  static String get baseUrl => '${Config.serverUrl}/api/admin/hospitals';

  // 토큰 가져오기
  static Future<String> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ?? '';
  }

  // 병원 목록 조회
  static Future<HospitalListResponse> getHospitalList({
    int page = 1,
    int pageSize = 10,
    String? search,
    bool? isActive,
    bool? approved,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다. 다시 로그인해주세요.');
      }

      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (isActive != null) {
        queryParams['is_active'] = isActive.toString();
      }
      if (approved != null) {
        queryParams['approved'] = approved.toString();
      }

      final uri = Uri.parse(
        '$baseUrl/list',
      ).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return HospitalListResponse.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('권한이 없습니다. 관리자 계정으로 로그인해주세요.');
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(
          '병원 목록 조회 실패: ${error['detail'] ?? error['message'] ?? response.body}',
        );
      }
    } catch (e) {
      throw Exception('병원 목록 조회 중 오류 발생: $e');
    }
  }

  // 병원 검색
  static Future<HospitalListResponse> searchHospitals(
    HospitalSearchRequest request,
  ) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다. 다시 로그인해주세요.');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/search'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return HospitalListResponse.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('권한이 없습니다. 관리자 계정으로 로그인해주세요.');
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(
          '병원 검색 실패: ${error['detail'] ?? error['message'] ?? response.body}',
        );
      }
    } catch (e) {
      throw Exception('병원 검색 중 오류 발생: $e');
    }
  }

  // 병원 상세 조회
  static Future<HospitalInfo> getHospitalDetail(int accountIdx) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다. 다시 로그인해주세요.');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/$accountIdx'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return HospitalInfo.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('병원을 찾을 수 없습니다.');
      } else if (response.statusCode == 401) {
        throw Exception('권한이 없습니다. 관리자 계정으로 로그인해주세요.');
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(
          '병원 조회 실패: ${error['detail'] ?? error['message'] ?? response.body}',
        );
      }
    } catch (e) {
      throw Exception('병원 조회 중 오류 발생: $e');
    }
  }

  // 병원 정보 수정
  static Future<HospitalInfo> updateHospital(
    int accountIdx,
    HospitalUpdateRequest request,
  ) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다. 다시 로그인해주세요.');
      }

      final response = await http.put(
        Uri.parse('$baseUrl/$accountIdx'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        // API가 메시지만 반환하는 경우, 현재 병원 정보를 다시 조회
        if (data.containsKey('message') && !data.containsKey('account_idx')) {
          return await getHospitalDetail(accountIdx);
        }

        return HospitalInfo.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('병원을 찾을 수 없습니다.');
      } else if (response.statusCode == 401) {
        throw Exception('권한이 없습니다. 관리자 계정으로 로그인해주세요.');
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(
          '병원 정보 수정 실패: ${error['detail'] ?? error['message'] ?? response.body}',
        );
      }
    } catch (e) {
      throw Exception('병원 정보 수정 중 오류 발생: $e');
    }
  }

  // 병원 탈퇴 (삭제)
  static Future<void> deleteHospital(int accountIdx) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다. 다시 로그인해주세요.');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/$accountIdx'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        return; // 성공적으로 삭제됨
      } else if (response.statusCode == 404) {
        throw Exception('병원을 찾을 수 없습니다.');
      } else if (response.statusCode == 401) {
        throw Exception('권한이 없습니다. 관리자 계정으로 로그인해주세요.');
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(
          '병원 삭제 실패: ${error['detail'] ?? error['message'] ?? response.body}',
        );
      }
    } catch (e) {
      throw Exception('병원 삭제 중 오류 발생: $e');
    }
  }

  // 병원 통계 조회
  static Future<Map<String, dynamic>> getHospitalStatistics() async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다. 다시 로그인해주세요.');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/statistics/summary'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else if (response.statusCode == 401) {
        throw Exception('권한이 없습니다. 관리자 계정으로 로그인해주세요.');
      } else if (response.statusCode == 403) {
        throw Exception('관리자 권한이 필요합니다.');
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(
          '통계 조회 실패: ${error['detail'] ?? error['message'] ?? response.body}',
        );
      }
    } catch (e) {
      throw Exception('병원 통계 조회 중 오류 발생: $e');
    }
  }
}
