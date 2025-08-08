// hospital/hospital_datetime_management.dart

import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/app_app_bar.dart';
import '../services/donation_date_service.dart';
import '../services/donation_time_service.dart';
import '../models/donation_post_date_model.dart';
import '../models/donation_post_time_model.dart';
import '../services/dashboard_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HospitalDateTimeManagementScreen extends StatefulWidget {
  const HospitalDateTimeManagementScreen({super.key});

  @override
  State<HospitalDateTimeManagementScreen> createState() => _HospitalDateTimeManagementScreenState();
}

class _HospitalDateTimeManagementScreenState extends State<HospitalDateTimeManagementScreen> {
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
      // 병원의 게시글만 조회
      final posts = await DashboardService.getPublicPosts(limit: 50);
      
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
        title: '헌혈 날짜/시간 관리',
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDateTimeManagementDialog(post),
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
                        color: _getStatusColor(post.statusText).withOpacity(0.1),
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
                    color: AppTheme.lightBlue.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: AppTheme.primaryBlue),
                      const SizedBox(width: AppTheme.spacing8),
                      Expanded(
                        child: Text(
                          '헌혈 날짜/시간 관리하기',
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

  void _showDateTimeManagementDialog(DonationPost post) {
    showDialog(
      context: context,
      builder: (context) => DateTimeManagementDialog(
        post: post,
        onUpdated: _loadHospitalPosts,
      ),
    );
  }
}

class DateTimeManagementDialog extends StatefulWidget {
  final DonationPost post;
  final VoidCallback onUpdated;

  const DateTimeManagementDialog({
    super.key,
    required this.post,
    required this.onUpdated,
  });

  @override
  State<DateTimeManagementDialog> createState() => _DateTimeManagementDialogState();
}

class _DateTimeManagementDialogState extends State<DateTimeManagementDialog> {
  List<DonationDateWithTimes> datesWithTimes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDatesWithTimes();
  }

  Future<void> _loadDatesWithTimes() async {
    setState(() {
      isLoading = true;
    });

    try {
      final data = await DonationTimeService.getPostDatesWithTimes(widget.post.postIdx);
      setState(() {
        datesWithTimes = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('날짜/시간 정보를 불러오는데 실패했습니다: $e')),
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
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 500),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing20),
              decoration: BoxDecoration(
                color: AppTheme.lightBlue.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.radius16),
                  topRight: Radius.circular(AppTheme.radius16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '헌혈 날짜/시간 관리',
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
            ),
            
            // 액션 버튼들
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showAddDateTimeDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('날짜+시간 추가'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radius8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  ElevatedButton.icon(
                    onPressed: _showQuickTemplateDialog,
                    icon: const Icon(Icons.template_outlined, size: 18),
                    label: const Text('템플릿'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryBlue,
                      side: BorderSide(color: AppTheme.primaryBlue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(height: 1),
            
            // 날짜/시간 목록
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue))
                  : datesWithTimes.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.schedule, size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  '설정된 헌혈 날짜/시간이 없습니다',
                                  style: AppTheme.bodyLargeStyle.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '위의 버튼을 눌러 날짜와 시간을 추가해주세요',
                                  style: AppTheme.bodyMediumStyle.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(AppTheme.spacing16),
                          itemCount: datesWithTimes.length,
                          itemBuilder: (context, index) {
                            final dateWithTimes = datesWithTimes[index];
                            return _buildDateWithTimesCard(dateWithTimes);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateWithTimesCard(DonationDateWithTimes dateWithTimes) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: AppTheme.lightBlue.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.lightBlue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.date_range, color: AppTheme.primaryBlue, size: 20),
        ),
        title: Text(
          dateWithTimes.formattedDate,
          style: AppTheme.bodyLargeStyle.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          dateWithTimes.timeSummary,
          style: AppTheme.bodySmallStyle.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'add_time') {
              _showAddTimeDialog(dateWithTimes);
            } else if (value == 'delete_date') {
              _deleteDate(dateWithTimes);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'add_time',
              child: Row(
                children: [
                  Icon(Icons.add_circle_outline, size: 18),
                  SizedBox(width: 8),
                  Text('시간 추가'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete_date',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('날짜 삭제', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Column(
              children: [
                if (dateWithTimes.times.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          '설정된 시간이 없습니다',
                          style: AppTheme.bodyMediumStyle.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...dateWithTimes.sortedTimes.map((time) {
                    return _buildTimeItem(time, dateWithTimes);
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeItem(DonationPostTime time, DonationDateWithTimes parent) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing8,
      ),
      decoration: BoxDecoration(
        color: AppTheme.lightBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(color: AppTheme.lightBlue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time, size: 16, color: AppTheme.primaryBlue),
          const SizedBox(width: AppTheme.spacing8),
          Text(
            time.formatted12Hour,
            style: AppTheme.bodyMediumStyle.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              IconButton(
                onPressed: () => _editTime(time, parent),
                icon: const Icon(Icons.edit, size: 16),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                visualDensity: VisualDensity.compact,
                tooltip: '시간 수정',
              ),
              IconButton(
                onPressed: () => _deleteTime(time, parent),
                icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                visualDensity: VisualDensity.compact,
                tooltip: '시간 삭제',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 날짜+시간 추가 다이얼로그
  void _showAddDateTimeDialog() {
    showDialog(
      context: context,
      builder: (context) => AddDateTimeDialog(
        postIdx: widget.post.postIdx,
        onAdded: () {
          _loadDatesWithTimes();
          widget.onUpdated();
        },
      ),
    );
  }

  // 기존 날짜에 시간 추가
  void _showAddTimeDialog(DonationDateWithTimes dateWithTimes) {
    showDialog(
      context: context,
      builder: (context) => AddTimeDialog(
        dateWithTimes: dateWithTimes,
        onAdded: () {
          _loadDatesWithTimes();
          widget.onUpdated();
        },
      ),
    );
  }

  // 템플릿 선택 다이얼로그
  void _showQuickTemplateDialog() {
    showDialog(
      context: context,
      builder: (context) => TimeTemplateDialog(
        postIdx: widget.post.postIdx,
        onApplied: () {
          _loadDatesWithTimes();
          widget.onUpdated();
        },
      ),
    );
  }

  // 시간 수정
  Future<void> _editTime(DonationPostTime time, DonationDateWithTimes parent) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(time.donationTime),
    );

    if (pickedTime != null && mounted) {
      final DateTime newDateTime = DateTime(
        parent.donationDate.year,
        parent.donationDate.month,
        parent.donationDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );

      try {
        await DonationTimeService.updateDonationTime(time.postTimesId!, newDateTime);
        await _loadDatesWithTimes();
        widget.onUpdated();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('헌혈 시간이 수정되었습니다.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('헌혈 시간 수정 실패: $e')),
          );
        }
      }
    }
  }

  // 시간 삭제
  Future<void> _deleteTime(DonationPostTime time, DonationDateWithTimes parent) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('시간 삭제'),
        content: Text('${time.formatted12Hour} 시간을 삭제하시겠습니까?'),
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
        await DonationTimeService.deleteDonationTime(time.postTimesId!);
        await _loadDatesWithTimes();
        widget.onUpdated();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('헌혈 시간이 삭제되었습니다.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('헌혈 시간 삭제 실패: $e')),
          );
        }
      }
    }
  }

  // 날짜 전체 삭제
  Future<void> _deleteDate(DonationDateWithTimes dateWithTimes) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('날짜 삭제'),
        content: Text('${dateWithTimes.formattedDate}의 모든 시간을 삭제하시겠습니까?'),
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
        // 모든 시간 삭제
        for (final time in dateWithTimes.times) {
          await DonationTimeService.deleteDonationTime(time.postTimesId!);
        }
        // 날짜 삭제
        await DonationDateService.deleteDonationDate(dateWithTimes.postDatesId);
        
        await _loadDatesWithTimes();
        widget.onUpdated();
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

// 새 날짜+시간 추가 다이얼로그는 별도 파일로 분리하는 것이 좋지만,
// 여기서는 간단하게 구현
class AddDateTimeDialog extends StatefulWidget {
  final int postIdx;
  final VoidCallback onAdded;

  const AddDateTimeDialog({
    super.key,
    required this.postIdx,
    required this.onAdded,
  });

  @override
  State<AddDateTimeDialog> createState() => _AddDateTimeDialogState();
}

class _AddDateTimeDialogState extends State<AddDateTimeDialog> {
  DateTime? selectedDate;
  List<TimeOfDay> selectedTimes = [];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('날짜+시간 추가'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 날짜 선택
          ListTile(
            leading: const Icon(Icons.date_range),
            title: Text(selectedDate != null 
                ? '${selectedDate!.year}년 ${selectedDate!.month}월 ${selectedDate!.day}일'
                : '날짜 선택'),
            onTap: _selectDate,
          ),
          const Divider(),
          // 시간 선택
          const Text('시간 선택', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (selectedTimes.isEmpty)
            const Text('선택된 시간이 없습니다', style: TextStyle(color: Colors.grey))
          else
            Wrap(
              children: selectedTimes.map((time) {
                return Chip(
                  label: Text('${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'),
                  onDeleted: () {
                    setState(() {
                      selectedTimes.remove(time);
                    });
                  },
                );
              }).toList(),
            ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _addTime,
            icon: const Icon(Icons.add),
            label: const Text('시간 추가'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: selectedDate != null && selectedTimes.isNotEmpty ? _save : null,
          child: const Text('저장'),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _addTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );

    if (picked != null && !selectedTimes.contains(picked)) {
      setState(() {
        selectedTimes.add(picked);
        selectedTimes.sort((a, b) {
          final aMinutes = a.hour * 60 + a.minute;
          final bMinutes = b.hour * 60 + b.minute;
          return aMinutes.compareTo(bMinutes);
        });
      });
    }
  }

  Future<void> _save() async {
    if (selectedDate == null || selectedTimes.isEmpty) return;

    try {
      final donationTimes = selectedTimes.map((time) {
        return DateTime(
          selectedDate!.year,
          selectedDate!.month,
          selectedDate!.day,
          time.hour,
          time.minute,
        );
      }).toList();

      await DonationTimeService.createDateWithTimes(
        widget.postIdx,
        selectedDate!,
        donationTimes,
      );

      widget.onAdded();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('헌혈 날짜와 시간이 추가되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('추가 실패: $e')),
        );
      }
    }
  }
}

// 기존 날짜에 시간만 추가하는 다이얼로그
class AddTimeDialog extends StatefulWidget {
  final DonationDateWithTimes dateWithTimes;
  final VoidCallback onAdded;

  const AddTimeDialog({
    super.key,
    required this.dateWithTimes,
    required this.onAdded,
  });

  @override
  State<AddTimeDialog> createState() => _AddTimeDialogState();
}

class _AddTimeDialogState extends State<AddTimeDialog> {
  List<TimeOfDay> selectedTimes = [];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.dateWithTimes.formattedDate}에 시간 추가'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selectedTimes.isEmpty)
            const Text('추가할 시간을 선택하세요', style: TextStyle(color: Colors.grey))
          else
            Wrap(
              children: selectedTimes.map((time) {
                return Chip(
                  label: Text('${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'),
                  onDeleted: () {
                    setState(() {
                      selectedTimes.remove(time);
                    });
                  },
                );
              }).toList(),
            ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _addTime,
            icon: const Icon(Icons.add),
            label: const Text('시간 추가'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: selectedTimes.isNotEmpty ? _save : null,
          child: const Text('저장'),
        ),
      ],
    );
  }

  Future<void> _addTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );

    if (picked != null && !selectedTimes.contains(picked)) {
      setState(() {
        selectedTimes.add(picked);
        selectedTimes.sort((a, b) {
          final aMinutes = a.hour * 60 + a.minute;
          final bMinutes = b.hour * 60 + b.minute;
          return aMinutes.compareTo(bMinutes);
        });
      });
    }
  }

  Future<void> _save() async {
    if (selectedTimes.isEmpty) return;

    try {
      final donationTimes = selectedTimes.map((time) {
        return DateTime(
          widget.dateWithTimes.donationDate.year,
          widget.dateWithTimes.donationDate.month,
          widget.dateWithTimes.donationDate.day,
          time.hour,
          time.minute,
        );
      }).toList();

      await DonationTimeService.addMultipleDonationTimes(
        widget.dateWithTimes.postDatesId,
        donationTimes,
      );

      widget.onAdded();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('헌혈 시간이 추가되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('시간 추가 실패: $e')),
        );
      }
    }
  }
}

// 시간 템플릿 선택 다이얼로그 
class TimeTemplateDialog extends StatelessWidget {
  final int postIdx;
  final VoidCallback onApplied;

  const TimeTemplateDialog({
    super.key,
    required this.postIdx,
    required this.onApplied,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('시간 템플릿'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.business_center),
            title: const Text('일반 진료 시간'),
            subtitle: const Text('오전 9시 - 오후 6시 (1시간 간격)'),
            onTap: () => _applyTemplate(context, 'business'),
          ),
          ListTile(
            leading: const Icon(Icons.wb_sunny),
            title: const Text('오전만'),
            subtitle: const Text('오전 9시 - 오후 12시 (1시간 간격)'),
            onTap: () => _applyTemplate(context, 'morning'),
          ),
          ListTile(
            leading: const Icon(Icons.wb_twilight),
            title: const Text('오후만'),
            subtitle: const Text('오후 2시 - 오후 5시 (1시간 간격)'),
            onTap: () => _applyTemplate(context, 'afternoon'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
      ],
    );
  }

  Future<void> _applyTemplate(BuildContext context, String template) async {
    // 먼저 날짜 선택
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (selectedDate == null || !context.mounted) return;

    try {
      List<DateTime> times;
      switch (template) {
        case 'business':
          times = DonationTimeService.getCommonHospitalHours(selectedDate);
          break;
        case 'morning':
          times = DonationTimeService.getMorningHours(selectedDate);
          break;
        case 'afternoon':
          times = DonationTimeService.getAfternoonHours(selectedDate);
          break;
        default:
          times = [];
      }

      if (times.isNotEmpty) {
        await DonationTimeService.createDateWithTimes(postIdx, selectedDate, times);
        onApplied();
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${times.length}개의 시간이 추가되었습니다.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('템플릿 적용 실패: $e')),
        );
      }
    }
  }
}