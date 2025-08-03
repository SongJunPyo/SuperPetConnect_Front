import 'package:flutter/material.dart';
import '../models/hospital_post_model.dart';
import '../services/hospital_post_service.dart';
import '../utils/app_theme.dart';

class HospitalPostCheck extends StatefulWidget {
  const HospitalPostCheck({super.key});

  @override
  _HospitalPostCheckState createState() => _HospitalPostCheckState();
}

class _HospitalPostCheckState extends State<HospitalPostCheck> {
  List<HospitalPost> posts = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final loadedPosts = await HospitalPostService.getHospitalPosts();
      setState(() {
        posts = loadedPosts;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "나의 모집글 현황",
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
            icon: const Icon(Icons.refresh),
            onPressed: _loadPosts,
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
                        onPressed: _loadPosts,
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
              : posts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.post_add_outlined,
                            size: 64,
                            color: AppTheme.mediumGray,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '등록된 게시글이 없습니다',
                            style: AppTheme.h4Style,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '새로운 헌혈 게시글을 작성해보세요',
                            style: AppTheme.bodyMediumStyle,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadPosts,
                      color: AppTheme.primaryBlue,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                          vertical: 16.0,
                        ),
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          final post = posts[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12.0),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PostDetailScreen(post: post),
                                  ),
                                );
                              },
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
                                            post.title,
                                            style: AppTheme.h4Style.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8.0,
                                            vertical: 4.0,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(
                                              post.status,
                                            ).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(8.0),
                                          ),
                                          child: Text(
                                            post.status,
                                            style: AppTheme.bodySmallStyle.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: _getStatusColor(post.status),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // 긴급 여부 태그
                                    if (post.isUrgent)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8.0),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8.0,
                                            vertical: 4.0,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.error.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8.0),
                                          ),
                                          child: Text(
                                            '긴급',
                                            style: AppTheme.bodySmallStyle.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.error,
                                            ),
                                          ),
                                        ),
                                      ),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today_outlined,
                                          size: 16,
                                          color: AppTheme.textTertiary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          post.date,
                                          style: AppTheme.bodyMediumStyle,
                                        ),
                                        if (post.timeRanges.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            post.timeRanges.first.time,
                                            style: AppTheme.bodyMediumStyle,
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on_outlined,
                                          size: 16,
                                          color: AppTheme.textTertiary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          post.location,
                                          style: AppTheme.bodyMediumStyle,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.people_outline,
                                          size: 16,
                                          color: AppTheme.textTertiary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '신청자 ${post.applicantCount}명',
                                          style: AppTheme.bodyMediumStyle.copyWith(
                                            color: AppTheme.primaryBlue,
                                            fontWeight: FontWeight.w500,
                                          ),
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
    );
  }

  // 상태에 따른 색상 반환 함수
  Color _getStatusColor(String status) {
    switch (status) {
      case '모집중':
      case '모집 중':
        return AppTheme.primaryBlue;
      case '모집마감':
      case '모집 마감':
        return AppTheme.mediumGray;
      case '대기':
        return AppTheme.warning;
      case '거절':
        return AppTheme.error;
      default:
        return AppTheme.textPrimary;
    }
  }
}

class PostDetailScreen extends StatefulWidget {
  final HospitalPost post;

  const PostDetailScreen({super.key, required this.post});

