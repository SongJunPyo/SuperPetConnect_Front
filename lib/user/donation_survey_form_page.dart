// lib/user/donation_survey_form_page.dart
//
// 헌혈 사전 정보 설문 작성 화면 (2026-05 PR-2).
//
// 진입 경로:
// 1. 선정 알림 → deep link (donation_application_approved 알림 탭)
// 2. 내 신청 내역 > 선정된 신청 > "설문 작성" 버튼
//
// 모드:
// - 신규 작성: GET template으로 자동 채움 → POST 제출
// - 수정: GET survey + GET template 병렬 → PATCH 제출
// - 잠금 (locked_at != null): 조회 화면(donation_survey_read_page)으로 redirect

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/donation_consent_model.dart';
import '../models/donation_survey_model.dart';
import '../services/donation_survey_service.dart';
import '../utils/app_constants.dart';
import '../utils/app_theme.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/app_button.dart';

class DonationSurveyFormPage extends StatefulWidget {
  /// `applied_donation.applied_donation_idx`. status==APPROVED이어야 폼 진입 가능.
  final int applicationId;

  const DonationSurveyFormPage({super.key, required this.applicationId});

  @override
  State<DonationSurveyFormPage> createState() => _DonationSurveyFormPageState();
}

class _DonationSurveyFormPageState extends State<DonationSurveyFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  String? _loadError;
  bool _submitting = false;

  DonationSurveyTemplate? _template;
  DonationConsentItems? _consent;
  /// 기존 설문이 있으면 수정 모드. null이면 신규 작성 모드.
  DonationSurveyResponse? _existing;

  // ===== 입력 컨트롤러 =====
  final _hospitalChoiceReasonController = TextEditingController();
  final _medicalHistoryController = TextEditingController();
  final _preventiveMedicationDetailController = TextEditingController();
  final _hospitalSpecialNoteController = TextEditingController();
  final _personalityController = TextEditingController();
  final _snsAccountController = TextEditingController();
  final _companionPetCountController = TextEditingController(text: '0');
  // 직전 외부 헌혈 (prev_donation_source == "external"일 때만 사용)
  final _prevHospitalNameController = TextEditingController();
  final _prevBloodVolumeController = TextEditingController();
  final _prevBloodCollectionSiteEtcController = TextEditingController();

  // ===== 입력 상태 =====
  /// 0=실내, 1=실외 (NOT NULL, default 0)
  int _livingEnvironment = 0;
  DateTime? _lastMenstruationDate;
  bool? _prevSedationUsed;
  bool? _prevOwnerObserved;
  /// BloodCollectionSite enum (0/1/2/3)
  int? _prevBloodCollectionSite;

  // ===== 동의 5개 =====
  bool _agreeReadGuidance = false;
  bool _agreeFamilyConsent = false;
  bool _agreeSufficientRest = false;
  bool _agreeAssociationCooperation = false;
  bool _agreeUnderstandingOperation = false;

  bool get _allAgreed =>
      _agreeReadGuidance &&
      _agreeFamilyConsent &&
      _agreeSufficientRest &&
      _agreeAssociationCooperation &&
      _agreeUnderstandingOperation;

  bool get _isEditMode => _existing != null;

  /// 잠금 상태 — 헌혈 D-2 자정 이후. 모든 인터랙션 차단 + 제출 버튼 숨김.
  /// 백엔드 PATCH가 400 SURVEY_LOCKED를 반환하므로 클라이언트 측 가드가 일관성 유지.
  bool get _isLocked => _existing?.isLocked ?? false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hospitalChoiceReasonController.dispose();
    _medicalHistoryController.dispose();
    _preventiveMedicationDetailController.dispose();
    _hospitalSpecialNoteController.dispose();
    _personalityController.dispose();
    _snsAccountController.dispose();
    _companionPetCountController.dispose();
    _prevHospitalNameController.dispose();
    _prevBloodVolumeController.dispose();
    _prevBloodCollectionSiteEtcController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      // template과 consent는 항상 호출. 기존 설문은 있으면 수정, 없으면(404) 신규.
      final template =
          await DonationSurveyService.getTemplate(widget.applicationId);
      final consent = await DonationSurveyService.getConsentItems();
      DonationSurveyResponse? existing;
      try {
        existing =
            await DonationSurveyService.getSurvey(widget.applicationId);
      } catch (_) {
        // 404 SURVEY_NOT_FOUND → 신규 모드
        existing = null;
      }
      if (!mounted) return;
      setState(() {
        _template = template;
        _consent = consent;
        _existing = existing;
        _loading = false;
        if (existing != null) {
          _populateFromExisting(existing);
        } else {
          _populateFromTemplate(template);
        }
      });

      // 잠금 시 IgnorePointer + 잠금 배너로 처리. 별도 SnackBar 불필요.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  /// 기존 설문 응답값을 폼 컨트롤러에 채움 (수정 모드).
  void _populateFromExisting(DonationSurveyResponse s) {
    _hospitalChoiceReasonController.text = s.hospitalChoiceReason;
    _medicalHistoryController.text = s.medicalHistory;
    _preventiveMedicationDetailController.text = s.preventiveMedicationDetail;
    _hospitalSpecialNoteController.text = s.hospitalSpecialNote ?? '';
    _personalityController.text = s.personality;
    _livingEnvironment = s.livingEnvironment;
    _snsAccountController.text = s.snsAccount ?? '';
    _companionPetCountController.text = s.companionPetCount.toString();
    if (s.lastMenstruationDate != null) {
      _lastMenstruationDate = DateTime.tryParse(s.lastMenstruationDate!);
    }
    _prevHospitalNameController.text = s.prevDonationHospitalName ?? '';
    _prevBloodVolumeController.text = s.prevBloodVolumeMl?.toString() ?? '';
    _prevSedationUsed = s.prevSedationUsed;
    _prevOwnerObserved = s.prevOwnerObserved;
    _prevBloodCollectionSite = s.prevBloodCollectionSite;
    _prevBloodCollectionSiteEtcController.text =
        s.prevBloodCollectionSiteEtc ?? '';

    // 수정 모드는 기존 동의값을 자동 체크 (이미 한 번 동의했으므로)
    _agreeReadGuidance = true;
    _agreeFamilyConsent = true;
    _agreeSufficientRest = true;
    _agreeAssociationCooperation = true;
    _agreeUnderstandingOperation = true;
  }

  /// 신규 작성 모드 — 자동 채움 가능한 prev_* 필드만 미리 채움.
  void _populateFromTemplate(DonationSurveyTemplate t) {
    if (t.prevDonationSource == AppConstants.prevDonationSourceSystem) {
      _prevHospitalNameController.text = t.prevDonationHospitalName ?? '';
      _prevBloodVolumeController.text =
          t.prevBloodVolumeMl?.toString() ?? '';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_allAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('5개 동의 항목 모두에 체크해주세요.')),
      );
      return;
    }

    setState(() => _submitting = true);

    final payload = _buildPayload();

    try {
      if (_isEditMode) {
        await DonationSurveyService.updateSurvey(
          widget.applicationId,
          payload,
        );
      } else {
        await DonationSurveyService.createSurvey(
          widget.applicationId,
          payload,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditMode ? '설문이 수정되었습니다.' : '설문이 제출되었습니다.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  DonationSurveyPayload _buildPayload() {
    final template = _template!;
    final source = template.prevDonationSource;
    return DonationSurveyPayload(
      weightKgSnapshot: template.petWeightKg,
      hospitalChoiceReason: _hospitalChoiceReasonController.text.trim(),
      medicalHistory: _medicalHistoryController.text.trim(),
      preventiveMedicationDetail:
          _preventiveMedicationDetailController.text.trim(),
      hospitalSpecialNote: _hospitalSpecialNoteController.text.trim().isEmpty
          ? null
          : _hospitalSpecialNoteController.text.trim(),
      personality: _personalityController.text.trim(),
      livingEnvironment: _livingEnvironment,
      snsAccount: _snsAccountController.text.trim().isEmpty
          ? null
          : _snsAccountController.text.trim(),
      companionPetCount:
          int.tryParse(_companionPetCountController.text.trim()) ?? 0,
      lastMenstruationDate:
          _lastMenstruationDate?.toIso8601String().split('T')[0],
      // 직전 외부 헌혈 — source에 따라 다르게 직렬화.
      // - none: 모든 prev_* null
      // - system: 자동 채움된 값을 그대로 보냄 (백엔드가 무시할 수도 있지만 안전)
      // - external: 사용자 입력값
      prevDonationHospitalName: source == AppConstants.prevDonationSourceNone
          ? null
          : (_prevHospitalNameController.text.trim().isEmpty
              ? null
              : _prevHospitalNameController.text.trim()),
      prevBloodVolumeMl: source == AppConstants.prevDonationSourceNone
          ? null
          : double.tryParse(_prevBloodVolumeController.text.trim()),
      prevSedationUsed:
          source == AppConstants.prevDonationSourceNone ? null : _prevSedationUsed,
      prevOwnerObserved:
          source == AppConstants.prevDonationSourceNone ? null : _prevOwnerObserved,
      prevBloodCollectionSite: source == AppConstants.prevDonationSourceNone
          ? null
          : _prevBloodCollectionSite,
      prevBloodCollectionSiteEtc:
          _prevBloodCollectionSite == AppConstants.bloodCollectionSiteOther
              ? (_prevBloodCollectionSiteEtcController.text.trim().isEmpty
                  ? null
                  : _prevBloodCollectionSiteEtcController.text.trim())
              : null,
      consent: DonationConsentPayload(
        agreeReadGuidance: _agreeReadGuidance,
        agreeFamilyConsent: _agreeFamilyConsent,
        agreeSufficientRest: _agreeSufficientRest,
        agreeAssociationCooperation: _agreeAssociationCooperation,
        agreeUnderstandingOperation: _agreeUnderstandingOperation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppAppBar(
        title: _isLocked ? '헌혈 사전 정보 설문 (조회)' : '헌혈 사전 정보 설문',
      ),
      // 잠금 시 IgnorePointer로 모든 입력 차단. 잠금 배너가 시각적으로 안내.
      body: _isLocked ? IgnorePointer(child: _buildBody()) : _buildBody(),
      bottomNavigationBar: _loading || _loadError != null || _isLocked
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                child: AppButton(
                  text: _submitting
                      ? '제출 중...'
                      : (_isEditMode ? '수정 제출' : '제출'),
                  onPressed: _submitting || !_allAgreed ? null : _submit,
                ),
              ),
            ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(
                '설문 폼을 불러오지 못했습니다',
                style: AppTheme.bodyLargeStyle
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                _loadError!,
                style: AppTheme.bodySmallStyle
                    .copyWith(color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _loadError = null;
                  });
                  _load();
                },
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    final t = _template!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_existing != null && _existing!.isLocked)
              _buildLockedBanner(),
            _buildScheduleSection(t),
            const SizedBox(height: AppTheme.spacing24),
            _buildPetInfoSection(t),
            const SizedBox(height: AppTheme.spacing24),
            _buildOwnerInfoSection(t),
            const SizedBox(height: AppTheme.spacing24),
            _buildMedicalAutoSection(t),
            const SizedBox(height: AppTheme.spacing24),
            _buildInputSection(),
            const SizedBox(height: AppTheme.spacing24),
            _buildPrevDonationSection(t),
            const SizedBox(height: AppTheme.spacing24),
            _buildExtraSection(t),
            const SizedBox(height: AppTheme.spacing24),
            _buildConsentSection(),
            const SizedBox(height: AppTheme.spacing24),
            _buildEditableNotice(),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppTheme.spacing16),
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: AppTheme.warning, size: 20),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Text(
              '헌혈 D-2 자정 이후 잠금되어 수정할 수 없습니다.',
              style: AppTheme.bodySmallStyle
                  .copyWith(color: AppTheme.warning),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: AppTheme.lightBlue,
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Text(
        '※ 헌혈일 D-2 자정까지 자유롭게 수정할 수 있습니다.',
        style: AppTheme.bodySmallStyle
            .copyWith(color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
      child: Text(title, style: AppTheme.h4Style),
    );
  }

  Widget _buildReadOnlyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTheme.bodyMediumStyle.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyMediumStyle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSection(DonationSurveyTemplate t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('헌혈 일정'),
        _buildReadOnlyRow('일자', t.donationDate),
        _buildReadOnlyRow('시간', t.donationTime),
        _buildReadOnlyRow('병원', t.hospitalName),
        _buildReadOnlyRow('유형', t.postType == 0 ? '긴급' : '정기'),
      ],
    );
  }

  Widget _buildPetInfoSection(DonationSurveyTemplate t) {
    final sex = t.petSex == 0 ? '암컷' : '수컷';
    final birth = t.petBirthDate ?? '미입력';
    final weight = t.petWeightKg != null ? '${t.petWeightKg}kg' : '미입력';
    final blood = t.petBloodType ?? '미입력';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('반려동물 정보'),
        _buildReadOnlyRow('이름', t.petName),
        _buildReadOnlyRow('품종', t.petBreed ?? '미입력'),
        _buildReadOnlyRow('성별', sex),
        _buildReadOnlyRow('생년월일', birth),
        _buildReadOnlyRow('체중', weight),
        _buildReadOnlyRow('혈액형', blood),
      ],
    );
  }

  Widget _buildOwnerInfoSection(DonationSurveyTemplate t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('보호자 정보'),
        _buildReadOnlyRow('이름', t.ownerName),
        _buildReadOnlyRow('연락처', t.ownerPhoneNumber ?? '미입력'),
        _buildReadOnlyRow('주소', t.ownerAddress ?? '미입력'),
      ],
    );
  }

  Widget _buildMedicalAutoSection(DonationSurveyTemplate t) {
    final neuteredText = t.petIsNeutered == true
        ? (t.petNeuteredDate ?? '완료 (일자 미입력)')
        : '미시행';
    String pregnancyText;
    switch (t.petPregnancyBirthStatus) {
      case 1:
        pregnancyText = '임신중';
        break;
      case 2:
        pregnancyText =
            t.petLastPregnancyEndDate != null ? '출산 ${t.petLastPregnancyEndDate}' : '출산 이력';
        break;
      default:
        pregnancyText = '해당 없음';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('의료 정보 (펫 프로필 자동)'),
        _buildReadOnlyRow('중성화', neuteredText),
        _buildReadOnlyRow('임신/출산', pregnancyText),
        _buildReadOnlyRow('종합백신', t.lastVaccinationDate ?? '미입력'),
        _buildReadOnlyRow('항체검사', t.lastAntibodyTestDate ?? '미입력'),
        _buildReadOnlyRow('예방약', t.lastPreventiveMedicationDate ?? '미입력'),
        const SizedBox(height: AppTheme.spacing4),
        Text(
          '※ 위 정보는 펫 프로필에서 자동으로 가져옵니다. 수정하려면 펫 프로필 화면에서 변경해주세요.',
          style:
              AppTheme.bodySmallStyle.copyWith(color: AppTheme.textTertiary),
        ),
      ],
    );
  }

  Widget _buildInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('헌혈 신청 정보 (필수)'),
        _buildLabel('헌혈 신청 사유', required: true),
        TextFormField(
          controller: _hospitalChoiceReasonController,
          maxLines: 2,
          maxLength: 500,
          decoration: _inputDecoration(hint: '예: 가까워서, 지인 추천 등'),
          validator: (v) =>
              v == null || v.trim().isEmpty ? '신청 사유는 필수입니다.' : null,
        ),
        const SizedBox(height: AppTheme.spacing12),
        _buildLabel('성격', required: true),
        TextFormField(
          controller: _personalityController,
          maxLines: 2,
          maxLength: 500,
          decoration: _inputDecoration(hint: '예: 활발하고 사람을 잘 따름'),
          validator: (v) =>
              v == null || v.trim().isEmpty ? '성격은 필수입니다.' : null,
        ),
        const SizedBox(height: AppTheme.spacing12),
        _buildLabel('생활 환경', required: true),
        // RadioGroup으로 groupValue/onChanged 관리 (Flutter 3.32+ 신규 API).
        RadioGroup<int>(
          groupValue: _livingEnvironment,
          onChanged: (v) => setState(() => _livingEnvironment = v ?? 0),
          child: const Row(
            children: [
              Expanded(
                child: RadioListTile<int>(
                  value: 0,
                  title: Text('실내'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              Expanded(
                child: RadioListTile<int>(
                  value: 1,
                  title: Text('실외'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),
        _buildLabel('과거 병력', required: true),
        TextFormField(
          controller: _medicalHistoryController,
          maxLines: 3,
          maxLength: 2000,
          decoration: _inputDecoration(hint: '없으면 "없음"으로 입력'),
          validator: (v) =>
              v == null || v.trim().isEmpty ? '과거 병력은 필수입니다.' : null,
        ),
        const SizedBox(height: AppTheme.spacing12),
        _buildLabel('예방약 상세 (약 이름)', required: true),
        TextFormField(
          controller: _preventiveMedicationDetailController,
          maxLines: 2,
          maxLength: 1000,
          decoration: _inputDecoration(hint: '예: 하트가드 매월 1일'),
          validator: (v) =>
              v == null || v.trim().isEmpty ? '예방약 상세는 필수입니다.' : null,
        ),
      ],
    );
  }

  Widget _buildPrevDonationSection(DonationSurveyTemplate t) {
    final source = t.prevDonationSource;

    if (source == AppConstants.prevDonationSourceNone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('직전 헌혈 정보'),
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing12),
            decoration: BoxDecoration(
              color: AppTheme.veryLightGray,
              borderRadius: BorderRadius.circular(AppTheme.radius8),
            ),
            child: Text(
              '첫 헌혈입니다. 직전 헌혈 정보 입력이 필요하지 않습니다.',
              style: AppTheme.bodySmallStyle
                  .copyWith(color: AppTheme.textSecondary),
            ),
          ),
        ],
      );
    }

    final isSystem = source == AppConstants.prevDonationSourceSystem;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          isSystem ? '직전 헌혈 정보 (시스템 자동)' : '직전 외부 헌혈 정보',
        ),
        if (isSystem)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
            child: Text(
              '※ 시스템에 저장된 직전 헌혈 정보입니다. 수정 불가.',
              style: AppTheme.bodySmallStyle
                  .copyWith(color: AppTheme.textTertiary),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
            child: Text(
              '※ 외부 헌혈 정보를 자세히 입력해주세요.',
              style: AppTheme.bodySmallStyle
                  .copyWith(color: AppTheme.textTertiary),
            ),
          ),
        if (t.effectiveLastDonationDate != null)
          _buildReadOnlyRow('마지막 헌혈일', t.effectiveLastDonationDate!),
        _buildLabel('헌혈한 병원'),
        TextFormField(
          controller: _prevHospitalNameController,
          enabled: !isSystem,
          decoration: _inputDecoration(hint: '병원 이름'),
        ),
        const SizedBox(height: AppTheme.spacing12),
        _buildLabel('헌혈량 (mL)'),
        TextFormField(
          controller: _prevBloodVolumeController,
          enabled: !isSystem,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          decoration: _inputDecoration(hint: '예: 350.0'),
        ),
        if (!isSystem) ...[
          const SizedBox(height: AppTheme.spacing12),
          _buildLabel('진정제 사용'),
          _buildBoolToggle(
            value: _prevSedationUsed,
            onChanged: (v) => setState(() => _prevSedationUsed = v),
          ),
          const SizedBox(height: AppTheme.spacing12),
          _buildLabel('보호자 동석 여부'),
          _buildBoolToggle(
            value: _prevOwnerObserved,
            onChanged: (v) => setState(() => _prevOwnerObserved = v),
          ),
          const SizedBox(height: AppTheme.spacing12),
          _buildLabel('채혈 부위'),
          _buildBloodCollectionSitePicker(),
          if (_prevBloodCollectionSite ==
              AppConstants.bloodCollectionSiteOther) ...[
            const SizedBox(height: AppTheme.spacing8),
            TextFormField(
              controller: _prevBloodCollectionSiteEtcController,
              maxLength: 200,
              decoration: _inputDecoration(hint: '기타 부위 입력'),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildBloodCollectionSitePicker() {
    final options = [
      (AppConstants.bloodCollectionSiteJugular, '경정맥'),
      (AppConstants.bloodCollectionSiteLimb, '사지'),
      (AppConstants.bloodCollectionSiteBoth, '둘 다'),
      (AppConstants.bloodCollectionSiteOther, '기타'),
    ];
    return Wrap(
      spacing: AppTheme.spacing8,
      children: options.map((o) {
        final selected = _prevBloodCollectionSite == o.$1;
        return ChoiceChip(
          label: Text(o.$2),
          selected: selected,
          onSelected: (sel) =>
              setState(() => _prevBloodCollectionSite = sel ? o.$1 : null),
        );
      }).toList(),
    );
  }

  Widget _buildBoolToggle({
    required bool? value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Row(
      children: [
        ChoiceChip(
          label: const Text('예'),
          selected: value == true,
          onSelected: (s) => onChanged(s ? true : null),
        ),
        const SizedBox(width: AppTheme.spacing8),
        ChoiceChip(
          label: const Text('아니오'),
          selected: value == false,
          onSelected: (s) => onChanged(s ? false : null),
        ),
      ],
    );
  }

  Widget _buildExtraSection(DonationSurveyTemplate t) {
    final isFemale = t.petSex == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('기타 정보 (선택)'),
        _buildLabel('병원에 전달할 특별사항'),
        TextFormField(
          controller: _hospitalSpecialNoteController,
          maxLines: 3,
          maxLength: 1000,
          decoration: _inputDecoration(hint: '병원에 미리 알려야 할 사항이 있다면 입력'),
        ),
        const SizedBox(height: AppTheme.spacing12),
        _buildLabel('SNS 계정 (선택)'),
        TextFormField(
          controller: _snsAccountController,
          maxLength: 200,
          decoration: _inputDecoration(hint: '예: @my_pet'),
        ),
        const SizedBox(height: AppTheme.spacing12),
        _buildLabel('동반 반려견 수'),
        TextFormField(
          controller: _companionPetCountController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _inputDecoration(hint: '0'),
        ),
        if (isFemale) ...[
          const SizedBox(height: AppTheme.spacing12),
          _buildLabel('마지막 생리일 (암컷, 선택)'),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _lastMenstruationDate ?? DateTime.now(),
                firstDate: DateTime(2010),
                lastDate: DateTime.now(),
                helpText: '마지막 생리일 선택',
                cancelText: '취소',
                confirmText: '선택',
              );
              if (picked != null) {
                setState(() => _lastMenstruationDate = picked);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              decoration: BoxDecoration(
                color: AppTheme.veryLightGray,
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 18),
                  const SizedBox(width: AppTheme.spacing8),
                  Expanded(
                    child: Text(
                      _lastMenstruationDate != null
                          ? '${_lastMenstruationDate!.year}-${_lastMenstruationDate!.month.toString().padLeft(2, '0')}-${_lastMenstruationDate!.day.toString().padLeft(2, '0')}'
                          : '날짜 선택',
                      style: AppTheme.bodyMediumStyle.copyWith(
                        color: _lastMenstruationDate != null
                            ? AppTheme.textPrimary
                            : AppTheme.textTertiary,
                      ),
                    ),
                  ),
                  if (_lastMenstruationDate != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () =>
                          setState(() => _lastMenstruationDate = null),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConsentSection() {
    final consent = _consent!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('헌혈 사전 동의 (전체 필수)'),
        // guidance_html 다시 표시 (사용자가 설문 단계에서도 확인 가능)
        Container(
          padding: const EdgeInsets.all(AppTheme.spacing12),
          decoration: BoxDecoration(
            color: AppTheme.veryLightGray,
            borderRadius: BorderRadius.circular(AppTheme.radius8),
          ),
          child: MarkdownBody(
            data: consent.guidanceHtml,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                .copyWith(
              p: AppTheme.bodySmallStyle.copyWith(height: 1.6),
              h2: AppTheme.bodyMediumStyle
                  .copyWith(fontWeight: FontWeight.w700),
              h3: AppTheme.bodyMediumStyle
                  .copyWith(fontWeight: FontWeight.w600),
              listBullet: AppTheme.bodySmallStyle.copyWith(height: 1.6),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),
        // 5개 동의 체크박스
        ...consent.items.map(_buildConsentItem),
        const SizedBox(height: AppTheme.spacing8),
        // 전체 동의 토글
        CheckboxListTile(
          title: Text(
            '5개 항목 모두 동의',
            style:
                AppTheme.bodyMediumStyle.copyWith(fontWeight: FontWeight.w600),
          ),
          value: _allAgreed,
          onChanged: (v) => setState(() {
            final all = v ?? false;
            _agreeReadGuidance = all;
            _agreeFamilyConsent = all;
            _agreeSufficientRest = all;
            _agreeAssociationCooperation = all;
            _agreeUnderstandingOperation = all;
          }),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ],
    );
  }

  Widget _buildConsentItem(DonationConsentItem item) {
    final value = _consentValueByKey(item.key);
    return CheckboxListTile(
      title: Text(item.title, style: AppTheme.bodyMediumStyle),
      subtitle: item.body.isEmpty
          ? null
          : Text(
              item.body,
              style: AppTheme.bodySmallStyle
                  .copyWith(color: AppTheme.textSecondary),
            ),
      value: value,
      onChanged: (v) => setState(() => _setConsentByKey(item.key, v ?? false)),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  bool _consentValueByKey(String key) {
    switch (key) {
      case 'agree_read_guidance':
        return _agreeReadGuidance;
      case 'agree_family_consent':
        return _agreeFamilyConsent;
      case 'agree_sufficient_rest':
        return _agreeSufficientRest;
      case 'agree_association_cooperation':
        return _agreeAssociationCooperation;
      case 'agree_understanding_operation':
        return _agreeUnderstandingOperation;
      default:
        return false;
    }
  }

  void _setConsentByKey(String key, bool value) {
    switch (key) {
      case 'agree_read_guidance':
        _agreeReadGuidance = value;
        break;
      case 'agree_family_consent':
        _agreeFamilyConsent = value;
        break;
      case 'agree_sufficient_rest':
        _agreeSufficientRest = value;
        break;
      case 'agree_association_cooperation':
        _agreeAssociationCooperation = value;
        break;
      case 'agree_understanding_operation':
        _agreeUnderstandingOperation = value;
        break;
    }
  }

  Widget _buildLabel(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing4),
      child: RichText(
        text: TextSpan(
          text: text,
          style: AppTheme.bodyMediumStyle.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
          children: required
              ? const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: Colors.red),
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppTheme.veryLightGray,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing12,
      ),
    );
  }
}
