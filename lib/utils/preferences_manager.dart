import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences 중앙 관리 클래스
class PreferencesManager {
  // ===== 키 상수 =====
  static const String keyAuthToken = 'auth_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyAccountType = 'account_type';
  static const String keyAccountIdx = 'account_idx';
  static const String keyUserEmail = 'user_email';
  static const String keyUserName = 'user_name';
  static const String keyUserNickname = 'user_nickname';
  static const String keyAdminName = 'admin_name';
  static const String keyAdminNickname = 'admin_nickname';
  static const String keyHospitalName = 'hospital_name';
  static const String keyHospitalNickname = 'hospital_nickname';
  static const String keyHospitalCode = 'hospital_code';
  static const String keyRegionInitialized = 'region_preference_initialized';
  static const String keyPreferredLargeRegions = 'preferred_large_regions';
  static const String keyPreferredMediumRegions = 'preferred_medium_regions';

  // ===== 인증 토큰 =====
  static Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyAuthToken);
  }

  static Future<bool> setAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(keyAuthToken, token);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyRefreshToken);
  }

  static Future<bool> setRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(keyRefreshToken, token);
  }

  // ===== 계정 정보 =====
  static Future<int?> getAccountType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(keyAccountType);
  }

  static Future<bool> setAccountType(int type) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setInt(keyAccountType, type);
  }

  static Future<int?> getAccountIdx() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(keyAccountIdx);
  }

  static Future<bool> setAccountIdx(int idx) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setInt(keyAccountIdx, idx);
  }

  // ===== 사용자 정보 =====
  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyUserEmail);
  }

  static Future<bool> setUserEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(keyUserEmail, email);
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyUserName);
  }

  static Future<bool> setUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(keyUserName, name);
  }

  static Future<String?> getUserNickname() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyUserNickname);
  }

  static Future<bool> setUserNickname(String nickname) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(keyUserNickname, nickname);
  }

  // ===== 관리자 정보 =====
  static Future<String?> getAdminName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyAdminName);
  }

  static Future<bool> setAdminName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(keyAdminName, name);
  }

  static Future<String?> getAdminNickname() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyAdminNickname);
  }

  static Future<bool> setAdminNickname(String nickname) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(keyAdminNickname, nickname);
  }

  // ===== 병원 정보 =====
  static Future<String?> getHospitalName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyHospitalName);
  }

  static Future<bool> setHospitalName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(keyHospitalName, name);
  }

  static Future<String?> getHospitalNickname() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyHospitalNickname);
  }

  static Future<bool> setHospitalNickname(String nickname) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(keyHospitalNickname, nickname);
  }

  static Future<String?> getHospitalCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyHospitalCode);
  }

  static Future<bool> setHospitalCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(keyHospitalCode, code);
  }

  // ===== 지역 선택 =====
  static Future<bool> isRegionInitialized() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyRegionInitialized) ?? false;
  }

  static Future<bool> setRegionInitialized(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setBool(keyRegionInitialized, value);
  }

  static Future<List<String>> getPreferredLargeRegions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(keyPreferredLargeRegions) ?? [];
  }

  static Future<bool> setPreferredLargeRegions(List<String> regions) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setStringList(keyPreferredLargeRegions, regions);
  }

  static Future<String?> getPreferredMediumRegions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyPreferredMediumRegions);
  }

  static Future<bool> setPreferredMediumRegions(String json) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(keyPreferredMediumRegions, json);
  }

  // ===== 칼럼 조회 기록 (동적 키) =====
  static Future<bool> isColumnViewed(int columnIdx) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('column_viewed_$columnIdx') ?? false;
  }

  static Future<bool> setColumnViewed(int columnIdx) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setBool('column_viewed_$columnIdx', true);
  }

  static Future<bool> isHospitalColumnViewed(int columnIdx) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('hospital_column_viewed_$columnIdx') ?? false;
  }

  static Future<bool> setHospitalColumnViewed(int columnIdx) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setBool('hospital_column_viewed_$columnIdx', true);
  }

  // ===== 유틸리티 =====
  static Future<bool> isLoggedIn() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }

  /// 모든 데이터 삭제 (로그아웃)
  static Future<bool> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.clear();
  }
}
