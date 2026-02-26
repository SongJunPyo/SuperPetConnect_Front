// user/user_donation_applications.dart

import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/app_app_bar.dart';
import '../services/applied_donation_service.dart';
import '../models/applied_donation_model.dart';

class UserDonationApplicationsScreen extends StatefulWidget {
  const UserDonationApplicationsScreen({super.key});

  @override
  State<UserDonationApplicationsScreen> createState() =>
      _UserDonationApplicationsScreenState();
}

class _UserDonationApplicationsScreenState
    extends State<UserDonationApplicationsScreen> {
  List<MyPetApplications> petApplications = [];
  Map<String, dynamic>? userStats;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final applications = await AppliedDonationService.getMyApplications();
      final stats = await AppliedDonationService.getUserDonationStats();

      setState(() {
        petApplications = applications;
        userStats = stats;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = '신청 목록을 불러오는데 실패했습니다: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppSimpleAppBar(title: '내 헌혈 신청'),
      body: RefreshIndicator(onRefresh: _loadApplications, child: _buildBody()),
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

    return Column(
      children: [
        if (userStats != null) _buildStatsHeader(),
        Expanded(
          child:
              petApplications.isEmpty
                  ? _buildEmptyState()
                  : _buildApplicationsList(),
        ),
      ],
    );
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
            onPressed: _loadApplications,
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

  Widget _buildStatsHeader() {
    final stats = userStats!;
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
                  '${stats['totalApplications']}건',
                  AppTheme.primaryBlue,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  '완료된 헌혈',
                  '${stats['completedDonations']}건',
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

  Widget _buildEmptyState() {
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
            child: Icon(Icons.pets, size: 64, color: AppTheme.primaryBlue),
          ),
          const SizedBox(height: 24),
          Text(
            '아직 헌혈 신청이 없습니다',
            style: AppTheme.h3Style.copyWith(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            '헌혈 게시판에서 우리 반려동물이\n도움을 줄 수 있는 기회를 찾아보세요',
            style: AppTheme.bodyMediumStyle.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // 헌혈 게시판으로 이동
              Navigator.pushNamed(context, '/donation_board');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
            ),
            child: const Text('헌혈 게시판 보기'),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      itemCount: petApplications.length,
      itemBuilder: (context, index) {
        final petApps = petApplications[index];
        return _buildPetApplicationsCard(petApps);
      },
    );
  }

  Widget _buildPetApplicationsCard(MyPetApplications petApps) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: AppTheme.lightGray.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(AppTheme.spacing16),
        childrenPadding: const EdgeInsets.only(
          left: AppTheme.spacing16,
          right: AppTheme.spacing16,
          bottom: AppTheme.spacing16,
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.lightBlue.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppTheme.radius8),
          ),
          child: Icon(Icons.pets, color: AppTheme.primaryBlue, size: 28),
        ),
        title: Text(
          petApps.petName,
          style: AppTheme.h4Style.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppTheme.spacing4),
            Text(
              petApps.animalTypeKr,
              style: AppTheme.bodySmallStyle.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Row(
              children: [
                _buildStatusChip(
                  '총 ${petApps.applications.length}건 신청',
                  AppTheme.mediumGray,
                ),
                const SizedBox(width: AppTheme.spacing8),
                if (petApps.activeApplicationsCount > 0)
                  _buildStatusChip(
                    '진행 중 ${petApps.activeApplicationsCount}건',
                    Colors.orange,
                  ),
              ],
            ),
          ],
        ),
        children:
            petApps.applications.map((application) {
              return _buildApplicationItem(application);
            }).toList(),
      ),
    );
  }

  Widget _buildStatusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: AppTheme.spacing4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Text(
        text,
        style: AppTheme.captionStyle.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildApplicationItem(AppliedDonation application) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(
          color: _getStatusColor(application.status),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  application.postTitle ?? '헌혈 요청',
                  style: AppTheme.bodyLargeStyle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing8,
                  vertical: AppTheme.spacing4,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(
                    application.status,
                  ).withValues(alpha: 0.1),
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
            ],
          ),
          const SizedBox(height: AppTheme.spacing8),
          Row(
            children: [
              Icon(
                Icons.local_hospital,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: AppTheme.spacing4),
              Expanded(
                child: Text(
                  application.hospitalName ?? '병원',
                  style: AppTheme.bodySmallStyle.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing4),
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: AppTheme.spacing4),
              Text(
                application.formattedDateTime,
                style: AppTheme.bodySmallStyle.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          if (application.createdAt != null) ...[
            const SizedBox(height: AppTheme.spacing4),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: AppTheme.spacing4),
                Text(
                  '신청일: ${application.formattedCreatedAt}',
                  style: AppTheme.bodySmallStyle.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          if (application.canCancel) ...[
            const SizedBox(height: AppTheme.spacing12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _showCancelConfirmation(application),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('취소하기'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(int status) {
    return AppliedDonationStatus.getStatusColorValue(status);
  }

  void _showCancelConfirmation(AppliedDonation application) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('신청 취소'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('다음 헌혈 신청을 취소하시겠습니까?'),
                const SizedBox(height: 12),
                Text(
                  application.postTitle ?? '헌혈 요청',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${application.hospitalName ?? '병원'} · ${application.formattedDateTime}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _cancelApplication(application);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('신청 취소'),
              ),
            ],
          ),
    );
  }

  Future<void> _cancelApplication(AppliedDonation application) async {
    try {
      await AppliedDonationService.cancelApplication(
        application.appliedDonationIdx!,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('헌혈 신청이 취소되었습니다.')));
      }

      await _loadApplications(); // 목록 새로고침
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('신청 취소 실패: $e')));
      }
    }
  }
}
