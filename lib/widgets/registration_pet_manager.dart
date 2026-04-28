// 회원가입/온보딩 과정에서 사용하는 반려동물 관리 위젯
// 반려동물 추가/삭제/대표 선택 기능 제공
// 이메일 가입(register.dart)과 네이버 온보딩(onboarding_screen.dart)에서 재사용

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/app_theme.dart';
import '../utils/blood_type_constants.dart';

/// 가입 과정에서 수집하는 반려동물 데이터
///
/// [profileImage]는 가입 폼에서 선택한 프로필 사진을 메모리로 보관하기 위한 필드.
/// 가입 응답의 `pet_idxs[i]`와 매칭해 `POST /api/pets/{pet_idx}/profile-image`로
/// multipart 업로드. 직렬화 대상 아니므로 [toJson]에는 포함되지 않음.
class RegistrationPetData {
  String name;
  String species; // '강아지' or '고양이'
  int animalType; // 0=강아지, 1=고양이
  String? breed;
  DateTime? birthDate;
  String bloodType;
  double weightKg;
  bool isPrimary;
  // 성별 (0=암컷, 1=수컷). NOT NULL — 폼에서 필수 선택.
  int sex;
  // 임신/출산 상태 (0=해당없음, 1=임신중, 2=출산이력). NOT NULL.
  int pregnancyBirthStatus;
  // 출산 종료일 — pregnancyBirthStatus=2일 때만 입력.
  DateTime? lastPregnancyEndDate;
  bool vaccinated;
  bool hasDisease;
  bool isNeutered;
  DateTime? neuteredDate;
  bool hasPreventiveMedication;
  DateTime? prevDonationDate;
  XFile? profileImage;

  RegistrationPetData({
    required this.name,
    required this.species,
    required this.animalType,
    this.breed,
    this.birthDate,
    required this.bloodType,
    required this.weightKg,
    this.isPrimary = false,
    required this.sex,
    this.pregnancyBirthStatus = 0,
    this.lastPregnancyEndDate,
    this.vaccinated = false,
    this.hasDisease = false,
    this.isNeutered = false,
    this.neuteredDate,
    this.hasPreventiveMedication = false,
    this.prevDonationDate,
    this.profileImage,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'species': species,
      'animal_type': animalType,
      'breed': breed,
      'birth_date': birthDate?.toIso8601String().split('T')[0],
      'blood_type': bloodType,
      'weight_kg': weightKg,
      'is_primary': isPrimary,
      'sex': sex,
      'pregnancy_birth_status': pregnancyBirthStatus,
      'last_pregnancy_end_date':
          lastPregnancyEndDate?.toIso8601String().split('T')[0],
      'vaccinated': vaccinated,
      'has_disease': hasDisease,
      'is_neutered': isNeutered,
      'neutered_date': neuteredDate?.toIso8601String().split('T')[0],
      'has_preventive_medication': hasPreventiveMedication,
      'prev_donation_date': prevDonationDate?.toIso8601String().split('T')[0],
    };
  }
}

/// 가입 과정의 반려동물 관리 스텝 위젯
/// [pets] 현재 등록된 반려동물 목록
/// [onComplete] 완료 버튼 클릭 시 콜백
/// [onSkip] 스킵 버튼 클릭 시 콜백
/// [onBack] 이전 버튼 클릭 시 콜백
/// [isSubmitting] 제출 중 여부
class RegistrationPetManager extends StatefulWidget {
  final List<RegistrationPetData> pets;
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final VoidCallback? onBack;
  final bool isSubmitting;

  const RegistrationPetManager({
    super.key,
    required this.pets,
    required this.onComplete,
    required this.onSkip,
    this.onBack,
    this.isSubmitting = false,
  });

  @override
  State<RegistrationPetManager> createState() => _RegistrationPetManagerState();
}

class _RegistrationPetManagerState extends State<RegistrationPetManager> {
  String _formatAge(DateTime? birthDate) {
    if (birthDate == null) return '나이 미상';
    final now = DateTime.now();
    final totalMonths = (now.year - birthDate.year) * 12 + (now.month - birthDate.month);
    if (totalMonths < 0) return '나이 미상';
    if (totalMonths < 12) return '$totalMonths개월';
    return '${totalMonths ~/ 12}살';
  }

