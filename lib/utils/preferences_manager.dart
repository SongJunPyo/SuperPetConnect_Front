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
  static const String keyOnboardingCompleted = 'onboarding_completed';
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

  // ===== 온보딩 상태 =====
  static Future<bool> getOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyOnboardingCompleted) ?? false;
  }

  static Future<bool> setOnboardingCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setBool(keyOnboardingCompleted, value);
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

  // ===== 사용자 튜토리얼 (계정별 동적 키) =====
  // 키: tutorial_seen_user_$accountIdx
  // 자동 진입: UserDashboard 첫 빌드 시 false면 표시 → 종료 시 true 저장.
  // logout 시 clearAll()이 prefs.clear()로 모든 키 정리하므로 다음 로그인 때 다시 표시됨.
  static Future<bool> isTutorialSeenUser(int accountIdx) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('tutorial_seen_user_$accountIdx') ?? false;
  }

  static Future<bool> setTutorialSeenUser(int accountIdx) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setBool('tutorial_seen_user_$accountIdx', true);
  }

  // ===== 유틸리티 =====
  static Future<bool> isLoggedIn() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }

  /// 모든 데이터 삭제 (로그아웃)
  /// SharedPreferences 2.5.x에서 clear()만으로는 인메모리 캐시가 완전히 삭제되지 않는
  /// 버그가 있어, 각 키를 개별적으로 remove() 호출하여 캐시를 확실히 삭제.
  ///
  /// 단, `tutorial_seen_user_*` 플래그는 로그아웃 후 재로그인 시에도 보존
  /// (한 번 본 튜토리얼이 다시 안 뜨도록). 백업 → clear → 복원 패턴.
  static Future<bool> clearAll() async {
    final prefs = await SharedPreferences.getInstance();

    // 보존할 동적 키(튜토리얼 시청 기록) 백업
    final preservedKeys = prefs.getKeys()
        .where((k) => k.startsWith('tutorial_seen_user_'))
        .toList();
    final preserved = <String, bool>{
      for (final k in preservedKeys) k: prefs.getBool(k) ?? false,
    };

    // 인메모리 캐시에서 확실히 삭제하기 위해 각 키를 개별 remove
    await Future.wait([
      prefs.remove(keyAuthToken),
      prefs.remove(keyRefreshToken),
      prefs.remove(keyAccountType),
      prefs.remove(keyAccountIdx),
      prefs.remove(keyUserEmail),
      prefs.remove(keyUserName),
      prefs.remove(keyUserNickname),
      prefs.remove(keyAdminName),
      prefs.remove(keyAdminNickname),
      prefs.remove(keyHospitalName),
      prefs.remove(keyHospitalNickname),
      prefs.remove(keyHospitalCode),
      prefs.remove(keyOnboardingCompleted),
      prefs.remove(keyRegionInitialized),
      prefs.remove(keyPreferredLargeRegions),
      prefs.remove(keyPreferredMediumRegions),
    ]);
    // 마지막으로 clear()도 호출하여 동적 키(column_viewed_* 등)도 삭제
    final cleared = await prefs.clear();

    // 보존된 튜토리얼 플래그 복원
    for (final entry in preserved.entries) {
      await prefs.setBool(entry.key, entry.value);
    }

    return cleared;
  }
}
