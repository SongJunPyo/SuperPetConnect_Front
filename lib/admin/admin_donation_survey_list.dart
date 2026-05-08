// lib/admin/admin_donation_survey_list.dart
//
// 관리자 헌혈 사전 정보 설문 목록 (2026-05 PR-3).
//
// 디자인: 칼럼/공지 관리와 동일하게 BoardListHeader + BoardListRow + PaginationBar.
// 상태 표시: 제목 색으로만 구분 — 대기=빨강, 검토 완료=검정(기본). 필터 칩 없음.
//
// 기능:
// - 정렬, 페이지네이션
// - 응답의 pending_count로 상단 "대기 N" 배지 표시
// - 행 탭 → AdminDonationSurveyDetail (첫 GET 시 자동 PATCH 옵션 a)

import 'package:flutter/material.dart';

import '../models/donation_survey_model.dart';
import '../services/donation_survey_download_service.dart';
import '../services/donation_survey_service.dart';
import '../utils/app_theme.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/post_list/board_list_header.dart';
import '../widgets/post_list/board_list_row.dart';
import '../widgets/state_view.dart';
import 'admin_donation_survey_detail.dart';

class AdminDonationSurveyList extends StatefulWidget {
  const AdminDonationSurveyList({super.key});

  @override
  State<AdminDonationSurveyList> createState() =>
      _AdminDonationSurveyListState();
}

class _AdminDonationSurveyListState extends State<AdminDonationSurveyList> {
  // reviewStatus 필터 없음 — 대기/완료 한 화면에 표시하고 제목 색으로만 구분.
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
          _buildSortBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSortBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing4,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
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
      return Container(
        decoration: const BoxDecoration(color: Colors.white),
        child: Column(
          children: const [
            BoardListHeader(),
            Expanded(
              child: StateView.empty(
                icon: Icons.fact_check_outlined,
                message: '조건에 맞는 설문이 없습니다',
              ),
            ),
          ],
        ),
      );
    }

    final data = _data!;
    final totalPages = (data.totalCount / data.pageSize).ceil();
    final paginationBarCount = totalPages > 1 ? 1 : 0;

    return Container(
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        children: [
          const BoardListHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: items.length + paginationBarCount,
                separatorBuilder: (_, __) => Container(
                  height: 1,
                  color: AppTheme.lightGray.withValues(alpha: 0.2),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
                itemBuilder: (_, index) {
                  if (index >= items.length) {
                    return PaginationBar(
                      currentPage: data.page,
                      totalPages: totalPages,
                      onPageChanged: _changePage,
                    );
                  }
                  return _buildItemRow(items[index], index);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(DonationSurveyListItem item, int index) {
    // 미검토(대기) → 빨강, 검토 완료 → 기본(검정).
    // 잠금(D-2 23:55 이후)은 별도 색 표시 없이 isReviewed에 따른 분기 그대로.
    final titleColor = item.isReviewed ? null : AppTheme.error;
    final submittedAt = _parseIsoDate(item.submittedAt);

    return BoardListRow(
      index: index + 1,
      title: item.petName,
      titleColor: titleColor,
      authorName: item.hospitalName,
      authorProfileImage: null,
      createdAt: submittedAt,
      onTap: () => _openDetail(item),
    );
  }

  /// `2026-05-08T12:34:56` 같은 ISO datetime을 DateTime으로. 파싱 실패 시 epoch.
  DateTime _parseIsoDate(String iso) {
    return DateTime.tryParse(iso) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
}
