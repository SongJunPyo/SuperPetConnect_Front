import 'dart:convert';
import '../models/donation_application_model.dart';
import '../utils/config.dart';
import 'auth_http_client.dart';

/// 헌혈 신청자 관리 서비스 (병원용)
class DonationApplicationService {
  static String get baseUrl => Config.serverUrl;

  /// 특정 게시글의 신청자 목록 조회 (병원용)
  /// GET /api/hospital/posts/{post_idx}/applicants
  static Future<ApplicationListResponse> getApplications(int postIdx) async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse('$baseUrl/api/hospital/posts/$postIdx/applicants'),
      );


      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        // 서버가 직접 배열을 반환하는 경우
        if (data is List) {
          return ApplicationListResponse(
            postIdx: 0,
            postTitle: '',
            totalApplications: data.length,
            applications: data.map((app) => DonationApplication.fromJson(app)).toList(),
          );
        }
        // 기존 형태로 반환하는 경우
        else if (data is Map) {
          return ApplicationListResponse.fromJson(data as Map<String, dynamic>);
        }

        throw Exception('예상치 못한 응답 형식');
      } else if (response.statusCode == 404) {
        throw Exception('게시글을 찾을 수 없습니다.');
      } else {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw Exception('신청자 목록 조회 실패: ${error['detail'] ?? response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// 신청 상태 업데이트 (승인/거절) (병원용)
  /// PUT /api/hospital/posts/{post_idx}/applicants/{applicant_id}
  static Future<bool> updateApplicationStatus(
    int postIdx,
    int applicationId,
    ApplicationStatus status, {
    String? hospitalNotes,
  }) async {
    try {
      final request = UpdateApplicationRequest(
        status: status,
        hospitalNotes: hospitalNotes,
      );

      final response = await AuthHttpClient.put(
        Uri.parse('$baseUrl/api/hospital/posts/$postIdx/applicants/$applicationId'),
        body: json.encode(request.toJson()),
      );


      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 404) {
        throw Exception('신청 내역을 찾을 수 없습니다.');
      } else {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw Exception('상태 업데이트 실패: ${error['detail'] ?? response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// 신청 삭제 (병원용 - 필요시)
  /// DELETE /api/hospital/posts/{post_idx}/applicants/{applicant_id}
  static Future<bool> deleteApplication(int postIdx, int applicationId) async {
    try {
      final response = await AuthHttpClient.delete(
        Uri.parse('$baseUrl/api/hospital/posts/$postIdx/applicants/$applicationId'),
      );


      if (response.statusCode == 204 || response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 404) {
        throw Exception('신청 내역을 찾을 수 없습니다.');
      } else {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw Exception('신청 삭제 실패: ${error['detail'] ?? response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }
}

/// 사용자용 헌혈 신청 서비스
class UserApplicationService {
  static String get baseUrl => Config.serverUrl;

  /// 헌혈 신청하기 (사용자용)
  /// POST /api/hospital/posts/{post_idx}/applications
  static Future<DonationApplication> createApplication(
    int postIdx,
    int petId,
  ) async {
    try {
      final request = CreateApplicationRequest(
        postId: postIdx,
        petId: petId,
      );

      final response = await AuthHttpClient.post(
        Uri.parse('$baseUrl/api/hospital/posts/$postIdx/applications'),
        body: json.encode(request.toJson()),
      );


      if (response.statusCode == 201) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return DonationApplication.fromJson(data);
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
      rethrow;
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
      final queryParams = <String, String>{};
      if (status != null) queryParams['status'] = status.value;
      if (limit != null) queryParams['limit'] = limit.toString();
      if (offset != null) queryParams['offset'] = offset.toString();

      final uri = Uri.parse('$baseUrl/api/user/applications').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final response = await AuthHttpClient.get(uri);


      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

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
      } else {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw Exception('신청 내역 조회 실패: ${error['detail'] ?? response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// 신청 취소 (사용자용)
  /// DELETE /api/hospital/posts/{post_idx}/applicants/{applicant_id}
  static Future<bool> cancelApplication(int postIdx, int applicationId) async {
    try {
      final response = await AuthHttpClient.delete(
        Uri.parse('$baseUrl/api/hospital/posts/$postIdx/applicants/$applicationId'),
      );


      if (response.statusCode == 204 || response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 404) {
        throw Exception('신청 내역을 찾을 수 없습니다.');
      } else if (response.statusCode == 403) {
        throw Exception('취소할 수 없는 상태입니다.');
      } else {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw Exception('신청 취소 실패: ${error['detail'] ?? response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }
}

/// 헌혈 이력 관리 서비스
class DonationHistoryService {
  static String get baseUrl => Config.serverUrl;

  /// 반려동물별 헌혈 이력 조회
  /// GET /api/pets/{pet_id}/donation-history
  static Future<List<DonationHistory>> getPetDonationHistory(int petId) async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse('$baseUrl/api/pets/$petId/donation-history'),
      );


      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

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
      } else if (response.statusCode == 404) {
        throw Exception('반려동물을 찾을 수 없습니다.');
      } else {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw Exception('헌혈 이력 조회 실패: ${error['detail'] ?? response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
