// lib/hospital/hospital_donation_survey_detail.dart
//
// 병원 측 헌혈 사전 설문 상세 (read-only, 2026-05 PR-3).
//
// admin과 달리 자동 PATCH 없음 — 의료진 검토 시점성 추적은 admin 단계에서만 처리.
// 백엔드 권한: assert_hospital_owns_application 가드 (다른 병원 → 403).

import 'package:flutter/material.dart';

import '../models/donation_survey_model.dart';
import '../services/donation_survey_download_service.dart';
import '../services/donation_survey_service.dart';
import '../utils/app_constants.dart';
import '../utils/app_theme.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/state_view.dart';

class HospitalDonationSurveyDetail extends StatefulWidget {
  final int surveyIdx;

  const HospitalDonationSurveyDetail({super.key, required this.surveyIdx});

  @override
  State<HospitalDonationSurveyDetail> createState() =>
      _HospitalDonationSurveyDetailState();
}

class _HospitalDonationSurveyDetailState
    extends State<HospitalDonationSurveyDetail> {
  DonationSurveyResponse? _survey;
  bool _loading = true;
  String? _error;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final survey = await HospitalSurveyService.getSurvey(widget.surveyIdx);
      if (!mounted) return;
      setState(() {
        _survey = survey;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _downloadPdf() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final message =
          await DonationSurveyDownloadService.downloadHospitalSurveyPdf(
        widget.surveyIdx,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'PDF 다운로드 실패: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppAppBar(
        title: '사전 설문 상세',
        actions: [
          if (_survey != null)
            IconButton(
              icon: _downloading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'PDF 다운로드',
              onPressed: _downloading ? null : _downloadPdf,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const StateView.loading();
    }
    if (_error != null) {
      return StateView.error(message: _error!, onRetry: _load);
    }
    final s = _survey!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetaBanner(s),
          const SizedBox(height: AppTheme.spacing24),
          _section('헌혈 신청 사유', [_row('사유', s.hospitalChoiceReason)]),
          const SizedBox(height: AppTheme.spacing24),
          _section('펫 시점성', [
            _row('성격', s.personality),
            _row('생활 환경', s.livingEnvironment == 0 ? '실내' : '실외'),
          ]),
          const SizedBox(height: AppTheme.spacing24),
          _section('의료 이력', [
            _row('과거 병력', s.medicalHistory),
            _row('예방약 상세', s.preventiveMedicationDetail),
          ]),
          const SizedBox(height: AppTheme.spacing24),
          _section('기타', [
            _row('병원 특별사항', s.hospitalSpecialNote ?? '입력 없음'),
            _row('SNS 계정', s.snsAccount ?? '입력 없음'),
            _row('동반 반려견 수', '${s.companionPetCount}마리'),
            _row('마지막 생리일', s.lastMenstruationDate ?? '해당 없음'),
            if (s.weightKgSnapshot != null)
              _row('체중 (제출 시점)', '${s.weightKgSnapshot}kg'),
          ]),
          const SizedBox(height: AppTheme.spacing24),
          _buildPrevDonationSection(s),
          const SizedBox(height: AppTheme.spacing24),
          _buildConsentSection(),
        ],
      ),
    );
  }

  Widget _buildMetaBanner(DonationSurveyResponse s) {
    final color = s.isLocked ? AppTheme.textTertiary : AppTheme.primaryBlue;
    final label = s.isLocked ? '잠금됨 (D-2 이후 read-only)' : '조회 (read-only)';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                s.isLocked ? Icons.lock_outline : Icons.visibility_outlined,
                size: 16,
                color: color,
              ),
              const SizedBox(width: AppTheme.spacing4),
              Text(
                label,
                style: AppTheme.bodyMediumStyle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '제출: ${s.submittedAt}'
            '${s.updatedAt != s.submittedAt ? '  ·  마지막 수정: ${s.updatedAt}' : ''}',
            style: AppTheme.bodySmallStyle.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTheme.h4Style),
        const SizedBox(height: AppTheme.spacing8),
        ...children,
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
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
              value.isEmpty ? '입력 없음' : value,
              style: AppTheme.bodyMediumStyle.copyWith(
                color: value.isEmpty
                    ? AppTheme.textTertiary
                    : AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrevDonationSection(DonationSurveyResponse s) {
    final hasAny = s.prevDonationHospitalName != null ||
        s.prevBloodVolumeMl != null ||
        s.prevSedationUsed != null ||
        s.prevOwnerObserved != null ||
        s.prevBloodCollectionSite != null;
    if (!hasAny) {
      return _section('직전 헌혈 정보', [
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacing8),
          child: Text(
            '입력된 직전 헌혈 정보 없음 (첫 헌혈)',
            style: AppTheme.bodySmallStyle.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ]);
    }
    return _section('직전 헌혈 정보', [
      _row('병원', s.prevDonationHospitalName ?? '입력 없음'),
      _row(
        '헌혈량',
        s.prevBloodVolumeMl != null ? '${s.prevBloodVolumeMl}mL' : '입력 없음',
      ),
      _row(
        '진정제 사용',
        s.prevSedationUsed == null
            ? '입력 없음'
            : (s.prevSedationUsed! ? '예' : '아니오'),
      ),
      _row(
        '보호자 동석',
        s.prevOwnerObserved == null
            ? '입력 없음'
            : (s.prevOwnerObserved! ? '예' : '아니오'),
      ),
      _row(
        '채혈 부위',
        AppConstants.getBloodCollectionSiteText(s.prevBloodCollectionSite) +
            (s.prevBloodCollectionSiteEtc != null &&
                    s.prevBloodCollectionSiteEtc!.isNotEmpty
                ? ' (${s.prevBloodCollectionSiteEtc})'
                : ''),
      ),
    ]);
  }

  Widget _buildConsentSection() {
    return _section('동의 5개 (모두 true)', [
      Padding(
        padding: const EdgeInsets.all(AppTheme.spacing8),
        child: Row(
          children: const [
            Icon(Icons.check_circle, size: 16, color: AppTheme.success),
            SizedBox(width: 4),
            Text('5개 항목 모두 동의 완료'),
          ],
        ),
      ),
    ]);
  }
}
