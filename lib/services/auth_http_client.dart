// 인증된 HTTP 요청을 처리하는 중앙 래퍼
// - 모든 요청에 자동으로 Authorization 헤더 추가
// - 401 응답 시 Refresh Token으로 자동 갱신 후 재시도
// - 갱신 실패 시 로그인 화면으로 자동 이동

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/config.dart';
import '../utils/preferences_manager.dart';
import 'notification_service.dart';

class AuthHttpClient {
  // 동시 토큰 갱신 방지용
  static bool _isRefreshing = false;
  static Completer<bool>? _refreshCompleter;

  // SharedPreferences에서 Access Token 조회
  static Future<String?> _getToken() async {
    return await PreferencesManager.getAuthToken();
  }

  // 토큰을 포함한 인증 헤더 생성
  static Future<Map<String, String>> _buildHeaders(
    Map<String, String>? extraHeaders,
  ) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('로그인이 필요합니다.');
    }
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
      ...?extraHeaders,
    };
  }

  // Refresh Token으로 Access Token 갱신
  // 여러 요청이 동시에 401을 받아도 갱신은 한 번만 실행
  static Future<bool> _refreshToken() async {
    if (_isRefreshing) {
      // 이미 갱신 중이면 완료될 때까지 대기
      return _refreshCompleter!.future;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();

    try {
      final refreshToken = await PreferencesManager.getRefreshToken();

      if (refreshToken == null || refreshToken.isEmpty) {
        _refreshCompleter!.complete(false);
        return false;
      }

      final response = await http.post(
        Uri.parse('${Config.serverUrl}/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await PreferencesManager.setAuthToken(data['access_token']);
        if (data['refresh_token'] != null) {
          await PreferencesManager.setRefreshToken(data['refresh_token']);
        }
        _refreshCompleter!.complete(true);
        return true;
      } else {
        // Refresh Token도 만료 → 로그인 필요
        _refreshCompleter!.complete(false);
        return false;
      }
    } catch (e) {
      debugPrint('[AuthHttpClient] 토큰 갱신 실패: $e');
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  // 강제 로그아웃 (토큰 삭제 + 로그인 화면 이동)
  static Future<void> _forceLogout() async {
    await PreferencesManager.clearAll();

    final navigator = NotificationService.navigatorKey.currentState;
    if (navigator != null) {
      navigator.pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  // 401 응답 처리: 토큰 갱신 시도 → 성공 시 true, 실패 시 강제 로그아웃
  static Future<bool> _handle401() async {
    final refreshed = await _refreshToken();
    if (!refreshed) {
      await _forceLogout();
    }
    return refreshed;
  }

  // ─── HTTP 메서드들 ───

  /// GET 요청
  static Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    final authHeaders = await _buildHeaders(headers);
    var response = await http.get(url, headers: authHeaders);

    if (response.statusCode == 401) {
      if (await _handle401()) {
        final retryHeaders = await _buildHeaders(headers);
        response = await http.get(url, headers: retryHeaders);
      }
    }
    return response;
  }

  /// POST 요청
  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    final authHeaders = await _buildHeaders(headers);
    var response = await http.post(
      url,
      headers: authHeaders,
      body: body,
      encoding: encoding,
    );

    if (response.statusCode == 401) {
      if (await _handle401()) {
        final retryHeaders = await _buildHeaders(headers);
        response = await http.post(
          url,
          headers: retryHeaders,
          body: body,
          encoding: encoding,
        );
      }
    }
    return response;
  }

  /// PUT 요청
  static Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    final authHeaders = await _buildHeaders(headers);
    var response = await http.put(
      url,
      headers: authHeaders,
      body: body,
      encoding: encoding,
    );

    if (response.statusCode == 401) {
      if (await _handle401()) {
        final retryHeaders = await _buildHeaders(headers);
        response = await http.put(
          url,
          headers: retryHeaders,
          body: body,
          encoding: encoding,
        );
      }
    }
    return response;
  }

  /// DELETE 요청
  static Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    final authHeaders = await _buildHeaders(headers);
    var response = await http.delete(
      url,
      headers: authHeaders,
      body: body,
      encoding: encoding,
    );

    if (response.statusCode == 401) {
      if (await _handle401()) {
        final retryHeaders = await _buildHeaders(headers);
        response = await http.delete(
          url,
          headers: retryHeaders,
          body: body,
          encoding: encoding,
        );
      }
    }
    return response;
  }

  /// PATCH 요청
  static Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    final authHeaders = await _buildHeaders(headers);
    var response = await http.patch(
      url,
      headers: authHeaders,
      body: body,
      encoding: encoding,
    );

    if (response.statusCode == 401) {
      if (await _handle401()) {
        final retryHeaders = await _buildHeaders(headers);
        response = await http.patch(
          url,
          headers: retryHeaders,
          body: body,
          encoding: encoding,
        );
      }
    }
    return response;
  }

  /// MultipartRequest 전송 (파일 업로드용)
  /// 사용법: AuthHttpClient.sendMultipart(request)
  /// request에 Authorization 헤더를 자동 추가합니다.
  static Future<http.StreamedResponse> sendMultipart(
    http.MultipartRequest request,
  ) async {
    final token = await _getToken();
    if (token == null) throw Exception('로그인이 필요합니다.');
    request.headers['Authorization'] = 'Bearer $token';

    var response = await request.send();

    if (response.statusCode == 401) {
      if (await _handle401()) {
        // MultipartRequest는 재사용 불가하므로 새로 생성해야 함
        // 호출자에서 재시도해야 합니다
        final newToken = await _getToken();
        if (newToken != null) {
          request.headers['Authorization'] = 'Bearer $newToken';
          response = await request.send();
        }
      }
    }
    return response;
  }
}

