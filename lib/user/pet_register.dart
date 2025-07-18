// lib/user/pet_register.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connect/models/pet_model.dart'; // Pet 모델 import
import 'package:intl/intl.dart'; // 날짜 포맷을 위한 패키지
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connect/utils/config.dart'; // 서버 URL 관리를 위해 import

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

  // 상태 관리를 위한 변수들
  DateTime? _selectedBirthDate;
  String? _selectedBloodType;
  bool? _isPregnant;

  // 수정 모드인지 확인하는 getter
  bool get _isEditMode => widget.petToEdit != null;

  @override
  void initState() {
    super.initState();
    // 수정 모드일 경우, 전달받은 펫 데이터로 컨트롤러와 상태 변수 초기화
    if (_isEditMode) {
      final pet = widget.petToEdit!;
      _nameController.text = pet.name;
      _speciesController.text = pet.species;
      _breedController.text = pet.breed;
      _weightController.text = pet.weightKg.toString();
      _selectedBirthDate = pet.birthDate;
      _selectedBloodType = pet.bloodType;
      _isPregnant = pet.pregnant; // +++ 임신 여부 초기화
    }
  }

  @override
  void dispose() {
    // 컨트롤러 리소스 해제
    _nameController.dispose();
    _speciesController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  // +++ 핵심 변경 포인트 2: _savePet 함수를 API 요청 로직으로 전면 수정 +++
  void _savePet() async {
    // 폼 유효성 검사
    if (!_formKey.currentState!.validate()) {
      return;
    }
    // 생년월일, 혈액형 선택 유효성 검사
    if (_selectedBirthDate == null || _selectedBloodType == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('생년월일과 혈액형을 모두 선택해주세요.')));
      return;
    }

    // 1. 저장된 인증 토큰 가져오기
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다. 다시 로그인해주세요.')));
      return;
    }

    // 2. API로 보낼 데이터 준비 (Map 형식)
    // 백엔드의 PetCreate 스키마에 맞춰 데이터를 구성합니다.
    final Map<String, dynamic> petData = {
      'name': _nameController.text.trim(),
      'species': _speciesController.text.trim(),
      'breed': _breedController.text.trim(),
      'birth_date':
          _selectedBirthDate!.toIso8601String(), // DateTime을 ISO 형식의 문자열로 변환
      'weight_kg': double.parse(_weightController.text.trim()),
      'pregnant': _isPregnant == true ? 1 : 0, // bool을 int (0 또는 1)로 변환
      // 'blood_type'은 백엔드 PetCreate 스키마에 없으므로 주석 처리합니다.
      'blood_type': _selectedBloodType!,
    };

    // 3. 서버에 POST 요청 보내기
    try {
      final response = await http.post(
        Uri.parse('${Config.serverUrl}/api/v1/pets'), // 백엔드 엔드포인트
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token', // 인증 헤더 추가
        },
        body: jsonEncode(petData), // Map 데이터를 JSON 문자열로 인코딩
      );

      // 4. 서버 응답 처리
      if (response.statusCode == 201) {
        // 201 Created 성공
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('반려동물이 성공적으로 등록되었습니다.')));
        Navigator.pop(context, true); // 성공했다는 의미로 true를 반환하며 창 닫기
      } else {
        // 실패 시 에러 메시지 표시
        final responseBody = jsonDecode(utf8.decode(response.bodyBytes));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('등록 실패: ${responseBody['detail']}')),
        );
      }
    } catch (e) {
      // 네트워크 오류 등 예외 처리
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
        centerTitle: true,
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
              // <<< 수정: 품종은 선택 입력이므로 validator 없음
              _buildTextField(
                controller: _breedController,
                label: '품종',
                hint: '예: 푸들, 코리안 숏헤어',
              ),
              _buildDatePicker(),
              // <<< 수정: 몸무게는 필수, 소수점 허용
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
              _buildBloodTypeDropdown(),
              // +++ 추가: 임신 여부 스위치
              _buildPregnantSwitch(),
              const SizedBox(height: 40),
              _buildSaveButton(),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
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
  Widget _buildDatePicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '생년월일',
            style: TextStyle(fontSize: 14, color: Colors.grey),
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
              ),
              child: Text(
                _selectedBirthDate == null
                    ? '날짜를 선택해주세요.'
                    : DateFormat('yyyy년 MM월 dd일').format(_selectedBirthDate!),
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 혈액형 선택 드롭다운 위젯
  Widget _buildBloodTypeDropdown() {
    final bloodTypes = [
      'DEA 1.1+',
      'DEA 1.1-',
      'DEA 1.2+',
      'DEA 1.2-',
      'DEA 3',
      'DEA 4',
      'DEA 5',
      'DEA 6',
      'DEA 7',
      'A',
      'B',
      'AB',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('혈액형', style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedBloodType,
                hint: const Text('혈액형을 선택해주세요.'),
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
                style: const TextStyle(fontSize: 16, color: Colors.black87),
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
  Widget _buildPregnantSwitch() {
    return SwitchListTile(
      title: const Text(
        '임신 여부 (선택)',
        style: TextStyle(fontSize: 14, color: Colors.grey),
      ),
      value: _isPregnant ?? false,
      onChanged: (bool value) {
        setState(() {
          _isPregnant = value;
        });
      },
      activeColor: Colors.blueAccent,
      contentPadding: EdgeInsets.zero,
    );
  }

  // 저장 버튼 위젯
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _savePet,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          _isEditMode ? '정보 수정' : '등록하기',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
