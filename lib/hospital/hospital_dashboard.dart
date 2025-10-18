// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:connect/hospital/hospital_post.dart';
import '../widgets/unified_notification_page.dart';
import 'package:connect/hospital/hospital_post_check.dart';
import '../utils/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_app_bar.dart';
import '../auth/profile_management.dart';
import 'hospital_column_list.dart';
import 'hospital_column_management_list.dart';
import '../services/hospital_column_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:async';
import '../utils/config.dart';
import '../services/dashboard_service.dart';
import '../models/hospital_column_model.dart';
import '../models/notice_model.dart';
import '../widgets/marquee_text.dart';
import '../utils/number_format_util.dart';
import '../utils/text_personalization_util.dart';
import 'package:url_launcher/url_launcher.dart';
import 'hospital_notice_list.dart';

class HospitalDashboard extends StatefulWidget {
  final String? highlightPostId;
  final String? highlightColumnId;
  final String? initialTab;
  final bool showPostDetail;

  const HospitalDashboard({
    super.key,
    this.highlightPostId,
    this.highlightColumnId,
    this.initialTab,
    this.showPostDetail = false,
  });

  @override
  State<HospitalDashboard> createState() => _HospitalDashboardState();
}

class _HospitalDashboardState extends State<HospitalDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String hospitalName = "S동물메디컬센터";
  String hospitalNickname = "S동물메디컬센터";
  String currentDateTime = "";
  Timer? _timer;

  // 서버 데이터
  List<HospitalColumn> columns = [];
  List<Notice> notices = [];
  bool isLoadingColumns = false;
  bool isLoadingNotices = false;
  bool isLoadingDashboard = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2, // 2개의 탭 (공지사항, 칼럼)
      vsync: this,
    );
    _tabController.addListener(() {
      setState(() {}); // 탭이 변경될 때 UI를 다시 그리도록 강제
    });
    _loadHospitalName();
    _updateDateTime();
    _startTimer();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _updateDateTime() {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy년 M월 d일 (EEEE) HH:mm', 'ko_KR');
    setState(() {
      currentDateTime = formatter.format(now);
    });
  }

  Future<void> _refreshData() async {
    await _loadHospitalName();
    _updateDateTime();
    await _loadDashboardData();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateDateTime();
    });
  }

  Future<void> _loadHospitalName() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    // 먼저 로컬에 저장된 이름과 닉네임 확인
    final savedName = prefs.getString('hospital_name');
    final savedNickname = prefs.getString('hospital_nickname');
    if (savedName != null && savedName.isNotEmpty) {
      setState(() {
        hospitalName = savedName;
        hospitalNickname = savedNickname ?? savedName;
      });
    }

    // 서버에서 최신 이름 가져오기
    if (token != null) {
      try {
        final response = await http.get(
          Uri.parse('${Config.serverUrl}/api/auth/profile'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json; charset=UTF-8',
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          final userName = data['name'] ?? 'S동물메디컬센터';
          final userNickname = data['nickname'] ?? userName;

          setState(() {
            hospitalName = userName;
            hospitalNickname = userNickname;
          });

          // 로컬 저장소에도 업데이트
          await prefs.setString('hospital_name', userName);
          await prefs.setString('hospital_nickname', userNickname);
        }
      } catch (e) {
        // 오류 발생 시 기본값 유지
      }
    }
  }

  // 통합 대시보드 데이터 로드
  Future<void> _loadDashboardData() async {
    setState(() {
      isLoadingDashboard = true;
      isLoadingColumns = true;
      isLoadingNotices = true;
    });

    try {
      // 개별 API들을 직접 사용
      final futures = await Future.wait([
        DashboardService.getPublicColumns(limit: 50),
        DashboardService.getPublicNotices(limit: 50),
      ]);

      final columnPosts = futures[0] as List<ColumnPost>;
      final noticePosts = futures[1] as List<NoticePost>;

      // 칼럼 정렬 (중요 공지 우선, 그 다음 최신순)
      final sortedColumns =
          columnPosts.map((column) {
            final displayNickname =
                (column.authorNickname.toLowerCase() != '닉네임 없음')
                    ? column.authorNickname
                    : column.authorName;

            return HospitalColumn(
              columnIdx: column.columnIdx,
              title: column.title,
              content: column.contentPreview,
              hospitalName: column.authorName,
              hospitalIdx: 0,
              isPublished: true,
              viewCount: column.viewCount,
              createdAt: column.createdAt,
              updatedAt: column.updatedAt,
              authorNickname: displayNickname,
              columnUrl: column.columnUrl,
            );
          }).toList();

      sortedColumns.sort((a, b) {
        final aImportant = a.title.contains('[중요]') || a.title.contains('[공지]');
        final bImportant = b.title.contains('[중요]') || b.title.contains('[공지]');
        if (aImportant && !bImportant) return -1;
        if (!aImportant && bImportant) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      // 공지사항 필터링 및 정렬 (청중 타겟이 전체(0) 또는 병원(2)만)
      final sortedNotices =
          noticePosts
              .where(
                (notice) =>
                    notice.targetAudience == 0 || notice.targetAudience == 2,
              )
              .map((notice) {
                final displayNickname =
                    (notice.authorNickname.toLowerCase() != '닉네임 없음')
                        ? notice.authorNickname
                        : notice.authorName;

                return Notice(
                  noticeIdx: notice.noticeIdx,
                  accountIdx: 0,
                  title: notice.title,
                  content: notice.contentPreview,
                  noticeImportant: notice.noticeImportant,
                  noticeActive: true,
                  createdAt: notice.createdAt,
                  updatedAt: notice.updatedAt,
                  authorEmail: notice.authorEmail,
                  authorName: notice.authorName,
                  authorNickname: displayNickname,
                  viewCount: notice.viewCount,
                  targetAudience: notice.targetAudience,
                  noticeUrl: notice.noticeUrl,
                );
              })
              .toList();

      sortedNotices.sort((a, b) {
        if (a.showBadge && !b.showBadge) return -1;
        if (!a.showBadge && b.showBadge) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      setState(() {
        columns = sortedColumns;
        notices = sortedNotices;
        isLoadingDashboard = false;
        isLoadingColumns = false;
        isLoadingNotices = false;
      });
    } catch (e) {
      setState(() {
        isLoadingDashboard = false;
        isLoadingColumns = false;
        isLoadingNotices = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // 뒤로가기 방지
      child: Scaffold(
        appBar: AppDashboardAppBar(
          onProfilePressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ProfileManagement(),
              ),
            );
          },
          onNotificationPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const UnifiedNotificationPage(),
              ),
            );
          },
        ),
        body: RefreshIndicator(
          onRefresh: _refreshData,
          color: AppTheme.primaryBlue,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단 고정 컨텐츠
                Padding(
                  padding: AppTheme.pagePadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '안녕하세요, $hospitalNickname 님!',
                        style: AppTheme.h2Style,
                      ),
                      const SizedBox(height: AppTheme.spacing8),
                      Text(
                        currentDateTime,
                        style: AppTheme.bodyLargeStyle.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing20),
                      SizedBox(
                        width: double.infinity,
                        child: AppInfoCard(
                          icon: Icons.info_outline,
                          title: '새로운 헌혈 신청 2건이 도착했습니다!',
                          description: '신청 현황 보기',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const HospitalPostCheck(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // 게시글 관리 섹션
                Padding(
                  padding: AppTheme.pageHorizontalPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("게시글 관리", style: AppTheme.h3Style),
                      const SizedBox(height: AppTheme.spacing16),
                      Column(
                        children: [
                          _buildPremiumFeatureCard(
                            icon: Icons.edit_note_outlined,
                            title: "헌혈 게시판 작성",
                            subtitle: "새로운 헌혈 요청 게시글 작성",
                            iconColor: AppTheme.primaryBlue,
                            backgroundColor: AppTheme.lightBlue,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const HospitalPost(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: AppTheme.spacing16),
                          _buildPremiumFeatureCard(
                            icon: Icons.check_circle_outline,
                            title: "헌혈 신청 현황",
                            subtitle: "헌혈 신청자 관리 및 승인 처리",
                            iconColor: AppTheme.success,
                            backgroundColor: AppTheme.success.withValues(
                              alpha: 0.1,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => const HospitalPostCheck(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: AppTheme.spacing16),
                          _buildPremiumFeatureCard(
                            icon: Icons.article_outlined,
                            title: "칼럼 게시글 작성",
                            subtitle: "반려동물 헌혈 관련 정보 공유",
                            iconColor: Colors.pink.shade600,
                            backgroundColor: Colors.pink.shade50,
                            onTap: () async {
                              final hasPermission =
                                  await HospitalColumnService.checkColumnPermission();
                              if (hasPermission) {
                                if (mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) =>
                                              const HospitalColumnManagementScreen(),
                                    ),
                                  );
                                }
                              } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('관리자의 권한이 필요합니다.'),
                                      backgroundColor: Colors.pink,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppTheme.spacing32),

                // 탭바
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing16,
                  ),
                  child: TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.announcement, size: 20),
                            SizedBox(width: 8),
                            Text('공지사항'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.article, size: 20),
                            SizedBox(width: 8),
                            Text('칼럼'),
                          ],
                        ),
                      ),
                    ],
                    labelColor: Colors.black87,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.black87,
                    dividerColor: Colors.transparent,
                  ),
                ),

                // 탭 뷰
                Container(
                  margin: const EdgeInsets.only(
                    left: AppTheme.spacing16,
                    right: AppTheme.spacing16,
                    bottom: AppTheme.spacing16,
                  ),
                  height: 400, // 고정 높이
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.lightGray.withValues(alpha: 0.3),
                    ),
                  ),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildNoticeBoard(), // 공지사항 게시판 내용
                      _buildColumnBoard(), // 칼럼 게시판 내용
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 공지사항 게시판 위젯을 생성합니다.
  Widget _buildNoticeBoard() {
    if (isLoadingNotices) {
      return const Center(child: CircularProgressIndicator());
    }

    if (notices.isEmpty) {
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
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // 공지사항 목록
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: notices.length + 1, // ... 아이템 추가를 위해 +1
              separatorBuilder:
                  (context, index) => Container(
                    height: 1,
                    color: AppTheme.lightGray.withValues(alpha: 0.2),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                  ),
              itemBuilder: (context, index) {
                // 마지막 아이템은 ... 버튼
                if (index == notices.length) {
                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => const HospitalNoticeListScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      child: Center(
                        child: Text(
                          '...',
                          style: AppTheme.h3Style.copyWith(
                            color: AppTheme.textTertiary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                final notice = notices[index];

                return InkWell(
                  onTap: () {
                    _showNoticeBottomSheet(context, notice);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 왼쪽: 순서 (2줄 높이 중앙 정렬)
                        SizedBox(
                          width: 28,
                          height: 40,
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: AppTheme.bodySmallStyle.copyWith(
                                color: AppTheme.textTertiary,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 중앙: 메인 콘텐츠
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 첫 번째 줄: 뱃지 + 제목
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // notice_important가 1이면 뱃지 표시
                                  if (notice.showBadge) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.error,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        notice.badgeText,
                                        style: AppTheme.bodySmallStyle.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: MarqueeText(
                                      text:
                                          TextPersonalizationUtil.personalizeTitle(
                                            title: notice.title,
                                            userName: hospitalName,
                                            userNickname: hospitalNickname,
                                          ),
                                      style: AppTheme.bodyMediumStyle.copyWith(
                                        color:
                                            notice.showBadge
                                                ? AppTheme.error
                                                : AppTheme.textPrimary,
                                        fontWeight:
                                            notice.showBadge
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                      animationDuration: const Duration(
                                        milliseconds: 4000,
                                      ),
                                      pauseDuration: const Duration(
                                        milliseconds: 1000,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // 두 번째 줄: 작성자 이름
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      (notice.authorNickname ??
                                                      notice.authorName)
                                                  .length >
                                              15
                                          ? '${(notice.authorNickname ?? notice.authorName).substring(0, 15)}..'
                                          : (notice.authorNickname ??
                                              notice.authorName),
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
                                color: AppTheme.mediumGray.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppTheme.lightGray.withValues(
                                    alpha: 0.3,
                                  ),
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
                                    NumberFormatUtil.formatViewCount(
                                      notice.viewCount ?? 0,
                                    ),
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
          ),
        ],
      ),
    );
  }

  // 칼럼 게시판 위젯을 생성합니다.
  Widget _buildColumnBoard() {
    if (isLoadingColumns) {
      return const Center(child: CircularProgressIndicator());
    }

    if (columns.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 64, color: AppTheme.mediumGray),
            const SizedBox(height: 16),
            Text('공개된 칼럼이 없습니다', style: AppTheme.h4Style),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // 칼럼 목록
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: columns.length + 1, // ... 아이템 추가를 위해 +1
              separatorBuilder:
                  (context, index) => Container(
                    height: 1,
                    color: AppTheme.lightGray.withValues(alpha: 0.2),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                  ),
              itemBuilder: (context, index) {
                // 마지막 아이템은 ... 버튼
                if (index == columns.length) {
                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HospitalColumnList(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      child: Center(
                        child: Text(
                          '...',
                          style: AppTheme.h3Style.copyWith(
                            color: AppTheme.textTertiary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                final column = columns[index];
                final isImportant =
                    column.title.contains('[중요]') ||
                    column.title.contains('[공지]');
                final displayNickname =
                    (column.authorNickname != null &&
                            column.authorNickname!.toLowerCase() != '닉네임 없음')
                        ? column.authorNickname!
                        : column.hospitalName;

                return InkWell(
                  onTap: () => _showColumnBottomSheet(column),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 왼쪽: 순서 번호 (1.5번째 줄 위치)
                        SizedBox(
                          width: 20,
                          height: 50, // 전체 높이에 맞춤
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: AppTheme.bodySmallStyle.copyWith(
                                color: AppTheme.textTertiary,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 중앙: 메인 콘텐츠
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 첫 번째 줄: 뱃지 + 제목
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isImportant) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.error,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '중요',
                                        style: AppTheme.bodySmallStyle.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: MarqueeText(
                                      text:
                                          TextPersonalizationUtil.personalizeTitle(
                                            title: column.title,
                                            userName: hospitalName,
                                            userNickname: hospitalNickname,
                                          ),
                                      style: AppTheme.bodyMediumStyle.copyWith(
                                        color:
                                            isImportant
                                                ? AppTheme.error
                                                : AppTheme.textPrimary,
                                        fontWeight:
                                            isImportant
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                      animationDuration: const Duration(
                                        milliseconds: 4000,
                                      ),
                                      pauseDuration: const Duration(
                                        milliseconds: 1000,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // 두 번째 줄: 작성자 닉네임
                              Text(
                                displayNickname.length > 15
                                    ? '${displayNickname.substring(0, 15)}..'
                                    : displayNickname,
                                style: AppTheme.bodySmallStyle.copyWith(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                                  '작성: ${DateFormat('yy.MM.dd').format(column.createdAt)}',
                                  style: AppTheme.bodySmallStyle.copyWith(
                                    color: AppTheme.textTertiary,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '수정: ${DateFormat('yy.MM.dd').format(column.updatedAt)}',
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
                                color: AppTheme.mediumGray.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppTheme.lightGray.withValues(
                                    alpha: 0.3,
                                  ),
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
                                    NumberFormatUtil.formatViewCount(
                                      column.viewCount,
                                    ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radius16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacing20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius16),
            border: Border.all(
              color: iconColor.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: Icon(icon, size: 28, color: iconColor),
              ),
              const SizedBox(width: AppTheme.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.h4Style.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing4),
                    Text(
                      subtitle,
                      style: AppTheme.bodyMediumStyle.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showColumnBottomSheet(HospitalColumn column) async {
    HospitalColumn detailColumn;
    try {
      detailColumn = await HospitalColumnService.getColumnDetail(
        column.columnIdx,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('칼럼을 불러오지 못했습니다: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      final idx = columns.indexWhere(
        (c) => c.columnIdx == detailColumn.columnIdx,
      );
      if (idx != -1) {
        columns[idx] = detailColumn;
      }
    });

    final displayNickname =
        (detailColumn.authorNickname != null &&
                detailColumn.authorNickname!.toLowerCase() != '닉네임 없음')
            ? detailColumn.authorNickname!
            : detailColumn.hospitalName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          detailColumn.title,
                          style: AppTheme.h3Style.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: '닫기',
                        icon: const Icon(
                          Icons.close,
                          color: AppTheme.textSecondary,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.warning,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '칼럼',
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          displayNickname,
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '작성: ${DateFormat('yyyy-MM-dd HH:mm').format(detailColumn.createdAt)}',
                        style: AppTheme.bodySmallStyle.copyWith(
                          color: AppTheme.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Text(
                        detailColumn.content,
                        style: AppTheme.bodyMediumStyle.copyWith(
                          height: 1.6,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (detailColumn.columnUrl != null &&
                      detailColumn.columnUrl!.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final url = detailColumn.columnUrl!.trim();
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          } else {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('링크를 열 수 없습니다'),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                          }
                        },
                        icon: const Icon(
                          Icons.open_in_new,
                          color: Colors.black,
                        ),
                        label: const Text('링크 열기'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '조회수 ${NumberFormatUtil.formatViewCount(detailColumn.viewCount)}회',
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        if (!detailColumn.updatedAt.isAtSameMomentAs(
                          detailColumn.createdAt,
                        ))
                          Text(
                            '수정: ${DateFormat('yyyy-MM-dd HH:mm').format(detailColumn.updatedAt)}',
                            style: AppTheme.bodySmallStyle.copyWith(
                              color: Colors.grey[600],
                            ),
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

  // 공지사항 바텀시트 표시
  void _showNoticeBottomSheet(BuildContext context, Notice notice) async {
    // 상세 조회 API 호출 (조회수 자동 증가)
    NoticePost? noticeDetail;
    try {
      noticeDetail = await DashboardService.getNoticeDetail(notice.noticeIdx);
    } catch (e) {
      // ignore, fall back to existing data
    }

    if (noticeDetail != null && mounted) {
      setState(() {
        final idx = notices.indexWhere((n) => n.noticeIdx == notice.noticeIdx);
        if (idx != -1) {
          final displayNickname =
              (noticeDetail!.authorNickname != null &&
                      noticeDetail.authorNickname!.toLowerCase() != '닉네임 없음')
                  ? noticeDetail.authorNickname
                  : noticeDetail.authorName;

          notices[idx] = Notice(
            noticeIdx: notices[idx].noticeIdx,
            accountIdx: notices[idx].accountIdx,
            title: noticeDetail.title,
            content: noticeDetail.contentPreview,
            noticeImportant: noticeDetail.noticeImportant,
            noticeActive: notices[idx].noticeActive,
            createdAt: noticeDetail.createdAt,
            updatedAt: noticeDetail.updatedAt,
            authorEmail: noticeDetail.authorEmail,
            authorName: noticeDetail.authorName,
            authorNickname: displayNickname,
            viewCount: noticeDetail.viewCount,
            targetAudience: noticeDetail.targetAudience,
            noticeUrl: noticeDetail.noticeUrl,
          );
        }
      });
    }

    if (!mounted) return;

    final bool isImportant =
        (noticeDetail?.noticeImportant ?? notice.noticeImportant) == 0;
    final DateTime createdAt = noticeDetail?.createdAt ?? notice.createdAt;
    final DateTime updatedAt = noticeDetail?.updatedAt ?? notice.updatedAt;
    final int viewCount = noticeDetail?.viewCount ?? notice.viewCount ?? 0;
    final String authorName =
        noticeDetail?.authorNickname != null &&
                noticeDetail!.authorNickname!.toLowerCase() != '닉네임 없음'
            ? noticeDetail.authorNickname!
            : notice.authorNickname ?? notice.authorName;
    final String title = noticeDetail?.title ?? notice.title;
    final String content = noticeDetail?.contentPreview ?? notice.content;
    final String? noticeUrl = noticeDetail?.noticeUrl ?? notice.noticeUrl;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTheme.h3Style.copyWith(
                            fontWeight: FontWeight.bold,
                            color:
                                isImportant
                                    ? AppTheme.error
                                    : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black87),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isImportant
                                  ? AppTheme.error
                                  : AppTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isImportant ? '공지' : '알림',
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          authorName,
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '작성: ${DateFormat('yyyy-MM-dd HH:mm').format(createdAt)}',
                        style: AppTheme.bodySmallStyle.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Text(
                        content,
                        style: AppTheme.bodyMediumStyle.copyWith(
                          height: 1.6,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (noticeUrl != null && noticeUrl.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(noticeUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          } else if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('링크를 열 수 없습니다.'),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                          }
                        },
                        icon: const Icon(
                          Icons.open_in_new,
                          color: Colors.black,
                        ),
                        label: const Text('관련 링크 열기'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '조회수 ${NumberFormatUtil.formatViewCount(viewCount)}회',
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        if (!updatedAt.isAtSameMomentAs(createdAt))
                          Text(
                            '수정: ${DateFormat('yyyy-MM-dd HH:mm').format(updatedAt)}',
                            style: AppTheme.bodySmallStyle.copyWith(
                              color: Colors.grey[600],
                            ),
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
}
