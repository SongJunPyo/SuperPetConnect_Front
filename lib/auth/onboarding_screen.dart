// lib/auth/onboarding_screen.dart
// 네이버 회원가입 후 온보딩 화면
// Step 1: 별명 + 주소 검색
// Step 2: 반려동물 관리 (추가/삭제/대표 선택)
// 최종 완료 시 POST /api/auth/onboarding 1회 호출

import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:kpostal/kpostal.dart';
import '../utils/app_theme.dart';
import '../utils/config.dart';
import '../utils/debouncer.dart';
import '../utils/preferences_manager.dart';
import '../utils/kakao_postcode_stub.dart'
    if (dart.library.html) '../utils/kakao_postcode_web.dart';
import '../services/auth_http_client.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/app_button.dart';
import '../widgets/registration_pet_manager.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  bool _isSubmitting = false;

  // === Step 1: 별명 + 주소 ===
  final _nicknameController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isNicknameAvailable = true;
  bool _isCheckingNickname = false;
  String? _nicknameError;
  final Debouncer _nicknameDebouncer = Debouncer(
    delay: const Duration(milliseconds: 500),
  );

  // === Step 2: 반려동물 ===
  final List<RegistrationPetData> _pets = [];

  @override
  void dispose() {
    _pageController.dispose();
    _nicknameController.dispose();
    _addressController.dispose();
    _nicknameDebouncer.dispose();
    super.dispose();
  }

  // 닉네임 중복 체크 (debounce 적용)
  void _onNicknameChanged(String value) {
    if (value.trim().isEmpty) {
      _nicknameDebouncer.cancel();
      setState(() {
        _nicknameError = null;
        _isNicknameAvailable = true;
        _isCheckingNickname = false;
      });
      return;
    }

    if (value.trim().length < 2) {
      _nicknameDebouncer.cancel();
      setState(() {
        _nicknameError = '별명은 2자 이상 입력해주세요.';
        _isNicknameAvailable = false;
        _isCheckingNickname = false;
      });
      return;
    }

    setState(() {
      _isCheckingNickname = true;
      _nicknameError = null;
    });

    _nicknameDebouncer(() {
      _checkNicknameAvailability(value.trim());
    });
  }

  Future<void> _checkNicknameAvailability(String nickname) async {
    try {
      // 별명 기준으로 중복 체크
      final response = await AuthHttpClient.get(
        Uri.parse(
          '${Config.serverUrl}/api/auth/check-nickname?nickname=${Uri.encodeComponent(nickname)}',
        ),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isNicknameAvailable = data['available'] == true;
          _isCheckingNickname = false;
          _nicknameError = _isNicknameAvailable ? null : '이미 사용 중인 별명입니다.';
        });
      } else {
        setState(() {
          _isCheckingNickname = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingNickname = false;
        });
      }
    }
  }

  // Step 1 유효성 검사
  bool _isStep1Valid() {
    return _nicknameController.text.trim().length >= 2 &&
        _isNicknameAvailable &&
        !_isCheckingNickname &&
        _addressController.text.trim().isNotEmpty;
  }

  // Step 1 → Step 2 이동
  void _goToStep2() {
    if (!_isStep1Valid()) return;
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

  // 온보딩 완료 API 호출
  Future<void> _submitOnboarding() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final Map<String, dynamic> body = {
        'nickname_input': _nicknameController.text.trim(),
        'address': _addressController.text.trim(),
        'pets': _pets.map((p) => p.toJson()).toList(),
      };

      final response = await AuthHttpClient.post(
        Uri.parse('${Config.serverUrl}/api/auth/onboarding'),
        body: jsonEncode(body),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        // 온보딩 완료 상태 저장
        await PreferencesManager.setOnboardingCompleted(true);

        if (mounted) {
          // 승인 대기 안내 — 로그아웃 처리 후 로그인 화면으로 이동
          await PreferencesManager.clearAll();

          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (dialogContext) => AlertDialog(
                title: const Text('가입 완료'),
                content: const Text(
                  '프로필 등록이 완료되었습니다.\n관리자 승인 후 이용 가능합니다.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        kIsWeb ? '/login' : '/',
                        (route) => false,
                      );
                    },
                    child: const Text('확인'),
                  ),
                ],
              ),
            );
          }
        }
      } else if (response.statusCode == 409) {
        // 닉네임 중복
        if (mounted) {
          _showError('이미 사용 중인 별명입니다. 다른 별명을 입력해주세요.');
          _goBack();
        }
      } else if (response.statusCode == 400) {
        _showError('이미 온보딩이 완료된 계정입니다.');
      } else {
        final responseBody = utf8.decode(response.bodyBytes);
        _showError('오류가 발생했습니다: $responseBody');
      }
    } catch (e) {
      if (mounted) {
        _showError('서버 연결 오류가 발생했습니다.\n$e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('오류'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  // 주소 검색
  void _searchAddress() async {
    if (kIsWeb) {
      openKakaoPostcode((String address) {
        setState(() {
          _addressController.text = address;
        });
      });
    } else {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            child: KpostalView(
              callback: (Kpostal result) {
                setState(() {
                  _addressController.text = result.address;
                });
              },
            ),
          ),
        ),
      );
    }
  }

  // 온보딩 취소 — 로그아웃 후 로그인 화면으로 이동
  Future<void> _cancelOnboarding() async {
    await PreferencesManager.clearAll();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        kIsWeb ? '/login' : '/',
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (_currentStep > 0) {
            _goBack();
          } else {
            _cancelOnboarding();
          }
        }
      },
      child: Scaffold(
        appBar: AppSimpleAppBar(
          title: '프로필 등록',
          onBackPressed: () {
            if (_currentStep > 0) {
              _goBack();
            } else {
              _cancelOnboarding();
            }
          },
        ),
        body: Column(
        children: [
          // 상단 스텝 인디케이터
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
          _buildStepDot(0, '프로필 정보'),
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
  // Step 1: 별명 + 주소
  // ============================
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: AppTheme.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppTheme.spacing8),
          Text('프로필을 완성해주세요', style: AppTheme.h2Style),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            '헌혈견 협회에서 사용할 별명과 주소를 입력해주세요.',
            style: AppTheme.bodyMediumStyle.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing32),

          // 별명 입력
          RichText(
            text: TextSpan(
              text: '별명',
              style: AppTheme.bodyMediumStyle.copyWith(
                fontWeight: FontWeight.w600,
              ),
              children: const [
                TextSpan(text: ' *', style: TextStyle(color: AppTheme.error)),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          TextField(
            controller: _nicknameController,
            maxLength: 30,
            decoration: InputDecoration(
              hintText: '협회에서 사용할 별명을 입력해주세요',
              hintStyle: AppTheme.bodyLargeStyle.copyWith(
                color: AppTheme.textTertiary,
              ),
              filled: true,
              fillColor: AppTheme.veryLightGray,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                borderSide: BorderSide(
                  color: _nicknameError != null
                      ? AppTheme.error
                      : Colors.transparent,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                borderSide: BorderSide(
                  color: _nicknameError != null
                      ? AppTheme.error
                      : AppTheme.primaryBlue,
                ),
              ),
              suffixIcon: _isCheckingNickname
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _nicknameController.text.trim().length >= 2
                      ? Icon(
                          _isNicknameAvailable
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          color: _isNicknameAvailable
                              ? Colors.green
                              : AppTheme.error,
                        )
                      : null,
              counterText: '',
            ),
            onChanged: _onNicknameChanged,
          ),
          if (_nicknameError != null) ...[
            const SizedBox(height: 4),
            Text(
              _nicknameError!,
              style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.error),
            ),
          ],
          if (_nicknameController.text.trim().length >= 2 &&
              _isNicknameAvailable &&
              !_isCheckingNickname) ...[
            const SizedBox(height: 4),
            Text(
              '사용 가능한 별명입니다.',
              style: AppTheme.bodySmallStyle.copyWith(
                color: Colors.green.shade600,
              ),
            ),
          ],

          // 안내 문구
          if (_nicknameController.text.trim().isNotEmpty &&
              _addressController.text.trim().isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacing8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.spacing12),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                border: Border.all(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.badge_outlined,
                    size: 18,
                    color: AppTheme.primaryBlue,
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Expanded(
                    child: Text(
                      '별명, 주소, 반려동물 정보를 기반으로 서버에서 닉네임이 자동 생성됩니다.',
                      style: AppTheme.bodySmallStyle.copyWith(
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppTheme.spacing24),

          // 주소 입력
          RichText(
            text: TextSpan(
              text: '주소',
              style: AppTheme.bodyMediumStyle.copyWith(
                fontWeight: FontWeight.w600,
              ),
              children: const [
                TextSpan(text: ' *', style: TextStyle(color: AppTheme.error)),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          TextField(
            controller: _addressController,
            readOnly: true,
            decoration: InputDecoration(
              hintText: '주소를 검색해주세요',
              hintStyle: AppTheme.bodyLargeStyle.copyWith(
                color: AppTheme.textTertiary,
              ),
              filled: true,
              fillColor: AppTheme.veryLightGray,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: Icon(
                Icons.search_outlined,
                color: AppTheme.textSecondary,
              ),
            ),
            onTap: _searchAddress,
          ),
          const SizedBox(height: AppTheme.spacing40),

          // 다음 버튼
          AppPrimaryButton(
            text: '다음',
            onPressed: _isStep1Valid() ? _goToStep2 : null,
            size: AppButtonSize.large,
          ),
        ],
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
      onComplete: _submitOnboarding,
      onSkip: _submitOnboarding, // 스킵해도 pets: [] 로 전송
    );
  }
}
