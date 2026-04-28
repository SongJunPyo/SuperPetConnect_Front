// lib/user/pet_register.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../utils/preferences_manager.dart';
import 'package:connect/utils/config.dart';
import 'package:connect/models/pet_model.dart';
import '../utils/app_theme.dart';
import '../utils/blood_type_constants.dart';
import '../widgets/app_button.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_input_field.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/pet_profile_image.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../services/auth_http_client.dart';
import '../utils/api_endpoints.dart';

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

  String? _selectedSpecies; // 강아지 또는 고양이 (UI 표시용)
  int? _selectedAnimalType; // 0=강아지, 1=고양이 (서버 전송용)
  String? _selectedBloodType;
  DateTime? _birthDate; // 생년월일
  bool _isPregnant = false;
  bool _isVaccinated = false;
  bool _hasDisease = false;
  bool _hasBirthExperience = false;
  bool _isNeutered = false; // 중성화 수술 여부
  DateTime? _neuteredDate; // 중성화 수술 일자
  bool _hasPreventiveMedication = false; // 예방약 복용 여부
  DateTime? _prevDonationDate; // 직전 헌혈 일자

  // 프로필 사진 (수정 모드 전용). _imageRefreshKey 는 업로드 직후 NetworkImage 캐시를 무효화하는 cache buster.
  // _pendingProfileImage 는 관리자 검토 대기 중인 신규 사진 (APPROVED 펫 사진 변경 시).
  String? _profileImage;
  String? _pendingProfileImage;
  int _imageRefreshKey = 0;

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
      _birthDate = pet.birthDate;

      // 혈액형 유효성 검사
      _selectedBloodType = _validateBloodType(pet.species, pet.bloodType);

      _isPregnant = pet.pregnant;
      _isVaccinated = pet.vaccinated ?? false;
      _hasDisease = pet.hasDisease ?? false;
      _hasBirthExperience = pet.hasBirthExperience ?? false;
      _isNeutered = pet.isNeutered ?? false;
      _neuteredDate = pet.neuteredDate;
      _hasPreventiveMedication = pet.hasPreventiveMedication ?? false;
      _prevDonationDate = pet.prevDonationDate;
      _profileImage = pet.profileImage;
      _pendingProfileImage =
          pet.hasPendingProfileImage ? pet.pendingProfileImage : null;
    }
  }

  // 혈액형 유효성 검사 함수
  String? _validateBloodType(String species, String? bloodType) {
    return BloodTypeConstants.normalizeBloodType(
      bloodType: bloodType,
      species: species,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _savePet() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedSpecies == null ||
        _selectedAnimalType == null ||
        _selectedBloodType == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('종과 혈액형을 모두 선택해주세요.')));
      return;
    }

    final int? accountIdx =
        await PreferencesManager.getAccountIdx(); // account_idx로 사용

    if (accountIdx == null || accountIdx == 0) {
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
      'birth_date': _birthDate?.toIso8601String().split('T')[0],
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
        response = await AuthHttpClient.put(
          Uri.parse(apiUrl),
          body: jsonEncode(petData),
        );
      } else {
        // 등록 모드: POST 요청
        apiUrl = '${Config.serverUrl}/api/pets';
        response = await AuthHttpClient.post(
          Uri.parse(apiUrl),
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
        final errorMessage = responseBody['detail'] ?? '처리에 실패했습니다.';
        if (mounted) {
          await AppDialog.notice(
            context,
            title: '알림',
            message: errorMessage.toString(),
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

  // cache buster: 같은 path에 새 사진을 덮어쓰는 백엔드 동작 대비. 0이면 그대로, 0보다 크면 ?v=N 부착.
  String? _withCacheBuster(String? path) {
    if (path == null) return null;
    if (_imageRefreshKey == 0) return path;
    final separator = path.contains('?') ? '&' : '?';
    return '$path${separator}v=$_imageRefreshKey';
  }

  String? get _displayProfileImage => _withCacheBuster(_profileImage);
  String? get _displayPendingProfileImage =>
      _withCacheBuster(_pendingProfileImage);
  bool get _hasPendingImage => _pendingProfileImage != null;

  void _showImageOptions() {
    final petIdx = widget.petToEdit?.petIdx;
    if (petIdx == null) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('갤러리에서 선택'),
              onTap: () {
                Navigator.pop(ctx);
                _uploadImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('카메라로 촬영'),
              onTap: () {
                Navigator.pop(ctx);
                _uploadImage(fromCamera: true);
              },
            ),
            if (_profileImage != null)
              ListTile(
                leading: Icon(Icons.delete_outline, color: AppTheme.error),
                title: Text('사진 삭제', style: TextStyle(color: AppTheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteImage();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadImage({bool fromCamera = false}) async {
    final petIdx = widget.petToEdit?.petIdx;
    if (petIdx == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (pickedFile == null) return;

    try {
      final uri = Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.petProfileImage(petIdx)}',
      );
      final request = http.MultipartRequest('POST', uri);
      final token = await PreferencesManager.getAuthToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      final bytes = await pickedFile.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes('image', bytes, filename: pickedFile.name),
      );
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;
      // 200: 즉시 반영 (PENDING/REJECTED 펫). 202: 검토 대기 (APPROVED 펫).
      if (response.statusCode == 200 || response.statusCode == 202) {
        Map<String, dynamic> data = const {};
        try {
          data = jsonDecode(response.body) as Map<String, dynamic>;
        } catch (_) {}
        final newProfileImage = data['profile_image'] as String?;
        final newPendingImage = data['pending_profile_image'] as String?;
        final serverMessage = data['message'] as String?;

        setState(() {
          if (response.statusCode == 202) {
            // 검토 대기: profile_image는 그대로, pending_profile_image에 신규 사진.
            if (newProfileImage != null) _profileImage = newProfileImage;
            _pendingProfileImage = newPendingImage;
          } else {
            // 즉시 반영: pending 정리, profile_image 갱신.
            if (newProfileImage != null) _profileImage = newProfileImage;
            _pendingProfileImage = null;
          }
          _imageRefreshKey++;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              serverMessage ??
                  (response.statusCode == 202
                      ? '프로필 사진 검토 요청이 등록되었습니다. 관리자 검토 후 적용됩니다.'
                      : '프로필 사진이 등록되었습니다.'),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['detail'] ?? '사진 업로드에 실패했습니다.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('사진 업로드 중 오류가 발생했습니다: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteImage() async {
    final petIdx = widget.petToEdit?.petIdx;
    if (petIdx == null) return;

    try {
      final response = await AuthHttpClient.delete(
        Uri.parse(
          '${Config.serverUrl}${ApiEndpoints.petProfileImage(petIdx)}',
        ),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        // 백엔드 정책: profile_image와 pending 둘 다 즉시 정리. 검토 대상 아님.
        setState(() {
          _profileImage = null;
          _pendingProfileImage = null;
          _imageRefreshKey++;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('프로필 사진이 삭제되었습니다.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['detail'] ?? '사진 삭제에 실패했습니다.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('사진 삭제 중 오류가 발생했습니다.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildAvatarSection() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(
          top: AppTheme.spacing8,
          bottom: AppTheme.spacing24,
        ),
        child: _hasPendingImage ? _buildPendingPair() : _buildSingleAvatar(),
      ),
    );
  }

  // 검토 중: [현재 사진] → [신규 사진]. 신규 쪽만 탭으로 재업로드 가능.
  Widget _buildPendingPair() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAvatarFigure(
              imagePath: _displayProfileImage,
              label: '현재',
              onTap: null, // 현재 사진은 탭 비활성 (검토 중에는 재업로드만 가능)
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing12),
              child: Icon(
                Icons.arrow_forward,
                size: 28,
                color: AppTheme.textTertiary,
              ),
            ),
            _buildAvatarFigure(
              imagePath: _displayPendingProfileImage,
              label: '검토 중',
              onTap: _showImageOptions,
              showCameraOverlay: true,
              labelColor: AppTheme.primaryBlue,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing8),
        Text(
          '관리자 검토 후 적용됩니다',
          style: AppTheme.captionStyle.copyWith(color: AppTheme.textTertiary),
        ),
      ],
    );
  }

  // 평상시: 가운데 1개 서클.
  Widget _buildSingleAvatar() {
    return _buildAvatarFigure(
      imagePath: _displayProfileImage,
      onTap: _showImageOptions,
      showCameraOverlay: true,
      radius: 48,
    );
  }

  Widget _buildAvatarFigure({
    required String? imagePath,
    String? label,
    Color? labelColor,
    VoidCallback? onTap,
    bool showCameraOverlay = false,
    double radius = 40,
  }) {
    final avatar = Stack(
      children: [
        // IgnorePointer로 PetProfileImage 내부 GestureDetector(풀스크린)를 무력화하여
        // 외부 GestureDetector(_showImageOptions)만 동작하게 통일.
        IgnorePointer(
          child: PetProfileImage(
            key: ValueKey('avatar_${label ?? "single"}_$_imageRefreshKey'),
            profileImage: imagePath,
            species: _selectedSpecies,
            radius: radius,
          ),
        ),
        if (showCameraOverlay)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
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
    );

    final wrapped = onTap != null
        ? GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: avatar,
          )
        : avatar;

    if (label == null) return wrapped;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        wrapped,
        const SizedBox(height: AppTheme.spacing4),
        Text(
          label,
          style: AppTheme.captionStyle.copyWith(
            color: labelColor ?? AppTheme.textTertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
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
              if (_isEditMode) _buildAvatarSection(),
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
              _buildBirthDatePicker(),
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
              _buildPrevDonationDatePicker(context),
              const SizedBox(height: AppTheme.spacing20),
              Text('헌혈 관련 정보', style: AppTheme.h4Style),
              const SizedBox(height: AppTheme.spacing12),
              _buildCheckboxTile(
                title: '백신 접종 여부',
                subtitle: '정기적으로 종합백신을 접종했나요?',
                value: _isVaccinated,
                onChanged:
                    (value) => setState(() => _isVaccinated = value ?? false),
              ),
              _buildCheckboxTile(
                title: '질병 이력',
                subtitle: '심장사상충, 바베시아, 혈액관련질병 등의 질병 이력이 있나요?',
                value: _hasDisease,
                onChanged:
                    (value) => setState(() => _hasDisease = value ?? false),
              ),
              _buildCheckboxTile(
                title: '출산 경험',
                subtitle: '출산 경험이 있나요? (출산 경험 존재 --> 헌혈 불가)',
                value: _hasBirthExperience,
                onChanged:
                    (value) =>
                        setState(() => _hasBirthExperience = value ?? false),
              ),
              _buildCheckboxTile(
                title: '현재 임신 여부',
                subtitle: '현재 임신 중인가요?',
                value: _isPregnant,
                onChanged:
                    (value) => setState(() => _isPregnant = value ?? false),
              ),
              _buildCheckboxTile(
                title: '예방약 복용',
                subtitle: '심장사상충 예방약을 정기적으로 복용하고 있나요?',
                value: _hasPreventiveMedication,
                onChanged:
                    (value) => setState(
                      () => _hasPreventiveMedication = value ?? false,
                    ),
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
              const SizedBox(height: 24),
              _buildSaveButton(context), // context 전달
            ],
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
          Text(
            '생년월일 (선택)',
            style: AppTheme.bodyMediumStyle.copyWith(fontWeight: FontWeight.w600),
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
              // 강아지 선택 버튼
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedSpecies = '강아지';
                      _selectedAnimalType = 0;
                      // 종류 변경시 혈액형 유효성 재검사
                      if (_selectedBloodType != null) {
                        _selectedBloodType = _validateBloodType(
                          '강아지',
                          _selectedBloodType,
                        );
                      } else {
                        _selectedBloodType = null;
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            _selectedSpecies == '강아지'
                                ? AppTheme.primaryBlue
                                : Colors.grey.shade300,
                        width: _selectedSpecies == '강아지' ? 2 : 1,
                      ),
                      color:
                          _selectedSpecies == '강아지'
                              ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                              : Colors.grey[100],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.pets,
                          size: 32,
                          color:
                              _selectedSpecies == '강아지'
                                  ? AppTheme.primaryBlue
                                  : Colors.grey[600],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '강아지',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color:
                                _selectedSpecies == '강아지'
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
                        _selectedBloodType = _validateBloodType(
                          '고양이',
                          _selectedBloodType,
                        );
                      } else {
                        _selectedBloodType = null;
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            _selectedSpecies == '고양이'
                                ? AppTheme.primaryBlue
                                : Colors.grey.shade300,
                        width: _selectedSpecies == '고양이' ? 2 : 1,
                      ),
                      color:
                          _selectedSpecies == '고양이'
                              ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                              : Colors.grey[100],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.cruelty_free, // 고양이 아이콘
                          size: 32,
                          color:
                              _selectedSpecies == '고양이'
                                  ? AppTheme.primaryBlue
                                  : Colors.grey[600],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '고양이',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color:
                                _selectedSpecies == '고양이'
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
            initialDate:
                _neuteredDate ??
                DateTime.now().subtract(const Duration(days: 180)),
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
                        color:
                            _neuteredDate != null
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

  // 직전 헌혈 일자 선택 위젯
  Widget _buildPrevDonationDatePicker(BuildContext context) {
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
                  color:
                      _prevDonationDate != null
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
                      color:
                          _prevDonationDate != null
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
                    onPressed: () {
                      setState(() {
                        _prevDonationDate = null;
                      });
                    },
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
          Text(
            _getDonationIntervalMessage(),
            style: AppTheme.bodySmallStyle.copyWith(
              color:
                  _canDonateAgain()
                      ? Colors.green.shade600
                      : Colors.orange.shade600,
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
    // 종류에 따른 혈액형 목록 (중앙집중식 관리)
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
