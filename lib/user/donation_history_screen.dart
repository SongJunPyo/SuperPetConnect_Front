import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../utils/app_theme.dart';
import '../utils/config.dart';
import '../widgets/app_app_bar.dart';
import '../services/auth_http_client.dart';

class DonationHistoryScreen extends StatefulWidget {
  const DonationHistoryScreen({super.key});

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

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDonationHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
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

        // 신청 중인 것과 완료된 것 분리
        // status_code: 0=대기중, 1=승인됨, 2=거절됨, 4=취소됨, 7=헌혈완료
        applications =
            allApplications.where((app) => app.statusCode != 7).toList();
        completed =
            allApplications.where((app) => app.statusCode == 7).toList();

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
            icon: const Icon(Icons.calendar_today, color: Colors.black87),
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
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat(
                      'yyyy년 MM월 dd일 (E)',
                      'ko_KR',
                    ).format(selectedDate!),
                    style: AppTheme.bodyMediumStyle.copyWith(
                      color: Colors.blue.shade700,
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
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),

          // 검색창
          Container(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: '게시글 제목, 반려동물 이름으로 검색...',
                prefixIcon: const Icon(Icons.search, color: Colors.black),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                suffixIcon:
                    searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                        : null,
              ),
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
                _buildApplicationsList(filteredApplications),
                _buildApplicationsList(filteredCompleted),
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
                  Colors.blue,
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

  Widget _buildApplicationsList(List<DonationApplication> applications) {
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
          return _buildApplicationCard(application);
        },
      ),
    );
  }

  Widget _buildApplicationCard(DonationApplication application) {
    Color statusColor;
    Color statusBackgroundColor;

    switch (application.status) {
      case '대기중':
        statusColor = Colors.orange.shade700;
        statusBackgroundColor = Colors.orange.shade50;
        break;
      case '승인':
        statusColor = Colors.green.shade700;
        statusBackgroundColor = Colors.green.shade50;
        break;
      case '완료':
        statusColor = Colors.blue.shade700;
        statusBackgroundColor = Colors.blue.shade50;
        break;
      default:
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
                    application.status,
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
          ],
        ),
      ),
    );
  }
}

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
  });

  factory DonationApplication.fromJson(Map<String, dynamic> json) {
    return DonationApplication(
      applicationId: json['application_id'] ?? 0,
      postId: json['post_id'] ?? 0,
      postTitle: json['post_title'] ?? '',
      petName: json['pet_name'] ?? '',
      petSpecies: json['pet_species'] ?? '',
      petBloodType: json['pet_blood_type'] ?? '',
      donationTime:
          DateTime.tryParse(json['donation_time'] ?? '') ?? DateTime.now(),
      status: json['status'] ?? '대기중',
      statusCode: json['status_code'] ?? 0,
    );
  }
}
