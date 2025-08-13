import 'package:flutter/material.dart';
import 'package:connect/hospital/hospital_post.dart';
import 'package:connect/hospital/hospital_alarm.dart';
import 'package:connect/hospital/hospital_post_check.dart';
import '../utils/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_app_bar.dart';
import '../auth/profile_management.dart';
import 'hospital_column_list.dart';
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
        print('병원 이름 로드 실패: $e');
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
        DashboardService.getPublicColumns(limit: 10),
        DashboardService.getPublicNotices(limit: 10),
      ]);

      final columnPosts = futures[0] as List<ColumnPost>;
      final noticePosts = futures[1] as List<NoticePost>;

      print('DEBUG: 병원 대시보드 데이터 로드 결과:');
      print('  - 칼럼: ${columnPosts.length}건');
      print('  - 공지사항: ${noticePosts.length}건');

      // 칼럼 정렬 (중요 공지 우선, 그 다음 최신순)
      final sortedColumns =
          columnPosts.map((column) {
            return HospitalColumn(
              columnIdx: column.columnIdx,
              title: column.title,
              content: column.contentPreview,
              hospitalName: column.authorName, // 병원 실명
              hospitalIdx: 0,
              isPublished: true,
              viewCount: column.viewCount,
              createdAt: column.createdAt,
              updatedAt: column.updatedAt,
              authorNickname: column.authorNickname, // 병원 닉네임
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
                  authorNickname: notice.authorNickname, // 작성자 닉네임
                  viewCount: notice.viewCount,
                  targetAudience: notice.targetAudience,
                );
              })
              .toList();

      sortedNotices.sort((a, b) {
        if (a.showBadge && !b.showBadge) return -1;
        if (!a.showBadge && b.showBadge) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      setState(() {
        columns = sortedColumns.take(10).toList();
        notices = sortedNotices.take(10).toList();
        isLoadingDashboard = false;
        isLoadingColumns = false;
        isLoadingNotices = false;
      });
    } catch (e) {
      print('병원 대시보드 데이터 로드 실패: $e');
      setState(() {
        isLoadingDashboard = false;
        isLoadingColumns = false;
        isLoadingNotices = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // 뒤로가기 방지
      child: Scaffold(
        appBar: AppDashboardAppBar(
          onProfilePressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileManagement()),
            );
          },
          onNotificationPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HospitalAlarm()),
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
                      Text('안녕하세요, $hospitalNickname 님!', style: AppTheme.h2Style),
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
                            backgroundColor: AppTheme.success.withOpacity(0.1),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const HospitalPostCheck(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: AppTheme.spacing16),
                          _buildPremiumFeatureCard(
                            icon: Icons.article_outlined,
                            title: "칼럼 게시글 작성",
                            subtitle: "반려동물 헌혈 관련 정보 공유",
                            iconColor: AppTheme.warning,
                            backgroundColor: AppTheme.warning.withOpacity(0.1),
                            onTap: () async {
                              final hasPermission = await HospitalColumnService.checkColumnPermission();
                              if (hasPermission) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const HospitalColumnList(),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('관리자의 권한이 필요합니다.'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: AppTheme.spacing16),
                          _buildPremiumFeatureCard(
                            icon: Icons.bloodtype_outlined,
                            title: "헌혈 완료 통계", 
                            subtitle: "완료된 헌혈 기록 및 통계 확인",
                            iconColor: Colors.red.shade600,
                            backgroundColor: Colors.red.shade50,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('헌혈 통계 화면 (구현 예정)')),
                              );
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
                  margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
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
                    border: Border.all(color: AppTheme.lightGray.withOpacity(0.3)),
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
                    color: AppTheme.lightGray.withOpacity(0.2),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                  ),
              itemBuilder: (context, index) {
                // 마지막 아이템은 ... 버튼
                if (index == notices.length) {
                  return InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('공지사항 더보기 (준비 중)')),
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
                        Container(
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
                                      text: TextPersonalizationUtil.personalizeTitle(
                                        title: notice.title,
                                        userName: hospitalName,
                                        userNickname: hospitalNickname,
                                      ),
                                      style: AppTheme.bodyMediumStyle.copyWith(
                                        color: notice.showBadge ? AppTheme.error : AppTheme.textPrimary,
                                        fontWeight: notice.showBadge ? FontWeight.w600 : FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                      animationDuration: const Duration(milliseconds: 4000),
                                      pauseDuration: const Duration(milliseconds: 1000),
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
                                color: AppTheme.mediumGray.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppTheme.lightGray.withOpacity(0.3),
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
                    color: AppTheme.lightGray.withOpacity(0.2),
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

                return InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('칼럼 ${column.columnIdx} 상세 페이지 (준비 중)'),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 왼쪽: 순서 번호 (1.5번째 줄 위치)
                        Container(
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
                                      text: TextPersonalizationUtil.personalizeTitle(
                                        title: column.title,
                                        userName: hospitalName,
                                        userNickname: hospitalNickname,
                                      ),
                                      style: AppTheme.bodyMediumStyle.copyWith(
                                        color: isImportant ? AppTheme.error : AppTheme.textPrimary,
                                        fontWeight: isImportant ? FontWeight.w600 : FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                      animationDuration: const Duration(milliseconds: 4000),
                                      pauseDuration: const Duration(milliseconds: 1000),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // 두 번째 줄: 작성자 닉네임
                              Text(
                                (column.authorNickname ?? column.hospitalName).length > 15
                                    ? '${(column.authorNickname ?? column.hospitalName).substring(0, 15)}..'
                                    : (column.authorNickname ?? column.hospitalName),
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
                                color: AppTheme.mediumGray.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppTheme.lightGray.withOpacity(0.3),
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
                                    NumberFormatUtil.formatViewCount(column.viewCount),
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
            border: Border.all(color: iconColor.withOpacity(0.2), width: 1.5),
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
                  color: iconColor.withOpacity(0.1),
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

  // 공지사항 바텀시트 표시
  void _showNoticeBottomSheet(BuildContext context, Notice notice) async {
    // 상세 조회 API 호출 (조회수 자동 증가)
    final noticeDetail = await DashboardService.getNoticeDetail(
      notice.noticeIdx,
    );
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // 핸들 바
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // 제목 영역
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Row(
                      children: [
                        if (notice.showBadge) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.error,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              notice.badgeText,
                              style: AppTheme.bodySmallStyle.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Text(
                            TextPersonalizationUtil.personalizeTitle(
                              title: noticeDetail?.title ?? notice.title,
                              userName: hospitalName,
                              userNickname: hospitalNickname,
                            ),
                            style: AppTheme.h3Style.copyWith(
                              color: notice.showBadge ? AppTheme.error : AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // 메타 정보
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Text(
                          '${notice.authorNickname ?? notice.authorName} • ',
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        Text(
                          DateFormat('yyyy년 MM월 dd일').format(noticeDetail?.createdAt ?? notice.createdAt),
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.visibility_outlined,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          NumberFormatUtil.formatViewCount(noticeDetail?.viewCount ?? notice.viewCount ?? 0),
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 내용
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Text(
                        TextPersonalizationUtil.personalizeContent(
                          content: noticeDetail?.contentPreview ?? notice.content,
                          userName: hospitalName,
                          userNickname: hospitalNickname,
                        ),
                        style: AppTheme.bodyMediumStyle.copyWith(
                          height: 1.6,
                        ),
                      ),
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