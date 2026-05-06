// lib/admin/admin_donation_survey_list.dart
//
// 관리자 헌혈 사전 정보 설문 목록 (2026-05 PR-3).
//
// 기능:
// - 필터: review_status (전체/검토대기/검토완료), 정렬, 페이지네이션
// - 응답의 pending_count로 검토 대기 배지 표시
// - 카드 탭 → AdminDonationSurveyDetail 진입 (첫 GET 시 자동 PATCH 옵션 a)

import 'package:flutter/material.dart';

import '../models/donation_survey_model.dart';
import '../services/donation_survey_download_service.dart';
import '../services/donation_survey_service.dart';
import '../utils/app_theme.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/state_view.dart';
import 'admin_donation_survey_detail.dart';

class AdminDonationSurveyList extends StatefulWidget {
  const AdminDonationSurveyList({super.key});

  @override
  State<AdminDonationSurveyList> createState() =>
      _AdminDonationSurveyListState();
}

class _AdminDonationSurveyListState extends State<AdminDonationSurveyList> {
  AdminSurveyListFilter _filter = const AdminSurveyListFilter(
    sort: 'submitted_at_desc',
  );
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
      final data = await AdminSurveyService.getList(_filter);
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

  void _onReviewStatusChanged(String? status) {
    setState(() {
      _filter = _filter.copyWith(
        reviewStatus: status,
        clearReviewStatus: status == null,
        page: 1,
      );
    });
    _load();
  }

  void _onSortChanged(String sort) {
    setState(() {
      _filter = _filter.copyWith(sort: sort, page: 1);
    });
    _load();
  }

  void _changePage(int newPage) {
    setState(() {
      _filter = _filter.copyWith(page: newPage);
    });
    _load();
  }

  Future<void> _openDetail(DonationSurveyListItem item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminDonationSurveyDetail(surveyIdx: item.surveyIdx),
      ),
    );
    if (!mounted) return;
    // 자동 PATCH로 admin_reviewed_at이 채워졌을 가능성 → 목록 갱신.
    _load();
  }

  /// 게시글 단위 Excel 다운로드 — `_filter.postIdx`가 있을 때만 활성.
  /// 백엔드: GET /api/admin/posts/{post_idx}/donation-surveys.xlsx
  Future<void> _downloadXlsx() async {
    final postIdx = _filter.postIdx;
    if (postIdx == null || _downloading) return;
    setState(() => _downloading = true);
    try {
      final message =
          await DonationSurveyDownloadService.downloadAdminPostSurveysXlsx(
        postIdx,
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
    return Scaffold(
      appBar: AppAppBar(
        title: '헌혈 사전 설문 검토',
        actions: [
          if (_filter.postIdx != null)
            IconButton(
              icon: _downloading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_download_outlined),
              tooltip: '게시글 단위 Excel 다운로드',
              onPressed: _downloading ? null : _downloadXlsx,
            ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildFilterBar(),
          Expanded(child: _buildBody()),
          if (_data != null && _data!.totalCount > _data!.pageSize)
            _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final pendingCount = _data?.pendingCount ?? 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing12,
      ),
      decoration: BoxDecoration(
        color: AppTheme.veryLightGray,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.fact_check_outlined,
            color: AppTheme.primaryBlue,
            size: 20,
          ),
          const SizedBox(width: AppTheme.spacing8),
          Text(
            '검토 대기',
            style: AppTheme.bodyMediumStyle.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing8,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: pendingCount > 0
                  ? AppTheme.error
                  : AppTheme.textTertiary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$pendingCount',
              style: AppTheme.bodySmallStyle.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Spacer(),
          if (_data != null)
            Text(
              '전체 ${_data!.totalCount}건',
              style: AppTheme.bodySmallStyle.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing8,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip(
                    '전체',
                    _filter.reviewStatus == null,
                    () => _onReviewStatusChanged(null),
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  _filterChip(
                    '검토 대기',
                    _filter.reviewStatus == 'pending',
                    () => _onReviewStatusChanged('pending'),
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  _filterChip(
                    '검토 완료',
                    _filter.reviewStatus == 'reviewed',
                    () => _onReviewStatusChanged('reviewed'),
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort, size: 20),
            tooltip: '정렬',
            onSelected: _onSortChanged,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'submitted_at_desc',
                child: Text('제출일 최신순'),
              ),
              PopupMenuItem(
                value: 'submitted_at_asc',
                child: Text('제출일 오래된순'),
              ),
              PopupMenuItem(
                value: 'donation_date_asc',
                child: Text('헌혈일 빠른순'),
              ),
              PopupMenuItem(
                value: 'donation_date_desc',
                child: Text('헌혈일 늦은순'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return StateView.error(
        message: _error!,
        onRetry: _load,
      );
    }
    final items = _data?.items ?? const <DonationSurveyListItem>[];
    if (items.isEmpty) {
      return const StateView.empty(
        icon: Icons.fact_check_outlined,
        message: '조건에 맞는 설문이 없습니다',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spacing8),
        itemBuilder: (_, index) => _buildItemCard(items[index]),
      ),
    );
  }

  Widget _buildItemCard(DonationSurveyListItem item) {
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
                  _buildStatusChip(item),
                ],
              ),
              const SizedBox(height: AppTheme.spacing8),
              _buildInfoLine(
                Icons.business_outlined,
                item.hospitalName,
              ),
              _buildInfoLine(
                Icons.event,
                '${item.donationDate} ${item.donationTime}',
              ),
              if (item.ownerName != null && item.ownerName!.isNotEmpty)
                _buildInfoLine(
                  Icons.person_outline,
                  item.ownerName!,
                ),
              const SizedBox(height: AppTheme.spacing8),
              Text(
                '제출: ${_shortDate(item.submittedAt)}'
                '${item.updatedAt != item.submittedAt ? '  ·  수정: ${_shortDate(item.updatedAt)}' : ''}',
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

  Widget _buildInfoLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spacing4),
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

  Widget _buildStatusChip(DonationSurveyListItem item) {
    if (item.isLocked) {
      return _chip(text: '잠금', color: AppTheme.textTertiary);
    }
    if (!item.isReviewed) {
      return _chip(text: '검토 대기', color: AppTheme.error);
    }
    return _chip(text: '검토 완료', color: AppTheme.success);
  }

  Widget _chip({required String text, required Color color}) {
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

  String _shortDate(String iso) {
    if (iso.length >= 10) return iso.substring(0, 10);
    return iso;
  }

  Widget _buildPagination() {
    final data = _data!;
    final totalPages = (data.totalCount / data.pageSize).ceil();
    final hasPrev = data.page > 1;
    final hasNext = data.page < totalPages;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: hasPrev ? () => _changePage(data.page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            '${data.page} / $totalPages',
            style: AppTheme.bodyMediumStyle.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            onPressed: hasNext ? () => _changePage(data.page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
