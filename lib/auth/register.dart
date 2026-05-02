import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kpostal/kpostal.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/registration_pet_uploader.dart';
import '../utils/app_theme.dart';
import '../utils/config.dart';
import '../utils/kakao_postcode_stub.dart'
    if (dart.library.html) '../utils/kakao_postcode_web.dart';
import '../utils/phone_input_formatter.dart';
import '../utils/preferences_manager.dart';
import '../widgets/registration_pet_manager.dart';
import 'welcome.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _pageController = PageController();
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isSubmitting = false;

  // Step 1: 계정 정보
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isObscurePassword = true;
  bool _isObscureConfirmPassword = true;
  String? _fcmToken;

  // Step 2: 반려동물
  final List<RegistrationPetData> _pets = [];

  @override
  void initState() {
    super.initState();
    _getFcmToken();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _nicknameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _getFcmToken() async {
    try {
      _fcmToken = await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('Failed to get FCM token: $e');
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isSuccess ? Colors.green : Theme.of(context).colorScheme.error,
      ),
    );
  }

  // Step 1 → Step 2
  void _goToStep2() {
    if (!_formKey.currentState!.validate()) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentStep = 1);
  }

  // Step 2 → Step 1
  void _goBack() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentStep = 0);
  }

  // 주소 검색
  void _searchAddress() async {
    if (!mounted) return;
    if (kIsWeb) {
      openKakaoPostcode((String address) {
        setState(() {
          _addressController.text = address;
        });
      });
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => KpostalView(
            callback: (Kpostal result) {
              setState(() {
                _addressController.text = result.address;
              });
            },
          ),
        ),
      );
    }
  }

  /// 가입 응답의 access_token을 저장한 뒤 `pet_idxs[]`와 `_pets[]`를
  /// 인덱스 매칭으로 사진 업로드. 부분 실패는 안내만 하고 흐름 진행.
  /// 업로드가 끝나면 토큰을 즉시 클리어 (어차피 미승인이라 다른 API 호출 불가).
  Future<void> _uploadPetPhotosAfterRegister(http.Response response) async {
    Map<String, dynamic> body = const {};
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      // 응답 파싱 실패 시 사진 업로드 스킵. 가입 자체는 성공.
      return;
    }

    final accessToken = body['access_token'] as String?;
    final rawIdxs = body['pet_idxs'];
    final petIdxs = (rawIdxs is List)
        ? rawIdxs.whereType<int>().toList()
        : <int>[];

    if (accessToken == null || petIdxs.isEmpty) return;
    final hasAnyPhoto = _pets.any((p) => p.profileImage != null);
    if (!hasAnyPhoto) return;

    await PreferencesManager.setAuthToken(accessToken);

    final result = await uploadRegistrationPetPhotos(
      pets: _pets,
      petIdxs: petIdxs,
    );

    // 업로드 종료 후 토큰 클리어 — 미승인 상태에서 토큰을 남겨둘 이유 없음.
    await PreferencesManager.clearAll();

    if (!mounted) return;
    if (result.hasFailure) {
      _showSnackBar(
        '일부 반려동물 사진 업로드에 실패했습니다. (${result.failed}/${result.total})\n'
        '승인 후 "프로필 > 반려동물"에서 다시 등록해주세요.',
      );
    }
  }

  // 회원가입 API 호출
  Future<void> _submitRegistration() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final String formattedPhoneNumber =
          _phoneController.text.replaceAll('-', '');

      final requestBody = {
        'email': _emailController.text.trim(),
        'password': _passwordController.text.trim(),
        'name': _nameController.text.trim(),
        'nickname_input': _nicknameController.text.trim(),
        'phone_number': formattedPhoneNumber.trim(),
        'address': _addressController.text,
        'fcm_token': _fcmToken ?? '',
        'pets': _pets.map((p) => p.toJson()).toList(),
      };

      final response = await http.post(
        Uri.parse('${Config.serverUrl}/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        // 가입 직후 사진 업로드를 위해 access_token 저장 + 펫 사진 일괄 업로드.
        // refresh_token은 응답에 없음 (CLAUDE.md "가입 직후 access_token 정책" 참고).
        await _uploadPetPhotosAfterRegister(response);
        if (!mounted) return;

        _showSnackBar('회원가입이 완료되었습니다. 관리자 승인까지 기다려주세요.',
            isSuccess: true);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        );
      } else if (response.statusCode == 409) {
        _showSnackBar('이미 가입된 이메일 또는 전화번호입니다.');
        // Step 1로 돌아가기
        _goBack();
      } else if (response.statusCode == 400) {
        try {
          final errorData = json.decode(response.body);
          _showSnackBar(errorData['detail'] ??
              errorData['message'] ??
              '입력 데이터에 오류가 있습니다.');
        } catch (_) {
          _showSnackBar('입력 데이터 형식이 올바르지 않습니다.');
        }
      } else if (response.statusCode == 429) {
        final retryAfter = response.headers['retry-after'];
        final seconds = int.tryParse(retryAfter ?? '') ?? 60;
        _showSnackBar('너무 많은 요청을 보냈습니다.\n$seconds초 후 다시 시도해주세요.');
      } else if (response.statusCode == 500) {
        _showSnackBar('서버 내부 오류가 발생했습니다.\n잠시 후 다시 시도해주세요.');
      } else {
        _showSnackBar(
            '회원가입에 실패했습니다. (오류코드: ${response.statusCode})\n${response.body}');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('네트워크 오류가 발생했습니다: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () {
            if (_currentStep > 0) {
              _goBack();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          '회원가입',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 스텝 인디케이터
          _buildStepIndicator(),
          // 페이지 뷰
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) => setState(() => _currentStep = index),
              children: [
                _buildStep1(),
                _buildStep2(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 스텝 인디케이터
  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing24,
        vertical: AppTheme.spacing16,
      ),
      child: Row(
        children: [
          _buildStepDot(0, '계정 정보'),
          Expanded(
            child: Container(
              height: 2,
              color: _currentStep >= 1
                  ? AppTheme.primaryBlue
                  : AppTheme.lightGray,
            ),
          ),
          _buildStepDot(1, '반려동물'),
        ],
      ),
    );
  }

  Widget _buildStepDot(int step, String label) {
    final isActive = _currentStep >= step;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppTheme.primaryBlue : AppTheme.lightGray,
          ),
          child: Center(
            child: Text(
              '${step + 1}',
              style: TextStyle(
                color: isActive ? Colors.white : AppTheme.textTertiary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTheme.bodySmallStyle.copyWith(
            color: isActive ? AppTheme.primaryBlue : AppTheme.textTertiary,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // ============================
  // Step 1: 계정 정보
  // ============================
  Widget _buildStep1() {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('계정 정보를 입력해주세요', style: AppTheme.h2Style),
            const SizedBox(height: AppTheme.spacing24),

            // 이메일
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDecoration('이메일 주소', colorScheme),
              style: const TextStyle(fontSize: 16),
              validator: (value) {
                if (value == null || value.isEmpty) return '이메일을 입력해주세요.';
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                  return '유효한 이메일 주소를 입력해주세요.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 비밀번호
            TextFormField(
              controller: _passwordController,
              obscureText: _isObscurePassword,
              maxLength: 72,
              decoration: _inputDecoration('비밀번호', colorScheme).copyWith(
                counterText: '',
                suffixIcon: IconButton(
                  icon: Icon(
                    _isObscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey[600],
                  ),
                  onPressed: () =>
                      setState(() => _isObscurePassword = !_isObscurePassword),
                ),
              ),
              style: const TextStyle(fontSize: 16),
              validator: (value) {
                if (value == null || value.isEmpty) return '비밀번호를 입력해주세요.';
                if (value.length < 8) return '비밀번호는 최소 8자 이상이어야 합니다.';
                if (!RegExp(r'[A-Za-z]').hasMatch(value)) return '영문자를 포함해야 합니다.';
                if (!RegExp(r'[0-9]').hasMatch(value)) return '숫자를 포함해야 합니다.';
                if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
                  return '특수문자를 포함해야 합니다.';
                }
                return null;
              },
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 6),
              child: Text(
                '8자 이상, 영문+숫자+특수문자 포함',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
            const SizedBox(height: 16),

            // 비밀번호 확인
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _isObscureConfirmPassword,
              decoration: _inputDecoration('비밀번호 확인', colorScheme).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _isObscureConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey[600],
                  ),
                  onPressed: () => setState(
                      () => _isObscureConfirmPassword = !_isObscureConfirmPassword),
                ),
              ),
              style: const TextStyle(fontSize: 16),
              validator: (value) {
                if (value == null || value.isEmpty) return '비밀번호를 다시 입력해주세요.';
                if (value != _passwordController.text) return '비밀번호가 일치하지 않습니다.';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 이름
            TextFormField(
              controller: _nameController,
              decoration: _inputDecoration('이름', colorScheme),
              style: const TextStyle(fontSize: 16),
              validator: (value) {
                if (value == null || value.isEmpty) return '이름을 입력해주세요.';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 별명
            TextFormField(
              controller: _nicknameController,
              maxLength: 30,
              decoration: _inputDecoration('별명 (2-30자)', colorScheme),
              style: const TextStyle(fontSize: 16),
              validator: (value) {
                if (value == null || value.isEmpty) return '별명을 입력해주세요.';
                if (value.length < 2) return '별명은 2자 이상 입력해주세요.';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 전화번호
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                PhoneNumberFormatter(),
              ],
              decoration: _inputDecoration('전화번호 (예: 010-1234-5678)', colorScheme),
              style: const TextStyle(fontSize: 16),
              validator: (value) {
                if (value == null || value.isEmpty) return '전화번호를 입력해주세요.';
                if (!RegExp(r'^\d{3}-\d{3,4}-\d{4}$').hasMatch(value)) {
                  return '유효한 전화번호 형식을 입력해주세요.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 주소
            TextFormField(
              controller: _addressController,
              readOnly: true,
              decoration: _inputDecoration('주소 검색', colorScheme).copyWith(
                suffixIcon: Icon(Icons.search_outlined, color: Colors.grey[600]),
              ),
              style: const TextStyle(fontSize: 16),
              onTap: _searchAddress,
              validator: (value) {
                if (value == null || value.isEmpty) return '주소를 입력해주세요.';
                return null;
              },
            ),
            const SizedBox(height: 30),

            // 다음 버튼
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _goToStep2,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '다음',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ============================
  // Step 2: 반려동물 관리
  // ============================
  Widget _buildStep2() {
    return RegistrationPetManager(
      pets: _pets,
      isSubmitting: _isSubmitting,
      onBack: _goBack,
      onComplete: _submitRegistration,
      onSkip: _submitRegistration, // 스킵해도 pets: [] 로 전송
    );
  }

  // 공통 InputDecoration
  InputDecoration _inputDecoration(String hintText, ColorScheme colorScheme) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }
}

// 전화번호 포맷터
