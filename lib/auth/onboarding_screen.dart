// lib/auth/onboarding_screen.dart
// 네이버 회원가입 후 온보딩 화면
// Step 1: 닉네임(지역 선택 + 닉네임 입력) + 주소 검색
// Step 2: 반려견 등록 (스킵 가능)
// 최종 완료 시 POST /api/auth/onboarding 1회 호출

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kpostal/kpostal.dart';
import '../utils/app_theme.dart';
import '../utils/config.dart';
import '../utils/preferences_manager.dart';
import '../utils/blood_type_constants.dart';
import '../utils/kakao_postcode_stub.dart'
    if (dart.library.html) '../utils/kakao_postcode_web.dart';
import '../services/auth_http_client.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input_field.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  bool _isSubmitting = false;

  // === Step 1: 닉네임 + 주소 ===
  final _nicknameController = TextEditingController();
  final _addressController = TextEditingController();
  String _selectedRegion = '서울';
  bool _isNicknameAvailable = true;
  bool _isCheckingNickname = false;
  String? _nicknameError;
  Timer? _nicknameDebounce;

  // === Step 2: 반려견 등록 (선택) ===
  final _petNameController = TextEditingController();
  final _petBreedController = TextEditingController();
  final _petAgeController = TextEditingController();
  final _petWeightController = TextEditingController();
  final _petAgeMonthsController = TextEditingController();
  String? _selectedSpecies;
  int? _selectedAnimalType;
  String? _selectedBloodType;
  bool _isVaccinated = false;
  bool _hasDisease = false;
  bool _hasBirthExperience = false;
  bool _isPregnant = false;
  bool _isNeutered = false;
  DateTime? _neuteredDate;
  bool _hasPreventiveMedication = false;
  DateTime? _prevDonationDate;

  // 지역 목록 (2글자 약칭)
  static const List<String> _regions = [
    '서울', '경기', '인천', '대구', '부산', '광주',
    '대전', '울산', '세종', '강원', '충북', '충남',
    '전북', '전남', '경북', '경남', '제주',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _nicknameController.dispose();
    _addressController.dispose();
    _petNameController.dispose();
    _petBreedController.dispose();
    _petAgeController.dispose();
    _petWeightController.dispose();
    _petAgeMonthsController.dispose();
    _nicknameDebounce?.cancel();
    super.dispose();
  }

  // 닉네임 중복 체크 (debounce 적용)
  void _onNicknameChanged(String value) {
    _nicknameDebounce?.cancel();

    if (value.trim().isEmpty) {
      setState(() {
        _nicknameError = null;
        _isNicknameAvailable = true;
        _isCheckingNickname = false;
      });
      return;
    }

    if (value.trim().length < 2) {
      setState(() {
        _nicknameError = '닉네임은 2자 이상 입력해주세요.';
        _isNicknameAvailable = false;
        _isCheckingNickname = false;
      });
      return;
    }

    setState(() {
      _isCheckingNickname = true;
      _nicknameError = null;
    });

    _nicknameDebounce = Timer(const Duration(milliseconds: 500), () {
      _checkNicknameAvailability(value.trim());
    });
  }

  Future<void> _checkNicknameAvailability(String nickname) async {
    try {
      // 전체 닉네임 형식으로 중복 체크
      final fullNickname = '[$_selectedRegion] $nickname';
      final response = await AuthHttpClient.get(
        Uri.parse(
          '${Config.serverUrl}/api/auth/check-nickname?nickname=${Uri.encodeComponent(fullNickname)}',
        ),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isNicknameAvailable = data['available'] == true;
          _isCheckingNickname = false;
          _nicknameError = _isNicknameAvailable ? null : '이미 사용 중인 닉네임입니다.';
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

  // 지역 변경 시 닉네임 중복 재체크
  void _onRegionChanged(String? region) {
    if (region == null) return;
    setState(() {
      _selectedRegion = region;
    });
    // 닉네임이 입력된 상태라면 중복 재체크
    if (_nicknameController.text.trim().length >= 2) {
      _onNicknameChanged(_nicknameController.text);
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

  // 최종 닉네임 조합
  String _buildFullNickname() {
    final nickname = _nicknameController.text.trim();
    final petName = _petNameController.text.trim();
    if (petName.isNotEmpty) {
      return '[$_selectedRegion] $nickname ($petName)';
    }
    return '[$_selectedRegion] $nickname';
  }

  // 펫 데이터 수집 (API 호출 없이 데이터만)
  Map<String, dynamic>? _collectPetData() {
    if (_selectedSpecies == null ||
        _selectedAnimalType == null ||
        _selectedBloodType == null ||
        _petNameController.text.trim().isEmpty ||
        _petAgeController.text.trim().isEmpty ||
        _petWeightController.text.trim().isEmpty) {
      return null;
    }

    int? ageMonths;
    if (_petAgeMonthsController.text.trim().isNotEmpty) {
      ageMonths = int.tryParse(_petAgeMonthsController.text.trim());
    }

    return {
      'name': _petNameController.text.trim(),
      'species': _selectedSpecies!,
      'animal_type': _selectedAnimalType!,
      'breed': _petBreedController.text.trim(),
      'age_number': int.parse(_petAgeController.text.trim()),
      'weight_kg': double.parse(_petWeightController.text.trim()),
      'pregnant': _isPregnant ? 1 : 0,
      'blood_type': _selectedBloodType!,
      'vaccinated': _isVaccinated ? 1 : 0,
      'has_disease': _hasDisease ? 1 : 0,
      'has_birth_experience': _hasBirthExperience ? 1 : 0,
      'prev_donation_date':
          _prevDonationDate?.toIso8601String().split('T')[0],
      'is_neutered': _isNeutered ? 1 : 0,
      'neutered_date': _neuteredDate?.toIso8601String().split('T')[0],
      'has_preventive_medication': _hasPreventiveMedication ? 1 : 0,
      'age_months': ageMonths,
    };
  }

  // 온보딩 완료 API 호출
  Future<void> _submitOnboarding({bool skipPet = false}) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final Map<String, dynamic> body = {
        'nickname': _buildFullNickname(),
        'address': _addressController.text.trim(),
      };

      // 펫 데이터 포함 (스킵하지 않은 경우)
      if (!skipPet) {
        final petData = _collectPetData();
        if (petData != null) {
          body['pet'] = petData;
        }
      }

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
          _showError('이미 사용 중인 닉네임입니다. 다른 닉네임을 입력해주세요.');
          // Step 1로 돌아가기
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          setState(() => _currentStep = 0);
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
        if (!didPop) _cancelOnboarding();
      },
      child: Scaffold(
        appBar: AppSimpleAppBar(
          title: '프로필 등록',
          onBackPressed: _cancelOnboarding,
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
          _buildStepDot(1, '반려견 등록'),
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
  // Step 1: 닉네임 + 주소
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
            '헌혈견 협회에서 사용할 닉네임과 주소를 입력해주세요.',
            style: AppTheme.bodyMediumStyle.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing32),

          // 지역 선택
          RichText(
            text: TextSpan(
              text: '지역',
              style: AppTheme.bodyMediumStyle.copyWith(
                fontWeight: FontWeight.w600,
              ),
              children: const [
                TextSpan(text: ' *', style: TextStyle(color: AppTheme.error)),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.veryLightGray,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedRegion,
                isExpanded: true,
                icon: Icon(
                  Icons.arrow_drop_down_circle_outlined,
                  color: AppTheme.textTertiary,
                ),
                style: AppTheme.bodyLargeStyle,
                onChanged: _onRegionChanged,
                items: _regions.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),

          // 닉네임 입력
          RichText(
            text: TextSpan(
              text: '닉네임',
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
            maxLength: 20,
            decoration: InputDecoration(
              hintText: '협회에서 사용할 닉네임을 입력해주세요',
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
              '사용 가능한 닉네임입니다.',
              style: AppTheme.bodySmallStyle.copyWith(
                color: Colors.green.shade600,
              ),
            ),
          ],

          // 닉네임 미리보기
          if (_nicknameController.text.trim().isNotEmpty) ...[
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
                    child: RichText(
                      text: TextSpan(
                        text: '표시될 닉네임: ',
                        style: AppTheme.bodySmallStyle.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                        children: [
                          TextSpan(
                            text:
                                '[$_selectedRegion] ${_nicknameController.text.trim()}',
                            style: AppTheme.bodySmallStyle.copyWith(
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
  // Step 2: 반려견 등록
  // ============================
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: AppTheme.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 이전 버튼
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
                setState(() => _currentStep = 0);
              },
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('이전'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text('반려견 정보를 등록해주세요', style: AppTheme.h2Style),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            '관리자가 승인 시 참고할 수 있습니다.\n나중에 등록할 수도 있습니다.',
            style: AppTheme.bodyMediumStyle.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),

          // 펫 이름
          _buildPetTextField(
            controller: _petNameController,
            label: '이름',
            hint: '반려동물의 이름을 입력해주세요.',
            required: true,
          ),

          // 종 선택
          _buildSpeciesSelector(),

          // 품종
          _buildPetTextField(
            controller: _petBreedController,
            label: '품종',
            hint: '예: 푸들, 코리안 숏헤어',
            required: false,
          ),

          // 나이
          _buildPetTextField(
            controller: _petAgeController,
            label: '나이',
            hint: '숫자만 입력해주세요 (예: 5)',
            required: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),

          // 몸무게
          _buildPetTextField(
            controller: _petWeightController,
            label: '몸무게 (kg)',
            hint: '몸무게를 숫자로 입력해주세요.',
            required: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
          ),

          // 혈액형
          _buildBloodTypeDropdown(),

          const SizedBox(height: AppTheme.spacing20),
          Text('헌혈 관련 정보', style: AppTheme.h4Style),
          const SizedBox(height: AppTheme.spacing12),

          _buildCheckboxTile(
            title: '백신 접종 여부',
            subtitle: '정기적으로 종합백신을 접종했나요?',
            value: _isVaccinated,
            onChanged: (v) => setState(() => _isVaccinated = v ?? false),
          ),
          _buildCheckboxTile(
            title: '질병 이력',
            subtitle: '심장사상충, 바베시아, 혈액관련질병 등의 질병 이력이 있나요?',
            value: _hasDisease,
            onChanged: (v) => setState(() => _hasDisease = v ?? false),
          ),
          _buildCheckboxTile(
            title: '출산 경험',
            subtitle: '출산 경험이 있나요? (출산 경험 존재 → 헌혈 불가)',
            value: _hasBirthExperience,
            onChanged: (v) =>
                setState(() => _hasBirthExperience = v ?? false),
          ),
          _buildCheckboxTile(
            title: '현재 임신 여부',
            subtitle: '현재 임신 중인가요?',
            value: _isPregnant,
            onChanged: (v) => setState(() => _isPregnant = v ?? false),
          ),
          _buildCheckboxTile(
            title: '예방약 복용',
            subtitle: '심장사상충 예방약을 정기적으로 복용하고 있나요?',
            value: _hasPreventiveMedication,
            onChanged: (v) =>
                setState(() => _hasPreventiveMedication = v ?? false),
          ),
          _buildCheckboxTile(
            title: '중성화 수술',
            subtitle: '중성화 수술을 받았나요? (수술 후 6개월 이후 헌혈 가능)',
            value: _isNeutered,
            onChanged: (v) {
              setState(() {
                _isNeutered = v ?? false;
                if (!_isNeutered) _neuteredDate = null;
              });
            },
          ),
          if (_isNeutered) _buildNeuteredDatePicker(),
          const SizedBox(height: AppTheme.spacing16),
          _buildPrevDonationDatePicker(),

          // 나이 (개월 단위, 선택)
          const SizedBox(height: AppTheme.spacing16),
          _buildPetTextField(
            controller: _petAgeMonthsController,
            label: '나이 (선택)',
            hint: '예: 24 (개월 단위)',
            required: false,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),

          const SizedBox(height: AppTheme.spacing24),

          // 등록 완료 버튼
          AppPrimaryButton(
            text: _isSubmitting ? '등록 중...' : '등록 완료',
            onPressed: _isSubmitting ? null : () => _submitOnboarding(),
            size: AppButtonSize.large,
          ),
          const SizedBox(height: AppTheme.spacing12),

          // 반려견 없어요 버튼
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: _isSubmitting
                  ? null
                  : () => _submitOnboarding(skipPet: true),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: BorderSide(color: AppTheme.lightGray),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
              ),
              child: const Text(
                '반려견이 없어요',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacing32),
        ],
      ),
    );
  }

  // === 공통 위젯 ===

  Widget _buildPetTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool required = true,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    AppInputType inputType = AppInputType.text;
    if (keyboardType == TextInputType.number) {
      inputType = AppInputType.number;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing16),
      child: AppInputField(
        label: label,
        hintText: hint,
        controller: controller,
        type: inputType,
        inputFormatters: inputFormatters,
        required: required,
      ),
    );
  }

  Widget _buildSpeciesSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: '종',
              style: AppTheme.bodyMediumStyle.copyWith(
                fontWeight: FontWeight.w600,
              ),
              children: const [
                TextSpan(text: ' *', style: TextStyle(color: AppTheme.error)),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Row(
            children: [
              Expanded(
                child: _buildSpeciesButton('강아지', Icons.pets, 0),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSpeciesButton('고양이', Icons.cruelty_free, 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeciesButton(String species, IconData icon, int animalType) {
    final isSelected = _selectedSpecies == species;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSpecies = species;
          _selectedAnimalType = animalType;
          if (_selectedBloodType != null) {
            _selectedBloodType = BloodTypeConstants.normalizeBloodType(
              bloodType: _selectedBloodType,
              species: species,
            );
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? AppTheme.primaryBlue.withValues(alpha: 0.1)
              : Colors.grey[100],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppTheme.primaryBlue : Colors.grey[600],
            ),
            const SizedBox(height: 8),
            Text(
              species,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppTheme.primaryBlue : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBloodTypeDropdown() {
    final bloodTypes = BloodTypeConstants.getBloodTypes(
      species: _selectedSpecies,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: '혈액형',
              style: AppTheme.bodyMediumStyle.copyWith(
                fontWeight: FontWeight.w600,
              ),
              children: const [
                TextSpan(text: ' *', style: TextStyle(color: AppTheme.error)),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.veryLightGray,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedBloodType,
                hint: Text(
                  '혈액형을 선택해주세요.',
                  style: AppTheme.bodyLargeStyle.copyWith(
                    color: AppTheme.textTertiary,
                  ),
                ),
                isExpanded: true,
                icon: Icon(
                  Icons.arrow_drop_down_circle_outlined,
                  color: AppTheme.textTertiary,
                ),
                style: AppTheme.bodyLargeStyle,
                onChanged: (v) => setState(() => _selectedBloodType = v),
                items: bloodTypes
                    .map<DropdownMenuItem<String>>(
                      (v) => DropdownMenuItem<String>(
                        value: v,
                        child: Text(v),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: CheckboxListTile(
          title: Text(
            title,
            style: AppTheme.bodyMediumStyle.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: AppTheme.bodySmallStyle.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.primaryBlue,
          checkColor: Colors.white,
          controlAffinity: ListTileControlAffinity.trailing,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing4,
          ),
        ),
      ),
    );
  }

  Widget _buildNeuteredDatePicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing12, left: 16),
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _neuteredDate ??
                DateTime.now().subtract(const Duration(days: 180)),
            firstDate: DateTime(2010),
            lastDate: DateTime.now(),
            helpText: '중성화 수술 일자 선택',
            cancelText: '취소',
            confirmText: '선택',
          );
          if (picked != null) setState(() => _neuteredDate = picked);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.lightBlue,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.lightGray),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today,
                  size: 20, color: AppTheme.primaryBlue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '중성화 수술 일자',
                      style: AppTheme.bodySmallStyle.copyWith(
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _neuteredDate != null
                          ? '${_neuteredDate!.year}년 ${_neuteredDate!.month}월 ${_neuteredDate!.day}일'
                          : '날짜를 선택하세요',
                      style: AppTheme.bodyMediumStyle.copyWith(
                        color: _neuteredDate != null
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppTheme.mediumGray),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrevDonationDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: '직전 헌혈 일자',
            style: AppTheme.bodyMediumStyle.copyWith(
              fontWeight: FontWeight.w600,
            ),
            children: const [
              TextSpan(
                text: ' (선택)',
                style: TextStyle(
                  color: AppTheme.textTertiary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacing8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _prevDonationDate ?? DateTime.now(),
              firstDate: DateTime(2010),
              lastDate: DateTime.now(),
              helpText: '직전 헌혈 일자 선택',
              cancelText: '취소',
              confirmText: '선택',
            );
            if (picked != null) setState(() => _prevDonationDate = picked);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.veryLightGray,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.bloodtype_outlined,
                  size: 20,
                  color: _prevDonationDate != null
                      ? AppTheme.primaryBlue
                      : AppTheme.textTertiary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _prevDonationDate != null
                        ? '${_prevDonationDate!.year}년 ${_prevDonationDate!.month}월 ${_prevDonationDate!.day}일'
                        : '헌혈 경험이 있다면 날짜를 선택하세요',
                    style: AppTheme.bodyLargeStyle.copyWith(
                      color: _prevDonationDate != null
                          ? AppTheme.textPrimary
                          : AppTheme.textTertiary,
                    ),
                  ),
                ),
                if (_prevDonationDate != null)
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: AppTheme.textTertiary,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _prevDonationDate = null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                else
                  Icon(
                    Icons.calendar_today,
                    color: AppTheme.textTertiary,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
        if (_prevDonationDate != null) ...[
          const SizedBox(height: AppTheme.spacing8),
          Builder(builder: (context) {
            final daysSince =
                DateTime.now().difference(_prevDonationDate!).inDays;
            final canDonate = daysSince >= 56;
            return Text(
              canDonate
                  ? '✓ 마지막 헌혈 후 $daysSince일 경과 (헌혈 가능)'
                  : '⏳ 마지막 헌혈 후 $daysSince일 경과 (${56 - daysSince}일 후 헌혈 가능)',
              style: AppTheme.bodySmallStyle.copyWith(
                color: canDonate
                    ? Colors.green.shade600
                    : Colors.orange.shade600,
              ),
            );
          }),
        ],
      ],
    );
  }
}
