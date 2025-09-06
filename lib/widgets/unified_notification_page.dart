import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';
import '../models/notification_types.dart';
import '../services/notification_list_service.dart';
import '../admin/admin_post_management_page.dart';
import '../admin/admin_signup_management.dart';
import 'common_notification_page.dart';
import 'notification_debug_page.dart';

class UnifiedNotificationPage extends StatefulWidget {
  const UnifiedNotificationPage({super.key});

  @override
  State<UnifiedNotificationPage> createState() =>
      _UnifiedNotificationPageState();
}

class _UnifiedNotificationPageState extends State<UnifiedNotificationPage> {
  UserType? currentUserType;
  bool isLoading = true;

  // 실시간 알림 리스너
  StreamSubscription<NotificationModel>? _realTimeNotificationSubscription;
  StreamSubscription<bool>? _connectionStatusSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserType();
    _setupRealTimeNotifications();
  }

  @override
  void dispose() {
    _realTimeNotificationSubscription?.cancel();
    _connectionStatusSubscription?.cancel();
    super.dispose();
  }

  // 실시간 알림 설정
  void _setupRealTimeNotifications() {
    // 실시간 알림 리스너 설정
    _realTimeNotificationSubscription = NotificationListService
        .realTimeNotifications
        .listen((notification) {
          if (mounted) {
            // 새로운 알림이 왔을 때 스낵바로 알림
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(
                      Icons.notifications_active,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            notification.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.blue.shade600,
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: '확인',
                  textColor: Colors.white,
                  onPressed: () {
                    // 알림 클릭 시 처리 로직 실행
                    _onNotificationTap(notification);
                  },
                ),
              ),
            );
          }
        });

    // 연결 상태 리스너 설정
    _connectionStatusSubscription = NotificationListService.connectionStatus
        .listen((isConnected) {
          if (mounted) {
            // 필요시 UI에 연결 상태 표시
          }
        });
  }

  // SharedPreferences에서 사용자 타입 로드
  Future<void> _loadUserType() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // account_type을 가져와서 UserType으로 변환
      final accountType = prefs.getInt('account_type');

      if (accountType != null) {
        final userType = UserTypeMapper.fromDbType(accountType);

        if (mounted) {
          setState(() {
            currentUserType = userType;
            isLoading = false;
          });
        }
      } else {
        // account_type이 없으면 기본값을 user로 설정
        if (mounted) {
          setState(() {
            currentUserType = UserType.user;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          currentUserType = UserType.user; // 기본값
          isLoading = false;
        });
      }
    }
  }

  // 사용자 타입별 알림 로드 함수
  Future<NotificationListResponse> _loadNotifications() async {
    if (currentUserType == null) {
      return NotificationListResponse(
        notifications: [],
        totalCount: 0,
        unreadCount: 0,
      );
    }

    try {
      switch (currentUserType!) {
        case UserType.admin:
          return await NotificationListService.getAdminNotifications();
        case UserType.hospital:
          return await NotificationListService.getHospitalNotifications();
        case UserType.user:
          return await NotificationListService.getUserNotifications();
      }
    } catch (e) {
      return NotificationListResponse(
        notifications: [],
        totalCount: 0,
        unreadCount: 0,
      );
    }
  }

  // 개별 알림 읽음 처리
  Future<bool> _markAsRead(int notificationId) async {
    try {
      return await NotificationListService.markAsRead(notificationId);
    } catch (e) {
      return false;
    }
  }

  // 전체 알림 읽음 처리
  Future<bool> _markAllAsRead() async {
    try {
      return await NotificationListService.markAllAsRead();
    } catch (e) {
      return false;
    }
  }

  // 알림 탭 시 처리
  void _onNotificationTap(NotificationModel notification) {
    // 알림 타입에 따른 페이지 이동 로직
    _navigateToRelevantPage(notification);
  }

  // 알림별 적절한 페이지로 이동
  void _navigateToRelevantPage(NotificationModel notification) {
    switch (currentUserType!) {
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
          // 회원가입 승인 요청 - 회원가입 관리 페이지로 이동
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminSignupManagement(),
            ),
          );
          break;
        case AdminNotificationType.postApprovalRequest:
          // 게시글 승인 요청 - 승인 대기 탭으로 이동하고 해당 게시글 하이라이트
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => AdminPostManagementPage(
                    initialTab: 'pending_approval',
                    highlightPostId: notification.relatedId?.toString(),
                  ),
            ),
          );
          break;
        case AdminNotificationType.columnApprovalRequest:
          break;
        case AdminNotificationType.systemNotice:
          break;
      }
    }
  }

  void _handleHospitalNotificationTap(NotificationModel notification) {
    if (notification is HospitalNotificationModel) {
      switch (notification.hospitalType) {
        case HospitalNotificationType.postApproved:
        case HospitalNotificationType.postRejected:
          // 게시글 승인/거절 - 병원 대시보드로 이동
          Navigator.pushReplacementNamed(context, '/hospital/dashboard');
          // 추가 정보: 게시글 하이라이트가 필요하면 relatedId 사용 가능
          break;
        case HospitalNotificationType.recruitmentDeadline:
          // 모집 마감 - 병원 대시보드로 이동하여 해당 게시글 확인
          Navigator.pushReplacementNamed(
            context,
            '/hospital/dashboard',
            arguments: {'highlightPostId': notification.relatedId},
          );
          break;
        case HospitalNotificationType.columnApproved:
        case HospitalNotificationType.columnRejected:
          // 칼럼 승인/거절 - 병원 대시보드로 이동
          Navigator.pushReplacementNamed(context, '/hospital/dashboard');
          break;
        case HospitalNotificationType.systemNotice:
          // 시스템 공지 - 공지사항 확인을 위해 대시보드로 이동
          Navigator.pushReplacementNamed(context, '/hospital/dashboard');
          break;
      }
    }
  }

  void _handleUserNotificationTap(NotificationModel notification) {
    if (notification is UserNotificationModel) {
      switch (notification.userType) {
        case UserNotificationType.systemNotice:
          // 시스템 공지 - 사용자 대시보드로 이동
          // 계정 승인/거절, 헌혈 신청 승인/거절 등 모두 포함
          Navigator.pushReplacementNamed(
            context,
            '/user/dashboard',
            arguments: {'highlightNotificationId': notification.notificationId},
          );
          break;
      }
    }
  }

  // 알림 설정 페이지로 이동
  void _openNotificationSettings() {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.bug_report),
                  title: const Text('디버그 페이지'),
                  subtitle: const Text('알림 시스템 연결 상태 확인'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationDebugPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('알림 설정'),
                  subtitle: const Text('구현 예정'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('알림 설정 기능 구현 예정')),
                    );
                  },
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (currentUserType == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('알림')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text('사용자 타입을 확인할 수 없습니다.', style: TextStyle(fontSize: 16)),
              SizedBox(height: 8),
              Text('다시 로그인해 주세요.', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    // 사용자 타입이 확정되면 공통 알림 페이지 사용
    return CommonNotificationPage(
      userType: currentUserType!,
      onLoadNotifications: _loadNotifications,
      onMarkAsRead: _markAsRead,
      onMarkAllAsRead: _markAllAsRead,
      onNotificationTap: _onNotificationTap,
      onNotificationSettingsPressed: _openNotificationSettings,
    );
  }
}

// 알림 페이지 간편 사용을 위한 헬퍼 위젯
class NotificationPageRoute {
  static MaterialPageRoute<void> get route {
    return MaterialPageRoute<void>(
      builder: (context) => const UnifiedNotificationPage(),
    );
  }
}
