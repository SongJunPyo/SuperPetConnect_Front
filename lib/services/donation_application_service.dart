import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/donation_application_model.dart';
import '../utils/config.dart';

/// 헌혈 신청자 관리 서비스 (병원용)
class DonationApplicationService {
  static String get baseUrl => Config.serverUrl;

  // 토큰 가져오기
  static Future<String> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ?? '';
  }

  /// 특정 게시글의 신청자 목록 조회 (병원용)
  /// GET /api/hospital/posts/{post_id}/applicants
  static Future<ApplicationListResponse> getApplications(int postId) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다.');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/hospital/posts/$postId/applicants'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      print('DEBUG: 신청자 목록 조회 - 상태코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        print('DEBUG: 신청자 목록 데이터: $data');
        
        // 서버가 직접 배열을 반환하는 경우
        if (data is List) {
          return ApplicationListResponse(
            applications: data.map((app) => DonationApplication.fromJson(app)).toList(),
            totalCount: data.length,
          );
        }
        // 기존 형태로 반환하는 경우
        else if (data is Map) {
          return ApplicationListResponse.fromJson(data as Map<String, dynamic>);
        }
        
        throw Exception('예상치 못한 응답 형식');
      } else if (response.statusCode == 401) {
        throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
      } else if (response.statusCode == 404) {
        throw Exception('게시글을 찾을 수 없습니다.');
      } else {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw Exception('신청자 목록 조회 실패: ${error['detail'] ?? response.body}');
      }
    } catch (e) {
      print('Error fetching applications: $e');
      throw e;
    }
  }

  /// 신청 상태 업데이트 (승인/거절) (병원용)
  /// PUT /api/hospital/posts/{post_id}/applicants/{applicant_id}
  static Future<bool> updateApplicationStatus(
    int postId,
    int applicationId,
    ApplicationStatus status, {
    String? hospitalNotes,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다.');
      }

      final request = UpdateApplicationRequest(
        status: status,
        hospitalNotes: hospitalNotes,
      );

      final response = await http.put(
        Uri.parse('$baseUrl/api/hospital/posts/$postId/applicants/$applicationId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode(request.toJson()),
      );

      print('DEBUG: 신청 상태 업데이트 - 상태코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
      } else if (response.statusCode == 404) {
        throw Exception('신청 내역을 찾을 수 없습니다.');
      } else {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw Exception('상태 업데이트 실패: ${error['detail'] ?? response.body}');
      }
    } catch (e) {
      print('Error updating application status: $e');
      throw e;
    }
  }

  /// 신청 삭제 (병원용 - 필요시)
  /// DELETE /api/hospital/posts/{post_id}/applicants/{applicant_id}
  static Future<bool> deleteApplication(int postId, int applicationId) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다.');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/api/hospital/posts/$postId/applicants/$applicationId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      print('DEBUG: 신청 삭제 - 상태코드: ${response.statusCode}');

      if (response.statusCode == 204 || response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
      } else if (response.statusCode == 404) {
        throw Exception('신청 내역을 찾을 수 없습니다.');
      } else {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw Exception('신청 삭제 실패: ${error['detail'] ?? response.body}');
      }
    } catch (e) {
      print('Error deleting application: $e');
      throw e;
    }
  }
}

/// 사용자용 헌혈 신청 서비스
class UserApplicationService {
  static String get baseUrl => Config.serverUrl;