/// HTTP 응답 파싱을 위한 확장 메서드
extension HttpResponseParsing on http.Response {
  /// 응답을 dynamic으로 파싱 (List 또는 Map 모두 가능)
  dynamic parseJsonDynamic() {
    return json.decode(utf8.decode(bodyBytes));
  }

  /// 응답을 `Map<String, dynamic>`으로 파싱
  Map<String, dynamic> parseJson() {
    return json.decode(utf8.decode(bodyBytes)) as Map<String, dynamic>;
  }

  /// 응답을 `List<dynamic>`으로 파싱
  List<dynamic> parseJsonList() {
    return json.decode(utf8.decode(bodyBytes)) as List<dynamic>;
  }

  /// 응답을 단일 객체로 파싱
  T parseJsonAs<T>(T Function(Map<String, dynamic>) fromJson) {
    return fromJson(parseJson());
  }

  /// 응답을 객체 리스트로 파싱
  List<T> parseJsonListAs<T>(T Function(Map<String, dynamic>) fromJson) {
    final data = parseJson();
    final list = (data['items'] ?? data['data'] ?? data['list'] ?? data) as List;
    return list
        .map((item) => fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// 성공 응답 여부 확인 (200-299)
  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// 생성 성공 확인 (200 또는 201)
  bool get isCreated => statusCode == 200 || statusCode == 201;

  /// No Content 확인 (200 또는 204)
  bool get isNoContent => statusCode == 200 || statusCode == 204;

  /// 에러 응답에서 메시지 추출
  /// 서버 응답에서 detail → message → body 순으로 에러 메시지를 탐색
  /// detail이 Map인 경우 (자격 검증 실패 등) failed_conditions를 파싱하여 상세 메시지 반환
  String extractErrorMessage([String fallback = '요청 처리 중 오류가 발생했습니다.']) {
    try {
      final data = parseJson();
      final detail = data['detail'];

      // detail이 Map인 경우 (서버 자격 검증 실패 응답)
      if (detail is Map) {
        final msg = detail['message'] ?? '';
        final failedConditions = detail['failed_conditions'];
        if (failedConditions is List && failedConditions.isNotEmpty) {
          final reasons = failedConditions
              .map((c) => c['message'] ?? c['condition'] ?? '')
              .where((m) => m.toString().isNotEmpty)
              .join(', ');
          if (reasons.isNotEmpty) {
            return '$msg ($reasons)';
          }
        }
        return msg.toString().isNotEmpty ? msg.toString() : fallback;
      }

      // detail이 String인 경우 (기존 동작)
      final message = detail ?? data['message'] ?? data['error'];
      if (message != null && message.toString().isNotEmpty) {
        return message.toString();
      }
    } catch (_) {
      // JSON 파싱 실패 시 body 원문 사용
    }
    return body.isNotEmpty ? body : fallback;
  }

  /// 에러 응답을 Exception으로 변환
  /// throw response.toException('기본 에러 메시지'); 형태로 사용
  Exception toException([String fallback = '요청 처리 중 오류가 발생했습니다.']) {
    return Exception(extractErrorMessage(fallback));
  }
}
