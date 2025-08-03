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

  // 병원의 헌혈 게시글 목록 조회
  static Future<List<HospitalPost>> getHospitalPosts() async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다.');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/hospital/posts'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

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