  // 토큰 가져오기
  static Future<String> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ?? '';
  }

  /// 헌혈 신청하기 (사용자용)
  /// POST /api/hospital/posts/{post_id}/applications
  static Future<DonationApplication> createApplication(
    int postId,
    int petId,
  ) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다.');
      }

      final request = CreateApplicationRequest(
        postId: postId,
        petId: petId,
      );

      final response = await http.post(
        Uri.parse('$baseUrl/api/hospital/posts/$postId/applications'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode(request.toJson()),
      );

      print('DEBUG: 헌혈 신청 - 상태코드: ${response.statusCode}');

      if (response.statusCode == 201) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return DonationApplication.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
      } else if (response.statusCode == 400) {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw Exception('신청 실패: ${error['detail'] ?? '잘못된 요청입니다.'}');
      } else if (response.statusCode == 409) {
        throw Exception('이미 해당 게시글에 신청하셨습니다.');
      } else {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw Exception('신청 실패: ${error['detail'] ?? response.body}');
      }
    } catch (e) {
      print('Error creating application: $e');
      throw e;
    }
  }

  /// 내 신청 내역 조회 (사용자용)
  /// GET /api/user/applications
  static Future<List<DonationApplication>> getMyApplications({
    ApplicationStatus? status,
    int? limit,
    int? offset,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다.');
      }

      final queryParams = <String, String>{};
      if (status != null) queryParams['status'] = status.value;
      if (limit != null) queryParams['limit'] = limit.toString();
      if (offset != null) queryParams['offset'] = offset.toString();

      final uri = Uri.parse('$baseUrl/api/user/applications').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      print('DEBUG: 내 신청 내역 조회 - 상태코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        print('DEBUG: 내 신청 내역 데이터: $data');
        
        // 서버가 직접 배열을 반환하는 경우
        if (data is List) {
          return data.map((app) => DonationApplication.fromJson(app)).toList();
        }
        // 서버가 {applications: [...]} 형태로 반환하는 경우
        else if (data is Map && data['applications'] != null) {
          return (data['applications'] as List)
              .map((app) => DonationApplication.fromJson(app))
              .toList();
        }
        
        return [];
      } else if (response.statusCode == 401) {
        throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
      } else {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw Exception('신청 내역 조회 실패: ${error['detail'] ?? response.body}');
      }
    } catch (e) {
      print('Error fetching my applications: $e');
      throw e;
    }
  }

  /// 신청 취소 (사용자용)
  /// DELETE /api/hospital/posts/{post_id}/applicants/{applicant_id}
  static Future<bool> cancelApplication(int postId, int applicationId) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다.');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/api/hospital/posts/$postId/applicants/$applicationId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      print('DEBUG: 신청 취소 - 상태코드: ${response.statusCode}');

      if (response.statusCode == 204 || response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
      } else if (response.statusCode == 404) {
        throw Exception('신청 내역을 찾을 수 없습니다.');
      } else if (response.statusCode == 403) {
        throw Exception('취소할 수 없는 상태입니다.');
      } else {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw Exception('신청 취소 실패: ${error['detail'] ?? response.body}');
      }
    } catch (e) {
      print('Error canceling application: $e');
      throw e;
    }
  }
}

/// 헌혈 이력 관리 서비스
class DonationHistoryService {
  static String get baseUrl => Config.serverUrl;

  // 토큰 가져오기
  static Future<String> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ?? '';
  }

  /// 반려동물별 헌혈 이력 조회
  /// GET /api/pets/{pet_id}/donation-history
  static Future<List<DonationHistory>> getPetDonationHistory(int petId) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다.');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/pets/$petId/donation-history'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      print('DEBUG: 헌혈 이력 조회 - 상태코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        print('DEBUG: 헌혈 이력 데이터: $data');
        
        // 서버가 직접 배열을 반환하는 경우
        if (data is List) {
          return data.map((history) => DonationHistory.fromJson(history)).toList();
        }
        // 서버가 {history: [...]} 형태로 반환하는 경우
        else if (data is Map && data['history'] != null) {
          return (data['history'] as List)
              .map((history) => DonationHistory.fromJson(history))
              .toList();
        }
        
        return [];
      } else if (response.statusCode == 401) {
        throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
      } else if (response.statusCode == 404) {
        throw Exception('반려동물을 찾을 수 없습니다.');
      } else {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw Exception('헌혈 이력 조회 실패: ${error['detail'] ?? response.body}');
      }
    } catch (e) {
      print('Error fetching donation history: $e');
      throw e;
    }
  }
}