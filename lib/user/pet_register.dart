// lib/user/pet_register.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connect/utils/config.dart';
import 'package:connect/models/pet_model.dart';
import '../utils/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input_field.dart';
import '../widgets/app_app_bar.dart';

class PetRegisterScreen extends StatefulWidget {
  // 수정 모드를 위해 Pet 객체를 선택적으로 받음
  final Pet? petToEdit;

  const PetRegisterScreen({super.key, this.petToEdit});

  @override
  State<PetRegisterScreen> createState() => _PetRegisterScreenState();
}

class _PetRegisterScreenState extends State<PetRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _weightController = TextEditingController();
  final _ageController = TextEditingController();

  String? _selectedSpecies; // 강아지 또는 고양이 (UI 표시용)
  int? _selectedAnimalType; // 0=강아지, 1=고양이 (서버 전송용)
  String? _selectedBloodType;
  bool _isPregnant = false;
  bool _isVaccinated = false;
  bool _hasDisease = false;
  bool _hasBirthExperience = false;
  bool _isNeutered = false; // 중성화 수술 여부
  DateTime? _neuteredDate; // 중성화 수술 일자
  bool _hasPreventiveMedication = false; // 예방약 복용 여부
  final _ageMonthsController = TextEditingController(); // 나이 (개월 단위)
  DateTime? _prevDonationDate; // 직전 헌혈 일자

  bool get _isEditMode => widget.petToEdit != null;

  @override
  void initState() {
    super.initState();
    // 수정 모드일 경우, 전달받은 펫 데이터로 컨트롤러와 상태 변수 초기화
    if (_isEditMode) {
      final pet = widget.petToEdit!;
      _nameController.text = pet.name;
      _selectedSpecies = pet.species;
      // animal_type 설정 (기존 species 기반으로 변환)
      _selectedAnimalType = pet.species == '강아지' ? 0 : 1;
      _breedController.text = pet.breed ?? ''; // null일 경우 빈 문자열
      _weightController.text = pet.weightKg.toString();
      _ageController.text = pet.ageNumber.toString();
      
      // 혈액형 유효성 검사
      _selectedBloodType = _validateBloodType(pet.species, pet.bloodType);
      
      _isPregnant = pet.pregnant;
      _isVaccinated = pet.vaccinated ?? false;
      _hasDisease = pet.hasDisease ?? false;
      _hasBirthExperience = pet.hasBirthExperience ?? false;
      _isNeutered = pet.isNeutered ?? false;
      _neuteredDate = pet.neuteredDate;
      _hasPreventiveMedication = pet.hasPreventiveMedication ?? false;
      _ageMonthsController.text = pet.ageMonths?.toString() ?? '';
      _prevDonationDate = pet.prevDonationDate;
    }
  }

  // 혈액형 유효성 검사 함수
  String? _validateBloodType(String species, String? bloodType) {
    if (bloodType == null) return null;
    
    List<String> validBloodTypes;
    if (species == '강아지') {
      validBloodTypes = [
        'DEA 1.1+', 'DEA 1.1-', 'DEA 1.2+', 'DEA 1.2-', 
        'DEA 3', 'DEA 4', 'DEA 5', 'DEA 6', 'DEA 7', '기타'
      ];
    } else if (species == '고양이') {
      validBloodTypes = ['A형', 'B형', 'AB형', '기타'];
    } else {
      validBloodTypes = ['기타'];
    }
    
    // 혈액형이 유효한지 확인
    if (validBloodTypes.contains(bloodType)) {
      return bloodType;
    } else {
      // 유효하지 않은 혈액형인 경우 '기타'로 설정
      return '기타';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    _ageMonthsController.dispose();
    super.dispose();
  }

  void _savePet() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedSpecies == null || _selectedAnimalType == null || _selectedBloodType == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('종과 혈액형을 모두 선택해주세요.')));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final int? accountIdx = prefs.getInt('account_idx'); // account_idx로 사용

    // 🚨 불러온 값 확인하는 디버그 로그 추가

    if (token == null || accountIdx == null || accountIdx == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 정보가 없거나 유효하지 않습니다. 다시 로그인해주세요.')),
        );
      }
      return;
    }

    // 나이(개월) 파싱
    int? ageMonths;
    if (_ageMonthsController.text.trim().isNotEmpty) {
      ageMonths = int.tryParse(_ageMonthsController.text.trim());
    }

    final Map<String, dynamic> petData = {
      'name': _nameController.text.trim(),
      'species': _selectedSpecies!,
      'animal_type': _selectedAnimalType!, // 0=강아지, 1=고양이
      'breed': _breedController.text.trim(),
      'age_number': int.parse(_ageController.text.trim()),
      'weight_kg': double.parse(_weightController.text.trim()),
      'pregnant': _isPregnant ? 1 : 0,
      'blood_type': _selectedBloodType!,
      'vaccinated': _isVaccinated ? 1 : 0,
      'has_disease': _hasDisease ? 1 : 0,
      'has_birth_experience': _hasBirthExperience ? 1 : 0,
      'prev_donation_date': _prevDonationDate?.toIso8601String().split('T')[0],
      'is_neutered': _isNeutered ? 1 : 0,
      'neutered_date': _neuteredDate?.toIso8601String().split('T')[0],
      'has_preventive_medication': _hasPreventiveMedication ? 1 : 0,
      'age_months': ageMonths,
    };
    
    // 등록 모드일 때만 account_idx 추가
    // ignore: unnecessary_null_comparison
    if (!_isEditMode && accountIdx != null) {
      petData['account_idx'] = accountIdx;
    }

    try {
      final String apiUrl;
      final http.Response response;

      if (_isEditMode) {
        // 수정 모드: PUT 요청
        apiUrl =
            '${Config.serverUrl}/api/pets/${widget.petToEdit!.petIdx}'; // 펫 ID 포함
        response = await http.put(
          // PUT 요청
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(petData),
        );
      } else {
        // 등록 모드: POST 요청
        apiUrl = '${Config.serverUrl}/api/pets';
        response = await http.post(
          // POST 요청
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(petData),
        );
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        // 201은 생성, 200은 성공적인 수정
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isEditMode ? '반려동물 정보가 수정되었습니다.' : '반려동물이 성공적으로 등록되었습니다.',
              ),
            ),
          );
          Navigator.pop(context, true); // 성공했다는 의미로 true를 반환하며 창 닫기
        }
      } else {
        final responseBody = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '처리 실패: ${responseBody['detail'] ?? response.statusCode}',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('오류가 발생했습니다: $e')));
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // ... (기존 build 메서드 내용은 동일) ...
    // colorScheme을 사용하지 않으므로 제거

    return Scaffold(
      appBar: AppSimpleAppBar(
        title: _isEditMode ? '반려동물 정보 수정' : '새로운 반려동물 등록',
      ),
      body: SingleChildScrollView(
        padding: AppTheme.pagePadding,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(
                controller: _nameController,
                label: '이름',
                hint: '반려동물의 이름을 입력해주세요.',
                validator:
                    (value) => value!.isEmpty ? '이름은 필수 입력 항목입니다.' : null,
              ),
              _buildSpeciesDropdown(context), // 종류 선택
              _buildTextField(
                controller: _breedController,
                label: '품종',
                hint: '예: 푸들, 코리안 숏헤어',
                // 품종은 선택 입력이므로 validator 없음
              ),
              _buildTextField(
                controller: _ageController,
                label: '나이',
                hint: '숫자만 입력해주세요 (예: 5)',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator:
                    (value) => value!.isEmpty ? '나이는 필수 입력 항목입니다.' : null,
              ),
              _buildTextField(
                controller: _weightController,
                label: '몸무게 (kg)',
                hint: '몸무게를 숫자로 입력해주세요.',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator:
                    (value) => value!.isEmpty ? '몸무게는 필수 입력 항목입니다.' : null,
              ),
              _buildBloodTypeDropdown(context), // context 전달
              const SizedBox(height: AppTheme.spacing20),
              Text(
                '헌혈 관련 정보',
                style: AppTheme.h4Style,
              ),
              const SizedBox(height: AppTheme.spacing12),
              _buildCheckboxTile(
                title: '백신 접종 여부',
                subtitle: '정기적으로 종합백신을 접종했나요?',
                value: _isVaccinated,
                onChanged: (value) => setState(() => _isVaccinated = value ?? false),
              ),
              _buildCheckboxTile(
                title: '질병 이력',
                subtitle: '심장사상충, 바베시아, 혈액관련질병 등의 질병 이력이 있나요?',
                value: _hasDisease,
                onChanged: (value) => setState(() => _hasDisease = value ?? false),
              ),
              _buildCheckboxTile(
                title: '출산 경험',
                subtitle: '출산 경험이 있나요? (출산 경험 존재 --> 헌혈 불가)',
                value: _hasBirthExperience,
                onChanged: (value) => setState(() => _hasBirthExperience = value ?? false),
              ),
              _buildCheckboxTile(
                title: '현재 임신 여부',
                subtitle: '현재 임신 중인가요?',
                value: _isPregnant,
                onChanged: (value) => setState(() => _isPregnant = value ?? false),
              ),
              _buildCheckboxTile(
                title: '예방약 복용',
                subtitle: '심장사상충 예방약을 정기적으로 복용하고 있나요?',
                value: _hasPreventiveMedication,
                onChanged: (value) => setState(() => _hasPreventiveMedication = value ?? false),
              ),
              _buildCheckboxTile(
                title: '중성화 수술',
                subtitle: '중성화 수술을 받았나요? (수술 후 6개월 이후 헌혈 가능)',
                value: _isNeutered,
                onChanged: (value) {
                  setState(() {
                    _isNeutered = value ?? false;
                    if (!_isNeutered) {
                      _neuteredDate = null;
                    }
                  });
                },
              ),
              if (_isNeutered) _buildNeuteredDatePicker(context),
              const SizedBox(height: AppTheme.spacing16),
              _buildPrevDonationDatePicker(context),
              const SizedBox(height: AppTheme.spacing16),
              _buildTextField(
                controller: _ageMonthsController,
                label: '나이 (선택)',
                hint: '예: 24 (개월 단위)',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) => null, // 선택사항
                required: false,
              ),
              const SizedBox(height: 24),
              _buildSaveButton(context), // context 전달
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool required = true, // 필수 여부 (기본값: true)
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
        validator: validator,
        inputFormatters: inputFormatters,
        required: required,
      ),
    );
  }

  // 종 선택 버튼 위젯 (강아지/고양이)
  Widget _buildSpeciesDropdown(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: '종',
              style: AppTheme.bodyMediumStyle.copyWith(fontWeight: FontWeight.w600),
              children: const [
                TextSpan(text: ' *', style: TextStyle(color: AppTheme.error)),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Row(
            children: [
              // 강아지 선택 버튼
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedSpecies = '강아지';
                      _selectedAnimalType = 0;
                      // 종류 변경시 혈액형 유효성 재검사
                      if (_selectedBloodType != null) {
                        _selectedBloodType = _validateBloodType('강아지', _selectedBloodType);
                      } else {
                        _selectedBloodType = null;
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedSpecies == '강아지' 
                            ? AppTheme.primaryBlue 
                            : Colors.grey.shade300,
                        width: _selectedSpecies == '강아지' ? 2 : 1,
                      ),
                      color: _selectedSpecies == '강아지' 
                          ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                          : Colors.grey[100],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.pets,
                          size: 32,
                          color: _selectedSpecies == '강아지' 
                              ? AppTheme.primaryBlue
                              : Colors.grey[600],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '강아지',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _selectedSpecies == '강아지' 
                                ? AppTheme.primaryBlue
                                : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 고양이 선택 버튼
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedSpecies = '고양이';
                      _selectedAnimalType = 1;
                      // 종류 변경시 혈액형 유효성 재검사
                      if (_selectedBloodType != null) {
                        _selectedBloodType = _validateBloodType('고양이', _selectedBloodType);
                      } else {
                        _selectedBloodType = null;
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedSpecies == '고양이' 
                            ? AppTheme.primaryBlue 
                            : Colors.grey.shade300,
                        width: _selectedSpecies == '고양이' ? 2 : 1,
                      ),
                      color: _selectedSpecies == '고양이' 
                          ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                          : Colors.grey[100],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.cruelty_free, // 고양이 아이콘
                          size: 32,
                          color: _selectedSpecies == '고양이' 
                              ? AppTheme.primaryBlue
                              : Colors.grey[600],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '고양이',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _selectedSpecies == '고양이' 
                                ? AppTheme.primaryBlue
                                : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 중성화 수술 일자 선택 위젯
  Widget _buildNeuteredDatePicker(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing12, left: 16),
      child: InkWell(
        onTap: () async {
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: _neuteredDate ?? DateTime.now().subtract(const Duration(days: 180)),
            firstDate: DateTime(2010),
            lastDate: DateTime.now(),
            helpText: '중성화 수술 일자 선택',
            cancelText: '취소',
            confirmText: '선택',
          );
          if (picked != null) {
            setState(() {
              _neuteredDate = picked;
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 20, color: Colors.blue.shade600),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '중성화 수술 일자',
                      style: AppTheme.bodySmallStyle.copyWith(
                        color: Colors.blue.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _neuteredDate != null
                          ? '${_neuteredDate!.year}년 ${_neuteredDate!.month}월 ${_neuteredDate!.day}일'
                          : '날짜를 선택하세요',
                      style: AppTheme.bodyMediumStyle.copyWith(
                        color: _neuteredDate != null ? AppTheme.textPrimary : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.blue.shade400),
            ],
          ),
        ),
      ),
    );
  }

  // 직전 헌혈 일자 선택 위젯
  Widget _buildPrevDonationDatePicker(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: '직전 헌혈 일자',
            style: AppTheme.bodyMediumStyle.copyWith(fontWeight: FontWeight.w600),
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
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: _prevDonationDate ?? DateTime.now(),
              firstDate: DateTime(2010),
              lastDate: DateTime.now(),
              helpText: '직전 헌혈 일자 선택',
              cancelText: '취소',
              confirmText: '선택',
            );
            if (picked != null) {
              setState(() {
                _prevDonationDate = picked;
              });
            }
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
                  color: _prevDonationDate != null ? AppTheme.primaryBlue : AppTheme.textTertiary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _prevDonationDate != null
                        ? '${_prevDonationDate!.year}년 ${_prevDonationDate!.month}월 ${_prevDonationDate!.day}일'
                        : '헌혈 경험이 있다면 날짜를 선택하세요',
                    style: AppTheme.bodyLargeStyle.copyWith(
                      color: _prevDonationDate != null ? AppTheme.textPrimary : AppTheme.textTertiary,
                    ),
                  ),
                ),
                if (_prevDonationDate != null)
                  IconButton(
                    icon: Icon(Icons.close, color: AppTheme.textTertiary, size: 20),
                    onPressed: () {
                      setState(() {
                        _prevDonationDate = null;
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                else
                  Icon(Icons.calendar_today, color: AppTheme.textTertiary, size: 20),
              ],
            ),
          ),
        ),
        if (_prevDonationDate != null) ...[
          const SizedBox(height: AppTheme.spacing8),
          Text(
            _getDonationIntervalMessage(),
            style: AppTheme.bodySmallStyle.copyWith(
              color: _canDonateAgain() ? Colors.green.shade600 : Colors.orange.shade600,
            ),
          ),
        ],
      ],
    );
  }

  // 헌혈 간격 메시지
  String _getDonationIntervalMessage() {
    if (_prevDonationDate == null) return '';
    final daysSince = DateTime.now().difference(_prevDonationDate!).inDays;
    if (daysSince >= 56) {
      return '✓ 마지막 헌혈 후 $daysSince일 경과 (헌혈 가능)';
    } else {
      final remaining = 56 - daysSince;
      return '⏳ 마지막 헌혈 후 $daysSince일 경과 ($remaining일 후 헌혈 가능)';
    }
  }

  // 다시 헌혈 가능 여부
  bool _canDonateAgain() {
    if (_prevDonationDate == null) return true;
    return DateTime.now().difference(_prevDonationDate!).inDays >= 56;
  }

  // 체크박스 타일 위젯
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

  // 혈액형 선택 드롭다운 위젯
  Widget _buildBloodTypeDropdown(BuildContext context) {
    // 종류에 따른 혈액형 목록
    final List<String> bloodTypes;
    if (_selectedSpecies == '강아지') {
      bloodTypes = [
        'DEA 1.1+', 'DEA 1.1-', 'DEA 1.2+', 'DEA 1.2-',
        'DEA 3', 'DEA 4', 'DEA 5', 'DEA 6', 'DEA 7', '기타'
      ];
    } else if (_selectedSpecies == '고양이') {
      bloodTypes = ['A형', 'B형', 'AB형', '기타'];
    } else {
      bloodTypes = ['기타'];
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: '혈액형',
              style: AppTheme.bodyMediumStyle.copyWith(fontWeight: FontWeight.w600),
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
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedBloodType = newValue;
                  });
                },
                items:
                    bloodTypes.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }


  // 저장 버튼 위젯
  Widget _buildSaveButton(BuildContext context) {
    // context 받도록 수정
    // textTheme과 colorScheme을 사용하지 않으므로 제거

    return AppPrimaryButton(
      text: _isEditMode ? '정보 수정' : '등록하기',
      onPressed: _savePet,
      size: AppButtonSize.large,
    );
  }
}