  @override
  _PostDetailScreenState createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  List<DonationApplicant> applicants = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadApplicants();
  }

  Future<void> _loadApplicants() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final loadedApplicants = await HospitalPostService.getApplicants(widget.post.id);
      setState(() {
        applicants = loadedApplicants;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _updateApplicantStatus(DonationApplicant applicant, String status) async {
    try {
      final success = await HospitalPostService.updateApplicantStatus(
        widget.post.id,
        applicant.id,
        status,
      );
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${applicant.name}님의 신청을 $status했습니다.')),
        );
        _loadApplicants(); // 목록 새로고침
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류가 발생했습니다: ${e.toString()}'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "모집글 상세",
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
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == '모집마감' || value == '모집 마감') {
                try {
                  final success = await HospitalPostService.updatePostStatus(
                    widget.post.id,
                    value,
                  );
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('게시글이 $value 처리되었습니다.')),
                    );
                    Navigator.pop(context);
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('오류가 발생했습니다: ${e.toString()}'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: '모집마감',
                child: Text('모집 마감하기'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 게시물 정보 섹션
          Card(
            margin: const EdgeInsets.all(20.0),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.post.title,
                          style: AppTheme.h3Style.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10.0,
                          vertical: 6.0,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            widget.post.status,
                          ).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Text(
                          widget.post.status,
                          style: AppTheme.bodyLargeStyle.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(widget.post.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (widget.post.isUrgent)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10.0,
                          vertical: 6.0,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Text(
                          '긴급',
                          style: AppTheme.bodyLargeStyle.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.error,
                          ),
                        ),
                      ),
                    ),
                  _buildDetailRow(
                    context,
                    Icons.calendar_today_outlined,
                    '날짜',
                    widget.post.date,
                  ),
                  _buildDetailRow(
                    context,
                    Icons.location_on_outlined,
                    '장소',
                    widget.post.location,
                  ),
                  if (widget.post.bloodType != null)
                    _buildDetailRow(
                      context,
                      Icons.bloodtype_outlined,
                      '혈액형',
                      widget.post.bloodType!,
                    ),
                  _buildDetailRow(
                    context,
                    Icons.access_time_outlined,
                    '시간대',
                    widget.post.timeRanges.map((t) => '${t.time} (${t.team}팀)').join(', '),
                  ),
                  if (widget.post.description != null && widget.post.description!.isNotEmpty)
                    _buildDetailRow(
                      context,
                      Icons.description_outlined,
                      '설명',
                      widget.post.description!,
                    ),
                ],
              ),
            ),
          ),

          // 신청자 목록 제목
          Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '신청자 목록',
                  style: AppTheme.h3Style,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadApplicants,
                ),
              ],
            ),
          ),

          // 신청자 목록
          Expanded(
            child: isLoading
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
                              size: 48,
                              color: AppTheme.error,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              errorMessage!,
                              style: AppTheme.bodyMediumStyle,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadApplicants,
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
                    : applicants.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 48,
                                  color: AppTheme.mediumGray,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '아직 신청자가 없습니다',
                                  style: AppTheme.bodyLargeStyle,
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadApplicants,
                            color: AppTheme.primaryBlue,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20.0,
                                vertical: 0,
                              ),
                              itemCount: applicants.length,
                              itemBuilder: (context, index) {
                                final applicant = applicants[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12.0),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: Colors.grey.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      _showApplicantActionDialog(context, applicant);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                applicant.name,
                                                style: AppTheme.h4Style.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8.0,
                                                  vertical: 4.0,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _getApplicantStatusColor(
                                                    applicant.status,
                                                  ).withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(8.0),
                                                ),
                                                child: Text(
                                                  applicant.status,
                                                  style: AppTheme.bodySmallStyle.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color: _getApplicantStatusColor(
                                                      applicant.status,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          _buildDetailRow(
                                            context,
                                            Icons.call_outlined,
                                            '연락처',
                                            applicant.contact,
                                          ),
                                          _buildDetailRow(
                                            context,
                                            Icons.pets_outlined,
                                            applicant.petInfo.species == 'dog' ? '반려견' : '반려묘',
                                            applicant.petInfo.displayText,
                                          ),
                                          if (applicant.lastDonationDate != null)
                                            _buildDetailRow(
                                              context,
                                              Icons.history,
                                              '직전 헌혈',
                                              '${applicant.lastDonationDate} / 총 ${applicant.donationCount}회',
                                            ),
                                          _buildDetailRow(
                                            context,
                                            Icons.date_range_outlined,
                                            '신청일',
                                            applicant.appliedDate,
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

  Color _getStatusColor(String status) {
    switch (status) {
      case '모집중':
      case '모집 중':
        return AppTheme.primaryBlue;
      case '모집마감':
      case '모집 마감':
        return AppTheme.mediumGray;
      case '대기':
        return AppTheme.warning;
      case '거절':
        return AppTheme.error;
      default:
        return AppTheme.textPrimary;
    }
  }

  Color _getApplicantStatusColor(String status) {
    switch (status) {
      case '승인':
        return AppTheme.success;
      case '대기':
        return AppTheme.warning;
      case '거절':
        return AppTheme.error;
      case '취소':
        return AppTheme.mediumGray;
      default:
        return AppTheme.textPrimary;
    }
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.textTertiary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: AppTheme.bodyMediumStyle.copyWith(
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyMediumStyle.copyWith(
                color: AppTheme.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showApplicantActionDialog(BuildContext context, DonationApplicant applicant) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${applicant.name} (${applicant.petInfo.displayText})'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('연락처: ${applicant.contact}'),
              if (applicant.lastDonationDate != null)
                Text('직전 헌혈: ${applicant.lastDonationDate}'),
              Text('총 헌혈 횟수: ${applicant.donationCount}회'),
              Text('신청일: ${applicant.appliedDate}'),
            ],
          ),
          actions: applicant.status == '대기'
              ? [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _updateApplicantStatus(applicant, '거절');
                    },
                    child: Text(
                      '거절',
                      style: TextStyle(color: AppTheme.error),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _updateApplicantStatus(applicant, '승인');
                    },
                    child: Text(
                      '승인',
                      style: TextStyle(color: AppTheme.primaryBlue),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('닫기'),
                  ),
                ]
              : [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('닫기'),
                  ),
                ],
        );
      },
    );
  }
}