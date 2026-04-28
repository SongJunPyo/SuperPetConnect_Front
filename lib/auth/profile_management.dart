import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:kpostal/kpostal.dart';
import 'package:provider/provider.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import '../utils/app_theme.dart';
import '../utils/api_endpoints.dart';
import '../utils/config.dart';
import '../utils/kakao_postcode_stub.dart'
    if (dart.library.html) '../utils/kakao_postcode_web.dart';
import '../services/auth_http_client.dart';
import '../utils/preferences_manager.dart';
import '../utils/app_constants.dart';
import '../providers/notification_provider.dart';
import '../widgets/pet_profile_image.dart';
import 'package:image_picker/image_picker.dart';
import '../web/web_storage_helper_stub.dart'
    if (dart.library.html) '../web/web_storage_helper.dart';

class ProfileManagement extends StatefulWidget {
  const ProfileManagement({super.key});

  @override
  State<ProfileManagement> createState() => _ProfileManagementState();
}

class _ProfileManagementState extends State<ProfileManagement> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController nicknameController = TextEditingController(); // 전체 닉네임 (readOnly)
  final TextEditingController nicknameInputController = TextEditingController(); // 별명 (수정 가능)
  final TextEditingController addressController = TextEditingController();

  // 내부적으로만 사용 (화면에 표시하지 않음)
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  bool isLoading = true;
  int? userType; // 1: 관리자, 2: 병원, 3: 사용자
  String loginType = 'email'; // 가입 방식: "email" 또는 "naver"
  String profileTitle = "프로필 관리";
  String? profileImage; // 대표 반려동물 프로필 사진
  // 같은 경로에 새 사진을 덮어쓴 직후에도 즉시 갱신되도록 NetworkImage 캐시를
  // 우회하는 cache buster. 업로드/삭제 시 증가시켜 PetProfileImage에 전달.
  int _imageRefreshKey = 0;

  @override
  void initState() {
    super.initState();
    _loadTokenAndProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    nicknameController.dispose();
    nicknameInputController.dispose();
    addressController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadTokenAndProfile() async {
    final storedUserType = await PreferencesManager.getAccountType();

    setState(() {
      userType = storedUserType;
      profileTitle = _getProfileTitle(storedUserType);
    });

    await _fetchUserProfile();
  }

  String _getProfileTitle(int? userType) {
    switch (userType) {
      case AppConstants.accountTypeAdmin:
        return "관리자 프로필";
      case AppConstants.accountTypeHospital:
        return "병원 프로필";
      case AppConstants.accountTypeUser:
        return "사용자 프로필";
      default:
        return "프로필 관리";
    }
  }

  Future<void> _fetchUserProfile() async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse('${Config.serverUrl}/api/auth/profile'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          nameController.text = data['name'] ?? '';
          nicknameController.text = data['nickname'] ?? '';
          nicknameInputController.text = data['nickname_input'] ?? '';
          addressController.text = data['address'] ?? '';
          // 내부적으로만 저장 (화면에 표시하지 않음)
          emailController.text = data['email'] ?? '';
          phoneController.text = data['phone_number'] ?? '';
          loginType = data['login_type'] ?? 'email';
          profileImage = data['profile_image'];
          isLoading = false;
        });
      } else {
        throw Exception('프로필 정보를 불러오는데 실패했습니다.');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('오류가 발생했습니다: $e')));
      }
    }
  }

  // 로그아웃 기능
  Future<void> _logout() async {
    final token = await PreferencesManager.getAuthToken();
    final refreshToken = await PreferencesManager.getRefreshToken();

    // 로컬 데이터 먼저 삭제 (서버 호출 결과와 관계없이 확실히 로그아웃)
    await PreferencesManager.clearAll();
    // 웹에서는 localStorage도 직접 클리어 (SharedPreferences 캐시 문제 방지)
    if (kIsWeb) {
      WebStorageHelper.clearAll();
    }

    // NotificationProvider 초기화 (알림 상태 및 연결 정리)
    if (mounted) {
      context.read<NotificationProvider>().reset();
    }

    // 서버에 로그아웃 API 호출 (Refresh Token 무효화)
    // AuthHttpClient 대신 plain http 사용 (로그아웃 중 자동 토큰 갱신 방지)
    try {
      await http.post(
        Uri.parse('${Config.serverUrl}/api/auth/logout'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'refresh_token': refreshToken}),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      // 서버 로그아웃 실패 시 무시 (로컬 데이터는 이미 삭제됨)
    }

    // 네이버 SDK 세션 클리어 (모바일에서 다른 계정으로 로그인 가능하도록)
    if (!kIsWeb) {
      try {
        await FlutterNaverLogin.logOutAndDeleteToken();
      } catch (_) {
        // 네이버 로그인 세션이 없는 경우 무시
      }
    }

    if (mounted) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
    }
  }

  // 로그아웃 팝업
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('로그아웃'),
          content: const Text('정말 로그아웃 하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logout();
              },
              child: Text('로그아웃', style: TextStyle(color: AppTheme.error)),
            ),
          ],
        );
      },
    );
  }

  // 저장 팝업
  void _showSaveDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('프로필 저장'),
          content: const Text('변경사항을 저장하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _updateUserProfile();
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }


  Future<void> _updateUserProfile() async {
    try {
      // 병원 계정은 nickname, address를 전송하지 않음 (서버에서 hospital_master 기준으로 자동 관리)
      final profileData = <String, String>{
        'name': nameController.text,
        'phone_number': phoneController.text,
      };
      if (isRegularUser) {
        // 일반 사용자: 별명(nickname_input)만 전송, 전체 닉네임은 서버가 자동 조합
        profileData['nickname_input'] = nicknameInputController.text;
        profileData['address'] = addressController.text;
      } else if (!isHospitalUser) {
        // 관리자: 기존대로 nickname 전송
        profileData['nickname'] = nicknameController.text;
        profileData['address'] = addressController.text;
      }

      final response = await AuthHttpClient.put(
        Uri.parse('${Config.serverUrl}/api/auth/profile'),
        body: jsonEncode(profileData),
      );

      if (response.statusCode == 200) {
        // 이름과 닉네임이 변경된 경우 사용자 타입에 따라 SharedPreferences에 저장
        switch (userType) {
          case AppConstants.accountTypeAdmin: // 관리자
            await PreferencesManager.setAdminName(nameController.text);
            await PreferencesManager.setAdminNickname(nicknameController.text);
            break;
          case AppConstants.accountTypeHospital: // 병원
            await PreferencesManager.setHospitalName(nameController.text);
            await PreferencesManager.setHospitalNickname(nicknameController.text);
            break;
          case AppConstants.accountTypeUser: // 사용자
            await PreferencesManager.setUserName(nameController.text);
            await PreferencesManager.setUserNickname(nicknameController.text);
            break;
        }

        // 서버에서 자동 생성된 닉네임 등 최신 프로필 반영
        await _fetchUserProfile();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('프로필이 성공적으로 업데이트되었습니다.')),
          );
        }
      } else {
        throw Exception('프로필 업데이트에 실패했습니다.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('오류가 발생했습니다: $e')));
      }
    }
  }

  /// 프로필 사진 옵션 표시 (병원/관리자용)
  void _showProfileImageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('갤러리에서 선택'),
              onTap: () {
                Navigator.pop(ctx);
                _uploadProfileImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('카메라로 촬영'),
              onTap: () {
                Navigator.pop(ctx);
                _uploadProfileImage(fromCamera: true);
              },
            ),
            if (profileImage != null)
              ListTile(
                leading: Icon(Icons.delete_outline, color: AppTheme.error),
                title: Text('사진 삭제', style: TextStyle(color: AppTheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteProfileImage();
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 프로필 사진 업로드 (병원/관리자: /api/auth/profile-image)
  Future<void> _uploadProfileImage({bool fromCamera = false}) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (pickedFile == null) return;

    try {
      final uri = Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.authProfileImage}',
      );
      final request = http.MultipartRequest('POST', uri);
      final token = await PreferencesManager.getAuthToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      // 웹/모바일 공통 동작을 위해 fromBytes 사용 (fromPath는 웹에서 동작 안 함)
      final bytes = await pickedFile.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes('image', bytes, filename: pickedFile.name),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (mounted) {
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            profileImage = data['profile_image'];
            _imageRefreshKey++;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('프로필 사진이 등록되었습니다.'), behavior: SnackBarBehavior.floating),
          );
        } else {
          final data = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['detail'] ?? '사진 업로드에 실패했습니다.'), behavior: SnackBarBehavior.floating),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[PROFILE UPLOAD ERROR] $e');
      debugPrint('[STACK] $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사진 업로드 중 오류가 발생했습니다: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  /// 프로필 사진 삭제 (병원/관리자)
  Future<void> _deleteProfileImage() async {
    try {
      final response = await AuthHttpClient.delete(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.authProfileImage}'),
      );
      if (mounted) {
        if (response.statusCode == 200) {
          setState(() {
            profileImage = null;
            _imageRefreshKey++;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('프로필 사진이 삭제되었습니다.'), behavior: SnackBarBehavior.floating),
          );
        }
      }
    } catch (_) {}
  }

  bool get isNaverUser => loginType == 'naver';
  bool get isHospitalUser => userType == AppConstants.accountTypeHospital;
  bool get isRegularUser => userType == AppConstants.accountTypeUser;

  InputDecoration _buildInputDecoration(
    String labelText,
    IconData icon,
    int maxLength,
    TextEditingController controller,
  ) {
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(icon, color: AppTheme.textSecondary),
      suffixText: "${controller.text.length}/$maxLength",
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        borderSide: BorderSide(color: AppTheme.lightGray),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        borderSide: BorderSide(color: AppTheme.lightGray),
      ),
      filled: true,
      fillColor: AppTheme.veryLightGray,
      labelStyle: AppTheme.bodyMediumStyle.copyWith(
        color: AppTheme.textSecondary,
      ),
      contentPadding: const EdgeInsets.symmetric(
        vertical: AppTheme.spacing16,
        horizontal: AppTheme.spacing12,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            profileTitle,
            style: AppTheme.h3Style.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          centerTitle: false,
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: AppTheme.textPrimary),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          profileTitle,
          style: AppTheme.h3Style.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
        actions: [
          // 저장 버튼
          TextButton.icon(
            icon: Icon(Icons.save_outlined, color: Colors.black87, size: 20),
            label: Text('저장', style: TextStyle(color: Colors.black87, fontSize: 14)),
            onPressed: _showSaveDialog,
          ),
          // 로그아웃 버튼
          Padding(
            padding: const EdgeInsets.only(right: AppTheme.spacing8),
            child: TextButton.icon(
              icon: Icon(Icons.logout, color: Colors.black87, size: 20),
              label: Text('로그아웃', style: TextStyle(color: Colors.black87, fontSize: 14)),
              onPressed: _showLogoutDialog,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 프로필 이미지
            GestureDetector(
              onTap: isRegularUser ? null : _showProfileImageOptions,
              child: Stack(
                children: [
                  PetProfileImage(
                    profileImage: profileImage,
                    radius: 48,
                    cacheBuster: _imageRefreshKey,
                  ),
                  if (!isRegularUser)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacing12),
            Text(
              nicknameController.text.isNotEmpty
                  ? nicknameController.text
                  : (nameController.text.isNotEmpty
                      ? nameController.text
                      : "사용자"),
              style: AppTheme.h2Style.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacing32),
            Container(
              margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radius16),
                elevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.1),
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spacing20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radius16),
                    border: Border.all(
                      color: AppTheme.lightGray.withValues(alpha: 0.8),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 네이버 사용자 안내 문구
                      if (isNaverUser)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(
                            bottom: AppTheme.spacing16,
                          ),
                          padding: const EdgeInsets.all(AppTheme.spacing12),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF03C75A,
                            ).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius8,
                            ),
                            border: Border.all(
                              color: const Color(
                                0xFF03C75A,
                              ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 18,
                                color: const Color(0xFF03C75A),
                              ),
                              const SizedBox(width: AppTheme.spacing8),
                              Expanded(
                                child: Text(
                                  isHospitalUser
                                      ? '네이버 연동 계정입니다. 닉네임과 주소는 소속 병원 기준으로 자동 관리됩니다.'
                                      : '네이버 연동 계정입니다. 이름은 네이버에서만 변경할 수 있습니다.',
                                  style: AppTheme.bodySmallStyle.copyWith(
                                    color: const Color(0xFF03C75A),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      // 일반 사용자 (비네이버) 안내 문구
                      if (!isNaverUser && isRegularUser)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(
                            bottom: AppTheme.spacing16,
                          ),
                          padding: const EdgeInsets.all(AppTheme.spacing12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius8,
                            ),
                            border: Border.all(
                              color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 18,
                                color: AppTheme.primaryBlue,
                              ),
                              const SizedBox(width: AppTheme.spacing8),
                              Expanded(
                                child: Text(
                                  '닉네임은 별명, 지역, 반려동물 정보로 자동 생성됩니다.',
                                  style: AppTheme.bodySmallStyle.copyWith(
                                    color: AppTheme.primaryBlue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      // 병원 계정 (비네이버) 주소 안내 문구
                      if (!isNaverUser && isHospitalUser)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(
                            bottom: AppTheme.spacing16,
                          ),
                          padding: const EdgeInsets.all(AppTheme.spacing12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius8,
                            ),
                            border: Border.all(
                              color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 18,
                                color: AppTheme.primaryBlue,
                              ),
                              const SizedBox(width: AppTheme.spacing8),
                              Expanded(
                                child: Text(
                                  '닉네임과 주소는 소속 병원 기준으로 자동 관리됩니다.',
                                  style: AppTheme.bodySmallStyle.copyWith(
                                    color: AppTheme.primaryBlue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      TextField(
                        controller: nameController,
                        maxLength: 30,
                        readOnly: true,
                        decoration: _buildInputDecoration(
                          "이름",
                          Icons.lock_outline,
                          30,
                          nameController,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing20),
                      // 일반 사용자: 별명만 수정 가능
                      if (isRegularUser) ...[
                        TextField(
                          controller: nicknameInputController,
                          maxLength: 30,
                          decoration: _buildInputDecoration(
                            "별명",
                            Icons.badge_outlined,
                            30,
                            nicknameInputController,
                          ),
                          onChanged: (value) => setState(() {}),
                        ),
                      ] else ...[
                        TextField(
                          controller: nicknameController,
                          maxLength: 40,
                          readOnly: isHospitalUser,
                          decoration: _buildInputDecoration(
                            isHospitalUser
                                ? "닉네임 (소속 병원 기준 자동 관리)"
                                : "닉네임",
                            isHospitalUser
                                ? Icons.lock_outline
                                : Icons.badge_outlined,
                            40,
                            nicknameController,
                          ),
                          onChanged:
                              isHospitalUser
                                  ? null
                                  : (value) => setState(() {}),
                        ),
                      ],
                      const SizedBox(height: AppTheme.spacing20),
                      TextField(
                        controller: addressController,
                        maxLength: 50,
                        maxLines: 2,
                        minLines: 1,
                        readOnly: true,
                        decoration: _buildInputDecoration(
                          isHospitalUser
                              ? "주소 (소속 병원 기준 자동 관리)"
                              : "주소",
                          Icons.location_on_outlined,
                          50,
                          addressController,
                        ).copyWith(
                          suffixIcon: Icon(
                            isHospitalUser
                                ? Icons.lock_outline
                                : Icons.search_outlined,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        onTap: isHospitalUser
                            ? null
                            : () async {
                                if (!mounted) return;
                                if (kIsWeb) {
                                  // 웹: 카카오 주소 검색 JS API 팝업 사용
                                  openKakaoPostcode((String address) {
                                    setState(() {
                                      addressController.text = address;
                                    });
                                  });
                                } else {
                                  // 모바일: 바텀시트로 kpostal 주소 검색
                                  await showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder:
                                        (context) => Container(
                                          height:
                                              MediaQuery.of(context)
                                                  .size
                                                  .height *
                                              0.9,
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.vertical(
                                              top: Radius.circular(20),
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                const BorderRadius.vertical(
                                              top: Radius.circular(20),
                                            ),
                                            child: KpostalView(
                                              callback: (Kpostal result) {
                                                setState(() {
                                                  addressController.text =
                                                      result.address;
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                  );
                                }
                              },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacing20),
          ],
        ),
      ),
    );
  }
}
