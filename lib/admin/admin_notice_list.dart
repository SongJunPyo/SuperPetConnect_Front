import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../models/notice_model.dart';
import '../services/notice_service.dart';
import 'admin_notice_create.dart';
import 'package:intl/intl.dart';
import '../widgets/marquee_text.dart';
import '../utils/number_format_util.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminNoticeListScreen extends StatefulWidget {
  const AdminNoticeListScreen({super.key});

  @override
  State<AdminNoticeListScreen> createState() => _AdminNoticeListScreenState();
}

class _AdminNoticeListScreenState extends State<AdminNoticeListScreen>
    with SingleTickerProviderStateMixin {
  List<Notice> notices = [];
  List<Notice> filteredNotices = [];
  bool isLoading = true;
  String? errorMessage;
  String searchQuery = '';
  TextEditingController searchController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;
  
  // 슬라이딩 탭 관련
  TabController? _tabController;
  int _currentTabIndex = 0; // 0: 공지, 1: 비공지

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController!.addListener(_handleTabChange);
    _loadNotices();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    searchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController!.indexIsChanging ||
        _tabController!.index != _currentTabIndex) {
      setState(() {
        _currentTabIndex = _tabController!.index;
        _updateFilteredNotices();
      });
    }
  }

  Future<void> _loadNotices() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final allNotices = await NoticeService.getAdminNotices(
        activeOnly: false, // 관리자용 API - 모든 공지글 포함
      );

      setState(() {
        notices = allNotices;
        _updateFilteredNotices();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }
  
  // 필터링된 공지사항 업데이트
  void _updateFilteredNotices() {
    List<Notice> filtered = notices;
    
    // 탭에 따른 필터링 (notice_important 활용)
    if (_currentTabIndex == 0) {
      // 공지 탭: notice_important가 0(긴급/공지)인 공지만  
      filtered = filtered.where((notice) => notice.noticeImportant == 0).toList();
    } else {
      // 비공지 탭: notice_important가 1(정기/비공지)인 공지만
      filtered = filtered.where((notice) => notice.noticeImportant == 1).toList();
    }
    
    // 검색 필터링
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((notice) {
        final titleMatch = notice.title.toLowerCase().contains(searchQuery.toLowerCase());
        final authorMatch = (notice.authorNickname ?? notice.authorName).toLowerCase().contains(searchQuery.toLowerCase());
        return titleMatch || authorMatch;
      }).toList();
    }
    
    // 날짜 범위 필터
    if (startDate != null && endDate != null) {
      filtered = filtered.where((notice) {
        final createdAt = notice.createdAt;
        return !createdAt.isBefore(startDate!) && 
               !createdAt.isAfter(endDate!.add(const Duration(days: 1)));
      }).toList();
    }
    
    // 정렬 (최신순)
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    setState(() {
      filteredNotices = filtered;
    });
  }
  
  // 검색 처리
  void _onSearchChanged(String value) {
    setState(() {
      searchQuery = value;
    });
    _updateFilteredNotices();
  }
  
  // 날짜 범위 선택
  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: (startDate != null && endDate != null)
          ? DateTimeRange(start: startDate!, end: endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppTheme.primaryBlue,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
      _updateFilteredNotices();
    }
  }
  
  // 날짜 범위 초기화
  void _clearDateRange() {
    setState(() {
      startDate = null;
      endDate = null;
    });
    _updateFilteredNotices();
  }

  Future<void> _toggleNoticeActive(Notice notice) async {
    try {
      final updatedNotice = await NoticeService.toggleNoticeActive(
        notice.noticeIdx,
      );

      if (mounted) {
        final statusText = updatedNotice.noticeActive ? '활성화' : '비활성화';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('공지글이 $statusText되었습니다.'),
            backgroundColor:
                updatedNotice.noticeActive ? AppTheme.success : AppTheme.mediumGray,
          ),
        );
        _loadNotices(); // 목록 새로고침
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('상태 변경 실패: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteNotice(Notice notice) async {
    // 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('공지글 삭제'),
          content: Text(
            '\'${notice.title}\'을(를) 삭제하시겠습니까?\n\n삭제된 공지글은 복구할 수 없습니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppTheme.error),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await NoticeService.deleteNotice(notice.noticeIdx);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('공지글이 삭제되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadNotices(); // 목록 새로고침
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('삭제 실패: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showNoticeDetail(Notice notice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 핸들 바
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // 제목
                  Text(
                    notice.title,
                    style: AppTheme.h3Style.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 메타 정보
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getTargetAudienceColor(notice.targetAudience),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getTargetAudienceText(notice.targetAudience),
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        notice.authorNickname ?? notice.authorName,
                        style: AppTheme.bodySmallStyle.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('yyyy-MM-dd HH:mm').format(notice.createdAt),
                        style: AppTheme.bodySmallStyle.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  // 내용
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Text(
                        notice.content,
                        style: AppTheme.bodyMediumStyle.copyWith(
                          height: 1.6,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // URL 버튼 (URL이 있을 경우에만 표시)
                  if (notice.noticeUrl != null && notice.noticeUrl!.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final url = notice.noticeUrl!;
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('링크를 열 수 없습니다'),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('링크 열기'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // 수정 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context); // 바텀시트 닫기
                        _navigateToEditNotice(notice); // 수정 페이지로 이동
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('수정하기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 하단 정보
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.visibility_outlined, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              '조회수 ${notice.viewCount ?? 0}회',
                              style: AppTheme.bodySmallStyle.copyWith(color: Colors.grey[600]),
                            ),
                            const Spacer(),
                            if (notice.updatedAt != notice.createdAt) ...[
                              Text(
                                '수정: ${DateFormat('yyyy-MM-dd HH:mm').format(notice.updatedAt)}',
                                style: AppTheme.bodySmallStyle.copyWith(color: Colors.grey[600]),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 공지사항 수정 페이지로 이동
  void _navigateToEditNotice(Notice notice) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminNoticeCreateScreen(
          editNotice: notice, // 수정할 공지사항 전달
        ),
      ),
    ).then((_) {
      _loadNotices(); // 수정 후 목록 새로고침
    });
  }

  String _getTargetAudienceText(int targetAudience) {
    switch (targetAudience) {
      case 0:
        return '전체';
      case 1:
        return '관리자';
      case 2:
        return '병원';
      case 3:
        return '사용자';
      default:
        return '전체';
    }
  }
  
  Color _getTargetAudienceColor(int targetAudience) {
    switch (targetAudience) {
      case 2:
        return Colors.orange; // 병원: 주황색
      case 3:
        return AppTheme.success; // 사용자: 초록색
      default:
        return Colors.red; // 전체: 빨간색
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '공지사항 관리',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range, color: Colors.black87),
            onPressed: _selectDateRange,
            tooltip: '날짜 범위 선택',
          ),
          if (startDate != null || endDate != null)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.black87),
              onPressed: _clearDateRange,
              tooltip: '날짜 범위 초기화',
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _loadNotices,
            tooltip: '새로고침',
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminNoticeCreateScreen(),
                ),
              ).then((_) {
                _loadNotices(); // 공지글 작성 후 목록 새로고침
              });
            },
            tooltip: '공지글 작성',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.campaign, size: 20),
                  SizedBox(width: 8),
                  Text('공지'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.article, size: 20),
                  SizedBox(width: 8),
                  Text('비공지'),
                ],
              ),
            ),
          ],
          labelColor: Colors.black87,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black87,
        ),
      ),
      body: Column(
        children: [
          // 검색창 및 필터 표시
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: '제목, 닉네임으로 검색...',
                    prefixIcon: const Icon(Icons.search, color: Colors.black87),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                  ),
                ),
                // 날짜 범위 표시
                if (startDate != null && endDate != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.date_range, size: 16, color: AppTheme.primaryBlue),
                        const SizedBox(width: 8),
                        Text(
                          '${DateFormat('yyyy.MM.dd').format(startDate!)} - ${DateFormat('yyyy.MM.dd').format(endDate!)}',
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppTheme.primaryBlue, size: 18),
                          onPressed: _clearDateRange,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadNotices,
              color: AppTheme.primaryBlue,
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryBlue),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.error),
            const SizedBox(height: 16),
            Text('오류가 발생했습니다', style: AppTheme.h4Style),
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              style: AppTheme.bodyMediumStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadNotices,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (filteredNotices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.announcement_outlined,
              size: 64,
              color: AppTheme.mediumGray,
            ),
            const SizedBox(height: 16),
            Text('공지사항이 없습니다', style: AppTheme.h4Style),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: filteredNotices.length,
        separatorBuilder: (context, index) => Container(
          height: 1,
          color: AppTheme.lightGray.withValues(alpha: 0.2),
          margin: const EdgeInsets.symmetric(horizontal: 16),
        ),
        itemBuilder: (context, index) {
          final notice = filteredNotices[index];
          
          return InkWell(
            onTap: () => _showNoticeDetail(notice),
            onLongPress: () {
              // 길게 누르면 옵션 메뉴 표시
              showModalBottomSheet(
                context: context,
                builder: (context) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.edit),
                        title: const Text('수정'),
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToEditNotice(notice);
                        },
                      ),
                      ListTile(
                        leading: Icon(
                          notice.noticeActive ? Icons.visibility_off : Icons.visibility,
                        ),
                        title: Text(notice.noticeActive ? '비활성화' : '활성화'),
                        onTap: () {
                          Navigator.pop(context);
                          _toggleNoticeActive(notice);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete, color: Colors.red),
                        title: const Text('삭제', style: TextStyle(color: Colors.red)),
                        onTap: () {
                          Navigator.pop(context);
                          _deleteNotice(notice);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 중앙: 메인 콘텐츠
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 첫 번째 줄: [대상 뱃지][제목][작성 일자]
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 대상 뱃지
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getTargetAudienceColor(notice.targetAudience),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _getTargetAudienceText(notice.targetAudience),
                                style: AppTheme.bodySmallStyle.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // 제목
                            Expanded(
                              child: MarqueeText(
                                text: notice.title,
                                style: AppTheme.bodyMediumStyle.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                                animationDuration: const Duration(milliseconds: 4000),
                                pauseDuration: const Duration(milliseconds: 1000),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // 두 번째 줄: [닉네임][수정 일자]
                        Row(
                          children: [
                            // 닉네임 (작성자 닉네임)
                            Expanded(
                              child: Text(
                                (notice.authorNickname ?? notice.authorName).length > 15
                                    ? '${(notice.authorNickname ?? notice.authorName).substring(0, 15)}..'
                                    : (notice.authorNickname ?? notice.authorName),
                                style: AppTheme.bodySmallStyle.copyWith(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 오른쪽: 날짜들 + 2줄 높이의 조회수 박스
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 날짜 컬럼 (작성/수정일 세로 배치)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '작성: ${DateFormat('yy.MM.dd').format(notice.createdAt)}',
                            style: AppTheme.bodySmallStyle.copyWith(
                              color: AppTheme.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '수정: ${DateFormat('yy.MM.dd').format(notice.updatedAt)}',
                            style: AppTheme.bodySmallStyle.copyWith(
                              color: AppTheme.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      // 2줄 높이의 조회수 박스
                      Container(
                        height: 36,
                        width: 40,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.mediumGray.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppTheme.lightGray.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.visibility_outlined,
                              size: 10,
                              color: AppTheme.textTertiary,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              NumberFormatUtil.formatViewCount(notice.viewCount ?? 0),
                              style: AppTheme.bodySmallStyle.copyWith(
                                color: AppTheme.textTertiary,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}