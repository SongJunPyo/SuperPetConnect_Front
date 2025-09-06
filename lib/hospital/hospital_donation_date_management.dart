// hospital/hospital_donation_date_management.dart

import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/app_app_bar.dart';
import '../services/donation_date_service.dart';
import '../models/donation_post_date_model.dart';
import '../services/dashboard_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HospitalDonationDateManagementScreen extends StatefulWidget {
  const HospitalDonationDateManagementScreen({super.key});

  @override
  State<HospitalDonationDateManagementScreen> createState() => _HospitalDonationDateManagementScreenState();
}

class _HospitalDonationDateManagementScreenState extends State<HospitalDonationDateManagementScreen> {
  List<DonationPost> hospitalPosts = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHospitalPosts();
  }

  Future<void> _loadHospitalPosts() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // 병원의 게시글만 조회 (실제로는 서버에서 현재 로그인한 병원의 게시글만 반환해야 함)
      final posts = await DashboardService.getPublicPosts(limit: 50);
      
      // 여기서는 임시로 모든 게시글을 가져오지만, 실제로는 현재 병원의 게시글만 필터링해야 함
      final prefs = await SharedPreferences.getInstance();
      final hospitalName = prefs.getString('hospital_name') ?? '';
      
      final filteredPosts = posts.where((post) => 
        hospitalName.isNotEmpty && post.hospitalName.contains(hospitalName)
      ).toList();

      setState(() {
        hospitalPosts = filteredPosts;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = '게시글을 불러오는데 실패했습니다: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppSimpleAppBar(
        title: '헌혈 날짜 관리',
      ),
      body: RefreshIndicator(
        onRefresh: _loadHospitalPosts,
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
              onPressed: _loadHospitalPosts,
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

    if (hospitalPosts.isEmpty) {
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
                Icons.article_outlined,
                size: 64,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '등록된 게시글이 없습니다',
              style: AppTheme.h3Style.copyWith(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              '헌혈 게시글을 먼저 작성해주세요',
              style: AppTheme.bodyMediumStyle.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      itemCount: hospitalPosts.length,
      itemBuilder: (context, index) {
        final post = hospitalPosts[index];
        return _buildPostCard(post);
      },
    );
  }

  Widget _buildPostCard(DonationPost post) {
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDateManagementDialog(post),
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          child: Padding(
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
                    const SizedBox(width: AppTheme.spacing8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing8,
                        vertical: AppTheme.spacing4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(post.statusText).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                      ),
                      child: Text(
                        post.statusText,
                        style: AppTheme.captionStyle.copyWith(
                          color: _getStatusColor(post.statusText),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing12),
                Text(
                  post.title,
                  style: AppTheme.h4Style.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppTheme.spacing8),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: AppTheme.spacing4),
                    Expanded(
                      child: Text(
                        post.location,
                        style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing4),
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
                const SizedBox(height: AppTheme.spacing12),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacing12),
                  decoration: BoxDecoration(
                    color: AppTheme.lightBlue.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.date_range, size: 16, color: AppTheme.primaryBlue),
                      const SizedBox(width: AppTheme.spacing8),
                      Expanded(
                        child: Text(
                          post.donationDates?.isEmpty ?? true
                              ? '헌혈 날짜가 설정되지 않았습니다'
                              : '${post.donationDates!.length}개의 헌혈 날짜 설정됨',
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.primaryBlue),
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

  Color _getStatusColor(String status) {
    switch (status) {
      case '승인':
        return AppTheme.success;
      case '대기':
        return AppTheme.warning;
      case '거절':
        return AppTheme.error;
      case '마감':
        return AppTheme.mediumGray;
      default:
        return AppTheme.textPrimary;
    }
  }

  void _showDateManagementDialog(DonationPost post) {
    showDialog(
      context: context,
      builder: (context) => DonationDateManagementDialog(
        post: post,
        onDatesUpdated: _loadHospitalPosts, // 날짜 수정 후 목록 새로고침
      ),
    );
  }
}

class DonationDateManagementDialog extends StatefulWidget {
  final DonationPost post;
  final VoidCallback onDatesUpdated;

  const DonationDateManagementDialog({
    super.key,
    required this.post,
    required this.onDatesUpdated,
  });

  @override
  State<DonationDateManagementDialog> createState() => _DonationDateManagementDialogState();
}

class _DonationDateManagementDialogState extends State<DonationDateManagementDialog> {
  List<DonationPostDate> donationDates = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDonationDates();
  }

  Future<void> _loadDonationDates() async {
    setState(() {
      isLoading = true;
    });

    try {
      final dates = await DonationDateService.getDonationDatesByPostIdx(widget.post.postIdx);
      setState(() {
        donationDates = dates;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('헌혈 날짜를 불러오는데 실패했습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
        padding: const EdgeInsets.all(AppTheme.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 제목
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '헌혈 날짜 관리',
                        style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.post.title,
                        style: AppTheme.bodyMediumStyle.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing20),
            
            // 날짜 추가 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addNewDate,
                icon: const Icon(Icons.add),
                label: const Text('새 헌혈 날짜 추가'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
            
            // 헌혈 날짜 목록
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue))
                  : donationDates.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.date_range_outlined, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                '설정된 헌혈 날짜가 없습니다',
                                style: AppTheme.bodyMediumStyle.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: donationDates.length,
                          itemBuilder: (context, index) {
                            final date = donationDates[index];
                            return _buildDateItem(date, index);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateItem(DonationPostDate date, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: AppTheme.lightBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(color: AppTheme.lightBlue),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 20, color: AppTheme.primaryBlue),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date.dateOnly,
                  style: AppTheme.bodyMediumStyle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  date.timeOnly,
                  style: AppTheme.bodySmallStyle.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _editDate(date);
              } else if (value == 'delete') {
                _deleteDate(date);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18),
                    SizedBox(width: 8),
                    Text('수정'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('삭제', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.more_vert, size: 20, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addNewDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 9, minute: 0),
      );

      if (pickedTime != null && mounted) {
        final DateTime fullDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        try {
          await DonationDateService.addDonationDate(widget.post.postIdx, fullDateTime);
          await _loadDonationDates();
          widget.onDatesUpdated();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('헌혈 날짜가 추가되었습니다.')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('헌혈 날짜 추가 실패: $e')),
            );
          }
        }
      }
    }
  }

  Future<void> _editDate(DonationPostDate date) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: date.donationDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(date.donationDate),
      );

      if (pickedTime != null && mounted) {
        final DateTime fullDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        try {
          await DonationDateService.updateDonationDate(date.postDatesId!, fullDateTime);
          await _loadDonationDates();
          widget.onDatesUpdated();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('헌혈 날짜가 수정되었습니다.')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('헌혈 날짜 수정 실패: $e')),
            );
          }
        }
      }
    }
  }

  Future<void> _deleteDate(DonationPostDate date) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('헌혈 날짜 삭제'),
        content: Text('${date.formattedDate} 헌혈 날짜를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await DonationDateService.deleteDonationDate(date.postDatesId!);
        await _loadDonationDates();
        widget.onDatesUpdated();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('헌혈 날짜가 삭제되었습니다.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('헌혈 날짜 삭제 실패: $e')),
          );
        }
      }
    }
  }
}