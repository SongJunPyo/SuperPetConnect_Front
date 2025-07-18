// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart'; // TextInputFormatter를 위해 추가
// import 'package:connect/models/pet_model.dart';
// import 'package:intl/intl.dart';
//
// class PetRegisterScreen extends StatefulWidget {
//   // 수정 모드를 위한 선택적 인자 추가
//   final Map<String, String>? petToEdit;
//   final int? petIndex;
//
//   const PetRegisterScreen({
//     super.key,
//     this.petToEdit, // 수정할 펫 데이터 (선택 사항)
//     this.petIndex, // 수정할 펫의 인덱스 (선택 사항)
//   });
//
//   @override
//   State<PetRegisterScreen> createState() => _PetRegisterScreenState();
// }
//
// class _PetRegisterScreenState extends State<PetRegisterScreen> {
//   final _formKey = GlobalKey<FormState>(); // Form 위젯의 상태를 관리하기 위한 키
//   final TextEditingController _petNameController = TextEditingController();
//   final TextEditingController _petBreedController = TextEditingController();
//   final TextEditingController _petAgeController = TextEditingController();
//   final TextEditingController _petWeightController = TextEditingController();
//
//   // 나이와 체중 필드의 포커스 노드 (late 키워드 제거, 바로 초기화)
//   final FocusNode _petAgeFocusNode = FocusNode();
//   final FocusNode _petWeightFocusNode = FocusNode();
//
//   // 펫 혈액형 선택을 위한 변수
//   String? _selectedBloodType;
//   final List<String> _bloodTypes = [
//     'DEA 1.1+',
//     'DEA 1.1-',
//     'DEA 1.2+',
//     'DEA 1.2-',
//     'AB',
//     '기타',
//   ]; // 강아지, 고양이 혈액형 예시
//
//   // 펫 성별 선택을 위한 변수
//   String? _selectedGender;
//   // 성별 옵션과 해당 아이콘 매핑
//   final Map<String, IconData> _genderIcons = {
//     '남아': Icons.male,
//     '여아': Icons.female,
//     '중성': Icons.transgender, // 중성화를 나타내는 아이콘
//   };
//   final List<String> _genders = ['남아', '여아', '중성'];
//
//   // 이 페이지가 수정 모드인지 확인하는 변수
//   bool get _isEditMode => widget.petToEdit != null;
//
//   @override
//   void initState() {
//     super.initState();
//     // 포커스 노드 초기화는 이제 여기서 하지 않고 선언 시 바로 합니다.
//
//     // 수정 모드인 경우, 전달받은 펫 데이터로 컨트롤러 초기화
//     if (_isEditMode) {
//       _petNameController.text = widget.petToEdit!['name'] ?? '';
//       _petBreedController.text = widget.petToEdit!['breed'] ?? '';
//       _petAgeController.text = widget.petToEdit!['age'] ?? '';
//       _petWeightController.text = widget.petToEdit!['weight'] ?? '';
//       _selectedBloodType = widget.petToEdit!['bloodType'];
//       _selectedGender = widget.petToEdit!['gender']; // 성별 초기화
//     }
//
//     // 나이 필드 포커스 변경 리스너
//     _petAgeFocusNode.addListener(() {
//       if (!_petAgeFocusNode.hasFocus) {
//         // 포커스를 잃었을 때 '살' 추가
//         _formatNumericInput(_petAgeController, '살');
//       } else {
//         // 포커스를 얻었을 때 '살' 제거
//         _removeUnitFromInput(_petAgeController, '살');
//       }
//     });
//
//     // 체중 필드 포커스 변경 리스너
//     _petWeightFocusNode.addListener(() {
//       if (!_petWeightFocusNode.hasFocus) {
//         // 포커스를 잃었을 때 'kg' 추가
//         _formatNumericInput(_petWeightController, 'kg');
//       } else {
//         // 포커스를 얻었을 때 'kg' 제거
//         _removeUnitFromInput(_petWeightController, 'kg');
//       }
//     });
//   }
//
//   // 숫자 입력 필드에 단위 추가
//   void _formatNumericInput(TextEditingController controller, String unit) {
//     String text = controller.text.trim();
//     if (text.isNotEmpty && !text.endsWith(unit)) {
//       // 숫자로만 구성되어 있는지 확인
//       if (double.tryParse(text.replaceAll(unit, '')) != null) {
//         controller.text = '$text$unit';
//       }
//     }
//   }
//
//   // 숫자 입력 필드에서 단위 제거
//   void _removeUnitFromInput(TextEditingController controller, String unit) {
//     String text = controller.text.trim();
//     if (text.endsWith(unit)) {
//       controller.text = text.substring(0, text.length - unit.length).trim();
//     }
//   }
//
//   @override
//   void dispose() {
//     _petNameController.dispose();
//     _petBreedController.dispose();
//     _petAgeController.dispose();
//     _petWeightController.dispose();
//     _petAgeFocusNode.dispose();
//     _petWeightFocusNode.dispose();
//     super.dispose();
//   }
//
//   // 펫 등록 또는 수정 버튼 클릭 시 호출될 함수
//   void _savePet() {
//     // 포커스가 있는 필드의 단위 제거 (유효성 검사 전 숫자만 남기기 위함)
//     _removeUnitFromInput(_petAgeController, '살');
//     _removeUnitFromInput(_petWeightController, 'kg');
//
//     if (_formKey.currentState!.validate()) {
//       final String petName = _petNameController.text;
//       final String petBreed = _petBreedController.text;
//       final String petAge = _petAgeController.text; // '살' 제거된 숫자만 남음
//       final String petWeight = _petWeightController.text; // 'kg' 제거된 숫자만 남음
//       final String? bloodType = _selectedBloodType;
//       final String? gender = _selectedGender;
//
//       final Map<String, String> petData = {
//         'name': petName,
//         'breed': petBreed,
//         'age': petAge,
//         'weight': petWeight,
//         'bloodType': bloodType ?? '', // null일 경우 빈 문자열 저장
//         'gender': gender ?? '', // 성별 정보 추가
//       };
//
//       if (_isEditMode) {
//         print('펫 수정 시도: 이름 - $petName');
//         // TODO: 실제 서버로 펫 수정 API 호출 로직 추가 (나중에)
//         // 수정 완료 후 이전 화면으로 수정된 데이터 반환
//         Navigator.pop(context, petData);
//       } else {
//         print('펫 등록 시도: 이름 - $petName');
//         // TODO: 실제 서버로 펫 등록 API 호출 로직 추가 (나중에)
//         // 등록 완료 후 이전 화면으로 등록된 데이터 반환
//         Navigator.pop(context, petData);
//       }
//     } else {
//       // 유효성 검사 실패 시, 다시 단위 붙이기 (옵션)
//       _formatNumericInput(_petAgeController, '살');
//       _formatNumericInput(_petWeightController, 'kg');
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
//           onPressed: () {
//             // 수정/등록 취소 시 false를 반환하여 이전 화면에 알림
//             Navigator.pop(context, false);
//           },
//         ),
//         // 상단바에 제목을 제거합니다.
//         title: const SizedBox.shrink(),
//         centerTitle: true,
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(24.0),
//         child: Form(
//           key: _formKey, // Form 위젯에 _formKey 할당
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const SizedBox(height: 20),
//               Text(
//                 _isEditMode ? '반려동물 정보 수정' : '새로운 반려동물 등록', // 모드에 따라 제목 변경
//                 style: const TextStyle(
//                   fontSize: 28,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.black87,
//                 ),
//               ),
//               const SizedBox(height: 30),
//               // 반려동물 이름 항목
//               const Text(
//                 '반려동물 이름',
//                 style: TextStyle(fontSize: 14, color: Colors.grey),
//               ),
//               const SizedBox(height: 8),
//               TextFormField(
//                 controller: _petNameController,
//                 decoration: InputDecoration(
//                   hintText: '반려동물 이름을 입력해주세요.', // 힌트 텍스트 변경
//                   filled: true,
//                   fillColor: Colors.grey[100],
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                   contentPadding: const EdgeInsets.symmetric(
//                     horizontal: 20,
//                     vertical: 16,
//                   ),
//                 ),
//                 style: const TextStyle(fontSize: 16),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return '반려동물 이름을 입력해주세요.';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 16),
//               // 품종 항목
//               const Text(
//                 '품종',
//                 style: TextStyle(fontSize: 14, color: Colors.grey),
//               ),
//               const SizedBox(height: 8),
//               TextFormField(
//                 controller: _petBreedController,
//                 decoration: InputDecoration(
//                   hintText: '품종을 입력해주세요. (예: 푸들, 코숏)', // 힌트 텍스트 변경
//                   filled: true,
//                   fillColor: Colors.grey[100],
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                   contentPadding: const EdgeInsets.symmetric(
//                     horizontal: 20,
//                     vertical: 16,
//                   ),
//                 ),
//                 style: const TextStyle(fontSize: 16),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return '품종을 입력해주세요.';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 16),
//               // 펫 나이 항목
//               const Text(
//                 '나이',
//                 style: TextStyle(fontSize: 14, color: Colors.grey),
//               ),
//               const SizedBox(height: 8),
//               TextFormField(
//                 controller: _petAgeController,
//                 focusNode: _petAgeFocusNode, // 포커스 노드 연결
//                 keyboardType: TextInputType.number,
//                 inputFormatters: [
//                   FilteringTextInputFormatter.digitsOnly,
//                 ], // 숫자만 입력 가능
//                 decoration: InputDecoration(
//                   hintText: '나이를 입력해주세요. (숫자만 입력)', // 힌트 텍스트 변경
//                   filled: true,
//                   fillColor: Colors.grey[100],
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                   contentPadding: const EdgeInsets.symmetric(
//                     horizontal: 20,
//                     vertical: 16,
//                   ),
//                 ),
//                 style: const TextStyle(fontSize: 16),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return '나이를 입력해주세요.';
//                   }
//                   // '살'이 붙어있을 경우 제거하고 숫자 검사
//                   final numericValue = value.replaceAll('살', '');
//                   if (int.tryParse(numericValue) == null) {
//                     return '유효한 숫자를 입력해주세요.';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 16),
//               // 펫 체중 항목
//               const Text(
//                 '체중',
//                 style: TextStyle(fontSize: 14, color: Colors.grey),
//               ),
//               const SizedBox(height: 8),
//               TextFormField(
//                 controller: _petWeightController,
//                 focusNode: _petWeightFocusNode, // 포커스 노드 연결
//                 keyboardType: TextInputType.number,
//                 inputFormatters: [
//                   FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
//                 ], // 숫자와 소수점 허용
//                 decoration: InputDecoration(
//                   hintText: '체중을 입력해주세요. (kg, 숫자만 입력)', // 힌트 텍스트 변경
//                   filled: true,
//                   fillColor: Colors.grey[100],
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: BorderSide.none,
//                   ),
//                   contentPadding: const EdgeInsets.symmetric(
//                     horizontal: 20,
//                     vertical: 16,
//                   ),
//                 ),
//                 style: const TextStyle(fontSize: 16),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return '체중을 입력해주세요.';
//                   }
//                   // 'kg'이 붙어있을 경우 제거하고 숫자 검사
//                   final numericValue = value.replaceAll('kg', '');
//                   if (double.tryParse(numericValue) == null) {
//                     return '유효한 숫자를 입력해주세요.';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 16),
//               // 성별 선택 항목
//               const Text(
//                 '성별',
//                 style: TextStyle(fontSize: 14, color: Colors.grey),
//               ),
//               const SizedBox(height: 8),
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // 기존 성별 선택 UI
//                   Row(
//                     mainAxisAlignment:
//                         MainAxisAlignment.spaceEvenly, // 핵심 수정: 버튼들을 균등하게 분배
//                     children:
//                         _genders.map((gender) {
//                           final isSelected = _selectedGender == gender;
//                           return Expanded(
//                             // 각 버튼이 동일한 공간을 차지하도록 Expanded 사용
//                             child: Padding(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 4.0,
//                               ), // 버튼 간 간격
//                               child: ChoiceChip(
//                                 label: SizedBox(
//                                   // label을 SizedBox로 감싸서 최소 너비 지정
//                                   width: 60, // 아이콘과 텍스트가 잘리지 않도록 충분한 너비 지정
//                                   child: Column(
//                                     // 아이콘과 텍스트를 함께 표시
//                                     mainAxisSize:
//                                         MainAxisSize.min, // 컬럼의 크기를 최소화
//                                     children: [
//                                       Icon(
//                                         _genderIcons[gender], // 성별에 맞는 아이콘
//                                         color:
//                                             isSelected
//                                                 ? Colors.white
//                                                 : Colors.black87,
//                                         size: 24,
//                                       ),
//                                       const SizedBox(height: 4),
//                                       Text(
//                                         gender, // 텍스트 라벨
//                                         style: TextStyle(
//                                           color:
//                                               isSelected
//                                                   ? Colors.white
//                                                   : Colors.black87,
//                                           fontWeight: FontWeight.bold,
//                                         ),
//                                         overflow:
//                                             TextOverflow.visible, // 텍스트 잘림 방지
//                                         textAlign:
//                                             TextAlign.center, // 텍스트 중앙 정렬
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                                 selected: isSelected,
//                                 onSelected: (selected) {
//                                   setState(() {
//                                     _selectedGender = selected ? gender : null;
//                                   });
//                                 },
//                                 selectedColor: Colors.blueAccent,
//                                 backgroundColor: Colors.grey[100],
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(
//                                     12,
//                                   ), // 버튼 모서리 둥글게
//                                   side: BorderSide(
//                                     color:
//                                         isSelected
//                                             ? Colors.blueAccent
//                                             : Colors.grey[300]!,
//                                     width: 1.5,
//                                   ),
//                                 ),
//                                 elevation: 1,
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 12,
//                                   vertical: 12,
//                                 ), // 패딩 조정
//                               ),
//                             ),
//                           );
//                         }).toList(),
//                   ),
//                   // 성별 선택 유효성 검사 (선택 안 했을 경우)
//                   if (_formKey.currentState?.validate() == true &&
//                       _selectedGender == null)
//                     Padding(
//                       padding: const EdgeInsets.only(top: 8.0, left: 12.0),
//                       child: Text(
//                         '성별을 선택해주세요.',
//                         style: TextStyle(
//                           color: Theme.of(context).colorScheme.error,
//                           fontSize: 12,
//                         ),
//                       ),
//                     ),
//                 ],
//               ),
//               const SizedBox(height: 16),
//               // 혈액형 항목
//               const Text(
//                 '혈액형',
//                 style: TextStyle(fontSize: 14, color: Colors.grey),
//               ),
//               const SizedBox(height: 8),
//               // 혈액형 선택 드롭다운 (기존 유지)
//               Container(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 16,
//                   vertical: 5,
//                 ),
//                 decoration: BoxDecoration(
//                   color: Colors.grey[100],
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(color: Colors.transparent), // 테두리 없음
//                 ),
//                 child: DropdownButtonHideUnderline(
//                   child: DropdownButtonFormField<String>(
//                     value: _selectedBloodType,
//                     hint: const Text('혈액형을 선택해주세요.'), // 힌트 텍스트 변경
//                     isExpanded: true,
//                     icon: const Icon(
//                       Icons.arrow_drop_down,
//                       color: Colors.black54,
//                     ),
//                     style: const TextStyle(fontSize: 16, color: Colors.black87),
//                     decoration: const InputDecoration(
//                       border:
//                           InputBorder
//                               .none, // DropdownButtonFormField의 기본 테두리 제거
//                       contentPadding: EdgeInsets.zero, // 내부 패딩 제거
//                     ),
//                     onChanged: (String? newValue) {
//                       setState(() {
//                         _selectedBloodType = newValue;
//                       });
//                     },
//                     validator: (value) {
//                       if (value == null || value.isEmpty) {
//                         return '혈액형을 선택해주세요.';
//                       }
//                       return null;
//                     },
//                     items:
//                         _bloodTypes.map<DropdownMenuItem<String>>((
//                           String value,
//                         ) {
//                           return DropdownMenuItem<String>(
//                             value: value,
//                             child: Text(value),
//                           );
//                         }).toList(),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 30),
//               // 펫 등록/수정 버튼
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: _savePet, // 등록/수정 로직 호출
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.blueAccent,
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(vertical: 16),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     elevation: 0,
//                   ),
//                   child: Text(
//                     _isEditMode ? '펫 정보 수정' : '펫 등록', // 모드에 따라 버튼 텍스트 변경
//                     style: const TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 20),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }


//================================================================================


// lib/user/pet_register.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connect/models/pet_model.dart'; // Pet 모델 import
import 'package:intl/intl.dart'; // 날짜 포맷을 위한 패키지

class PetRegisterScreen extends StatefulWidget {
  // 수정 모드를 위해 Pet 객체를 선택적으로 받음
  final Pet? petToEdit;

  const PetRegisterScreen({
    super.key,
    this.petToEdit,
  });

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
  bool? _isPregnant; // +++ 임신 여부 상태 변수 추가

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

  // 날짜 선택 UI를 표시하는 함수
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate,
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

  // 폼 데이터를 저장하고 이전 화면으로 돌아가는 함수
  void _savePet() {
    // 유효성 검사 실행
    if (_formKey.currentState!.validate()) {
      // Pet 객체 생성
      final newPet = Pet(
        petId: widget.petToEdit?.petId, // 수정 시 기존 ID 사용
        guardianIdx: 1, // TODO: 실제 로그인된 보호자 ID로 교체 필요
        name: _nameController.text.trim(),
        species: _speciesController.text.trim(),
        // 품종은 선택 사항이므로 비어있을 경우 null 저장
        breed: _breedController.text.trim(),
        birthDate: _selectedBirthDate!,
        // <<< 수정: double 타입으로 변환
        weightKg: double.parse(_weightController.text.trim()),
        bloodType: _selectedBloodType!,
        pregnant: _isPregnant, // +++ 임신 여부 추가
      );

      // 수정 또는 등록된 Pet 객체를 이전 화면으로 전달
      Navigator.pop(context, newPet);
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
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
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
                validator: (value) =>
                value!.isEmpty ? '이름은 필수 입력 항목입니다.' : null,
              ),
              _buildTextField(
                controller: _speciesController,
                label: '종',
                hint: '예: 개, 고양이',
                validator: (value) =>
                value!.isEmpty ? '종은 필수 입력 항목입니다.' : null,
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) =>
                value!.isEmpty ? '몸무게는 필수 입력 항목입니다.' : null,
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
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
          const Text('생년월일', style: TextStyle(fontSize: 14, color: Colors.grey)),
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
      'AB'
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
                items: bloodTypes.map<DropdownMenuItem<String>>((String value) {
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
      title: const Text('임신 여부 (선택)', style: TextStyle(fontSize: 14, color: Colors.grey)),
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
