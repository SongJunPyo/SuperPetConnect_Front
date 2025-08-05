import 'package:flutter/material.dart';
import '../models/donation_application_model.dart';
import '../services/donation_application_service.dart';
import '../utils/app_theme.dart';

/// 내 헌혈 신청 내역 화면 (사용자용)
class MyApplicationsScreen extends StatefulWidget {
  const MyApplicationsScreen({super.key});

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen> {
  List<DonationApplication> applications = [];
  bool isLoading = true;
  String? errorMessage;
  ApplicationStatus? selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final loadedApplications = await UserApplicationService.getMyApplications(
        status: selectedStatus,
      );

      setState(() {
        applications = loadedApplications;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('상태 필터'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ApplicationStatus?>(
                title: const Text('전체'),
                value: null,
                groupValue: selectedStatus,
                onChanged: (value) {
                  setState(() {
                    selectedStatus = value;
                  });
                  Navigator.of(context).pop();
                  _loadApplications();
                },
              ),
              ...ApplicationStatus.values.map((status) => RadioListTile<ApplicationStatus?>(
                    title: Text(status.displayName),
                    value: status,
                    groupValue: selectedStatus,
                    onChanged: (value) {
                      setState(() {
                        selectedStatus = value;
                      });
                      Navigator.of(context).pop();
                      _loadApplications();
                    },
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _cancelApplication(DonationApplication application) async {
    // 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('신청 취소'),
          content: Text('${application.pet.name}의 헌혈 신청을 취소하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('아니오'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.error,
              ),
              child: const Text('취소하기'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final success = await UserApplicationService.cancelApplication(
        application.postId,
        application.applicationId,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('신청이 취소되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadApplications(); // 목록 새로고침
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('취소 실패: ${e.toString()}'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _showApplicationDetail(DonationApplication application) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('신청 상세 정보'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '반려동물: ${application.pet.name}',
                  style: AppTheme.bodyLargeStyle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text('종류: ${application.pet.speciesKorean}'),
                Text('나이: ${application.pet.age}'),
                Text('체중: ${application.pet.weightKg}kg'),
                if (application.pet.bloodType != null)
                  Text('혈액형: ${application.pet.bloodType}'),
                const SizedBox(height: 16),
                Text(
                  '상태: ${application.status.displayName}',
                  style: TextStyle(
                    color: _getStatusColor(application.status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text('신청일: ${_formatDate(application.appliedDate)}'),
                if (application.updatedDate != null)
                  Text('업데이트: ${_formatDate(application.updatedDate!)}'),
                if (application.hospitalNotes != null && application.hospitalNotes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '병원 메모: ${application.hospitalNotes}',
                      style: AppTheme.bodyMediumStyle.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            if (application.status == ApplicationStatus.pending)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _cancelApplication(application);
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.error,
                ),
                child: const Text('신청 취소'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }

  Color _getStatusColor(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.pending:
        return AppTheme.warning;
      case ApplicationStatus.approved:
        return AppTheme.success;
      case ApplicationStatus.rejected:
        return AppTheme.error;
      case ApplicationStatus.completed:
        return AppTheme.primaryBlue;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '내 신청 내역',
          style: AppTheme.h3Style.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadApplications,
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryBlue,
              ),
            )
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppTheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '오류가 발생했습니다',
                        style: AppTheme.h4Style,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        errorMessage!,
                        style: AppTheme.bodyMediumStyle,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadApplications,
                        icon: const Icon(Icons.refresh),
                        label: const Text('다시 시도'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : applications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.volunteer_activism_outlined,
                            size: 64,
                            color: AppTheme.mediumGray,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            selectedStatus != null
                                ? '${selectedStatus!.displayName} 상태의 신청이 없습니다'
                                : '신청 내역이 없습니다',
                            style: AppTheme.h4Style,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '헌혈 게시글에서 신청해보세요',
                            style: AppTheme.bodyMediumStyle,
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // 필터 상태 표시
                        if (selectedStatus != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16.0),
                            color: AppTheme.lightGray,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.filter_list,
                                  size: 20,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '필터: ${selectedStatus!.displayName}',
                                  style: AppTheme.bodyMediumStyle.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      selectedStatus = null;
                                    });
                                    _loadApplications();
                                  },
                                  child: const Text('필터 해제'),
                                ),
                              ],
                            ),
                          ),

                        // 신청 목록
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _loadApplications,
                            color: AppTheme.primaryBlue,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20.0,
                                vertical: 16.0,
                              ),
                              itemCount: applications.length,
                              itemBuilder: (context, index) {
                                final application = applications[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12.0),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => _showApplicationDetail(application),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  application.pet.name,
                                                  style: AppTheme.h4Style.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8.0,
                                                  vertical: 4.0,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _getStatusColor(application.status)
                                                      .withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(8.0),
                                                ),
                                                child: Text(
                                                  application.status.displayName,
                                                  style: AppTheme.bodySmallStyle.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color: _getStatusColor(application.status),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.pets_outlined,
                                                size: 16,
                                                color: AppTheme.textTertiary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${application.pet.speciesKorean} • ${application.pet.age}',
                                                style: AppTheme.bodyMediumStyle,
                                              ),
                                              if (application.pet.bloodType != null) ...[
                                                const SizedBox(width: 8),
                                                Text(
                                                  application.pet.bloodType!,
                                                  style: AppTheme.bodyMediumStyle.copyWith(
                                                    color: AppTheme.primaryBlue,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.date_range_outlined,
                                                size: 16,
                                                color: AppTheme.textTertiary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '신청일: ${_formatDate(application.appliedDate)}',
                                                style: AppTheme.bodyMediumStyle,
                                              ),
                                            ],
                                          ),
                                          if (application.donationCount > 0)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4.0),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.volunteer_activism_outlined,
                                                    size: 16,
                                                    color: AppTheme.textTertiary,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '총 헌혈 횟수: ${application.donationCount}회',
                                                    style: AppTheme.bodyMediumStyle.copyWith(
                                                      color: AppTheme.success,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}