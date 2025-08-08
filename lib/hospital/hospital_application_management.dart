// hospital/hospital_application_management.dart

import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/app_app_bar.dart';
import '../services/applied_donation_service.dart';
import '../services/dashboard_service.dart';
import '../models/applied_donation_model.dart';
import '../models/donation_post_date_model.dart';
import 'donation_completion_dialog.dart';
import 'donation_cancellation_dialog.dart';
import '../models/completed_donation_model.dart';
import '../models/cancelled_donation_model.dart';

class HospitalApplicationManagementScreen extends StatefulWidget {
  const HospitalApplicationManagementScreen({super.key});

  @override
  State<HospitalApplicationManagementScreen> createState() => _HospitalApplicationManagementScreenState();
}

class _HospitalApplicationManagementScreenState extends State<HospitalApplicationManagementScreen>
    with SingleTickerProviderStateMixin {
  List<DonationPost> hospitalPosts = [];
  Map<int, PostApplications> postApplications = {};
  bool isLoading = true;
  String? errorMessage;
  int selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // 병원의 게시글 조회
      final posts = await DashboardService.getPublicPosts(limit: 50);
      
      // 각 게시글의 신청 목록 조회
      final Map<int, PostApplications> applications = {};
      for (final post in posts) {
        try {
          final postApps = await AppliedDonationService.getPostApplications(post.postIdx);
          applications[post.postIdx] = postApps;
        } catch (e) {
          print('게시글 ${post.postIdx} 신청 목록 로드 실패: $e');
        }
      }

      setState(() {
        hospitalPosts = posts;
        postApplications = applications;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = '데이터를 불러오는데 실패했습니다: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppSimpleAppBar(
        title: '헌혈 신청 관리',
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppTheme.lightGray, width: 1),
        ),
      ),
      child: TabBar(
        controller: TabController(length: 3, vsync: this),
        indicatorColor: AppTheme.primaryBlue,
        labelColor: AppTheme.primaryBlue,
        unselectedLabelColor: AppTheme.textSecondary,
        onTap: (index) {
          setState(() {
            selectedTabIndex = index;
          });
        },
        tabs: const [
          Tab(text: '전체'),
          Tab(text: '대기중'),
          Tab(text: '승인완료'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryBlue),
      );
    }

    if (errorMessage != null) {
      return _buildErrorState();
    }

    final filteredPosts = _getFilteredPosts();

    if (filteredPosts.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      itemCount: filteredPosts.length,
      itemBuilder: (context, index) {
        final post = filteredPosts[index];
        final applications = postApplications[post.postIdx];
        return _buildPostCard(post, applications);
      },
    );
  }

  List<DonationPost> _getFilteredPosts() {
    return hospitalPosts.where((post) {
      final apps = postApplications[post.postIdx];
      if (apps == null) return false;

      switch (selectedTabIndex) {
        case 0: // 전체
          return apps.totalApplications > 0;
        case 1: // 대기중
          return apps.pendingCount > 0;
        case 2: // 승인완료
          return apps.approvedCount > 0;
        default:
          return false;
      }
    }).toList();
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            '오류 발생',
            style: AppTheme.h3Style.copyWith(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              errorMessage!,
              style: AppTheme.bodyMediumStyle.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
            ),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    switch (selectedTabIndex) {
      case 1:
        message = '대기 중인 신청이 없습니다';
        break;
      case 2:
        message = '승인된 신청이 없습니다';
        break;
      default:
        message = '아직 헌혈 신청이 없습니다';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.lightBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.assignment,
              size: 64,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: AppTheme.h3Style.copyWith(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            '헌혈 게시글을 작성하여\n반려동물 보호자들의 신청을 받아보세요',
            style: AppTheme.bodyMediumStyle.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(DonationPost post, PostApplications? applications) {
    if (applications == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: AppTheme.lightGray.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 게시글 정보 헤더
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing8,
                        vertical: AppTheme.spacing4,
                      ),
                      decoration: BoxDecoration(
                        color: post.isUrgent ? Colors.red.shade50 : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                        border: Border.all(
                          color: post.isUrgent ? Colors.red.shade200 : Colors.blue.shade200,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        post.typeText,
                        style: AppTheme.captionStyle.copyWith(
                          color: post.isUrgent ? Colors.red.shade700 : Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing8),
                Text(
                  post.title,
                  style: AppTheme.h4Style.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppTheme.spacing8),
                Row(
                  children: [
                    Icon(Icons.pets, size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: AppTheme.spacing4),
                    Text(
                      post.animalTypeText,
                      style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.textSecondary),
                    ),
                    if (post.isUrgent && post.emergencyBloodType != null) ...[
                      const SizedBox(width: AppTheme.spacing16),
                      Icon(Icons.bloodtype, size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: AppTheme.spacing4),
                      Text(
                        post.emergencyBloodType!,
                        style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.textSecondary),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // 신청 현황 요약
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            decoration: BoxDecoration(
              color: AppTheme.lightGray.withOpacity(0.3),
              border: Border(
                top: BorderSide(color: AppTheme.lightGray, width: 1),
                bottom: BorderSide(color: AppTheme.lightGray, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '신청 현황',
                  style: AppTheme.bodyMediumStyle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing8),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatusCount(
                        '전체',
                        applications.totalApplications,
                        AppTheme.primaryBlue,
                      ),
                    ),
                    Expanded(
                      child: _buildStatusCount(
                        '대기중',
                        applications.pendingCount,
                        Colors.orange,
                      ),
                    ),
                    Expanded(
                      child: _buildStatusCount(
                        '승인됨',
                        applications.approvedCount,
                        Colors.green,
                      ),
                    ),
                    Expanded(
                      child: _buildStatusCount(
                        '완료됨',
                        applications.completedCount,
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 신청자 목록 (최대 3명)
          if (applications.applications.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '신청자 목록',
                        style: AppTheme.bodyMediumStyle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (applications.applications.length > 3)
                        TextButton(
                          onPressed: () => _showAllApplications(post, applications),
                          child: Text(
                            '전체보기 (${applications.applications.length})',
                            style: TextStyle(color: AppTheme.primaryBlue),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  ...applications.applications.take(3).map((application) {
                    return _buildApplicationItem(application);
                  }),
                  if (applications.applications.length > 3) ...[
                    const SizedBox(height: AppTheme.spacing8),
                    Center(
                      child: TextButton(
                        onPressed: () => _showAllApplications(post, applications),
                        child: Text(
                          '${applications.applications.length - 3}명 더 보기',
                          style: TextStyle(color: AppTheme.primaryBlue),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCount(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
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

  Widget _buildApplicationItem(AppliedDonation application) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(
          color: _getStatusColor(application.status),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // 반려동물 정보
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.lightBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppTheme.radius8),
            ),
            child: Icon(
              Icons.pets,
              color: AppTheme.primaryBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: AppTheme.spacing12),
          
          // 신청 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  application.pet?.name ?? '반려동물',
                  style: AppTheme.bodyMediumStyle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing4),
                Row(
                  children: [
                    Text(
                      application.pet?.displayInfo ?? '',
                      style: AppTheme.bodySmallStyle.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (application.donationTime != null) ...[
                  const SizedBox(height: AppTheme.spacing4),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: AppTheme.spacing4),
                      Text(
                        application.formattedDateTime,
                        style: AppTheme.captionStyle.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // 상태 및 액션
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing8,
                  vertical: AppTheme.spacing4,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(application.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                child: Text(
                  application.statusText,
                  style: AppTheme.captionStyle.copyWith(
                    color: _getStatusColor(application.status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacing8),
              if (application.status == AppliedDonationStatus.pending)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildActionButton(
                      '거절',
                      Colors.red,
                      () => _updateStatus(application, AppliedDonationStatus.rejected),
                    ),
                    const SizedBox(width: AppTheme.spacing4),
                    _buildActionButton(
                      '승인',
                      Colors.green,
                      () => _updateStatus(application, AppliedDonationStatus.approved),
                    ),
                  ],
                )
              else if (application.status == AppliedDonationStatus.approved)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildActionButton(
                      '중지',
                      Colors.red,
                      () => _showCancellationDialog(application),
                    ),
                    const SizedBox(width: AppTheme.spacing4),
                    _buildActionButton(
                      '1차완료',
                      Colors.blue,
                      () => _showCompletionDialog(application),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, Color color, VoidCallback onPressed) {
    final isComplete = text == '1차완료';
    return SizedBox(
      width: isComplete ? 55 : 45,
      height: 24,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius8),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: isComplete ? 9 : 10),
        ),
      ),
    );
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case AppliedDonationStatus.pending:
        return Colors.orange;
      case AppliedDonationStatus.approved:
        return Colors.green;
      case AppliedDonationStatus.rejected:
        return Colors.red;
      case AppliedDonationStatus.completed:
        return Colors.blue;
      case AppliedDonationStatus.cancelled:
        return Colors.grey;
      case AppliedDonationStatus.pendingCompletion:
        return Colors.lightBlue;
      case AppliedDonationStatus.pendingCancellation:
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _updateStatus(AppliedDonation application, int newStatus) async {
    try {
      await AppliedDonationService.updateApplicationStatus(
        application.appliedDonationIdx!,
        newStatus,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('신청 상태가 변경되었습니다.')),
      );
      
      await _loadData(); // 목록 새로고침
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('상태 변경 실패: $e')),
      );
    }
  }

  void _showCompletionDialog(AppliedDonation application) {
    showDialog(
      context: context,
      builder: (context) => DonationCompletionDialog(
        appliedDonation: application,
        onCompleted: (completedDonation) async {
          // 완료 후 목록 새로고침
          await _loadData();
        },
      ),
    );
  }

  void _showCancellationDialog(AppliedDonation application) {
    showDialog(
      context: context,
      builder: (context) => DonationCancellationDialog(
        appliedDonation: application,
        onCancelled: (cancelledDonation) async {
          // 취소 후 목록 새로고침
          await _loadData();
        },
      ),
    );
  }

  void _showAllApplications(DonationPost post, PostApplications applications) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius16),
        ),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600),
          padding: const EdgeInsets.all(AppTheme.spacing20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '전체 신청자 목록',
                    style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing16),
              Expanded(
                child: ListView.builder(
                  itemCount: applications.applications.length,
                  itemBuilder: (context, index) {
                    final application = applications.applications[index];
                    return _buildApplicationItem(application);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}