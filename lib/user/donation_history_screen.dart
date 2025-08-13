import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';
import '../utils/config.dart';
import '../widgets/app_app_bar.dart';

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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) {
        throw Exception('로그인이 필요합니다.');
      }

      final response = await http.get(
        Uri.parse('${Config.serverUrl}/api/donation/my-applications'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> applicationsJson = data['applications'] ?? [];
        
        final allApplications = applicationsJson.map((json) => DonationApplication.fromJson(json)).toList();
        
        // 신청 중인 것과 완료된 것 분리
        applications = allApplications.where((app) => app.status != '완료').toList();
        completed = allApplications.where((app) => app.status == '완료').toList();
        
        totalApplications = allApplications.length;
        completedDonations = completed.length;
        
        _applySearchFilter();
      } else {
        throw Exception('데이터를 불러올 수 없습니다.');
      }
    } catch (e) {
      print('헌혈 이력 로드 실패: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _applySearchFilter() {
    if (searchQuery.isEmpty) {
      filteredApplications = applications;
      filteredCompleted = completed;
    } else {
      filteredApplications = applications.where((app) =>
        app.postTitle.toLowerCase().contains(searchQuery.toLowerCase()) ||
        app.petName.toLowerCase().contains(searchQuery.toLowerCase())
      ).toList();
      
      filteredCompleted = completed.where((app) =>
        app.postTitle.toLowerCase().contains(searchQuery.toLowerCase()) ||
        app.petName.toLowerCase().contains(searchQuery.toLowerCase())
      ).toList();
    }
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
            icon: const Icon(Icons.date_range),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('달력 필터 기능 준비 중입니다')),
              );
            },
            tooltip: '날짜 범위 선택',
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
          
          // 검색창
          Container(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: '게시글 제목, 반려동물 이름으로 검색...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.black,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Colors.black,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                suffixIcon: searchQuery.isNotEmpty
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
        color: AppTheme.lightBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: AppTheme.lightBlue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '나의 헌혈 현황',
            style: AppTheme.h4Style.copyWith(
              color: AppTheme.primaryBlue,
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
              Expanded(
                child: Container(), // 빈 공간
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
            Icon(
              Icons.bloodtype,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              '헌혈 내역이 없습니다',
              style: AppTheme.h4Style.copyWith(
                color: Colors.grey.shade500,
              ),
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
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                Icon(Icons.pets, size: 18, color: AppTheme.primaryBlue),
                const SizedBox(width: 6),
                Text(
                  '${application.petName} (${application.petSpecies})',
                  style: AppTheme.bodyMediumStyle.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  DateFormat('yyyy년 MM월 dd일 HH:mm').format(application.donationTime),
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
      donationTime: DateTime.tryParse(json['donation_time'] ?? '') ?? DateTime.now(),
      status: json['status'] ?? '대기중',
      statusCode: json['status_code'] ?? 0,
    );
  }
}