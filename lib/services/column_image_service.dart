import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'auth_http_client.dart';
import '../models/hospital_column_model.dart';
import '../utils/config.dart';
import '../utils/api_endpoints.dart';

/// 칼럼 이미지 서비스
///
/// 칼럼 이미지 업로드, 삭제 등의 API 통신 담당
class ColumnImageService {

  /// 이미지 업로드 (바이트 기반 - 웹/앱 공통)
  ///
  /// [imageBytes] - 업로드할 이미지 바이트
  /// [fileName] - 파일 이름
  /// [columnIdx] - 기존 칼럼에 추가할 경우 칼럼 ID (선택)
  /// [imageOrder] - 이미지 순서 (선택, 기본값 0)
  /// [onProgress] - 업로드 진행률 콜백 (0.0 ~ 1.0)
  static Future<ColumnImage> uploadImageBytes({
    required Uint8List imageBytes,
    required String fileName,
    int? columnIdx,
    int imageOrder = 0,
    Function(double)? onProgress,
  }) async {
    debugPrint(
      '[ColumnImageService] uploadImageBytes 시작: fileName=$fileName, size=${imageBytes.length}',
    );
    try {
      // 파일 확장자 확인
      final extension = fileName.split('.').last.toLowerCase();
      final mimeType = _getMimeType(extension);
      debugPrint('[ColumnImageService] 확장자: $extension, MIME: $mimeType');

      // multipart 요청 생성
      final uri = Uri.parse('${Config.serverUrl}${ApiEndpoints.hospitalColumnImageUpload}');
      debugPrint('[ColumnImageService] 요청 URL: $uri');
      final request = http.MultipartRequest('POST', uri);

      // 바이트에서 파일 추가
      final multipartFile = http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      );
      request.files.add(multipartFile);

      // 추가 필드
      if (columnIdx != null) {
        request.fields['column_idx'] = columnIdx.toString();
      }
      request.fields['image_order'] = imageOrder.toString();
      debugPrint('[ColumnImageService] 요청 필드: ${request.fields}');

      // 요청 전송
      debugPrint('[ColumnImageService] 요청 전송 중...');
      final streamedResponse = await AuthHttpClient.sendMultipart(request);
      debugPrint(
        '[ColumnImageService] 응답 상태 코드: ${streamedResponse.statusCode}',
      );
      final response = await http.Response.fromStream(streamedResponse);
      debugPrint('[ColumnImageService] 응답 본문: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.parseJsonDynamic();

        // 다양한 응답 형식 처리
        if (data['success'] == true ||
            data['image_id'] != null ||
            data['image_path'] != null) {
          debugPrint('[ColumnImageService] 업로드 성공!');
          return ColumnImage.fromJson(data);
        } else {
          debugPrint('[ColumnImageService] 서버 응답 실패: ${data['message']}');
          throw Exception(data['message'] ?? '이미지 업로드에 실패했습니다.');
        }
      } else if (response.statusCode == 400) {
        debugPrint('[ColumnImageService] 400 에러: ${response.extractErrorMessage()}');
        throw response.toException('잘못된 요청입니다.');
      } else if (response.statusCode == 413) {
        debugPrint('[ColumnImageService] 413 이미지 개수 초과');
        throw Exception('칼럼당 최대 5개의 이미지만 업로드할 수 있습니다.');
      } else {
        debugPrint('[ColumnImageService] 기타 에러: ${response.statusCode}');
        throw Exception('이미지 업로드에 실패했습니다. (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('[ColumnImageService] 예외 발생: $e');
      rethrow;
    }
  }

  /// 이미지 삭제
  ///
  /// [imageId] - 삭제할 이미지 ID
  static Future<bool> deleteImage(int imageId) async {
    try {
      final response = await AuthHttpClient.delete(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.hospitalColumnImage(imageId)}'),
      );

      if (response.statusCode == 200) {
        final data = response.parseJsonDynamic();
        return data['success'] == true;
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

  /// 칼럼의 이미지 목록 조회
  ///
  /// [columnIdx] - 칼럼 ID
  static Future<List<ColumnImage>> getColumnImages(int columnIdx) async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.hospitalColumnImagesByColumn(columnIdx)}'),
      );

      if (response.statusCode == 200) {
        final data = response.parseJsonDynamic();

        if (data is List) {
          return data.map((img) => ColumnImage.fromJson(img)).toList();
        } else if (data is Map && data['images'] != null) {
          return (data['images'] as List)
              .map((img) => ColumnImage.fromJson(img))
              .toList();
        }
        return [];
      } else if (response.statusCode == 404) {
        return []; // 칼럼에 이미지가 없는 경우
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
    return '${Config.serverUrl}$imagePath';
  }
}
