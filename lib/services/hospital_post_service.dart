import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hospital_post_model.dart';
import '../utils/config.dart';

class HospitalPostService {
  static const String baseUrl = Config.serverUrl;

  // 토큰 가져오기
  static Future<String> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ?? '';
  }

  // 병원 코드 가져오기 (병원 사용자용)
  static Future<String?> _getHospitalCode() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 디버깅: SharedPreferences의 모든 관련 키 확인
    print('DEBUG: SharedPreferences 확인');
    print('  - auth_token: ${prefs.getString('auth_token')?.substring(0, 10) ?? 'null'}...');
    print('  - hospital_code: ${prefs.getString('hospital_code') ?? 'null'}');
    print('  - user_email: ${prefs.getString('user_email') ?? 'null'}');
    print('  - user_name: ${prefs.getString('user_name') ?? 'null'}');
    print('  - guardian_idx: ${prefs.getInt('guardian_idx') ?? 'null'}');
    
    return prefs.getString('hospital_code');
  }

  // 병원의 헌혈 게시글 목록 조회
  static Future<List<HospitalPost>> getHospitalPosts({String? hospitalCode}) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다.');
      }

      String url = '$baseUrl/api/v1/posts';
      if (hospitalCode != null && hospitalCode.isNotEmpty) {
        url += '?hospital_code=$hospitalCode';
      }

      print('DEBUG: API 호출 URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      print('DEBUG: API 응답 상태코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        print('Raw response data: $data');
        print('Data type: ${data.runtimeType}');
        
        // 서버가 직접 배열을 반환하는 경우
        if (data is List) {
          final posts = data
              .map((post) {
                print('Processing post: $post');
                return HospitalPost.fromJson(post);
              })
              .toList();
          return posts;
        } 
        // 서버가 {posts: [...]} 형태로 반환하는 경우
        else if (data is Map && data['posts'] != null) {
          final posts = (data['posts'] as List)
              .map((post) {
                print('Processing post: $post');
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
      print('Error fetching hospital posts: $e');
      throw e;
    }
  }

  // 현재 병원 사용자의 게시글만 조회
  static Future<List<HospitalPost>> getHospitalPostsForCurrentUser() async {
    try {
      final hospitalCode = await _getHospitalCode();
      print('DEBUG: 조회된 hospital_code: $hospitalCode');
      
      if (hospitalCode == null || hospitalCode.isEmpty) {
        print('DEBUG: hospital_code가 없음 - 전체 게시글 조회로 대체');
        return await getHospitalPosts();
      }
      
      // 먼저 기존 hospital API 시도
      print('DEBUG: /api/v1/hospital/posts API 시도');
      try {
        final hospitalPosts = await _getHospitalPostsViaHospitalAPI();
        if (hospitalPosts.isNotEmpty) {
          print('DEBUG: hospital API에서 ${hospitalPosts.length}개 게시글 조회됨');
          return hospitalPosts;
        }
      } catch (e) {
        print('DEBUG: hospital API 실패: $e');
      }
      
      // hospital API가 실패하거나 빈 결과면 필터링 API 시도
      print('DEBUG: hospital_code로 게시글 조회 시작: $hospitalCode');
      final filteredPosts = await getHospitalPosts(hospitalCode: hospitalCode);
      if (filteredPosts.isNotEmpty) {
        return filteredPosts;
      }
      
      // 모두 실패하면 전체 게시글 조회
      print('DEBUG: 모든 방법 실패 - 전체 게시글 조회로 대체');
      return await getHospitalPosts();
      
    } catch (e) {
      print('Error fetching current user hospital posts: $e');
      // 에러 발생 시에도 전체 게시글 조회 시도
      try {
        print('DEBUG: 에러 발생으로 전체 게시글 조회 시도');
        return await getHospitalPosts();
      } catch (fallbackError) {
        print('Error in fallback getHospitalPosts: $fallbackError');
        throw e; // 원래 에러 throw
      }
    }
  }

  // 기존 hospital API 사용
  static Future<List<HospitalPost>> _getHospitalPostsViaHospitalAPI() async {
    final token = await _getAuthToken();
    if (token.isEmpty) {
      throw Exception('인증 토큰이 없습니다.');
    }

    print('DEBUG: API 호출 URL: $baseUrl/api/v1/hospital/posts');

    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/hospital/posts'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=UTF-8',
      },
    );

    print('DEBUG: hospital API 응답 상태코드: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      print('DEBUG: hospital API 응답 데이터: $data');
      
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

  // 특정 게시글의 신청자 목록 조회
  static Future<List<DonationApplicant>> getApplicants(String postId) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다.');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/hospital/posts/$postId/applicants'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final applicants = (data['applicants'] as List)
            .map((applicant) => DonationApplicant.fromJson(applicant))
            .toList();
        return applicants;
      } else if (response.statusCode == 401) {
        throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
      } else {
        throw Exception('신청자 목록을 불러오는데 실패했습니다.');
      }
    } catch (e) {
      print('Error fetching applicants: $e');
      throw e;
    }
  }

  // 신청자 승인/거절
  static Future<bool> updateApplicantStatus(
    String postId,
    String applicantId,
    String status,
  ) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다.');
      }

      final response = await http.put(
        Uri.parse('$baseUrl/api/v1/hospital/posts/$postId/applicants/$applicantId'),
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
        throw Exception(error['message'] ?? '상태 업데이트에 실패했습니다.');
      }
    } catch (e) {
      print('Error updating applicant status: $e');
      throw e;
    }
  }

  // 게시글 상태 변경
  static Future<bool> updatePostStatus(String postId, String status) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다.');
      }

      final response = await http.put(
        Uri.parse('$baseUrl/api/v1/hospital/posts/$postId/status'),
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
      print('Error updating post status: $e');
      throw e;
    }
  }
}