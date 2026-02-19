// user/user_donation_history.dart

import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/app_app_bar.dart';
import '../models/completed_donation_model.dart';
import '../services/completed_donation_service.dart';

class UserDonationHistoryScreen extends StatefulWidget {
  const UserDonationHistoryScreen({super.key});

  @override
  State<UserDonationHistoryScreen> createState() =>
      _UserDonationHistoryScreenState();
}

class _UserDonationHistoryScreenState extends State<UserDonationHistoryScreen> {
  List<PetDonationHistory> petHistories = [];
  Map<String, dynamic>? totalStats;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDonationHistory();
  }

  Future<void> _loadDonationHistory() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // 반려동물별 헌혈 이력 조회
      final histories =
          await CompletedDonationService.getMyPetsDonationHistory();

      // 전체 통계 조회
      final stats = await CompletedDonationService.getMyTotalDonationStats();

      setState(() {
        petHistories = histories;
        totalStats = stats;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = '헌혈 이력을 불러오는데 실패했습니다: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppSimpleAppBar(title: '헌혈 이력'),
      body: RefreshIndicator(
        onRefresh: _loadDonationHistory,
        child: _buildBody(),
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

    if (petHistories.isEmpty) {
      return _buildEmptyState();
    }

    return CustomScrollView(
      slivers: [
        // 통계 헤더
        SliverToBoxAdapter(child: _buildStatsHeader()),

        // 반려동물별 헌혈 이력
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final petHistory = petHistories[index];
            return _buildPetHistoryCard(petHistory);
          }, childCount: petHistories.length),
        ),
      ],
    );
  }

  Widget _buildStatsHeader() {
    if (totalStats == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(AppTheme.spacing16),
      padding: const EdgeInsets.all(AppTheme.spacing20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade50, Colors.pink.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(color: Colors.red.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                child: Icon(
                  Icons.bloodtype,
                  color: Colors.red.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Text(
                '나의 헌혈 통계',
                style: AppTheme.h3Style.copyWith(
                  color: Colors.red.shade800,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing16),

          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '등록 반려동물',
                  '${totalStats!['totalPets']}마리',
                  Icons.pets,
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  '참여 반려동물',
                  '${totalStats!['activePetsCount']}마리',
                  Icons.favorite,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),

          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '총 헌혈 횟수',
                  '${totalStats!['totalDonations']}회',
                  Icons.inventory,
                  Colors.orange,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  '총 헌혈량',
                  totalStats!['formattedTotalBloodVolume'],
                  Icons.water_drop,
                  Colors.red,
                ),
              ),
            ],
          ),

          if (totalStats!['firstDonationDate'] != null) ...[
            const SizedBox(height: AppTheme.spacing12),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: Colors.red.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Text(
                    '첫 헌혈: ${_formatDate(totalStats!['firstDonationDate'])}',
                    style: AppTheme.bodySmallStyle.copyWith(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (totalStats!['lastDonationDate'] != null) ...[
                    const SizedBox(width: AppTheme.spacing16),
                    Icon(Icons.event, color: Colors.red.shade600, size: 16),
                    const SizedBox(width: AppTheme.spacing4),
                    Text(
                      '최근: ${_formatDate(totalStats!['lastDonationDate'])}',
                      style: AppTheme.bodySmallStyle.copyWith(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500,
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

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            value,
            style: AppTheme.h4Style.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppTheme.spacing2),
          Text(
            label,
            style: AppTheme.captionStyle.copyWith(
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetHistoryCard(PetDonationHistory petHistory) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        0,
        AppTheme.spacing16,
        AppTheme.spacing16,
      ),
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
        initiallyExpanded: petHistory.totalDonations <= 3,
        tilePadding: const EdgeInsets.all(AppTheme.spacing16),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppTheme.spacing16,
          0,
          AppTheme.spacing16,
          AppTheme.spacing16,
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color:
                petHistory.totalDonations > 0
                    ? Colors.red.shade50
                    : AppTheme.lightGray,
            borderRadius: BorderRadius.circular(AppTheme.radius8),
          ),
          child: Icon(
            Icons.pets,
            color:
                petHistory.totalDonations > 0
                    ? Colors.red.shade600
                    : AppTheme.textSecondary,
            size: 24,
          ),
        ),
        title: Text(
          petHistory.petInfo,
          style: AppTheme.h4Style.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppTheme.spacing4),
            Text(
              petHistory.donationStats,
              style: AppTheme.bodyMediumStyle.copyWith(
                color:
                    petHistory.totalDonations > 0
                        ? Colors.red.shade600
                        : AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (petHistory.totalDonations > 0) ...[
              const SizedBox(height: AppTheme.spacing4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing8,
                      vertical: AppTheme.spacing2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          petHistory.canDonateAgain
                              ? Colors.green.shade50
                              : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                      border: Border.all(
                        color:
                            petHistory.canDonateAgain
                                ? Colors.green.shade200
                                : Colors.orange.shade200,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      petHistory.canDonateAgain ? '헌혈 가능' : '대기 중',
                      style: AppTheme.captionStyle.copyWith(
                        color:
                            petHistory.canDonateAgain
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!petHistory.canDonateAgain &&
                      petHistory.nextAvailableDonationDate != null) ...[
                    const SizedBox(width: AppTheme.spacing8),
                    Text(
                      '${_formatDate(petHistory.nextAvailableDonationDate!)}부터 가능',
                      style: AppTheme.captionStyle.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
        children:
            petHistory.donations.isEmpty
                ? [_buildNoDonationsMessage()]
                : petHistory.donations.map((donation) {
                  return _buildDonationItem(donation);
                }).toList(),
      ),
    );
  }

  Widget _buildNoDonationsMessage() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing20),
      child: Column(
        children: [
          Icon(Icons.info_outline, color: AppTheme.textSecondary, size: 48),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            '아직 헌혈 기록이 없습니다',
            style: AppTheme.bodyMediumStyle.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationItem(CompletedDonation donation) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(color: Colors.red.shade100, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                donation.hospitalName ?? '병원 정보 없음',
                style: AppTheme.bodyMediumStyle.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing8,
                  vertical: AppTheme.spacing2,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                child: Text(
                  donation.formattedBloodVolume,
                  style: AppTheme.captionStyle.copyWith(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (donation.postTitle != null) ...[
            const SizedBox(height: AppTheme.spacing4),
            Text(
              donation.postTitle!,
              style: AppTheme.bodySmallStyle.copyWith(
                color: AppTheme.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppTheme.spacing8),
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: AppTheme.spacing4),
              Text(
                '완료: ${donation.formattedCompletedDateTime}',
                style: AppTheme.captionStyle.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              if (donation.donationTime != null) ...[
                const SizedBox(width: AppTheme.spacing12),
                Icon(Icons.event, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: AppTheme.spacing4),
                Text(
                  '예정: ${donation.formattedDonationTime}',
                  style: AppTheme.captionStyle.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
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
            onPressed: _loadDonationHistory,
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
            child: Icon(Icons.bloodtype, size: 64, color: AppTheme.primaryBlue),
          ),
          const SizedBox(height: 24),
          Text(
            '헌혈 이력이 없습니다',
            style: AppTheme.h3Style.copyWith(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            '반려동물과 함께 헌혈에 참여하여\n생명을 구하는 일에 동참해보세요',
            style: AppTheme.bodyMediumStyle.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
            ),
            child: const Text('헌혈 게시글 보러가기'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.year}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.day.toString().padLeft(2, '0')}';
  }
}
