import 'package:flutter/material.dart';
import '../models/donation_application_model.dart';
import '../models/applied_donation_model.dart';
import '../services/hospital_post_service.dart';
import '../utils/app_theme.dart';
import '../widgets/app_dialog.dart';
import '../widgets/state_view.dart';

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
  String? selectedStatus; // 상태를 String으로 변경

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

      // 임시로 빈 리스트 반환
      final loadedApplications = <DonationApplication>[];

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
          content: RadioGroup<String?>(
            groupValue: selectedStatus,
            onChanged: (value) {
              setState(() {
                selectedStatus = value;
              });
              Navigator.of(context).pop();
              _loadApplications();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String?>(
                  title: const Text('전체'),
                  value: null,
                ),
                ...['대기중', '승인됨', '미승인', '완료됨'].map(
                  (status) => RadioListTile<String?>(
                    title: Text(status),
                    value: status,
                  ),
                ),
              ],
            ),
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
    final confirmed = await AppDialog.confirm(
      context,
      title: '신청 취소',
      message: '${application.pet.name}의 헌혈 신청을 취소하시겠습니까?',
      cancelLabel: '아니오',
      confirmLabel: '취소하기',
      isDestructive: true,
    );

    if (confirmed != true) return;

    try {
      final success = await HospitalPostService.updateApplicantStatus(
        application.appliedDonationIdx,
        2, // 2=미승인/취소
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('신청이 취소되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _loadApplications(); // 목록 새로고침
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('취소 실패: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
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
                Text('종류: ${application.pet.species}'),
                if (application.pet.breed != null)
                  Text('품종: ${application.pet.breed}'),
                if (application.pet.bloodType != null)
                  Text('혈액형: ${application.pet.bloodType}'),
                Text('생년월일: ${application.pet.birthDateWithAge}'),
                Text('체중: ${application.pet.weightKg}kg'),
                const SizedBox(height: 16),
                Text(
                  '상태: ${application.statusKr}',
                  style: TextStyle(
                    color: _getStatusColorFromString(application.statusKr),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text('헌혈 일시: ${_formatDateTime(application.donationTime)}'),
                Text('게시글: ${application.postTitle}'),
              ],
            ),
          ),
          actions: [
            if (application.status == 0) // 0=대기중
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _cancelApplication(application);
                },
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
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

  Color _getStatusColorFromString(String statusKr) {
    switch (statusKr) {
      case '대기중':
      case '대기':
        return AppTheme.warning;
      case '승인됨':
      case '승인':
        return AppTheme.success;
      case '미승인':
        return AppTheme.mediumGray;
      case '완료됨':
      case '완료':
        return AppTheme.primaryBlue;
      default:
        return AppTheme.mediumGray;
    }
  }

  Color _getStatusColor(int status) {
    return AppliedDonationStatus.getStatusColorValue(status);
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '내 신청 내역',
          style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.w700),
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
      body:
          isLoading
              ? const StateView.loading()
              : errorMessage != null
              ? StateView.error(
                  message: errorMessage!,
                  onRetry: _loadApplications,
                )
              : applications.isEmpty
              ? StateView.empty(
                  icon: Icons.volunteer_activism_outlined,
                  message: selectedStatus != null
                      ? '$selectedStatus 상태의 신청이 없습니다'
                      : '신청 내역이 없습니다',
                  subtitle: '헌혈 게시글에서 신청해보세요',
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
                            '필터: $selectedStatus',
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
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
                                            color: _getStatusColor(
                                              application.status,
                                            ).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(
                                              8.0,
                                            ),
                                          ),
                                          child: Text(
                                            application.statusKr,
                                            style: AppTheme.bodySmallStyle
                                                .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: _getStatusColor(
                                                    application.status,
                                                  ),
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
                                        Expanded(
                                          child: Text(
                                            application.pet.summaryLine,
                                            style: AppTheme.bodyMediumStyle,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
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
                                          '헌혈 일시: ${_formatDateTime(application.donationTime)}',
                                          style: AppTheme.bodyMediumStyle,
                                        ),
                                      ],
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
