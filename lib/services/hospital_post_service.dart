import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/hospital_post_model.dart';
import '../models/donation_application_model.dart';
import '../utils/config.dart';

class HospitalPostService {
  static String get baseUrl => Config.serverUrl;

  // 토큰 가져오기
  static Future<String> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ?? '';
  }

  // 병원 코드 가져오기 (병원 사용자용)
  static Future<String?> _getHospitalCode() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 디버깅: SharedPreferences의 모든 관련 키 확인
    
    return prefs.getString('hospital_code');
  }

  // 병원의 헌혈 게시글 목록 조회
  static Future<List<HospitalPost>> getHospitalPosts({String? hospitalCode}) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다.');
      }

      String url = '$baseUrl/api/posts';
      if (hospitalCode != null && hospitalCode.isNotEmpty) {
        url += '?hospital_code=$hospitalCode';
      }


      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );


      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        
        // 서버가 직접 배열을 반환하는 경우
        if (data is List) {
          final posts = data
              .map((post) {
                return HospitalPost.fromJson(post);
              })
              .toList();
          return posts;
        } 
        // 서버가 {posts: [...]} 형태로 반환하는 경우
        else if (data is Map && data['posts'] != null) {
          final posts = (data['posts'] as List)
              .map((post) {
                return HospitalPost.fromJson(post);
              })
              .toList();
          return posts;
        }
        
        return [];
      } else if (response.statusCode == 401) {
        throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
      } else {
        throw Exception('게시글 목록을 불러오는데 실패했습니다.');
      }
    } catch (e) {
      rethrow;
    }
  }

  // 현재 병원 사용자의 게시글만 조회
  static Future<List<HospitalPost>> getHospitalPostsForCurrentUser() async {
    try {
      final hospitalCode = await _getHospitalCode();
      
      if (hospitalCode == null || hospitalCode.isEmpty) {
        return await getHospitalPosts();
      }
      
      // 먼저 기존 hospital API 시도
      try {
        final hospitalPosts = await _getHospitalPostsViaHospitalAPI();
        if (hospitalPosts.isNotEmpty) {
          return hospitalPosts;
        }
      } catch (e) {
        // 병원 게시물 조회 실패 시 다음 API 시도
        debugPrint('Failed to fetch hospital posts: $e');
      }
      
      // hospital API가 실패하거나 빈 결과면 필터링 API 시도
      final filteredPosts = await getHospitalPosts(hospitalCode: hospitalCode);
      if (filteredPosts.isNotEmpty) {
        return filteredPosts;
      }
      
      // 모두 실패하면 전체 게시글 조회
      return await getHospitalPosts();
      
    } catch (e) {
      // 에러 발생 시에도 전체 게시글 조회 시도
      try {
        return await getHospitalPosts();
      } catch (fallbackError) {
        rethrow; // 원래 에러 throw
      }
    }
  }

  // 기존 hospital API 사용
  static Future<List<HospitalPost>> _getHospitalPostsViaHospitalAPI() async {
    final token = await _getAuthToken();
    if (token.isEmpty) {
      throw Exception('인증 토큰이 없습니다.');
    }


    final response = await http.get(
      Uri.parse('$baseUrl/api/hospital/posts'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=UTF-8',
      },
    );


    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      
      if (data is List) {
        return data.map((post) => HospitalPost.fromJson(post)).toList();
      } else if (data is Map && data['posts'] != null) {
        return (data['posts'] as List).map((post) => HospitalPost.fromJson(post)).toList();
      }
      return [];
    } else {
      throw Exception('hospital API 호출 실패: ${response.statusCode}');
    }
  }

  // 특정 게시글의 신청자 목록 조회 (수정된 API 사용)
  static Future<ApplicationListResponse> getApplicants(String postId) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다.');
      }

      final postIdInt = int.tryParse(postId) ?? 0;
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/applied_donation/post/$postIdInt/applications'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );


      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        
        // 새로운 API 응답 구조에 따른 파싱
        return ApplicationListResponse.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
      } else if (response.statusCode == 403) {
        throw Exception('권한이 없습니다. 해당 게시글의 작성자만 신청자를 확인할 수 있습니다.');
      } else {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['detail'] ?? '신청자 목록을 불러오는데 실패했습니다.';
        throw Exception('API 오류 (${response.statusCode}): $errorMessage');
      }
    } catch (e) {
      rethrow;
    }
  }

  // 신청자 승인/거절 (수정된 API 사용)
  static Future<bool> updateApplicantStatus(
    int appliedDonationIdx,
    int statusCode, {
    String? hospitalNotes,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다.');
      }

      
      final response = await http.put(
        Uri.parse('$baseUrl/api/applied_donation/$appliedDonationIdx/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode({
          'status': statusCode,
          if (hospitalNotes != null) 'hospital_notes': hospitalNotes,
        }),
      );


      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
      } else if (response.statusCode == 403) {
        throw Exception('권한이 없습니다. 해당 신청에 대한 권한이 없습니다.');
      } else {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(error['detail'] ?? '상태 업데이트에 실패했습니다.');
      }
    } catch (e) {
      rethrow;
    }
  }

  // 게시글 상태 변경
  static Future<bool> updatePostStatus(String postIdx, String status) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다.');
      }

      final response = await http.put(
        Uri.parse('$baseUrl/api/hospital/posts/$postIdx/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode({'status': status}),
      );

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
      } else {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(error['message'] ?? '상태 변경에 실패했습니다.');
      }
    } catch (e) {
      rethrow;
    }
  }
}