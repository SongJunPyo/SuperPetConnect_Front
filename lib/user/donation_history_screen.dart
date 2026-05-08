import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_theme.dart';
import '../utils/config.dart';
import '../utils/api_endpoints.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/app_search_bar.dart';
import '../services/auth_http_client.dart';
import 'package:http/http.dart' as http;
import 'donation_survey_form_page.dart';

class DonationHistoryScreen extends StatefulWidget {
  /// 알림 탭 등 외부 진입 시 강조할 신청 application_id (= applied_donation_idx).
  /// 데이터 로딩 후 statusCode에 따라 자동 탭 전환 + 카드 일시 highlight.
  final int? initialApplicationId;

  const DonationHistoryScreen({super.key, this.initialApplicationId});

  @override
  State<DonationHistoryScreen> createState() => _DonationHistoryScreenState();
}

class _DonationHistoryScreenState extends State<DonationHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 통계 데이터
  int totalApplications = 0;
  int completedDonations = 0;

  // UI 상태
  bool isLoading = true;
  String searchQuery = '';
  DateTime? selectedDate; // 날짜 필터

  // 데이터
  List<DonationApplication> applications = [];
  List<DonationApplication> completed = [];
  List<DonationApplication> filteredApplications = [];
  List<DonationApplication> filteredCompleted = [];

  // 구글폼 URL
  String? _satisfactionSurveyUrl;
  String? _giftApplicationUrl;

  // 클릭 상태 (SharedPreferences)
  Set<String> _surveyClicked = {};
  Set<String> _giftClicked = {};

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDonationHistoryAndMaybeAutoOpen();
    _loadSurveyLinks();
    _loadClickStatus();
  }

  /// _loadDonationHistory 완료 후 알림 진입(initialApplicationId)이 있으면
  /// 매칭 항목의 탭으로 자동 전환 + 상세 시트 자동 오픈 (패턴 A).
  Future<void> _loadDonationHistoryAndMaybeAutoOpen() async {
    await _loadDonationHistory();
    if (!mounted) return;

    final id = widget.initialApplicationId;
    if (id == null) return;

    final completedMatch =
        completed.where((a) => a.applicationId == id).firstOrNull;
    final applicationMatch =
        applications.where((a) => a.applicationId == id).firstOrNull;
    final match = completedMatch ?? applicationMatch;
    if (match == null) return;

    if (completedMatch != null) {
      _tabController.animateTo(1);
    } else {
      _tabController.animateTo(0);
    }

    // 탭 애니메이션과 시트 오픈이 겹치지 않게 한 프레임 양보.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showApplicationDetailSheet(match);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// 구글폼 URL 조회 (인증 불필요)
  Future<void> _loadSurveyLinks() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.surveyLinks}'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _satisfactionSurveyUrl = data['satisfaction_survey_url'];
          _giftApplicationUrl = data['gift_application_url'];
        });
      }
    } catch (e) {
      debugPrint('구글폼 URL 로딩 실패: $e');
    }
  }

  /// SharedPreferences에서 클릭 상태 로드
  Future<void> _loadClickStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final surveyKeys = prefs.getKeys().where((k) => k.startsWith('survey_clicked_'));
    final giftKeys = prefs.getKeys().where((k) => k.startsWith('gift_clicked_'));
    setState(() {
      _surveyClicked = surveyKeys.toSet();
      _giftClicked = giftKeys.toSet();
    });
  }

  /// 클릭 상태 저장
  Future<void> _markClicked(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, true);
    setState(() {
      if (key.startsWith('survey_clicked_')) {
        _surveyClicked.add(key);
      } else {
        _giftClicked.add(key);
      }
    });
  }

  /// 외부 URL 열기
  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// 헌혈 자료 요청
  Future<void> _requestDocuments(int applicationId) async {
    try {
      final response = await AuthHttpClient.post(
        Uri.parse(
            '${Config.serverUrl}${ApiEndpoints.donationRequestDocuments}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'applicationId': applicationId}),
      );

      if (!mounted) return;

      String title;
      String message;
      if (response.statusCode == 200) {
        title = '자료 요청 완료';
        message = '자료 요청이 전송되었습니다.';
      } else if (response.statusCode == 409) {
        title = '자료 요청 안내';
        message = '이미 오늘 자료 요청을 보냈습니다.\n내일 다시 요청할 수 있습니다.';
      } else {
        final data = jsonDecode(response.body);
        title = '자료 요청 실패';
        message = data['detail'] ?? '자료 요청에 실패했습니다.';
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('오류'),
            content: const Text('자료 요청 중 오류가 발생했습니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _loadDonationHistory() async {
    setState(() => isLoading = true);

    try {
      final response = await AuthHttpClient.get(
        Uri.parse('${Config.serverUrl}/api/donation/my-applications'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> applicationsJson = data['applications'] ?? [];

        // 디버그: API 응답 확인
        debugPrint('[DonationHistory] API 응답: $data');
        for (var app in applicationsJson) {
          debugPrint(
            '[DonationHistory] 신청 데이터: status=${app['status']}, status_kr=${app['status_kr']}, status_code=${app['status_code']}',
          );
        }

        final allApplications =
            applicationsJson
                .map((json) => DonationApplication.fromJson(json))
                .toList();

        // 신청 중인 것과 완료된 것 분리.
        // status_code: 0=대기, 1=선정, 2=완료대기(=사용자 표시 시 승인됨으로 통합),
        //              3=완료, 4=종결(미선정/사용자 자발 취소 후 시스템 종결)
        // statusCode 4는 사용자 신청 이력에서 양쪽 탭 모두 숨김 — 'recruitment_closed'
        // 알림으로 별도 안내됨. 백엔드 데이터는 보존(admin 통계용).
        applications = allApplications
            .where((app) =>
                app.statusCode == 0 ||
                app.statusCode == 1 ||
                app.statusCode == 2)
            .toList();
        completed =
            allApplications.where((app) => app.statusCode == 3).toList();

        debugPrint(
          '[DonationHistory] 신청 중: ${applications.length}개, 완료: ${completed.length}개',
        );

        totalApplications = allApplications.length;
        completedDonations = completed.length;

        _applySearchFilter();
      } else {
        throw Exception('데이터를 불러올 수 없습니다.');
      }
    } catch (e) {
      // 헌혈 이력 로딩 실패 시 로그 출력
      debugPrint('Failed to load donation history: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _applySearchFilter() {
    // 먼저 전체 데이터로 시작
    filteredApplications = applications.toList();
    filteredCompleted = completed.toList();

    // 검색어 필터링
    if (searchQuery.isNotEmpty) {
      filteredApplications =
          filteredApplications
              .where(
                (app) =>
                    app.postTitle.toLowerCase().contains(
                      searchQuery.toLowerCase(),
                    ) ||
                    app.petName.toLowerCase().contains(
                      searchQuery.toLowerCase(),
                    ),
              )
              .toList();

      filteredCompleted =
          filteredCompleted
              .where(
                (app) =>
                    app.postTitle.toLowerCase().contains(
                      searchQuery.toLowerCase(),
                    ) ||
                    app.petName.toLowerCase().contains(
                      searchQuery.toLowerCase(),
                    ),
              )
              .toList();
    }

    // 날짜 필터링
    if (selectedDate != null) {
      filteredApplications =
          filteredApplications
              .where((app) => _isSameDay(app.donationTime, selectedDate!))
              .toList();

      filteredCompleted =
          filteredCompleted
              .where((app) => _isSameDay(app.donationTime, selectedDate!))
              .toList();
    }

    setState(() {});
  }

  void _onSearchChanged(String value) {
    setState(() {
      searchQuery = value;
      _applySearchFilter();
    });
  }

  Future<void> _refreshData() async {
    await _loadDonationHistory();
  }

  // 날짜 선택 함수
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ko', 'KR'), // 한국어 로케일
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      _applySearchFilter();
    }
  }

  // 같은 날인지 확인
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppAppBar(
        title: '헌혈 이력',
        showBackButton: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined, color: Colors.black87),
            onPressed: () => _selectDate(context),
            tooltip: '날짜 선택',
          ),
          if (selectedDate != null)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.black87),
              onPressed: () {
                setState(() {
                  selectedDate = null;
                });
                _applySearchFilter();
              },
              tooltip: '날짜 필터 해제',
            ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined, color: Colors.black87),
            tooltip: '새로고침',
            onPressed: _refreshData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 통계 섹션 (기존 신청 현황 스타일)
          if (totalApplications > 0 || completedDonations > 0)
            _buildStatsHeader(),

          // 선택된 날짜 표시
          if (selectedDate != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.lightBlue,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.lightGray),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: AppTheme.primaryDarkBlue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat(
                      'yyyy년 MM월 dd일 (E)',
                      'ko_KR',
                    ).format(selectedDate!),
                    style: AppTheme.bodyMediumStyle.copyWith(
                      color: AppTheme.primaryDarkBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedDate = null;
                      });
                      _applySearchFilter();
                    },
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: AppTheme.primaryDarkBlue,
                    ),
                  ),
                ],
              ),
            ),

          // 검색창
          Container(
            padding: const EdgeInsets.all(16.0),
            child: AppSearchBar(
              controller: _searchController,
              hintText: '게시글 제목, 반려동물 이름으로 검색...',
              onChanged: _onSearchChanged,
              onClear: () {
                _onSearchChanged('');
              },
            ),
          ),

          // 탭바
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.black,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey.shade600,
              labelStyle: AppTheme.bodyLargeStyle.copyWith(
                fontWeight: FontWeight.w600,
              ),
              tabs: [
                Tab(text: '헌혈 신청 (${filteredApplications.length})'),
                Tab(text: '헌혈 완료 (${filteredCompleted.length})'),
              ],
            ),
          ),

          // 탭 내용
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildApplicationsList(filteredApplications, isCompleted: false),
                _buildApplicationsList(filteredCompleted, isCompleted: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      margin: const EdgeInsets.all(AppTheme.spacing16),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: AppTheme.lightBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: AppTheme.lightBlue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '나의 헌혈 현황',
            style: AppTheme.h4Style.copyWith(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '총 신청',
                  '$totalApplications건',
                  AppTheme.primaryBlue,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  '완료된 헌혈',
                  '$completedDonations건',
                  Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: AppTheme.h4Style.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppTheme.spacing4),
        Text(
          label,
          style: AppTheme.bodySmallStyle.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  /// 헌혈 사전 정보 설문 작성/수정 화면 진입.
  /// APPROVED 신청 카드의 버튼에서 호출. 작성 화면이 신규/수정/잠금을 자동 분기.
  /// 제출 성공(true) 반환 시 목록을 다시 불러와 상태 변동 가능성 반영.
  Future<void> _openSurveyForm(int applicationId) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DonationSurveyFormPage(applicationId: applicationId),
      ),
    );
    if (result == true && mounted) {
      _loadDonationHistory();
    }
  }

  Widget _buildApplicationsList(List<DonationApplication> applications, {bool isCompleted = false}) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
        ),
      );
    }

    if (applications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bloodtype, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              '헌혈 내역이 없습니다',
              style: AppTheme.h4Style.copyWith(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: AppTheme.primaryBlue,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        itemCount: applications.length,
        itemBuilder: (context, index) {
          final application = applications[index];
          return _buildApplicationCard(application, isCompleted: isCompleted);
        },
      ),
    );
  }


  Widget _buildApplicationCard(DonationApplication application, {bool isCompleted = false}) {
    // statusCode 기반 라벨/색 결정 (서버 status 텍스트 대신).
    // 1(APPROVED)과 2(PENDING_COMPLETION)는 사용자 입장에서 동일하게 "승인됨" 표시.
    Color statusColor;
    Color statusBackgroundColor;
    String statusLabel;

    switch (application.statusCode) {
      case 0:
        statusLabel = '대기중';
        statusColor = Colors.orange.shade700;
        statusBackgroundColor = Colors.orange.shade50;
        break;
      case 1:
      case 2:
        statusLabel = '승인됨';
        statusColor = Colors.green.shade700;
        statusBackgroundColor = Colors.green.shade50;
        break;
      case 3:
        statusLabel = '헌혈 완료';
        statusColor = AppTheme.primaryDarkBlue;
        statusBackgroundColor = AppTheme.lightBlue;
        break;
      default:
        // statusCode 4는 _loadDonationHistory에서 이미 필터링되어 도달 불가.
        // 알 수 없는 상태(5+)는 서버 텍스트 fallback.
        statusLabel = application.status;
        statusColor = Colors.grey.shade700;
        statusBackgroundColor = Colors.grey.shade50;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black, width: 1),
      ),
      child: InkWell(
        onTap: () => _showApplicationDetailSheet(application),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    application.postTitle,
                    style: AppTheme.bodyLargeStyle.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusBackgroundColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Text(
                    statusLabel,
                    style: AppTheme.bodySmallStyle.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FaIcon(
                  application.petSpecies.contains('강아지') ||
                          application.petSpecies.contains('개')
                      ? FontAwesomeIcons.dog
                      : FontAwesomeIcons.cat,
                  size: 16,
                  color: Colors.black87,
                ),
                const SizedBox(width: 8),
                Text(
                  '${application.petName} (${application.petSpecies})',
                  style: AppTheme.bodyMediumStyle.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    application.petBloodType,
                    style: AppTheme.bodySmallStyle.copyWith(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  DateFormat(
                    'yyyy년 MM월 dd일 HH:mm',
                  ).format(application.donationTime),
                  style: AppTheme.bodyMediumStyle.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            // APPROVED(선정) 상태에서만 사전 설문 작성 진입점 노출.
            // 알림(D-2 09:00) 도착 전에도 사용자가 직접 미리 작성 가능하도록.
            if (application.statusCode == 1) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openSurveyForm(application.applicationId),
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: const Text('헌혈 사전 정보 설문'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryBlue,
                    side: const BorderSide(color: AppTheme.primaryBlue),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
            // 액션 버튼들(자료 요청 / 만족도 / 후원선물)은 카드에서 제외하고
            // 상세 시트로 이동 — 카드는 한 줄 요약, 시트는 전체 정보 + 액션.
          ],
        ),
        ),
      ),
    );
  }

  /// 신청 카드 클릭 또는 알림 진입 시 열리는 상세 시트.
  /// 패턴 A — 다른 화면(HospitalPostCheck, PetManagementScreen 등)과 통일.
  ///
  /// 표시 내용:
  /// - 신청 상태 헤더 + 게시글 제목
  /// - 병원 정보 (이름/주소/전화) — 백엔드 응답 확장 필드 사용 (없으면 자동 숨김)
  /// - 펫 정보 (이름/종/품종/혈액형)
  /// - 일정 (헌혈 예정/완료 일시)
  /// - 헌혈량 + 다음 헌혈 가능일 (statusCode==3에서만)
  /// - 액션 버튼 (자료 요청 / 만족도 / 후원선물 — 완료 상태에서만)
  void _showApplicationDetailSheet(DonationApplication application) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: _DonationApplicationDetailSheetContent(
              application: application,
              scrollController: scrollController,
              satisfactionSurveyUrl: _satisfactionSurveyUrl,
              giftApplicationUrl: _giftApplicationUrl,
              isSurveyClicked: _surveyClicked
                  .contains('survey_clicked_${application.applicationId}'),
              isGiftClicked: _giftClicked
                  .contains('gift_clicked_${application.applicationId}'),
              onRequestDocuments: () =>
                  _requestDocuments(application.applicationId),
              onSurveyTap: () async {
                await _markClicked(
                    'survey_clicked_${application.applicationId}');
                await _openUrl(_satisfactionSurveyUrl!);
              },
              onGiftTap: () async {
                await _markClicked(
                    'gift_clicked_${application.applicationId}');
                await _openUrl(_giftApplicationUrl!);
              },
            ),
          ),
        );
      },
    );
  }
}

