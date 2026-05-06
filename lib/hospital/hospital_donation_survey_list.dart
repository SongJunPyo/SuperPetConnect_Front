// lib/hospital/hospital_donation_survey_list.dart
//
// 병원이 자기 게시글의 신청자 설문을 일괄 조회 (2026-05 PR-3).
//
// 백엔드 권한 격리:
// - 목록: WHERE post.hospital_idx = current.hospital_idx 자동 필터
// - 단건: assert_hospital_owns_application 가드 → 403
//
// admin과 달리 자동 PATCH 없음. 의료진 사전 검토 용도.

import 'package:flutter/material.dart';

import '../models/donation_survey_model.dart';
import '../services/donation_survey_download_service.dart';
import '../services/donation_survey_service.dart';
import '../utils/app_theme.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/state_view.dart';
import 'hospital_donation_survey_detail.dart';

class HospitalDonationSurveyList extends StatefulWidget {
  /// 병원 자기 게시글의 post_idx. 백엔드가 hospital 소유권 자동 검증.
  final int postIdx;
  /// AppBar에 표시할 게시글 제목 (호출부가 알고 있으면 전달).
  final String? postTitle;

  const HospitalDonationSurveyList({
    super.key,
    required this.postIdx,
    this.postTitle,
  });

  @override
  State<HospitalDonationSurveyList> createState() =>
      _HospitalDonationSurveyListState();
}

class _HospitalDonationSurveyListState
    extends State<HospitalDonationSurveyList> {
  DonationSurveyListResponse? _data;
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
      final data = await HospitalSurveyService.getByPost(widget.postIdx);
      if (!mounted) return;
      setState(() {
        _data = data;
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

  Future<void> _downloadXlsx() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final message =
          await DonationSurveyDownloadService.downloadHospitalPostSurveysXlsx(
        widget.postIdx,
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
            'Excel 다운로드 실패: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasItems = (_data?.items.isNotEmpty ?? false);
    return Scaffold(
      appBar: AppAppBar(
        title: widget.postTitle == null
            ? '신청자 사전 설문'
            : '${widget.postTitle} - 사전 설문',
        actions: [
          if (hasItems)
            IconButton(
              icon: _downloading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_download_outlined),
              tooltip: '전체 Excel 다운로드',
              onPressed: _downloading ? null : _downloadXlsx,
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
    final items = _data?.items ?? const <DonationSurveyListItem>[];
    if (items.isEmpty) {
      return const StateView.empty(
        icon: Icons.fact_check_outlined,
        message: '제출된 사전 설문이 없습니다',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spacing8),
        itemBuilder: (_, i) => _buildCard(items[i]),
      ),
    );
  }

  Widget _buildCard(DonationSurveyListItem item) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        onTap: () => _openDetail(item),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.petName,
                      style: AppTheme.h4Style.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (item.isLocked)
                    _chip('잠금', AppTheme.textTertiary),
                ],
              ),
              const SizedBox(height: AppTheme.spacing8),
              if (item.ownerName != null && item.ownerName!.isNotEmpty)
                _info(Icons.person_outline, item.ownerName!),
              _info(
                Icons.event,
                '${item.donationDate} ${item.donationTime}',
              ),
              const SizedBox(height: AppTheme.spacing8),
              Text(
                '제출: ${_short(item.submittedAt)}'
                '${item.updatedAt != item.submittedAt ? '  ·  수정: ${_short(item.updatedAt)}' : ''}',
                style: AppTheme.bodySmallStyle.copyWith(
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _info(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textTertiary),
          const SizedBox(width: AppTheme.spacing4),
          Expanded(
            child: Text(
              text,
              style: AppTheme.bodySmallStyle.copyWith(
                color: AppTheme.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: AppTheme.bodySmallStyle.copyWith(
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  String _short(String iso) =>
      iso.length >= 10 ? iso.substring(0, 10) : iso;

  void _openDetail(DonationSurveyListItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            HospitalDonationSurveyDetail(surveyIdx: item.surveyIdx),
      ),
    );
  }
}
