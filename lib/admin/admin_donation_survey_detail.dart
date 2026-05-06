// lib/admin/admin_donation_survey_detail.dart
//
// 관리자 헌혈 사전 설문 상세 화면 (read-only, 2026-05 PR-3).
//
// 옵션 a 자동 PATCH: 첫 GET 시 admin_reviewed_at = NOW + admin_reviewed_by 설정.
// 두 번째 이후 호출은 read-only.
// 옵션 A+C: admin 열람 후 사용자가 수정 → admin_reviewed_at NULL 복귀 + 재검토 알림.

import 'package:flutter/material.dart';

import '../models/donation_survey_model.dart';
import '../services/donation_survey_download_service.dart';
import '../services/donation_survey_service.dart';
import '../utils/app_constants.dart';
import '../utils/app_theme.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/state_view.dart';

class AdminDonationSurveyDetail extends StatefulWidget {
  final int surveyIdx;

  const AdminDonationSurveyDetail({super.key, required this.surveyIdx});

  @override
  State<AdminDonationSurveyDetail> createState() =>
      _AdminDonationSurveyDetailState();
}

class _AdminDonationSurveyDetailState
    extends State<AdminDonationSurveyDetail> {
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
      final survey = await AdminSurveyService.getSurvey(widget.surveyIdx);
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
      final message = await DonationSurveyDownloadService.downloadAdminSurveyPdf(
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
        title: '설문 상세',
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
          _section('헌혈 신청 사유', [
            _row('사유', s.hospitalChoiceReason),
          ]),
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
          _buildConsentSection(s),
          const SizedBox(height: AppTheme.spacing24),
        ],
      ),
    );
  }

  /// 검토 시점 / 잠금 / 옵션 A+C 안내 배너.
  Widget _buildMetaBanner(DonationSurveyResponse s) {
    final color = s.isLocked
        ? AppTheme.textTertiary
        : (s.isReviewed ? AppTheme.success : AppTheme.error);
    final label = s.isLocked
        ? '잠금됨 (D-2 이후 read-only)'
        : (s.isReviewed ? '검토 완료' : '검토 대기 → 본 화면 진입으로 자동 검토 처리됨');

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
                s.isLocked
                    ? Icons.lock_outline
                    : (s.isReviewed
                        ? Icons.check_circle_outline
                        : Icons.error_outline),
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
          if (s.adminReviewedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              '검토 시점: ${s.adminReviewedAt}',
              style: AppTheme.bodySmallStyle.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          if (s.lockedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              '잠금 시점: ${s.lockedAt}',
              style: AppTheme.bodySmallStyle.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
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

  /// 직전 외부 헌혈 영역 — `prev_*` 6필드.
  /// 모두 NULL이면 "직전 헌혈 정보 없음" 안내 (`prev_donation_source = "none"` 또는 unchanged).
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
            '입력된 직전 헌혈 정보 없음 (첫 헌혈 또는 시스템 자동값 미존재)',
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

  /// 동의 5개 — 백엔드 가드로 모두 true이지만 명시 표시.
  Widget _buildConsentSection(DonationSurveyResponse s) {
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
