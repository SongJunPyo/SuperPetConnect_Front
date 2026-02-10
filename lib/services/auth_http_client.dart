// 인증된 HTTP 요청을 처리하는 중앙 래퍼
// - 모든 요청에 자동으로 Authorization 헤더 추가
// - 401 응답 시 Refresh Token으로 자동 갱신 후 재시도
// - 갱신 실패 시 로그인 화면으로 자동 이동

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/config.dart';
import 'notification_service.dart';

class AuthHttpClient {
  // 동시 토큰 갱신 방지용
  static bool _isRefreshing = false;
  static Completer<bool>? _refreshCompleter;

  // SharedPreferences에서 Access Token 조회
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // 토큰을 포함한 인증 헤더 생성
  static Future<Map<String, String>> _buildHeaders(Map<String, String>? extraHeaders) async {
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
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');

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
        await prefs.setString('auth_token', data['access_token']);
        if (data['refresh_token'] != null) {
          await prefs.setString('refresh_token', data['refresh_token']);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

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
    var response = await http.post(url, headers: authHeaders, body: body, encoding: encoding);

    if (response.statusCode == 401) {
      if (await _handle401()) {
        final retryHeaders = await _buildHeaders(headers);
        response = await http.post(url, headers: retryHeaders, body: body, encoding: encoding);
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
    var response = await http.put(url, headers: authHeaders, body: body, encoding: encoding);

    if (response.statusCode == 401) {
      if (await _handle401()) {
        final retryHeaders = await _buildHeaders(headers);
        response = await http.put(url, headers: retryHeaders, body: body, encoding: encoding);
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
    var response = await http.delete(url, headers: authHeaders, body: body, encoding: encoding);

    if (response.statusCode == 401) {
      if (await _handle401()) {
        final retryHeaders = await _buildHeaders(headers);
        response = await http.delete(url, headers: retryHeaders, body: body, encoding: encoding);
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
    var response = await http.patch(url, headers: authHeaders, body: body, encoding: encoding);

    if (response.statusCode == 401) {
      if (await _handle401()) {
        final retryHeaders = await _buildHeaders(headers);
        response = await http.patch(url, headers: retryHeaders, body: body, encoding: encoding);
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