/// 헌혈 신청 상세 시트의 본문. 부모 화면에서 콜백을 주입받아 액션 처리.
class _DonationApplicationDetailSheetContent extends StatelessWidget {
  final DonationApplication application;
  final ScrollController scrollController;
  final String? satisfactionSurveyUrl;
  final String? giftApplicationUrl;
  final bool isSurveyClicked;
  final bool isGiftClicked;
  final VoidCallback onRequestDocuments;
  final Future<void> Function() onSurveyTap;
  final Future<void> Function() onGiftTap;

  const _DonationApplicationDetailSheetContent({
    required this.application,
    required this.scrollController,
    required this.satisfactionSurveyUrl,
    required this.giftApplicationUrl,
    required this.isSurveyClicked,
    required this.isGiftClicked,
    required this.onRequestDocuments,
    required this.onSurveyTap,
    required this.onGiftTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = application.statusCode == 3;
    final (statusLabel, statusColor, statusBg) = _statusVisuals(application);

    return Column(
      children: [
        // 핸들 바
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // 헤더
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              Text(
                isCompleted ? '헌혈 완료 상세' : '헌혈 신청 상세',
                style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // 본문
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              // 상태 뱃지
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor, width: 1),
                ),
                child: Text(
                  statusLabel,
                  style: AppTheme.bodyMediumStyle.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // 게시글 제목
              _section(
                icon: Icons.description_outlined,
                title: '게시글',
                child: Text(
                  application.postTitle,
                  style: AppTheme.bodyLargeStyle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // 병원 정보 (필드가 있으면 표시)
              if (application.hospitalName != null) ...[
                const SizedBox(height: 16),
                _section(
                  icon: Icons.local_hospital_outlined,
                  title: '병원',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        application.hospitalName!,
                        style: AppTheme.bodyLargeStyle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (application.hospitalAddress != null &&
                          application.hospitalAddress!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.place_outlined,
                                size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                application.hospitalAddress!,
                                style: AppTheme.bodyMediumStyle.copyWith(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (application.hospitalPhone != null &&
                          application.hospitalPhone!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => launchUrl(
                            Uri.parse('tel:${application.hospitalPhone}'),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.phone_outlined,
                                  size: 16,
                                  color: AppTheme.primaryBlue),
                              const SizedBox(width: 4),
                              Text(
                                application.hospitalPhone!,
                                style: AppTheme.bodyMediumStyle.copyWith(
                                  color: AppTheme.primaryBlue,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // 펫 정보
              _section(
                icon: application.petSpecies.contains('강아지') ||
                        application.petSpecies.contains('개')
                    ? Icons.pets
                    : Icons.pets,
                title: '헌혈 반려동물',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _kv('이름', application.petName),
                    const SizedBox(height: 4),
                    _kv('종/품종', _formatSpeciesBreed(application)),
                    const SizedBox(height: 4),
                    _kv('혈액형', application.petBloodType),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 일정
              _section(
                icon: Icons.calendar_today_outlined,
                title: '일정',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _kv(
                      '헌혈 예정',
                      DateFormat('yyyy-MM-dd (E) HH:mm', 'ko_KR')
                          .format(application.donationTime),
                    ),
                    if (application.donationCompletedAt != null) ...[
                      const SizedBox(height: 4),
                      _kv(
                        '완료 처리',
                        DateFormat('yyyy-MM-dd (E) HH:mm', 'ko_KR')
                            .format(application.donationCompletedAt!),
                      ),
                    ],
                  ],
                ),
              ),
              // 헌혈량 + 다음 헌혈 가능일 (완료 시에만)
              if (isCompleted && application.bloodVolumeMl != null) ...[
                const SizedBox(height: 16),
                _section(
                  icon: Icons.bloodtype_outlined,
                  title: '헌혈량',
                  child: Text(
                    '${application.bloodVolumeMl!.toStringAsFixed(application.bloodVolumeMl! % 1 == 0 ? 0 : 1)} mL',
                    style: AppTheme.h3Style.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryDarkBlue,
                    ),
                  ),
                ),
              ],
              if (isCompleted && application.nextEligibleDate != null) ...[
                const SizedBox(height: 16),
                _section(
                  icon: Icons.schedule_outlined,
                  title: '다음 헌혈 가능일',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${DateFormat('yyyy-MM-dd (E)', 'ko_KR').format(application.nextEligibleDate!)} 이후',
                        style: AppTheme.bodyLargeStyle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '※ 마지막 헌혈일로부터 180일',
                        style: AppTheme.bodySmallStyle.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // 액션 버튼 (완료 시에만)
              if (isCompleted) ...[
                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onRequestDocuments,
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: const Text('헌혈 자료 요청'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                      side: BorderSide(color: AppTheme.mediumGray),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                if (satisfactionSurveyUrl != null ||
                    giftApplicationUrl != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (satisfactionSurveyUrl != null)
                        Expanded(
                          child: _surveyButton(
                            label: '만족도 조사',
                            icon: Icons.rate_review_outlined,
                            isClicked: isSurveyClicked,
                            onPressed: onSurveyTap,
                          ),
                        ),
                      if (satisfactionSurveyUrl != null &&
                          giftApplicationUrl != null)
                        const SizedBox(width: 8),
                      if (giftApplicationUrl != null)
                        Expanded(
                          child: _surveyButton(
                            label: '후원선물 신청',
                            icon: Icons.card_giftcard_outlined,
                            isClicked: isGiftClicked,
                            onPressed: onGiftTap,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  static (String, Color, Color) _statusVisuals(DonationApplication a) {
    switch (a.statusCode) {
      case 0:
        return ('대기중', Colors.orange.shade700, Colors.orange.shade50);
      case 1:
      case 2:
        return ('승인됨', Colors.green.shade700, Colors.green.shade50);
      case 3:
        return ('헌혈 완료', AppTheme.primaryDarkBlue, AppTheme.lightBlue);
      default:
        return (a.status, Colors.grey.shade700, Colors.grey.shade50);
    }
  }

  static String _formatSpeciesBreed(DonationApplication a) {
    if (a.petBreed == null || a.petBreed!.isEmpty) return a.petSpecies;
    return '${a.petSpecies} / ${a.petBreed}';
  }

  Widget _section({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              title,
              style: AppTheme.bodyMediumStyle.copyWith(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          margin: const EdgeInsets.only(left: 24),
          child: child,
        ),
      ],
    );
  }

  Widget _kv(String key, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(
            key,
            style: AppTheme.bodyMediumStyle.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTheme.bodyMediumStyle.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _surveyButton({
    required String label,
    required IconData icon,
    required bool isClicked,
    required Future<void> Function() onPressed,
  }) {
    return OutlinedButton(
      onPressed: () async => onPressed(),
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: isClicked ? Colors.grey.shade300 : AppTheme.primaryBlue,
        ),
        backgroundColor: isClicked
            ? Colors.grey.shade50
            : AppTheme.primaryBlue.withAlpha(13),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            isClicked ? Icons.check_circle : Icons.check_circle_outline,
            size: 18,
            color: isClicked ? Colors.green : Colors.grey.shade400,
          ),
        ],
      ),
    );
  }
}

/// `/api/donation/my-applications` 응답의 한 신청 항목.
///
/// 백엔드 contract (CLAUDE.md "헌혈 완료 처리 contract" + 응답 확장 합의):
/// - 기본 필드: applicationId, postId, postTitle, petName, petSpecies,
///   petBloodType, donationTime, status, statusCode
/// - 확장 필드 (상세 시트용):
///   * hospitalName (NOT NULL), hospitalAddress / hospitalPhone (nullable)
///   * petBreed (NOT NULL — 자유 텍스트)
///   * statusCode==3에서만: bloodVolumeMl, donationCompletedAt
///
/// 백엔드 작업 진행 중 응답에 신규 필드가 아직 없을 수 있어 모든 신규 필드는
/// nullable + null-safe 기본값으로 받음 (구버전 응답 호환).
class DonationApplication {
  final int applicationId;
  final int postId;
  final String postTitle;
  final String petName;
  final String petSpecies;
  final String petBloodType;
  final DateTime donationTime;
  final String status;
  final int statusCode;

  // 상세 시트용 확장 필드 (응답 확장 후 채워짐)
  final String? hospitalName;
  final String? hospitalAddress;
  final String? hospitalPhone;
  final String? petBreed;
  final double? bloodVolumeMl;
  final DateTime? donationCompletedAt;

  DonationApplication({
    required this.applicationId,
    required this.postId,
    required this.postTitle,
    required this.petName,
    required this.petSpecies,
    required this.petBloodType,
    required this.donationTime,
    required this.status,
    required this.statusCode,
    this.hospitalName,
    this.hospitalAddress,
    this.hospitalPhone,
    this.petBreed,
    this.bloodVolumeMl,
    this.donationCompletedAt,
  });

  factory DonationApplication.fromJson(Map<String, dynamic> json) {
    return DonationApplication(
      applicationId: json['applied_donation_idx'] ?? json['application_id'] ?? 0,
      postId: json['post_id'] ?? 0,
      postTitle: json['post_title'] ?? '',
      petName: json['pet_name'] ?? '',
      petSpecies: json['pet_species'] ?? '',
      petBloodType: json['pet_blood_type'] ?? '',
      donationTime:
          DateTime.tryParse(json['donation_time'] ?? '') ?? DateTime.now(),
      status: json['status'] ?? '대기중',
      statusCode: json['status_code'] ?? 0,
      hospitalName: json['hospital_name'] as String?,
      hospitalAddress: json['hospital_address'] as String?,
      hospitalPhone: json['hospital_phone'] as String?,
      petBreed: json['pet_breed'] as String?,
      bloodVolumeMl: (json['blood_volume_ml'] as num?)?.toDouble(),
      donationCompletedAt: json['donation_completed_at'] != null
          ? DateTime.tryParse(json['donation_completed_at'] as String)
          : null,
    );
  }

  /// 다음 헌혈 가능일 = donation_completed_at + 180일 (CLAUDE.md
  /// "헌혈 완료 처리 contract" - DONATION_INTERVAL_DAYS=180).
  /// statusCode != 3이거나 donation_completed_at이 없으면 null.
  DateTime? get nextEligibleDate {
    if (donationCompletedAt == null) return null;
    return donationCompletedAt!.add(const Duration(days: 180));
  }
}
