import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/donation_post_image_model.dart';
import '../utils/config.dart';

// 웹이 아닐 때만 dart:io 사용 (File 타입)
import 'donation_post_image_service_io.dart' if (dart.library.html) 'donation_post_image_service_web.dart';

/// 헌혈 게시글 이미지 서비스
///
/// 이미지 업로드, 삭제, 순서 변경 등의 API 통신 담당
class DonationPostImageService {
  static String get baseUrl => Config.serverUrl;

  // 토큰 가져오기
  static Future<String> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ?? '';
  }

  /// 이미지 업로드
  ///
  /// [imageFile] - 업로드할 이미지 파일
  /// [postIdx] - 기존 게시글에 추가할 경우 게시글 ID (선택)
  /// [imageOrder] - 이미지 순서 (기본값: 0)
  /// [caption] - 이미지 설명 (선택)
  /// [onProgress] - 업로드 진행률 콜백 (0.0 ~ 1.0)
  static Future<DonationPostImage> uploadImage({
    required File imageFile,
    int? postIdx,
    int imageOrder = 0,
    String? caption,
    Function(double)? onProgress,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다.');
      }

      // 파일 확장자 확인
      final extension = imageFile.path.split('.').last.toLowerCase();
      final mimeType = _getMimeType(extension);

      // multipart 요청 생성
      final uri = Uri.parse('$baseUrl/api/hospital/post/image');
      final request = http.MultipartRequest('POST', uri);

      // 헤더 설정
      request.headers['Authorization'] = 'Bearer $token';

      // 파일 추가
      final multipartFile = await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
        contentType: MediaType.parse(mimeType),
      );
      request.files.add(multipartFile);

      // 추가 필드
      if (postIdx != null) {
        request.fields['post_idx'] = postIdx.toString();
      }
      request.fields['image_order'] = imageOrder.toString();
      if (caption != null && caption.isNotEmpty) {
        request.fields['caption'] = caption;
      }

      // 요청 전송
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        if (data['success'] == true) {
          return DonationPostImage.fromJson(data);
        } else {
          throw Exception(data['message'] ?? '이미지 업로드에 실패했습니다.');
        }
      } else if (response.statusCode == 400) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(data['message'] ?? '잘못된 요청입니다.');
      } else if (response.statusCode == 401) {
        throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
      } else if (response.statusCode == 413) {
        throw Exception('게시글당 최대 5개의 이미지만 업로드할 수 있습니다.');
      } else {
        throw Exception('이미지 업로드에 실패했습니다. (${response.statusCode})');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// 이미지 업로드 (바이트 기반 - 웹/앱 공통)
  ///
  /// [imageBytes] - 업로드할 이미지 바이트
  /// [fileName] - 파일 이름
  /// [postIdx] - 기존 게시글에 추가할 경우 게시글 ID (선택)
  /// [imageOrder] - 이미지 순서 (기본값: 0)
  /// [caption] - 이미지 설명 (선택)
  /// [onProgress] - 업로드 진행률 콜백 (0.0 ~ 1.0)
  static Future<DonationPostImage> uploadImageBytes({
    required Uint8List imageBytes,
    required String fileName,
    int? postIdx,
    int imageOrder = 0,
    String? caption,
    Function(double)? onProgress,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다.');
      }

      // 파일 확장자 확인
      final extension = fileName.split('.').last.toLowerCase();
      final mimeType = _getMimeType(extension);

      // multipart 요청 생성
      final uri = Uri.parse('$baseUrl/api/hospital/post/image');
      final request = http.MultipartRequest('POST', uri);

      // 헤더 설정
      request.headers['Authorization'] = 'Bearer $token';

      // 바이트에서 파일 추가
      final multipartFile = http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      );
      request.files.add(multipartFile);

      // 추가 필드
      if (postIdx != null) {
        request.fields['post_idx'] = postIdx.toString();
      }
      request.fields['image_order'] = imageOrder.toString();
      if (caption != null && caption.isNotEmpty) {
        request.fields['caption'] = caption;
      }

      // 요청 전송
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        if (data['success'] == true) {
          return DonationPostImage.fromJson(data);
        } else {
          throw Exception(data['message'] ?? '이미지 업로드에 실패했습니다.');
        }
      } else if (response.statusCode == 400) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(data['message'] ?? '잘못된 요청입니다.');
      } else if (response.statusCode == 401) {
        throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
      } else if (response.statusCode == 413) {
        throw Exception('게시글당 최대 5개의 이미지만 업로드할 수 있습니다.');
      } else {
        throw Exception('이미지 업로드에 실패했습니다. (${response.statusCode})');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// 이미지 삭제
  ///
  /// [imageId] - 삭제할 이미지 ID
  static Future<bool> deleteImage(int imageId) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다.');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/api/hospital/post/image/$imageId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return data['success'] == true;
      } else if (response.statusCode == 401) {
        throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
      } else if (response.statusCode == 403) {
        throw Exception('본인 병원의 이미지만 삭제할 수 있습니다.');
      } else if (response.statusCode == 404) {
        throw Exception('이미지를 찾을 수 없습니다.');
      } else {
        throw Exception('이미지 삭제에 실패했습니다. (${response.statusCode})');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// 이미지 순서/캡션 수정
  ///
  /// [imageId] - 수정할 이미지 ID
  /// [imageOrder] - 새로운 순서 (선택)
  /// [caption] - 새로운 캡션 (선택)
  static Future<DonationPostImage> updateImage({
    required int imageId,
    int? imageOrder,
    String? caption,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다.');
      }

      final body = <String, dynamic>{};
      if (imageOrder != null) body['image_order'] = imageOrder;
      if (caption != null) body['caption'] = caption;

      final response = await http.put(
        Uri.parse('$baseUrl/api/hospital/post/image/$imageId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return DonationPostImage.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
      } else if (response.statusCode == 403) {
        throw Exception('본인 병원의 이미지만 수정할 수 있습니다.');
      } else if (response.statusCode == 404) {
        throw Exception('이미지를 찾을 수 없습니다.');
      } else {
        throw Exception('이미지 수정에 실패했습니다. (${response.statusCode})');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// 여러 이미지 순서 일괄 변경
  ///
  /// [updates] - 이미지 ID와 새로운 순서 목록
  static Future<bool> updateImageOrders(List<ImageOrderUpdate> updates) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다.');
      }

      final response = await http.put(
        Uri.parse('$baseUrl/api/hospital/post/image/order'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode({
          'image_orders': updates.map((u) => u.toJson()).toList(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return data['success'] == true;
      } else if (response.statusCode == 401) {
        throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
      } else {
        throw Exception('이미지 순서 변경에 실패했습니다. (${response.statusCode})');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// 게시글의 이미지 목록 조회
  ///
  /// [postIdx] - 게시글 ID
  static Future<List<DonationPostImage>> getPostImages(int postIdx) async {
    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        throw Exception('인증 토큰이 없습니다.');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/hospital/post/images/$postIdx'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        if (data is List) {
          return data.map((img) => DonationPostImage.fromJson(img)).toList();
        } else if (data is Map && data['images'] != null) {
          return (data['images'] as List)
              .map((img) => DonationPostImage.fromJson(img))
              .toList();
        }
        return [];
      } else if (response.statusCode == 401) {
        throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
      } else if (response.statusCode == 404) {
        return []; // 게시글에 이미지가 없는 경우
      } else {
        throw Exception('이미지 목록을 불러오는데 실패했습니다. (${response.statusCode})');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// MIME 타입 추출
  static String _getMimeType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      case 'bmp':
        return 'image/bmp';
      default:
        return 'image/jpeg'; // 기본값
    }
  }

  /// 이미지 전체 URL 생성
  static String getFullImageUrl(String imagePath) {
    if (imagePath.startsWith('http')) {
      return imagePath;
    }
    return '$baseUrl$imagePath';
  }
}
