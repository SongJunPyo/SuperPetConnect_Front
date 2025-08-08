// admin/admin_donation_approval.dart

import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/app_app_bar.dart';
import '../models/applied_donation_model.dart';
import '../models/cancelled_donation_model.dart';
import '../models/completed_donation_model.dart';
import '../services/applied_donation_service.dart';
import '../services/completed_donation_service.dart';
import '../services/cancelled_donation_service.dart';

class AdminDonationApprovalScreen extends StatefulWidget {
  const AdminDonationApprovalScreen({super.key});

  @override
  State<AdminDonationApprovalScreen> createState() => _AdminDonationApprovalScreenState();
}

class _AdminDonationApprovalScreenState extends State<AdminDonationApprovalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AdminPendingDonation> pendingCompletions = [];
  List<AdminPendingDonation> pendingCancellations = [];
  bool isLoadingCompletions = true;
  bool isLoadingCancellations = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPendingApprovals();
  }

  Future<void> _loadPendingApprovals() async {
    setState(() {
      isLoadingCompletions = true;
      isLoadingCancellations = true;
      errorMessage = null;
    });

    try {
      // 완료 대기 목록 조회 (pendingCompletion 상태인 것들)
      final completionApplications = await AppliedDonationService.getApplicationsByStatus(
        AppliedDonationStatus.pendingCompletion
      );
      
      // 취소 대기 목록 조회 (pendingCancellation 상태인 것들)
      final cancellationApplications = await AppliedDonationService.getApplicationsByStatus(
        AppliedDonationStatus.pendingCancellation
      );

      setState(() {
        // AdminPendingDonation 형태로 변환
        pendingCompletions = completionApplications.map((app) => 
          AdminPendingDonation.fromAppliedDonation(app, 'pending_completion')
        ).toList();
        
        pendingCancellations = cancellationApplications.map((app) => 
          AdminPendingDonation.fromAppliedDonation(app, 'pending_cancellation')
        ).toList();
        
        isLoadingCompletions = false;
        isLoadingCancellations = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = '데이터를 불러오는데 실패했습니다: $e';
        isLoadingCompletions = false;
        isLoadingCancellations = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppSimpleAppBar(
        title: '헌혈 승인 관리',
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCompletionApprovalTab(),
                _buildCancellationApprovalTab(),
              ],
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
        controller: _tabController,
        indicatorColor: AppTheme.primaryBlue,
        labelColor: AppTheme.primaryBlue,
        unselectedLabelColor: AppTheme.textSecondary,
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline, size: 18),
                const SizedBox(width: 8),
                Text('완료 승인 (${pendingCompletions.length})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cancel_outlined, size: 18),
                const SizedBox(width: 8),
                Text('취소 승인 (${pendingCancellations.length})'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionApprovalTab() {
    if (isLoadingCompletions) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryBlue),
      );
    }

    if (errorMessage != null) {
      return _buildErrorState();
    }

    if (pendingCompletions.isEmpty) {
      return _buildEmptyState('완료 승인 대기 중인 헌혈이 없습니다');
    }

    return RefreshIndicator(
      onRefresh: _loadPendingApprovals,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        itemCount: pendingCompletions.length,
        itemBuilder: (context, index) {
          final pending = pendingCompletions[index];
          return _buildCompletionApprovalCard(pending);
        },
      ),
    );
  }

  Widget _buildCancellationApprovalTab() {
    if (isLoadingCancellations) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryBlue),
      );
    }

    if (errorMessage != null) {
      return _buildErrorState();
    }

    if (pendingCancellations.isEmpty) {
      return _buildEmptyState('취소 승인 대기 중인 헌혈이 없습니다');
    }

    return RefreshIndicator(
      onRefresh: _loadPendingApprovals,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        itemCount: pendingCancellations.length,
        itemBuilder: (context, index) {
          final pending = pendingCancellations[index];
          return _buildCancellationApprovalCard(pending);
        },
      ),
    );
  }

  Widget _buildCompletionApprovalCard(AdminPendingDonation pending) {
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
          color: Colors.green.shade200,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacing8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '헌혈 완료 승인 요청',
                        style: AppTheme.h4Style.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade800,
                        ),
                      ),
                      Text(
                        '${pending.hospitalName ?? '병원'}에서 완료 처리 요청',
                        style: AppTheme.bodySmallStyle.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing8,
                    vertical: AppTheme.spacing4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                  child: Text(
                    '완료대기',
                    style: AppTheme.captionStyle.copyWith(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacing16),

            // 헌혈 정보
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              decoration: BoxDecoration(
                color: AppTheme.lightGray.withOpacity(0.3),
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.pets, size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: AppTheme.spacing4),
                      Text(
                        pending.petSummary,
                        style: AppTheme.bodyMediumStyle.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  Row(
                    children: [
                      Icon(Icons.article, size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: AppTheme.spacing4),
                      Expanded(
                        child: Text(
                          pending.postTitle ?? '헌혈 요청',
                          style: AppTheme.bodyMediumStyle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (pending.donationTime != null) ...[
                    const SizedBox(height: AppTheme.spacing8),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 16, color: AppTheme.textSecondary),
                        const SizedBox(width: AppTheme.spacing4),
                        Text(
                          '헌혈 시간: ${pending.formattedDonationTime}',
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (pending.bloodVolume != null) ...[
                    const SizedBox(height: AppTheme.spacing8),
                    Row(
                      children: [
                        Icon(Icons.water_drop, size: 16, color: Colors.red.shade600),
                        const SizedBox(width: AppTheme.spacing4),
                        Text(
                          '헌혈량: ${pending.bloodVolume!.toStringAsFixed(1)}mL',
                          style: AppTheme.bodyMediumStyle.copyWith(
                            color: Colors.red.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppTheme.spacing8),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: AppTheme.spacing4),
                      Text(
                        '요청 시간: ${pending.formattedCreatedAt}',
                        style: AppTheme.bodySmallStyle.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacing16),

            // 액션 버튼
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectCompletion(pending),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                      ),
                    ),
                    child: const Text('거부'),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _approveCompletion(pending),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                      ),
                    ),
                    child: const Text('최종 완료'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancellationApprovalCard(AdminPendingDonation pending) {
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
          color: Colors.orange.shade200,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacing8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                  child: Icon(
                    Icons.cancel,
                    color: Colors.orange.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '헌혈 취소 승인 요청',
                        style: AppTheme.h4Style.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      Text(
                        '${pending.hospitalName ?? '병원'}에서 중지 처리 요청',
                        style: AppTheme.bodySmallStyle.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing8,
                    vertical: AppTheme.spacing4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                  child: Text(
                    '취소대기',
                    style: AppTheme.captionStyle.copyWith(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacing16),

            // 취소 사유
            if (pending.cancelledReason != null) ...[
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.report_problem, size: 16, color: Colors.orange.shade700),
                        const SizedBox(width: AppTheme.spacing4),
                        Text(
                          '중지 사유',
                          style: AppTheme.bodyMediumStyle.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    Text(
                      pending.cancelledReason!,
                      style: AppTheme.bodyMediumStyle.copyWith(
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacing12),
            ],

            // 헌혈 정보
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              decoration: BoxDecoration(
                color: AppTheme.lightGray.withOpacity(0.3),
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.pets, size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: AppTheme.spacing4),
                      Text(
                        pending.petSummary,
                        style: AppTheme.bodyMediumStyle.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  Row(
                    children: [
                      Icon(Icons.article, size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: AppTheme.spacing4),
                      Expanded(
                        child: Text(
                          pending.postTitle ?? '헌혈 요청',
                          style: AppTheme.bodyMediumStyle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (pending.donationTime != null) ...[
                    const SizedBox(height: AppTheme.spacing8),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 16, color: AppTheme.textSecondary),
                        const SizedBox(width: AppTheme.spacing4),
                        Text(
                          '헌혈 시간: ${pending.formattedDonationTime}',
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppTheme.spacing8),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: AppTheme.spacing4),
                      Text(
                        '요청 시간: ${pending.formattedCreatedAt}',
                        style: AppTheme.bodySmallStyle.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacing16),

            // 취소 사유 수정 입력 필드
            TextField(
              controller: TextEditingController(text: pending.cancelledReason),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: '취소 사유 (수정 가능)',
                hintText: '관리자가 취소 사유를 수정할 수 있습니다',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                  borderSide: BorderSide(
                    color: AppTheme.primaryBlue,
                    width: 2,
                  ),
                ),
              ),
              onChanged: (value) {
                // 사유 수정 값 저장
                pending.cancelledReason = value;
              },
            ),

            const SizedBox(height: AppTheme.spacing16),

            // 액션 버튼
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectCancellation(pending),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: BorderSide(color: Colors.blue.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                      ),
                    ),
                    child: const Text('거부 (승인상태로)'),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _approveCancellation(pending),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                      ),
                    ),
                    child: const Text('최종 취소'),
                  ),
                ),
              ],
            ),
          ],
        ),
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
            onPressed: _loadPendingApprovals,
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

  Widget _buildEmptyState(String message) {
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
              Icons.inbox,
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
            '승인 요청이 들어오면\n여기에 표시됩니다',
            style: AppTheme.bodyMediumStyle.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _approveCompletion(AdminPendingDonation pending) async {
    try {
      // 실제 완료 처리 API 호출
      final request = CompleteDonationRequest(
        appliedDonationIdx: pending.appliedDonationIdx,
        bloodVolume: pending.bloodVolume!,
        completedAt: pending.completedAt ?? DateTime.now(),
      );

      await CompletedDonationService.completeBloodDonation(request);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('헌혈이 최종 완료되었습니다!'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadPendingApprovals();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('완료 승인 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectCompletion(AdminPendingDonation pending) async {
    try {
      // 상태를 approved로 되돌리기
      await AppliedDonationService.updateApplicationStatus(
        pending.appliedDonationIdx,
        AppliedDonationStatus.approved,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('완료 요청이 거부되어 승인 상태로 돌아갔습니다.'),
          backgroundColor: Colors.orange,
        ),
      );

      await _loadPendingApprovals();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('완료 거부 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _approveCancellation(AdminPendingDonation pending) async {
    try {
      // 실제 취소 처리 API 호출
      final request = CancelDonationRequest(
        appliedDonationIdx: pending.appliedDonationIdx,
        cancelledSubject: CancelledSubject.admin, // 관리자가 최종 취소
        cancelledReason: pending.cancelledReason ?? '관리자 승인',
        cancelledAt: DateTime.now(),
      );

      await CancelledDonationService.cancelBloodDonation(request);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('헌혈이 최종 취소되었습니다.'),
          backgroundColor: Colors.red,
        ),
      );

      await _loadPendingApprovals();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('취소 승인 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectCancellation(AdminPendingDonation pending) async {
    try {
      // 상태를 approved로 되돌리기
      await AppliedDonationService.updateApplicationStatus(
        pending.appliedDonationIdx,
        AppliedDonationStatus.approved,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('취소 요청이 거부되어 승인 상태로 돌아갔습니다.'),
          backgroundColor: Colors.orange,
        ),
      );

      await _loadPendingApprovals();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('취소 거부 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

// AdminPendingDonation 모델에 fromAppliedDonation 팩토리 메서드 추가를 위한 확장
extension AdminPendingDonationExt on AdminPendingDonation {
  static AdminPendingDonation fromAppliedDonation(AppliedDonation application, String status) {
    return AdminPendingDonation(
      appliedDonationIdx: application.appliedDonationIdx!,
      status: status,
      petName: application.pet?.name,
      petBloodType: application.pet?.bloodType,
      petWeight: application.pet?.weightKg,
      postTitle: application.postTitle,
      hospitalName: application.hospitalName,
      userName: application.userName,
      donationTime: application.donationTime,
      createdAt: application.appliedAt,
    );
  }
}