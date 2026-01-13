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
    super.dispose();
  }

  void _savePet() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedSpecies == null || _selectedAnimalType == null || _selectedBloodType == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('종류와 혈액형을 모두 선택해주세요.')));
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
      'prev_donation_date': null, // 신규 등록 시 null
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
                title: '정기 백신 접종 여부',
                subtitle: '매년 정기적인 종합백신을 접종했나요?',
                value: _isVaccinated,
                onChanged: (value) => setState(() => _isVaccinated = value ?? false),
              ),
              _buildCheckboxTile(
                title: '질병 이력',
                subtitle: '심장사상충, 진드기매개질병, 바베시아 등의 질병 이력이 있나요?',
                value: _hasDisease,
                onChanged: (value) => setState(() => _hasDisease = value ?? false),
              ),
              _buildCheckboxTile(
                title: '출산 경험',
                subtitle: '출산 경험이 있나요? (1년 이내 출산 시 헌혈 불가)',
                value: _hasBirthExperience,
                onChanged: (value) => setState(() => _hasBirthExperience = value ?? false),
              ),
              _buildCheckboxTile(
                title: '현재 임신 여부',
                subtitle: '현재 임신 중인가요?',
                value: _isPregnant,
                onChanged: (value) => setState(() => _isPregnant = value ?? false),
              ),
              const SizedBox(height: 40),
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
        required: true,
      ),
    );
  }

  // 종류 선택 버튼 위젯 (강아지/고양이)
  Widget _buildSpeciesDropdown(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '종류',
            style: textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
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
    // context 받도록 수정
    final TextTheme textTheme = Theme.of(context).textTheme;
    // colorScheme을 사용하지 않으므로 제거

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
          Text(
            '혈액형',
            style: textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
          ), // 폰트 스타일 통일
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300), // 테두리 추가
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedBloodType,
                hint: Text(
                  '혈액형을 선택해주세요.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
                ), // 폰트 스타일 통일
                isExpanded: true,
                icon: Icon(
                  Icons.arrow_drop_down_circle_outlined,
                  color: Colors.grey[600],
                ), // 아이콘 변경
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.black87,
                ), // 폰트 스타일 통일
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
