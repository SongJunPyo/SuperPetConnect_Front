import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notification_model.dart';
import '../models/notification_types.dart';
import '../providers/notification_provider.dart';
import '../admin/admin_post_check.dart';
import '../admin/admin_signup_management.dart';
import '../admin/admin_column_management.dart';
import '../hospital/hospital_post_check.dart';
import '../hospital/hospital_column_management_list.dart';
import '../user/user_donation_posts_list.dart';
import '../user/my_applications_screen.dart';
import '../services/dashboard_service.dart';
import '../utils/app_theme.dart';
import 'package:intl/intl.dart';

/// Provider 기반 통합 알림 페이지
class UnifiedNotificationPage extends StatefulWidget {
  const UnifiedNotificationPage({super.key});

  @override
  State<UnifiedNotificationPage> createState() =>
      _UnifiedNotificationPageState();
}

class _UnifiedNotificationPageState extends State<UnifiedNotificationPage> {
  final ScrollController _scrollController = ScrollController();

  // 선택 모드 상태
  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<NotificationProvider>();
      if (!provider.isInitialized) {
        provider.initialize();
      }
    });

    // 무한 스크롤
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 선택 모드 토글
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedIds.clear();
      }
    });
  }

  /// 알림 선택 토글
  void _toggleSelection(int notificationId) {
    setState(() {
      if (_selectedIds.contains(notificationId)) {
        _selectedIds.remove(notificationId);
      } else {
        _selectedIds.add(notificationId);
      }
    });
  }

  /// 전체 선택/해제
  void _toggleSelectAll(NotificationProvider provider) {
    setState(() {
      // 리스트 변경 중에도 안전하게 처리하기 위해 스냅샷 사용
      final notificationSnapshot = provider.notifications.toList();
      if (_selectedIds.length == notificationSnapshot.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.clear();
        for (final notification in notificationSnapshot) {
          _selectedIds.add(notification.notificationId);
        }
      }
    });
  }

  /// 선택된 알림 삭제
  Future<void> _deleteSelected(NotificationProvider provider) async {
    if (_selectedIds.isEmpty) return;

    final confirmed = await _showDeleteConfirmDialog(_selectedIds.length);
    if (!confirmed) return;

    setState(() => _isDeleting = true);

    try {
      final success = await provider.deleteNotifications(_selectedIds.toList());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? '${_selectedIds.length}개의 알림이 삭제되었습니다' : '삭제에 실패했습니다',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );

        if (success) {
          setState(() {
            _selectedIds.clear();
            _isSelectionMode = false;
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  /// 삭제 확인 다이얼로그
  Future<bool> _showDeleteConfirmDialog(int count) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text('알림 삭제'),
                content: Text('선택한 $count개의 알림을 삭제하시겠습니까?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      '취소',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('삭제', style: TextStyle(color: AppTheme.error)),
                  ),
                ],
              ),
        ) ??
        false;
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final provider = context.read<NotificationProvider>();
      if (!provider.isLoading && provider.hasMore) {
        provider.loadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        if (!provider.isInitialized) {
          return Scaffold(
            appBar: _buildAppBar(provider),
            body: const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue),
            ),
          );
        }

        if (provider.currentUserType == null) {
          return Scaffold(
            appBar: _buildAppBar(provider),
            body: _buildErrorState('사용자 정보를 확인할 수 없습니다.\n다시 로그인해 주세요.'),
          );
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar:
              _isSelectionMode
                  ? _buildSelectionAppBar(provider)
                  : _buildAppBar(provider),
          body: RefreshIndicator(
            onRefresh: () => provider.refresh(),
            color: AppTheme.primaryBlue,
            child: _buildBody(provider),
          ),
          // 선택 모드일 때 하단 액션 바
          bottomNavigationBar:
              _isSelectionMode ? _buildSelectionBottomBar(provider) : null,
        );
      },
    );
  }

  /// 선택 모드 AppBar
  PreferredSizeWidget _buildSelectionAppBar(NotificationProvider provider) {
    final allSelected =
        provider.notifications.isNotEmpty &&
        _selectedIds.length == provider.notifications.length;

    return AppBar(
      backgroundColor: AppTheme.primaryBlue,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: _toggleSelectionMode,
      ),
      title: Text(
        '${_selectedIds.length}개 선택됨',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      actions: [
        // 전체 선택/해제 버튼
        TextButton.icon(
          onPressed: () => _toggleSelectAll(provider),
          icon: Icon(
            allSelected ? Icons.deselect : Icons.select_all,
            color: Colors.white,
            size: 20,
          ),
          label: Text(
            allSelected ? '전체 해제' : '전체 선택',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// 선택 모드 하단 액션 바
  Widget _buildSelectionBottomBar(NotificationProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // 선택 개수 표시
              Expanded(
                child: Text(
                  '${_selectedIds.length}개 선택',
                  style: AppTheme.bodyMediumStyle.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              // 삭제 버튼
              ElevatedButton.icon(
                onPressed:
                    _selectedIds.isEmpty || _isDeleting
                        ? null
                        : () => _deleteSelected(provider),
                icon:
                    _isDeleting
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.delete_outline, size: 20),
                label: Text(_isDeleting ? '삭제 중...' : '삭제'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _selectedIds.isEmpty
                          ? AppTheme.lightGray
                          : AppTheme.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(NotificationProvider provider) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          Text(
            '알림',
            style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.bold),
          ),
          if (provider.unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.error,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                provider.unreadCount > 99 ? '99+' : '${provider.unreadCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        // 모두 읽음 버튼
        if (provider.unreadCount > 0)
          TextButton(
            onPressed: () => _markAllAsRead(provider),
            child: Text(
              '모두 읽음',
              style: AppTheme.bodySmallStyle.copyWith(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        // 편집(선택) 모드 버튼
        if (provider.notifications.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.checklist, color: AppTheme.textPrimary),
            tooltip: '편집',
            onPressed: _toggleSelectionMode,
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody(NotificationProvider provider) {
    // 로딩 중
    if (provider.isLoading && provider.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.primaryBlue),
            const SizedBox(height: 16),
            Text(
              '알림을 불러오는 중...',
              style: AppTheme.bodyMediumStyle.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // 에러 상태
    if (provider.errorMessage != null && provider.notifications.isEmpty) {
      return _buildErrorState(provider.errorMessage!);
    }

    // 빈 상태
    if (provider.notifications.isEmpty) {
      return _buildEmptyState();
    }

    // 알림 목록
    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: provider.notifications.length + (provider.hasMore ? 1 : 0),
      separatorBuilder:
          (context, index) => Divider(
            height: 1,
            thickness: 1,
            color: AppTheme.lightGray.withValues(alpha: 0.3),
            indent: 16,
            endIndent: 16,
          ),
      itemBuilder: (context, index) {
        // 범위 에러 방지: 인덱스가 리스트 크기를 초과하면 로딩 표시
        if (index >= provider.notifications.length) {
          return _buildLoadingMore();
        }
        return _buildNotificationItem(provider.notifications[index], provider);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 64,
            color: AppTheme.mediumGray,
          ),
          const SizedBox(height: 16),
          Text(
            '알림이 없습니다',
            style: AppTheme.h4Style.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            '새로운 알림이 오면 여기에 표시됩니다',
            style: AppTheme.bodySmallStyle.copyWith(
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              style: AppTheme.bodyMediumStyle.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.read<NotificationProvider>().refresh(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingMore() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.primaryBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(
    NotificationModel notification,
    NotificationProvider provider,
  ) {
    final isRead = notification.isRead;
    final timeAgo = _getTimeAgo(notification.createdAt);
    final isSelected = _selectedIds.contains(notification.notificationId);

    return InkWell(
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(notification.notificationId);
        } else {
          _onNotificationTap(notification, provider);
        }
      },
      onLongPress: () {
        // 롱프레스로 선택 모드 진입
        if (!_isSelectionMode) {
          _toggleSelectionMode();
          _toggleSelection(notification.notificationId);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppTheme.primaryBlue.withValues(alpha: 0.15)
                  : (isRead ? Colors.white : const Color(0xFFE8F3FF)),
          border:
              isRead
                  ? null
                  : const Border(
                    left: BorderSide(color: Color(0xFF3182F6), width: 4),
                  ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 선택 모드: 체크박스
            if (_isSelectionMode)
              GestureDetector(
                onTap: () => _toggleSelection(notification.notificationId),
                child: Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color:
                        isSelected ? AppTheme.primaryBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color:
                          isSelected
                              ? AppTheme.primaryBlue
                              : AppTheme.mediumGray,
                      width: 2,
                    ),
                  ),
                  child:
                      isSelected
                          ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 16,
                          )
                          : null,
                ),
              ),
            // 아이콘 (동그란 원 배경)
            Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: _getIconBackgroundColor(
                  notification,
                ).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  _getNotificationIconData(notification, provider),
                  size: 22,
                  color: _getIconBackgroundColor(notification),
                ),
              ),
            ),
            // 내용
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제목
                  Text(
                    notification.title,
                    style: AppTheme.bodyMediumStyle.copyWith(
                      fontWeight: isRead ? FontWeight.w400 : FontWeight.bold,
                      color:
                          isRead
                              ? AppTheme.textSecondary
                              : AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // 내용
                  Text(
                    notification.content,
                    style: AppTheme.bodySmallStyle.copyWith(
                      color:
                          isRead
                              ? AppTheme.textTertiary
                              : AppTheme.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // 타입 & 시간
                  Row(
                    children: [
                      Text(
                        _getNotificationTypeName(notification, provider),
                        style: AppTheme.bodySmallStyle.copyWith(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                      Container(
                        width: 3,
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.textTertiary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        timeAgo,
                        style: AppTheme.bodySmallStyle.copyWith(
                          color: AppTheme.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 선택 모드가 아니고, 사용자가 아닌 경우에만 화살표 표시
            if (!_isSelectionMode &&
                context.read<NotificationProvider>().currentUserType !=
                    UserType.user)
              Icon(Icons.chevron_right, color: AppTheme.lightGray, size: 20),
          ],
        ),
      ),
    );
  }

  Color _getIconBackgroundColor(NotificationModel notification) {
    // 관리자 알림
    if (notification is AdminNotificationModel) {
      switch (notification.adminType) {
        case AdminNotificationType.signupRequest:
          return AppTheme.primaryBlue;
        case AdminNotificationType.postApprovalRequest:
          return const Color(0xFF6366F1); // 인디고
        case AdminNotificationType.donationApplicationRequest:
          return const Color(0xFFEC4899); // 핑크
        case AdminNotificationType.columnApprovalRequest:
          return const Color(0xFF8B5CF6); // 보라
        case AdminNotificationType.donationCompleted:
          return AppTheme.success;
        case AdminNotificationType.systemNotice:
          return const Color(0xFF64748B); // 슬레이트
      }
    }
    // 병원 알림
    else if (notification is HospitalNotificationModel) {
      switch (notification.hospitalType) {
        case HospitalNotificationType.postApproved:
        case HospitalNotificationType.columnApproved:
        case HospitalNotificationType.donationCompleted:
          return AppTheme.success;
        case HospitalNotificationType.postRejected:
        case HospitalNotificationType.columnRejected:
          return AppTheme.error;
        case HospitalNotificationType.recruitmentDeadline:
          return AppTheme.warning;
        case HospitalNotificationType.timeslotFilled:
          return const Color(0xFF06B6D4); // 시안
        case HospitalNotificationType.allTimeslotsFilled:
          return const Color(0xFF8B5CF6); // 보라
        case HospitalNotificationType.donationApplication:
          return AppTheme.primaryBlue;
        case HospitalNotificationType.systemNotice:
          return const Color(0xFF64748B); // 슬레이트
      }
    }
    // 사용자 알림
    else if (notification is UserNotificationModel) {
      switch (notification.userType) {
        case UserNotificationType.applicationApproved:
        case UserNotificationType.donationCompleted:
          return AppTheme.success;
        case UserNotificationType.applicationRejected:
          return AppTheme.error;
        case UserNotificationType.recruitmentClosed:
          return AppTheme.warning;
        case UserNotificationType.systemNotice:
          return const Color(0xFF64748B); // 슬레이트
      }
    }
    return AppTheme.primaryBlue;
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return DateFormat('MM.dd').format(dateTime);
    }
  }

  Future<void> _markAllAsRead(NotificationProvider provider) async {
    final success = await provider.markAllAsRead();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '모든 알림을 읽음 처리했습니다' : '읽음 처리에 실패했습니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onNotificationTap(
    NotificationModel notification,
    NotificationProvider provider,
  ) {
    // 사용자는 알림 확인만 (읽음 처리), 관리자/병원은 해당 페이지로 이동
    if (provider.currentUserType != UserType.user) {
      _navigateToRelevantPage(notification, provider.currentUserType!);
    }

    // 읽음 처리
    if (!notification.isRead) {
      provider.markAsRead(notification.notificationId);
    }
  }

  void _navigateToRelevantPage(
    NotificationModel notification,
    UserType userType,
  ) {
    switch (userType) {
      case UserType.admin:
        _handleAdminNotificationTap(notification);
        break;
      case UserType.hospital:
        _handleHospitalNotificationTap(notification);
        break;
      case UserType.user:
        _handleUserNotificationTap(notification);
        break;
    }
  }

  void _handleAdminNotificationTap(NotificationModel notification) {
    if (notification is AdminNotificationModel) {
      switch (notification.adminType) {
        case AdminNotificationType.signupRequest:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminSignupManagement(),
            ),
          );
          break;
        case AdminNotificationType.postApprovalRequest:
        case AdminNotificationType.donationApplicationRequest:
        case AdminNotificationType.donationCompleted:
          // 게시글 관련 알림 → 헌혈 게시글 관리 페이지
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AdminPostCheck()),
          );
          break;
        case AdminNotificationType.columnApprovalRequest:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminColumnManagement(),
            ),
          );
          break;
        case AdminNotificationType.systemNotice:
          break;
      }
    }
  }

  void _handleHospitalNotificationTap(NotificationModel notification) {
    if (notification is HospitalNotificationModel) {
      switch (notification.hospitalType) {
        // 게시글 관련 알림 → 게시글 관리 페이지
        case HospitalNotificationType.postApproved:
        case HospitalNotificationType.postRejected:
        case HospitalNotificationType.recruitmentDeadline:
        case HospitalNotificationType.timeslotFilled:
        case HospitalNotificationType.allTimeslotsFilled:
        case HospitalNotificationType.donationApplication:
        case HospitalNotificationType.donationCompleted:
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HospitalPostCheck()),
          );
          break;
        // 칼럼 관련 알림 → 칼럼 관리 페이지
        case HospitalNotificationType.columnApproved:
        case HospitalNotificationType.columnRejected:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const HospitalColumnManagementScreen(),
            ),
          );
          break;
        case HospitalNotificationType.systemNotice:
          // 시스템 공지는 대시보드로 이동
          Navigator.pushReplacementNamed(context, '/hospital/dashboard');
          break;
      }
    }
  }

  void _handleUserNotificationTap(NotificationModel notification) {
    if (notification is UserNotificationModel) {
      switch (notification.userType) {
        // 모집 마감, 신청 승인/거절, 헌혈 완료 → 내 신청 내역 페이지
        case UserNotificationType.recruitmentClosed:
        case UserNotificationType.applicationApproved:
        case UserNotificationType.applicationRejected:
        case UserNotificationType.donationCompleted:
          _navigateToUserPostDetail(notification);
          break;
        case UserNotificationType.systemNotice:
          // 시스템 공지는 대시보드로 이동
          Navigator.pushReplacementNamed(context, '/user/dashboard');
          break;
      }
    }
  }

  /// 사용자 알림에서 게시글 상세로 이동
  Future<void> _navigateToUserPostDetail(NotificationModel notification) async {
    // relatedData에서 post_id 추출
    final postId = _extractPostId(notification.relatedData);

    if (postId != null) {
      // 게시글 상세 정보 로드
      try {
        final post = await DashboardService.getDonationPostDetail(postId);
        if (post != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => UserDonationPostsListScreen(
                    initialPost: post,
                    autoShowBottomSheet: true,
                  ),
            ),
          );
          return;
        }
      } catch (e) {
        debugPrint('[UnifiedNotificationPage] 게시글 로드 실패: $e');
      }
    }

    // post_id가 없거나 로드 실패 시 내 신청 내역 페이지로 이동
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MyApplicationsScreen()),
      );
    }
  }

  /// relatedData에서 post_id 추출
  int? _extractPostId(Map<String, dynamic>? relatedData) {
    if (relatedData == null) return null;

    // 다양한 키 이름으로 post_id 추출 시도
    final postIdValue =
        relatedData['post_id'] ??
        relatedData['postId'] ??
        relatedData['post_idx'];

    if (postIdValue == null) return null;

    if (postIdValue is int) return postIdValue;
    if (postIdValue is String) return int.tryParse(postIdValue);

    return null;
  }

  IconData _getNotificationIconData(
    NotificationModel notification,
    NotificationProvider provider,
  ) {
    switch (provider.currentUserType!) {
      case UserType.admin:
        if (notification is AdminNotificationModel) {
          return _getAdminNotificationIcon(notification.adminType);
        }
        break;
      case UserType.hospital:
        if (notification is HospitalNotificationModel) {
          return _getHospitalNotificationIcon(notification.hospitalType);
        }
        break;
      case UserType.user:
        if (notification is UserNotificationModel) {
          return _getUserNotificationIcon(notification.userType);
        }
        break;
    }
    return Icons.notifications;
  }

  IconData _getAdminNotificationIcon(AdminNotificationType type) {
    switch (type) {
      case AdminNotificationType.signupRequest:
        return Icons.person_add;
      case AdminNotificationType.postApprovalRequest:
        return Icons.article;
      case AdminNotificationType.donationApplicationRequest:
        return Icons.bloodtype;
      case AdminNotificationType.columnApprovalRequest:
        return Icons.description;
      case AdminNotificationType.donationCompleted:
        return Icons.check_circle;
      case AdminNotificationType.systemNotice:
        return Icons.campaign;
    }
  }

  IconData _getHospitalNotificationIcon(HospitalNotificationType type) {
    switch (type) {
      case HospitalNotificationType.postApproved:
        return Icons.check_circle;
      case HospitalNotificationType.postRejected:
        return Icons.cancel;
      case HospitalNotificationType.recruitmentDeadline:
        return Icons.schedule;
      case HospitalNotificationType.timeslotFilled:
        return Icons.event_available;
      case HospitalNotificationType.allTimeslotsFilled:
        return Icons.celebration;
      case HospitalNotificationType.donationApplication:
        return Icons.bloodtype;
      case HospitalNotificationType.donationCompleted:
        return Icons.check_circle;
      case HospitalNotificationType.columnApproved:
        return Icons.check_circle;
      case HospitalNotificationType.columnRejected:
        return Icons.cancel;
      case HospitalNotificationType.systemNotice:
        return Icons.campaign;
    }
  }

  IconData _getUserNotificationIcon(UserNotificationType type) {
    switch (type) {
      case UserNotificationType.systemNotice:
        return Icons.campaign;
      case UserNotificationType.recruitmentClosed:
        return Icons.event_busy;
      case UserNotificationType.donationCompleted:
        return Icons.check_circle;
      case UserNotificationType.applicationApproved:
        return Icons.thumb_up;
      case UserNotificationType.applicationRejected:
        return Icons.thumb_down;
    }
  }

  String _getNotificationTypeName(
    NotificationModel notification,
    NotificationProvider provider,
  ) {
    switch (provider.currentUserType!) {
      case UserType.admin:
        if (notification is AdminNotificationModel) {
          return notification.typeName;
        }
        break;
      case UserType.hospital:
        if (notification is HospitalNotificationModel) {
          return notification.typeName;
        }
        break;
      case UserType.user:
        if (notification is UserNotificationModel) {
          return notification.typeName;
        }
        break;
    }
    return '알림';
  }
}

/// 알림 페이지 라우트 헬퍼
class NotificationPageRoute {
  static MaterialPageRoute<void> get route {
    return MaterialPageRoute<void>(
      builder: (context) => const UnifiedNotificationPage(),
    );
  }
}
