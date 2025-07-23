// lib/user/pet_register.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 전화번호 포맷터 사용을 위해 필요
import 'package:intl/intl.dart'; // 날짜 포맷을 위한 패키지
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connect/utils/config.dart'; // 서버 URL 관리를 위해 import
import 'package:connect/models/pet_model.dart'; // Pet 모델 import (필요시)

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
  final _speciesController = TextEditingController();
  final _breedController = TextEditingController();
  final _weightController = TextEditingController();

  DateTime? _selectedBirthDate;
  String? _selectedBloodType;
  bool? _isPregnant;

  bool get _isEditMode => widget.petToEdit != null;

  @override
  void initState() {
    super.initState();
    // 수정 모드일 경우, 전달받은 펫 데이터로 컨트롤러와 상태 변수 초기화
    if (_isEditMode) {
      final pet = widget.petToEdit!;
      _nameController.text = pet.name;
      _speciesController.text = pet.species;
      _breedController.text = pet.breed ?? ''; // null일 경우 빈 문자열
      _weightController.text = pet.weightKg.toString();
      _selectedBirthDate = pet.birthDate;
      _selectedBloodType = pet.bloodType;
      _isPregnant = pet.pregnant;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _speciesController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _savePet() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedBirthDate == null || _selectedBloodType == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('생년월일과 혈액형을 모두 선택해주세요.')));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final int? guardianIdx = prefs.getInt('guardian_idx');

    // 🚨 불러온 값 확인하는 디버그 로그 추가
    print('DEBUG: _savePet()에서 불러온 token: $token');
    print('DEBUG: _savePet()에서 불러온 guardianIdx: $guardianIdx');

    if (token == null || guardianIdx == null || guardianIdx == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보가 없거나 유효하지 않습니다. 다시 로그인해주세요.')),
      );
      return;
    }

    final Map<String, dynamic> petData = {
      'guardian_idx': guardianIdx,
      'name': _nameController.text.trim(),
      'species': _speciesController.text.trim(),
      'breed': _breedController.text.trim(),
      'birth_date': _selectedBirthDate!.toIso8601String().split('T')[0],
      'weight_kg': double.parse(_weightController.text.trim()),
      'pregnant': _isPregnant == true ? 1 : 0,
      'blood_type': _selectedBloodType!,
    };

    try {
      final String apiUrl;
      final http.Response response;

      if (_isEditMode) {
        // 수정 모드: PUT 요청
        apiUrl =
            '${Config.serverUrl}/api/v1/pets/${widget.petToEdit!.petId}'; // 펫 ID 포함
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
        apiUrl = '${Config.serverUrl}/api/v1/pets';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode ? '반려동물 정보가 수정되었습니다.' : '반려동물이 성공적으로 등록되었습니다.',
            ),
          ),
        );
        Navigator.pop(context, true); // 성공했다는 의미로 true를 반환하며 창 닫기
      } else {
        final responseBody = jsonDecode(utf8.decode(response.bodyBytes));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '처리 실패: ${responseBody['detail'] ?? response.statusCode}',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('오류가 발생했습니다: $e')));
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: '생년월일을 선택해주세요',
    );
    if (picked != null && picked != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (기존 build 메서드 내용은 동일) ...
    final ColorScheme colorScheme =
        Theme.of(context).colorScheme; // colorScheme 사용을 위해 추가

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditMode ? '반려동물 정보 수정' : '새로운 반려동물 등록',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false, // 왼쪽 정렬
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
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
              _buildTextField(
                controller: _speciesController,
                label: '종',
                hint: '예: 개, 고양이',
                validator: (value) => value!.isEmpty ? '종은 필수 입력 항목입니다.' : null,
              ),
              _buildTextField(
                controller: _breedController,
                label: '품종',
                hint: '예: 푸들, 코리안 숏헤어',
                // 품종은 선택 입력이므로 validator 없음
              ),
              _buildDatePicker(context), // context 전달
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
              _buildPregnantSwitch(context), // context 전달
              const SizedBox(height: 40),
              _buildSaveButton(context), // context 전달
            ],
          ),
        ),
      ),
    );
  }

  // 반복되는 TextFormField 위젯을 생성하는 함수
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final ColorScheme colorScheme =
        Theme.of(context).colorScheme; // colorScheme 사용을 위해 추가
    final TextTheme textTheme =
        Theme.of(context).textTheme; // textTheme 사용을 위해 추가
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
          ), // 폰트 스타일 통일
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                // 포커스 시 테두리
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                // 기본 테두리
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
            style: const TextStyle(fontSize: 16),
            validator: validator,
          ),
        ],
      ),
    );
  }

  // 생년월일 선택 위젯
  Widget _buildDatePicker(BuildContext context) {
    // context 받도록 수정
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '생년월일',
            style: textTheme.bodySmall?.copyWith(
              color: Colors.grey[700],
            ), // 폰트 스타일 통일
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _selectDate(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300), // 테두리 추가
              ),
              child: Row(
                // 아이콘 추가를 위해 Row로 변경
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedBirthDate == null
                        ? '날짜를 선택해주세요.'
                        : DateFormat(
                          'yyyy년 MM월 dd일',
                        ).format(_selectedBirthDate!),
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.black87,
                    ), // 폰트 스타일 통일
                  ),
                  Icon(
                    Icons.calendar_today_outlined,
                    color: Colors.grey[600],
                  ), // 아이콘 추가
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 혈액형 선택 드롭다운 위젯
  Widget _buildBloodTypeDropdown(BuildContext context) {
    // context 받도록 수정
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    final bloodTypes = [
      'DEA 1.1+', 'DEA 1.1-', 'DEA 1.2+', 'DEA 1.2-', 'DEA 3', 'DEA 4', 'DEA 5',
      'DEA 6', 'DEA 7', 'A', 'B', 'AB', '기타', // '기타' 추가
    ];
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

  // 임신 여부 스위치 위젯
  Widget _buildPregnantSwitch(BuildContext context) {
    // context 받도록 수정
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Padding(
      // Padding으로 감싸서 여백 통일
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ), // 내부 패딩
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300), // 테두리 추가
        ),
        child: Row(
          // SwitchListTile 대신 Row와 Switch 사용
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '임신 여부 (선택)',
              style: textTheme.bodySmall?.copyWith(
                color: Colors.grey[700],
              ), // 폰트 스타일 통일
            ),
            Switch(
              value: _isPregnant ?? false,
              onChanged: (bool value) {
                setState(() {
                  _isPregnant = value;
                });
              },
              activeColor: colorScheme.primary, // 테마 주 색상
            ),
          ],
        ),
      ),
    );
  }

  // 저장 버튼 위젯
  Widget _buildSaveButton(BuildContext context) {
    // context 받도록 수정
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      height: 56, // 버튼 높이 고정
      child: ElevatedButton(
        onPressed: _savePet,
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary, // 테마 주 색상
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          _isEditMode ? '정보 수정' : '등록하기',
          style: textTheme.titleMedium?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
