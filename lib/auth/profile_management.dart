import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';

class ProfileManagement extends StatefulWidget {
  const ProfileManagement({super.key});

  @override
  State<ProfileManagement> createState() => _ProfileManagementState();
}

class _ProfileManagementState extends State<ProfileManagement> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  bool isLoading = true;
  String? token;
  int? userType; // 1: 관리자, 2: 병원, 3: 사용자
  String profileTitle = "프로필 관리";

  @override
  void initState() {
    super.initState();
    _loadTokenAndProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Future<void> _loadTokenAndProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString('auth_token');
    final storedUserType = prefs.getInt('user_type');
    
    setState(() {
      token = storedToken;
      userType = storedUserType;
      profileTitle = _getProfileTitle(storedUserType);
    });

    if (token != null) {
      await _fetchUserProfile();
    } else {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보를 찾을 수 없습니다.')),
      );
    }
  }

  String _getProfileTitle(int? userType) {
    switch (userType) {
      case 1:
        return "관리자 프로필";
      case 2:
        return "병원 프로필";
      case 3:
        return "사용자 프로필";
      default:
        return "프로필 관리";
    }
  }

  IconData _getProfileIcon() {
    switch (userType) {
      case 1:
        return Icons.admin_panel_settings_outlined;
      case 2:
        return Icons.local_hospital_outlined;
      case 3:
        return Icons.person_outline;
      default:
        return Icons.person_outline;
    }
  }

  Future<void> _fetchUserProfile() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.100.54.176:8002/api/auth/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          nameController.text = data['name'] ?? '';
          emailController.text = data['email'] ?? '';
          phoneController.text = data['phone_number'] ?? '';
          addressController.text = data['address'] ?? '';
          isLoading = false;
        });
      } else {
        throw Exception('프로필 정보를 불러오는데 실패했습니다.');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    }
  }

  Future<void> _updateUserProfile() async {
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보를 찾을 수 없습니다.')),
      );
      return;
    }

    try {
      final response = await http.put(
        Uri.parse('http://10.100.54.176:8002/api/auth/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'name': nameController.text,
          'email': emailController.text,
          'phone_number': phoneController.text,
          'address': addressController.text,
        }),
      );

      if (response.statusCode == 200) {
        // 이름이 변경된 경우 사용자 타입에 따라 SharedPreferences에 저장
        final prefs = await SharedPreferences.getInstance();
        switch (userType) {
          case 1: // 관리자
            await prefs.setString('admin_name', nameController.text);
            break;
          case 2: // 병원
            await prefs.setString('hospital_name', nameController.text);
            break;
          case 3: // 사용자
            await prefs.setString('user_name', nameController.text);
            break;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필이 성공적으로 업데이트되었습니다.')),
        );
      } else {
        throw Exception('프로필 업데이트에 실패했습니다.');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    }
  }

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
        borderSide: BorderSide(
          color: AppTheme.primaryBlue,
          width: 2,
        ),
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
        body: const Center(
          child: CircularProgressIndicator(),
        ),
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
          Padding(
            padding: const EdgeInsets.only(right: AppTheme.spacing8),
            child: IconButton(
              icon: Icon(
                Icons.save_outlined,
                color: AppTheme.primaryBlue,
              ),
              onPressed: _updateUserProfile,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 20.0,
          vertical: 24.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 프로필 사진 섹션
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: AppTheme.veryLightGray,
                  child: Icon(
                    _getProfileIcon(),
                    size: 50,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('사진 변경 기능 (미구현)')),
                      );
                    },
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: AppTheme.primaryBlue,
                      child: Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              nameController.text.isNotEmpty ? nameController.text : "사용자",
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
                shadowColor: Colors.black.withOpacity(0.1),
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spacing20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radius16),
                    border: Border.all(
                      color: AppTheme.lightGray.withOpacity(0.8),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        maxLength: 30,
                        decoration: _buildInputDecoration(
                          "이름",
                          Icons.person_outline,
                          30,
                          nameController,
                        ),
                        onChanged: (value) => setState(() {}),
                      ),
                      TextField(
                        controller: emailController,
                        maxLength: 30,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _buildInputDecoration(
                          "이메일",
                          Icons.email_outlined,
                          30,
                          emailController,
                        ),
                        onChanged: (value) => setState(() {}),
                      ),
                      const SizedBox(height: AppTheme.spacing20),
                      TextField(
                        controller: phoneController,
                        maxLength: 15,
                        keyboardType: TextInputType.phone,
                        decoration: _buildInputDecoration(
                          "연락처",
                          Icons.phone_outlined,
                          15,
                          phoneController,
                        ),
                        onChanged: (value) => setState(() {}),
                      ),
                      const SizedBox(height: AppTheme.spacing20),
                      TextField(
                        controller: addressController,
                        maxLength: 50,
                        maxLines: 2,
                        minLines: 1,
                        decoration: _buildInputDecoration(
                          "주소",
                          Icons.location_on_outlined,
                          50,
                          addressController,
                        ),
                        onChanged: (value) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacing32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('계정 탈퇴 기능 (미구현)')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  "계정 탈퇴",
                  style: AppTheme.bodyLargeStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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