  void _addPet() async {
    final result = await Navigator.push<RegistrationPetData>(
      context,
      MaterialPageRoute(
        builder: (_) => const _PetRegistrationForm(),
      ),
    );

    if (result != null) {
      setState(() {
        // 첫 번째 펫이면 자동으로 대표 설정
        if (widget.pets.isEmpty) {
          result.isPrimary = true;
        }
        widget.pets.add(result);
      });
    }
  }

  void _deletePet(int index) {
    final pet = widget.pets[index];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('반려동물 삭제'),
        content: Text("'${pet.name}'을(를) 삭제하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                final wasPrimary = widget.pets[index].isPrimary;
                widget.pets.removeAt(index);
                // 대표가 삭제되면 첫 번째를 자동 대표로
                if (wasPrimary && widget.pets.isNotEmpty) {
                  widget.pets.first.isPrimary = true;
                }
              });
            },
            child: Text('삭제', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  void _setPrimary(int index) {
    setState(() {
      for (int i = 0; i < widget.pets.length; i++) {
        widget.pets[i].isPrimary = (i == index);
      }
    });
  }

  void _handleComplete() {
    // 펫이 있는데 대표가 없으면 경고
    if (widget.pets.isNotEmpty && !widget.pets.any((p) => p.isPrimary)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('대표 반려동물을 선택해주세요.')),
      );
      return;
    }
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppTheme.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 이전 버튼
          if (widget.onBack != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('이전'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          const SizedBox(height: AppTheme.spacing8),
          Text('반려동물을 등록해주세요', style: AppTheme.h2Style),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            '헌혈에 참여할 반려동물을 등록해주세요.\n나중에 등록할 수도 있습니다.',
            style: AppTheme.bodyMediumStyle.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),

          // 등록된 반려동물 목록
          if (widget.pets.isNotEmpty) ...[
            ...List.generate(widget.pets.length, (index) {
              return _buildPetCard(index);
            }),
            const SizedBox(height: AppTheme.spacing12),
          ],

          // 반려동물 추가 버튼
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addPet,
              icon: const Icon(Icons.add),
              label: Text(
                widget.pets.isEmpty ? '반려동물 등록하기' : '반려동물 추가하기',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryBlue,
                side: BorderSide(color: AppTheme.primaryBlue),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacing32),

          // 등록 완료 버튼
          if (widget.pets.isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: widget.isSubmitting ? null : _handleComplete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                ),
                child: Text(
                  widget.isSubmitting ? '등록 중...' : '등록 완료',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacing12),
          ],

          // 반려동물 없어요 (스킵) 버튼
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: widget.isSubmitting ? null : widget.onSkip,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: BorderSide(color: AppTheme.lightGray),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
              ),
              child: Text(
                widget.pets.isEmpty ? '반려동물이 없어요' : '반려동물 없이 완료',
                style: const TextStyle(
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

  Widget _buildPetCard(int index) {
    final pet = widget.pets[index];
    final isDog = pet.species == '강아지';

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        side: BorderSide(
          color: pet.isPrimary ? Colors.amber.shade600 : AppTheme.lightGray,
          width: pet.isPrimary ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Row(
          children: [
            // 아이콘
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing8),
              decoration: BoxDecoration(
                color: isDog ? Colors.orange.shade50 : Colors.purple.shade50,
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
              child: FaIcon(
                isDog ? FontAwesomeIcons.dog : FontAwesomeIcons.cat,
                color: isDog ? Colors.orange.shade600 : Colors.purple.shade600,
                size: 18,
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),
            // 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        pet.name,
                        style: AppTheme.bodyLargeStyle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (pet.isPrimary) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Text(
                            '대표',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.amber.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${pet.species}${pet.breed != null && pet.breed!.isNotEmpty ? ' • ${pet.breed}' : ''} • ${pet.bloodType} • ${_formatAge(pet.birthDate)} • ${pet.weightKg}kg',
                    style: AppTheme.bodySmallStyle.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // 대표 설정
            IconButton(
              icon: Icon(
                pet.isPrimary ? Icons.star : Icons.star_border,
                size: 22,
              ),
              style: IconButton.styleFrom(
                foregroundColor: AppTheme.textTertiary,
                disabledForegroundColor: Colors.amber.shade600,
              ),
              onPressed: pet.isPrimary ? null : () => _setPrimary(index),
              tooltip: pet.isPrimary ? '대표 반려동물' : '대표로 설정',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            // 삭제
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: Colors.red.shade400,
              onPressed: () => _deletePet(index),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 반려동물 등록 폼 (별도 페이지)
// ============================================================
class _PetRegistrationForm extends StatefulWidget {
  const _PetRegistrationForm();

  @override
  State<_PetRegistrationForm> createState() => _PetRegistrationFormState();
}

class _PetRegistrationFormState extends State<_PetRegistrationForm> {
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _weightController = TextEditingController();

  String? _selectedSpecies;
  int? _selectedAnimalType;
  String? _selectedBloodType;
  DateTime? _birthDate;
  // 성별 — 폼에서 필수 선택. null이면 미선택 상태.
  int? _sex;
  // 임신/출산 상태 (0=해당없음, 1=임신중, 2=출산이력)
  int _pregnancyBirthStatus = 0;
  DateTime? _lastPregnancyEndDate;
  bool _isVaccinated = false;
  bool _hasDisease = false;
  bool _isNeutered = false;
  DateTime? _neuteredDate;
  bool _hasPreventiveMedication = false;
  DateTime? _prevDonationDate;
  XFile? _profileImage;
  Uint8List? _profileImageBytes; // 미리보기용 (웹/모바일 공통, MemoryImage)

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage({bool fromCamera = false}) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (pickedFile != null && mounted) {
      // 웹/모바일 공통 미리보기를 위해 bytes를 즉시 로드.
      // 업로드 시점에 다시 readAsBytes()하기보다 한 번만 읽고 재사용.
      final bytes = await pickedFile.readAsBytes();
      if (mounted) {
        setState(() {
          _profileImage = pickedFile;
          _profileImageBytes = bytes;
        });
      }
    }
  }

  void _showProfileImageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리에서 선택'),
              onTap: () {
                Navigator.pop(context);
                _pickProfileImage(fromCamera: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('카메라로 촬영'),
              onTap: () {
                Navigator.pop(context);
                _pickProfileImage(fromCamera: true);
              },
            ),
            if (_profileImage != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppTheme.error),
                title: const Text('사진 삭제', style: TextStyle(color: AppTheme.error)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _profileImage = null;
                    _profileImageBytes = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  bool _isValid() {
    final basicValid = _nameController.text.trim().isNotEmpty &&
        _selectedSpecies != null &&
        _selectedBloodType != null &&
        _weightController.text.trim().isNotEmpty &&
        _breedController.text.trim().isNotEmpty &&
        _sex != null;
    if (!basicValid) return false;
    // 출산 이력(status=2) 선택 시 종료일 필수
    if (_pregnancyBirthStatus == 2 && _lastPregnancyEndDate == null) {
      return false;
    }
    // 중성화 체크 시 수술일 필수
    if (_isNeutered && _neuteredDate == null) {
      return false;
    }
    return true;
  }

  void _submit() {
    if (!_isValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('필수 항목을 모두 입력해주세요.')),
      );
      return;
    }

    final pet = RegistrationPetData(
      name: _nameController.text.trim(),
      species: _selectedSpecies!,
      animalType: _selectedAnimalType ?? 0,
      breed: _breedController.text.trim(),
      birthDate: _birthDate,
      bloodType: _selectedBloodType!,
      weightKg: double.parse(_weightController.text.trim()),
      sex: _sex!,
      pregnancyBirthStatus: _pregnancyBirthStatus,
      lastPregnancyEndDate: _lastPregnancyEndDate,
      vaccinated: _isVaccinated,
      hasDisease: _hasDisease,
      isNeutered: _isNeutered,
      neuteredDate: _neuteredDate,
      hasPreventiveMedication: _hasPreventiveMedication,
      prevDonationDate: _prevDonationDate,
      profileImage: _profileImage,
    );

    Navigator.pop(context, pet);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('반려동물 등록'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: AppTheme.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로필 사진 선택 (선택사항)
            Center(child: _buildProfileImagePicker()),
            const SizedBox(height: AppTheme.spacing24),

            // 이름
            _buildTextField(
              controller: _nameController,
              label: '이름',
              hint: '반려동물의 이름을 입력해주세요.',
              required: true,
            ),

            // 종 선택
            _buildSpeciesSelector(),

            // 성별 선택 (필수 — CLAUDE.md PetSex 미러)
            _buildSexSelector(),

            // 품종
            _buildTextField(
              controller: _breedController,
              label: '품종',
              hint: '예: 푸들, 코리안 숏헤어',
              required: true,
            ),

            // 생년월일
            _buildBirthDatePicker(),

            // 몸무게
            _buildTextField(
              controller: _weightController,
              label: '몸무게 (kg)',
              hint: '몸무게를 숫자로 입력해주세요.',
              required: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
            ),

            // 혈액형
            _buildBloodTypeDropdown(),

            // 직전 헌혈 일자
            _buildPrevDonationDatePicker(),

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
            // 임신/출산 통합 셀렉터 (CLAUDE.md PregnancyBirthStatus 미러)
            _buildPregnancyBirthSelector(),
            _buildCheckboxTile(
              title: '예방약 복용',
              subtitle: '심장사상충 예방약을 정기적으로 복용하고 있나요?',
              value: _hasPreventiveMedication,
              onChanged: (v) => setState(() => _hasPreventiveMedication = v ?? false),
            ),
            _buildCheckboxTile(
              title: '중성화 수술',
              subtitle: '중성화 수술을 받았나요? (수술 후 6개월 이후 헌혈 가능, 수술일 필수)',
              value: _isNeutered,
              onChanged: (v) {
                setState(() {
                  _isNeutered = v ?? false;
                  if (!_isNeutered) _neuteredDate = null;
                });
              },
            ),
            if (_isNeutered) _buildNeuteredDatePicker(),

            const SizedBox(height: AppTheme.spacing12),
            // 재심사 안내 (정보 수정 워크플로우 — 가입 폼이라 첫 등록은 해당 없지만 안내)
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              decoration: BoxDecoration(
                color: AppTheme.lightBlue,
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
              child: Text(
                '※ 등록 후 정보 수정 시 관리자 재심사가 진행되어 일시적으로 헌혈 신청이 제한될 수 있습니다.',
                style: AppTheme.bodySmallStyle.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacing24),

            // 등록 버튼
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isValid() ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.lightGray,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                ),
                child: const Text(
                  '등록',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacing32),
          ],
        ),
      ),
    );
  }

  // === 공통 위젯 ===

  /// 프로필 사진 선택 (선택사항). XFile은 가입 응답 후 multipart 업로드용.
  Widget _buildProfileImagePicker() {
    return GestureDetector(
      onTap: _showProfileImageOptions,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: AppTheme.veryLightGray,
            backgroundImage:
                _profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null,
            child: _profileImageBytes == null
                ? const Icon(
                    Icons.pets,
                    size: 36,
                    color: AppTheme.textTertiary,
                  )
                : null,
          ),
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
              child: const Icon(
                Icons.camera_alt,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool required = true,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: label,
              style: AppTheme.bodyMediumStyle.copyWith(
                fontWeight: FontWeight.w600,
              ),
              children: [
                if (required)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: AppTheme.error),
                  )
                else
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
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTheme.bodyLargeStyle.copyWith(
                color: AppTheme.textTertiary,
              ),
              filled: true,
              fillColor: AppTheme.veryLightGray,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                borderSide: BorderSide(color: AppTheme.primaryBlue),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeciesSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing16),
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
              Expanded(child: _buildSpeciesButton('강아지', Icons.pets, 0)),
              const SizedBox(width: 12),
              Expanded(child: _buildSpeciesButton('고양이', Icons.cruelty_free, 1)),
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
            Icon(icon, size: 32, color: isSelected ? AppTheme.primaryBlue : Colors.grey[600]),
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

  /// 성별 선택 (필수 — CLAUDE.md PetSex 미러: 0=암컷, 1=수컷)
  Widget _buildSexSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: '성별',
              style: AppTheme.bodyMediumStyle.copyWith(fontWeight: FontWeight.w600),
              children: const [
                TextSpan(text: ' *', style: TextStyle(color: AppTheme.error)),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Row(
            children: [
              Expanded(child: _buildSexButton('암컷', 0)),
              const SizedBox(width: 12),
              Expanded(child: _buildSexButton('수컷', 1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSexButton(String label, int value) {
    final isSelected = _sex == value;
    return GestureDetector(
      onTap: () => setState(() {
        _sex = value;
        // 수컷이면 임신/출산 자동 해당없음
        if (value == 1) {
          _pregnancyBirthStatus = 0;
          _lastPregnancyEndDate = null;
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppTheme.primaryBlue : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }

  /// 임신/출산 통합 셀렉터 (CLAUDE.md PregnancyBirthStatus 미러)
  /// 수컷이면 비활성화. status=2 선택 시 종료일 picker 노출.
  Widget _buildPregnancyBirthSelector() {
    final isMale = _sex == 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '임신/출산 상태',
              style: AppTheme.bodyMediumStyle.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              isMale
                  ? '수컷은 해당 없음으로 자동 설정됩니다.'
                  : '출산 종료 시 직접 \'출산 이력 있음\'으로 변경하고 종료일을 입력해주세요.',
              style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: AppTheme.spacing12),
            // RadioGroup으로 groupValue/onChanged 관리 (Flutter 3.32+ 신규 API).
            // onChanged는 non-nullable이라 disabled는 콜백 내부에서 처리.
            RadioGroup<int>(
              groupValue: _pregnancyBirthStatus,
              onChanged: (v) {
                if (isMale) return; // 수컷은 변경 불가
                setState(() {
                  _pregnancyBirthStatus = v ?? 0;
                  if (_pregnancyBirthStatus != 2) {
                    _lastPregnancyEndDate = null;
                  }
                });
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPregnancyBirthRadio(0, '해당 없음', isMale),
                  _buildPregnancyBirthRadio(1, '현재 임신중', isMale),
                  _buildPregnancyBirthRadio(2, '출산 이력 있음', isMale),
                ],
              ),
            ),
            if (_pregnancyBirthStatus == 2) ...[
              const SizedBox(height: AppTheme.spacing8),
              _buildLastPregnancyEndDatePicker(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPregnancyBirthRadio(int value, String label, bool disabled) {
    // groupValue/onChanged는 부모 RadioGroup에서 관리. InkWell 탭으로도 선택 가능.
    return InkWell(
      onTap: disabled
          ? null
          : () => setState(() {
                _pregnancyBirthStatus = value;
                if (value != 2) _lastPregnancyEndDate = null;
              }),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Radio<int>(
              value: value,
              activeColor: AppTheme.primaryBlue,
            ),
            Expanded(
              child: Text(
                label,
                style: AppTheme.bodyMediumStyle.copyWith(
                  color: disabled ? AppTheme.textTertiary : AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 출산 종료일 picker (status=2일 때만 노출, 필수)
  Widget _buildLastPregnancyEndDatePicker() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _lastPregnancyEndDate ?? DateTime.now(),
          firstDate: DateTime(2010),
          lastDate: DateTime.now(),
          helpText: '출산 종료일 선택',
          cancelText: '취소',
          confirmText: '선택',
        );
        if (picked != null) setState(() => _lastPregnancyEndDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.lightBlue,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.lightGray),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 18, color: AppTheme.primaryBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '출산 종료일 *',
                    style: AppTheme.bodySmallStyle.copyWith(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _lastPregnancyEndDate != null
                        ? '${_lastPregnancyEndDate!.year}년 ${_lastPregnancyEndDate!.month}월 ${_lastPregnancyEndDate!.day}일'
                        : '날짜를 선택하세요',
                    style: AppTheme.bodyMediumStyle.copyWith(
                      color: _lastPregnancyEndDate != null
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
    );
  }

  Widget _buildBloodTypeDropdown() {
    final bloodTypes = BloodTypeConstants.getBloodTypes(species: _selectedSpecies);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing16),
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
                  style: AppTheme.bodyLargeStyle.copyWith(color: AppTheme.textTertiary),
                ),
                isExpanded: true,
                icon: Icon(Icons.arrow_drop_down_circle_outlined, color: AppTheme.textTertiary),
                style: AppTheme.bodyLargeStyle,
                onChanged: (v) => setState(() => _selectedBloodType = v),
                items: bloodTypes
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
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
          title: Text(title, style: AppTheme.bodyMediumStyle.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle, style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.textSecondary)),
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

  Widget _buildBirthDatePicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: '생년월일',
              style: AppTheme.bodyMediumStyle.copyWith(fontWeight: FontWeight.w600),
              children: const [
                TextSpan(
                  text: ' (선택)',
                  style: TextStyle(color: AppTheme.textTertiary, fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _birthDate ?? DateTime.now().subtract(const Duration(days: 365 * 2)),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
                helpText: '생년월일 선택',
                cancelText: '취소',
                confirmText: '선택',
              );
              if (picked != null) setState(() => _birthDate = picked);
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
                    Icons.cake_outlined,
                    size: 20,
                    color: _birthDate != null ? AppTheme.primaryBlue : AppTheme.textTertiary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _birthDate != null
                          ? '${_birthDate!.year}년 ${_birthDate!.month}월 ${_birthDate!.day}일'
                          : '생년월일을 선택하세요',
                      style: AppTheme.bodyLargeStyle.copyWith(
                        color: _birthDate != null ? AppTheme.textPrimary : AppTheme.textTertiary,
                      ),
                    ),
                  ),
                  if (_birthDate != null)
                    IconButton(
                      icon: Icon(Icons.close, color: AppTheme.textTertiary, size: 20),
                      onPressed: () => setState(() => _birthDate = null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                  else
                    Icon(Icons.calendar_today, color: AppTheme.textTertiary, size: 20),
                ],
              ),
            ),
          ),
          if (_birthDate != null) ...[
            const SizedBox(height: AppTheme.spacing8),
            Builder(builder: (context) {
              final now = DateTime.now();
              final totalMonths = (now.year - _birthDate!.year) * 12 + (now.month - _birthDate!.month);
              final ageText = totalMonths < 12 ? '$totalMonths개월' : '${totalMonths ~/ 12}살 ${totalMonths % 12}개월';
              return Text(
                '현재 나이: $ageText',
                style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.primaryBlue),
              );
            }),
          ],
        ],
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
            initialDate: _neuteredDate ?? DateTime.now().subtract(const Duration(days: 180)),
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
              Icon(Icons.calendar_today, size: 20, color: AppTheme.primaryBlue),
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
                        color: _neuteredDate != null ? AppTheme.textPrimary : AppTheme.textSecondary,
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
            style: AppTheme.bodyMediumStyle.copyWith(fontWeight: FontWeight.w600),
            children: const [
              TextSpan(
                text: ' (선택)',
                style: TextStyle(color: AppTheme.textTertiary, fontWeight: FontWeight.w400),
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
                    onPressed: () => setState(() => _prevDonationDate = null),
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
          Builder(builder: (context) {
            final daysSince = DateTime.now().difference(_prevDonationDate!).inDays;
            final canDonate = daysSince >= 56;
            return Text(
              canDonate
                  ? '✓ 마지막 헌혈 후 $daysSince일 경과 (헌혈 가능)'
                  : '⏳ 마지막 헌혈 후 $daysSince일 경과 (${56 - daysSince}일 후 헌혈 가능)',
              style: AppTheme.bodySmallStyle.copyWith(
                color: canDonate ? Colors.green.shade600 : Colors.orange.shade600,
              ),
            );
          }),
        ],
      ],
    );
  }
}
