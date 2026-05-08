import 'package:flutter/material.dart';
import 'dart:convert';
import '../constants/dialog_messages.dart';
import '../utils/app_constants.dart';

import '../utils/config.dart';
import '../services/auth_http_client.dart';
import '../utils/app_theme.dart';
import '../utils/api_endpoints.dart';
import '../widgets/pet_profile_image.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_search_bar.dart';
import 'package:intl/intl.dart';
import '../services/admin_completed_donation_service.dart';
import '../widgets/post_detail/post_detail_header.dart';
import '../utils/time_format_util.dart';
import 'admin_active_posts_tab.dart';
import 'admin_completed_donations_tab.dart';
import 'admin_pending_completions_tab.dart';
import 'admin_pending_posts_tab.dart';
import 'admin_post_edit.dart';
import '../widgets/admin/applicant_detail_sheet.dart';
import '../widgets/admin/post_detail_sheet.dart';
import '../widgets/admin/completion_applicant_sheet.dart';
import '../widgets/admin_date_range_picker.dart';

class AdminPostCheck extends StatefulWidget {
  /// 알림 탭 등 외부 진입 시 자동으로 상세 시트를 열 게시글 post_idx.
  /// initialTabIndex == 1(헌혈모집)일 때 ActiveTab의 fetched 리스트에서
  /// post_idx 매칭 후 _openPostDetailSheet 자동 호출.
  final int? initialPostIdx;

  /// 알림 탭 진입 시 보일 초기 탭 (0~4). null이면 default 탭(0=모집대기).
  /// new_donation_application은 1=헌혈모집 탭으로 보냄.
  final int? initialTabIndex;

  const AdminPostCheck({
    super.key,
    this.initialPostIdx,
    this.initialTabIndex,
  });

  @override
  State createState() => _AdminPostCheckState();
}

class _AdminPostCheckState extends State<AdminPostCheck>
    with SingleTickerProviderStateMixin {
  String searchQuery = '';
  TextEditingController searchController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;

  // 슬라이딩 탭 관련
  TabController? _tabController;
  int _currentTabIndex = 0;

  // Tab 0(모집대기) 분리 위젯의 refresh 호출용 키.
  // 승인/거절 API 성공 후 부모가 자식 위젯의 fetchPosts를 트리거.
  final GlobalKey<AdminPendingPostsTabState> _pendingTabKey = GlobalKey();

  // Tab 3(헌혈완료) 분리 위젯 키. 새로고침/리스트 갱신 위임용.
  final GlobalKey<AdminCompletedDonationsTabState> _completedTabKey =
      GlobalKey();

  // Tab 1(헌혈모집) 분리 위젯 키. 시간대 마감/재오픈/대기 변경/삭제 후 갱신용.
  final GlobalKey<AdminActivePostsTabState> _activeTabKey = GlobalKey();

  // Tab 2(헌혈마감) 분리 위젯 키. 헌혈 마감 최종 승인 후 갱신용.
  final GlobalKey<AdminPendingCompletionsTabState> _pendingCompletionsTabKey =
      GlobalKey();

  @override
  void initState() {
    super.initState();
    final initialIndex = (widget.initialTabIndex ?? 0).clamp(0, 3);
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController!.addListener(_handleTabChange);
    _currentTabIndex = initialIndex;

    // 초기 탭의 데이터는 모두 자식 위젯이 자체 initState에서 fetch하므로
    // 부모의 별도 호출 없음.

    // 알림 탭 진입 시 자동으로 해당 게시글 상세 시트 오픈 (2-5b).
    // 백엔드에 admin 단건 fetch endpoint가 없어서, 각 탭의 fetched 리스트에서
    // post_idx 매칭으로 해결. 알림 type별 default 탭이 다름:
    // - new_post_approval → 모집대기(0): status=WAIT(0) / SUSPENDED(5)
    // - new_donation_application → 헌혈모집(1): status=APPROVED(1)/CLOSED(3)
    // 두 탭 모두 자동 시트 오픈 지원. 다른 탭은 미지원 (필요 시 추후 확장).
    if (widget.initialPostIdx != null &&
        (initialIndex == 0 || initialIndex == 1)) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _autoOpenInitialPostSheet(initialIndex);
      });
    }
  }

  /// initialPostIdx 매칭 게시글의 시트 자동 오픈. initState PostFrameCallback
  /// 에서만 호출되며, 알림 진입은 1회성이라 중복 fetch 비용 무시 가능.
  ///
  /// 자식 위젯 mount race 방어 (2026-05-07 #2 수정):
  /// - PostFrameCallback이 자식 initState보다 먼저 실행되면 currentState == null
  /// - 단발 50ms 대기로는 부족한 케이스 발견 → 폴링 루프(최대 1초)로 확장
  /// - currentState 확보 실패 시 silent noop 되던 버그(refresh가 null이라 fetch 안 일어남) 수정
  Future<void> _autoOpenInitialPostSheet(int tabIndex) async {
    Future<void> Function()? refresh;
    List<dynamic> Function()? getPosts;
    bool Function() hasState;

    // 주의: `() async => currentState?.refresh()` 단축형은 Future<Future<void>?>를
    // 반환해서 외부 Future만 await되고 내부 refresh의 fetch는 await 안 됨.
    // 명시 await 블록으로 작성해야 자식의 fetch 완료까지 기다림 (2026-05-07 #1 수정).
    if (tabIndex == 0) {
      refresh = () async {
        await _pendingTabKey.currentState?.refresh();
      };
      getPosts = () => _pendingTabKey.currentState?.posts ?? const [];
      hasState = () => _pendingTabKey.currentState != null;
    } else if (tabIndex == 1) {
      refresh = () async {
        await _activeTabKey.currentState?.refresh();
      };
      getPosts = () => _activeTabKey.currentState?.allPosts ?? const [];
      hasState = () => _activeTabKey.currentState != null;
    } else {
      return;
    }

    // 자식 currentState 폴링 (최대 1초, 50ms 간격). 단발 50ms로는 부족한 환경 발견.
    for (int i = 0; i < 20; i++) {
      if (hasState()) break;
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
    }
    if (!hasState()) {
      debugPrint(
        '[AdminPostCheck] _autoOpenInitialPostSheet: 자식 currentState 1초 폴링 후에도 null. '
        'tabIndex=$tabIndex, postIdx=${widget.initialPostIdx}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('게시글 자동 열기에 실패했습니다. 목록에서 직접 선택해주세요.'),
          ),
        );
      }
      return;
    }

    await refresh();
    if (!mounted) return;

    Map<String, dynamic>? matched;
    final posts = getPosts();
    for (final p in posts) {
      if (p is! Map) continue;
      // 응답 키 변형 방어: admin posts 응답은 `id`를 정식 키로 사용
      // (admin_post_check.dart:689의 _buildPostDetailMenuItems도 post['id'] 읽음).
      // FCM data의 `post_idx` ↔ REST `id` 차이는 CLAUDE.md "FCM data vs REST 응답 body
      // 키 이름 차이 (의도된 보존)" 패턴. camelCase 변형(`postIdx`)도 함께 fallback.
      final postIdx = _extractPostIdxFromMap(p);
      if (postIdx != null && postIdx == widget.initialPostIdx) {
        matched = Map<String, dynamic>.from(p);
        break;
      }
    }
    if (matched != null) {
      _openPostDetailSheet(
        matched,
        _getPostStatus(matched['status']),
        _getPostType(matched),
      );
    } else {
      // 매칭 실패 진단: 모든 후보 키 + 추출 결과 로그.
      // 페이지네이션(다른 페이지에 있음) / 상태 변경(다른 탭으로 이동) / 키 미스매치
      // 케이스 구분 가능하게.
      debugPrint(
        '[AdminPostCheck] post_idx=${widget.initialPostIdx} 매칭 실패. '
        'tabIndex=$tabIndex, posts.length=${posts.length}, '
        'extracted=${posts.map((p) => p is Map ? _extractPostIdxFromMap(p) : null).toList()}, '
        'sample keys=${posts.isNotEmpty && posts.first is Map ? (posts.first as Map).keys.toList() : null}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('게시글을 찾을 수 없습니다 (다른 페이지에 있거나 이미 처리되었을 수 있습니다).'),
          ),
        );
      }
    }
  }

  /// 응답 객체에서 post_idx 추출. 키 변형(`id` / `post_idx` / `postIdx`) 모두 대응.
  /// admin REST 응답은 `id`, FCM data는 `post_idx` — CLAUDE.md "FCM ↔ REST 키 차이" 패턴.
  int? _extractPostIdxFromMap(Map p) {
    final raw = p['id'] ?? p['post_idx'] ?? p['postIdx'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  void _handleTabChange() {
    if (_tabController!.indexIsChanging ||
        _tabController!.index != _currentTabIndex) {
      setState(() {
        _currentTabIndex = _tabController!.index;
      });

      // 탭에 따라 다른 API 호출 (자식 위젯이 자체 페이지/상태 관리)
      if (_currentTabIndex == 1) {
        // 헌혈모집 탭 - 자식 위젯에 위임. build 전이면 자식 initState에서 자동 fetch.
        _activeTabKey.currentState?.refresh();
      } else if (_currentTabIndex == 2) {
        // 헌혈마감 탭 - 자식 위젯에 위임. build 전이면 자식 initState에서 자동 fetch.
        _pendingCompletionsTabKey.currentState?.refresh();
      } else if (_currentTabIndex == 3) {
        // 헌혈완료 탭 - 자식 위젯에 위임. build 전이면 자식 initState에서 자동 fetch.
        _completedTabKey.currentState?.refresh();
      } else {
        // 모집대기(0) 탭 - 자식 위젯에 위임. 위젯이 살아 있으면 refresh,
        // 아직 build 전이면 자식의 initState에서 자동 fetch.
        _pendingTabKey.currentState?.refresh();
      }
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    searchController.dispose();
    super.dispose();
  }

  // 상태 관리는 AppliedDonationStatus 클래스 사용
  // (미사용 함수 제거됨 - lib/models/applied_donation_model.dart 참조)

  // 헌혈 완료 최종 승인
  Future<void> _finalApproveCompletion(int applicationId) async {
    try {
      final result = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        builder:
            (context) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 핸들 바
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // 제목
                  Text(
                    '헌혈 마감',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 내용
                  Text(
                    '헌혈 완료를 최종 승인하시겠습니까?',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),

                  // 버튼들
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('취소'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green.shade700,
                            side: BorderSide(color: Colors.green.shade400),
                            backgroundColor: Colors.white,
                          ),
                          child: const Text('헌혈 마감'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
      );

      if (result == true) {
        await AdminCompletedDonationService.finalApprove(applicationId);
        // 데이터 새로고침 - 현재 탭에 있을 때만 새로고침
        if (_currentTabIndex == 2) {
          _pendingCompletionsTabKey.currentState?.refresh();
        }
        // 헌혈완료 탭은 나중에 탭 이동 시 자동으로 로드됨
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('승인 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 현재 탭에 맞는 데이터 조회 함수 호출. 모든 탭이 자식 위젯이므로 GlobalKey로 위임.
  Future<void> _fetchDataForCurrentTab() async {
    if (_currentTabIndex == 1) {
      await _activeTabKey.currentState?.refresh();
    } else if (_currentTabIndex == 2) {
      await _pendingCompletionsTabKey.currentState?.refresh();
    } else if (_currentTabIndex == 3) {
      await _completedTabKey.currentState?.refresh();
    } else {
      await _pendingTabKey.currentState?.refresh();
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      searchQuery = query;
    });
    // 자식 위젯들의 didUpdateWidget이 props 변경을 감지해 1페이지로 리셋 + refetch.
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showAdminDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialRange:
          startDate != null && endDate != null
              ? DateTimeRange(start: startDate!, end: endDate!)
              : null,
    );

    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
      // 자식 위젯들이 props 변경을 감지해 페이지 리셋 + refetch.
    }
  }

  void _clearDateRange() {
    setState(() {
      startDate = null;
      endDate = null;
    });
    // 자식 위젯들이 props 변경을 감지해 페이지 리셋 + refetch.
  }

  Future<void> _showConfirmDialog(
    int postId,
    bool approve,
    String title,
  ) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 핸들바
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 제목
              Text(
                approve ? '게시글 승인' : '게시글 거절',
                style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 16),

              // 내용
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.lightGray.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  title,
                  style: AppTheme.bodyLargeStyle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
              const SizedBox(height: 24),

              // 버튼들
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: BorderSide(color: AppTheme.lightGray),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            approve ? AppTheme.success : AppTheme.error,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(approve ? '승인' : '거절'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (result == true) {
      approvePost(postId, approve);
    }
  }

  Future<void> approvePost(int postId, bool approve) async {
    try {
      final url = Uri.parse(
        '${Config.serverUrl}/api/admin/posts/$postId/approval',
      );
      final response = await AuthHttpClient.put(
        url,
        body: jsonEncode({'approved': approve}),
      );

      if (response.statusCode == 200) {
        _fetchDataForCurrentTab();
      } else if (response.statusCode == 404) {
        // 게시글이 이미 삭제됨 (병원이 WAIT 상태에서 삭제한 케이스).
        // 사용자 친화적 안내 + 목록 자동 갱신으로 stale 항목 제거.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이미 삭제된 게시글입니다. 목록을 갱신합니다.'),
            ),
          );
          _fetchDataForCurrentTab();
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('처리 실패 (코드 ${response.statusCode})'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("오류 발생: $e")));
      }
    }
  }

  /// 게시글 대기상태로 변경 (모집중 → 대기)
  Future<void> _suspendPost(int postIdx) async {
    try {
      final url = Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.adminPostSuspend(postIdx)}',
      );
      final response = await AuthHttpClient.patch(url);

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('게시글이 대기 상태로 변경되었습니다.')),
          );
        }
        _fetchDataForCurrentTab();
      } else {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(body['detail'] ?? '상태 변경에 실패했습니다.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류 발생: $e')),
        );
      }
    }
  }

  /// 게시글 모집중으로 변경 (대기 → 모집중)
  Future<void> _resumePost(int postIdx) async {
    try {
      final url = Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.adminPostResume(postIdx)}',
      );
      final response = await AuthHttpClient.patch(url);

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('게시글이 모집중 상태로 변경되었습니다.')),
          );
        }
        _fetchDataForCurrentTab();
      } else {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(body['detail'] ?? '상태 변경에 실패했습니다.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류 발생: $e')),
        );
      }
    }
  }

  /// 게시글 삭제
  Future<void> _deletePost(int postIdx) async {
    try {
      final url = Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.adminPostDelete(postIdx)}',
      );
      final response = await AuthHttpClient.delete(url);

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('게시글이 삭제되었습니다.')),
          );
        }
        _fetchDataForCurrentTab();
      } else {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(body['detail'] ?? '게시글 삭제에 실패했습니다.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류 발생: $e')),
        );
      }
    }
  }

  /// 삭제 확인 다이얼로그
  Future<void> _showDeleteConfirmDialog(int postIdx, String title) async {
    final ok = await AppDialog.confirm(
      context,
      title: '게시글 삭제',
      message: "'$title' 게시글을 삭제하시겠습니까?\n\n삭제된 게시글은 복구할 수 없습니다.",
      confirmLabel: '삭제',
      isDestructive: true,
    );
    if (ok == true) _deletePost(postIdx);
  }

  /// 대기 변경 확인 다이얼로그
  Future<void> _showSuspendConfirmDialog(int postIdx, String title) async {
    final ok = await AppDialog.confirm(
      context,
      title: '대기 상태로 변경',
      message: "'$title' 게시글을 대기 상태로 변경하시겠습니까?\n\n병원에게 알림이 발송됩니다.",
      confirmLabel: '변경',
    );
    if (ok == true) _suspendPost(postIdx);
  }

  /// 마감 상태에서 전환 시 경고 다이얼로그 (시간대 열기 + 신청자 초기화)
  void _showStatusChangeWithResetDialog(int postIdx, String title, String targetStatus, Future<void> Function(int) action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$targetStatus 상태로 변경'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("'$title' 게시글을 $targetStatus 상태로 변경하시겠습니까?"),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '승인된 신청자가 대기 상태로 변경됩니다.',
                      style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              action(postIdx);
            },
            child: const Text('변경'),
          ),
        ],
      ),
    );
  }

  /// 모집 재개 확인 다이얼로그
  Future<void> _showResumeConfirmDialog(int postIdx, String title) async {
    final ok = await AppDialog.confirm(
      context,
      title: '모집중으로 변경',
      message: "'$title' 게시글을 모집중 상태로 변경하시겠습니까?\n\n병원에게 알림이 발송됩니다.",
      confirmLabel: '변경',
    );
    if (ok == true) _resumePost(postIdx);
  }

  /// 게시글 상세 헤더의 ... 메뉴 항목 구성
  List<PostDetailMenuItem> _buildPostDetailMenuItems(Map<String, dynamic> post) {
    final items = <PostDetailMenuItem>[];
    final postId = post['id'];
    final postIdx = postId is int ? postId : int.tryParse(postId?.toString() ?? '') ?? 0;
    final title = post['title'] ?? '제목 없음';
    final applicantCount = post['applicantCount'] ?? post['applicant_count'] ?? 0;

    // 수정 (탭 0, 1 공통)
    items.add(PostDetailMenuItem(
      icon: Icons.edit_outlined,
      label: '수정',
      onTap: () async {
        Navigator.pop(context); // 바텀시트 닫기
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdminPostEdit(post: post),
          ),
        );
        if (result == true) {
          _fetchDataForCurrentTab();
        }
      },
    ));

    // 대기로 변경 (탭 1: 모집중, 탭 2: 헌혈마감)
    if ((_currentTabIndex == 1 && post['status'] == 1 && post['is_completion_pending'] != true) ||
        (_currentTabIndex == 2 && post['status'] == 3 && post['is_completion_pending'] != true)) {
      final isFromClosed = post['status'] == 3;
      items.add(PostDetailMenuItem(
        icon: Icons.pause_circle_outline,
        label: '대기',
        onTap: () {
          Navigator.pop(context);
          if (isFromClosed) {
            _showStatusChangeWithResetDialog(postIdx, title, '대기', _suspendPost);
          } else {
            _showSuspendConfirmDialog(postIdx, title);
          }
        },
      ));
    }

    // 모집중으로 변경 (탭 0: 대기상태, 탭 2: 헌혈마감)
    if ((_currentTabIndex == 0 && post['status'] == 5) ||
        (_currentTabIndex == 2 && post['status'] == 3 && post['is_completion_pending'] != true)) {
      final isFromClosed = post['status'] == 3;
      items.add(PostDetailMenuItem(
        icon: Icons.play_circle_outline,
        label: '모집',
        onTap: () {
          Navigator.pop(context);
          if (isFromClosed) {
            _showStatusChangeWithResetDialog(postIdx, title, '모집중', _resumePost);
          } else {
            _showResumeConfirmDialog(postIdx, title);
          }
        },
      ));
    }

    // 삭제
    // 탭 0: WAIT(0), SUSPENDED(5) 모두 삭제 가능
    // 탭 1: 신청자 0명일 때만
    if (_currentTabIndex == 0 ||
        (_currentTabIndex == 1 &&
            post['is_completion_pending'] != true &&
            applicantCount == 0)) {
      items.add(PostDetailMenuItem(
        icon: Icons.delete_outline,
        label: '삭제',
        onTap: () {
          Navigator.pop(context);
          _showDeleteConfirmDialog(postIdx, title);
        },
      ));
    }

    return items;
  }

  String _getPostStatus(dynamic status) {
    // 상태값이 숫자로 전달됨: 0=대기, 1=승인/모집중, 2=거절, 3=모집마감, 5=대기상태
    int statusNum =
        status is int ? status : int.tryParse(status.toString()) ?? 0;

    switch (statusNum) {
      case 0:
        return '승인 대기';
      case 1:
        return '모집중';
      case 2:
        return '거절됨';
      case 3:
        return '모집마감';
      case 5:
        return '대기상태';
      default:
        return '승인 대기'; // 기본값
    }
  }

  // 시간대별 신청자 목록을 가져오는 메소드
  Future<List<Map<String, dynamic>>> _fetchTimeSlotApplicants(
    int postId,
    int timeSlotId,
    String date,
  ) async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse(
          '${Config.serverUrl}/api/admin/time-slots/$timeSlotId/applicants',
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        throw Exception('Failed to load applicants');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // 신청자 승인 (silent) — 일괄 처리에서 호출. 성공 snackbar 미노출,
  // 실패는 caller가 모아서 한 번에 안내.
  Future<bool> _approveSilent(int appliedDonationIdx) async {
    try {
      final response = await AuthHttpClient.patch(
        Uri.parse(
          '${Config.serverUrl}/api/admin/applied-donations/$appliedDonationIdx/approve',
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // 신청자 대기 전환 (silent) — APPROVE 롤백 용도.
  Future<bool> _pendSilent(int appliedDonationIdx) async {
    try {
      final response = await AuthHttpClient.patch(
        Uri.parse(
          '${Config.serverUrl}/api/admin/applied-donations/$appliedDonationIdx/pend',
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "헌혈 게시글 관리",
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: '날짜 범위 선택',
          ),
          if (startDate != null || endDate != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearDateRange,
              tooltip: '날짜 범위 초기화',
            ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined, color: Colors.black87),
            tooltip: '새로고침',
            onPressed: () {
              _fetchDataForCurrentTab();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body:
          _tabController == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // 검색창
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: AppSearchBar(
                      controller: searchController,
                      hintText: '게시글 제목, 병원명, 내용으로 검색...',
                      onChanged: _onSearchChanged,
                      onClear: () => _onSearchChanged(''),
                    ),
                  ),

                  // 슬라이딩 탭
                  Container(
                    color: Colors.white,
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: false,
                      tabs: const [
                        Tab(text: '모집대기'),
                        Tab(text: '헌혈모집'),
                        Tab(text: '헌혈마감'),
                        Tab(text: '헌혈완료'),
                      ],
                      indicatorColor: Colors.black,
                      labelColor: Colors.black,
                      unselectedLabelColor: Colors.grey,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      unselectedLabelStyle: const TextStyle(fontSize: 14),
                      indicatorWeight: 3.0,
                    ),
                  ),

                  // 날짜 범위 표시
                  if (startDate != null || endDate != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.date_range,
                              color: Colors.black,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '기간: ${startDate != null ? DateFormat('yyyy-MM-dd').format(startDate!) : '시작일 미지정'} ~ ${endDate != null ? DateFormat('yyyy-MM-dd').format(endDate!) : '종료일 미지정'}',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.black,
                                size: 18,
                              ),
                              onPressed: _clearDateRange,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 콘텐츠
                  Expanded(child: _buildContent()),
                ],
              ),
    );
  }

  Widget _buildContent() {
    // Tab 0(모집대기)는 분리된 자식 위젯으로 위임. 검색/날짜 필터를 props로 전달.
    if (_currentTabIndex == 0) {
      return AdminPendingPostsTab(
        key: _pendingTabKey,
        searchQuery: searchQuery,
        startDate: startDate,
        endDate: endDate,
        onTapPost: (post) {
          final postStatus = _getPostStatus(post['status']);
          final postType = _getPostType(post);
          _openPostDetailSheet(post, postStatus, postType);
        },
      );
    }

    // Tab 1(헌혈모집)도 분리된 자식 위젯으로 위임. 행 탭 시 부모의 상세 시트를 연다.
    if (_currentTabIndex == 1) {
      return AdminActivePostsTab(
        key: _activeTabKey,
        searchQuery: searchQuery,
        startDate: startDate,
        endDate: endDate,
        onTapPost: (post) {
          final postStatus = _getPostStatus(post['status']);
          final postType = _getPostType(post);
          _openPostDetailSheet(post, postStatus, postType);
        },
      );
    }

    // Tab 2(헌혈마감)도 분리된 자식 위젯으로 위임.
    // is_completion_pending 분기로 시트 종류를 결정.
    if (_currentTabIndex == 2) {
      return AdminPendingCompletionsTab(
        key: _pendingCompletionsTabKey,
        searchQuery: searchQuery,
        startDate: startDate,
        endDate: endDate,
        onTapPost: (post) {
          if (post['is_completion_pending'] == true) {
            _openCompletionApplicantSheet(post);
          } else {
            final postStatus = _getPostStatus(post['status']);
            final postType = _getPostType(post);
            _openPostDetailSheet(post, postStatus, postType);
          }
        },
      );
    }

    // Tab 3(헌혈완료)도 분리된 자식 위젯으로 위임. 행 탭 시 신청자 시트를 연다.
    if (_currentTabIndex == 3) {
      return AdminCompletedDonationsTab(
        key: _completedTabKey,
        searchQuery: searchQuery,
        startDate: startDate,
        endDate: endDate,
        onTapPost: _openCompletionApplicantSheet,
      );
    }

    // _currentTabIndex는 initState에서 clamp(0,3)이라 도달 불가. 방어용 빈 상태.
    return const SizedBox.shrink();
  }

  /// 게시글 상세 시트를 열기 위한 진입점.
  /// 시트 자체는 [showPostDetailBottomSheet] (lib/widgets/admin/post_detail_sheet.dart)에 있고,
  /// 여기서는 메뉴/시간대 빌더 + 액션 콜백을 본 화면 컨텍스트에 묶어 전달.
  void _openPostDetailSheet(
    Map<String, dynamic> post,
    String postStatus,
    String postType,
  ) {
    showPostDetailBottomSheet(
      context,
      post: post,
      postStatus: postStatus,
      postType: postType,
      currentTabIndex: _currentTabIndex,
      menuItems: (_currentTabIndex == 0 ||
              _currentTabIndex == 1 ||
              _currentTabIndex == 2)
          ? _buildPostDetailMenuItems(post)
          : null,
      timeSlotBuilder: (setState) => _buildDateTimeDropdown(post, setState),
      actions: PostDetailSheetActions(
        onApprovePostTap: (id, title) => _showConfirmDialog(id, true, title),
        onRejectPostTap: (id, title) => _showConfirmDialog(id, false, title),
        onFinalApproveCompletion: _finalApproveCompletion,
        onClosePost: (setState) =>
            _showClosePostConfirmationSheet(post, setState),
        onReopenPost: (setState) =>
            _showReopenPostConfirmationSheet(post, setState),
      ),
    );
  }

  /// 헌혈완료/취소 신청자 시트를 열기 위한 진입점.
  /// 시트 자체는 [showCompletionApplicantSheet]
  /// (lib/widgets/admin/completion_applicant_sheet.dart)에 있고,
  /// 여기서는 상태별 액션 콜백을 본 화면 컨텍스트에 묶어 전달.
  void _openCompletionApplicantSheet(Map<String, dynamic> post) {
    showCompletionApplicantSheet(
      context,
      post: post,
      actions: CompletionApplicantSheetActions(
        onFinalApproveCompletion: _finalApproveCompletion,
        onRequestDocuments: _requestDocuments,
      ),
    );
  }


  Widget _buildDateTimeDropdown(
    Map<String, dynamic> post,
    StateSetter onUpdate,
  ) {
    final timeRanges = post['timeRanges'] as List<dynamic>? ?? [];
    final isActive =
        post['status'] == 1 ||
        post['status'] == 3 ||
        post['status'] == 5; // 모집중, 마감, 대기 상태 모두 관리 가능

    if (timeRanges.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Center(
          child: Text(
            '헌혈 날짜 정보가 없습니다',
            style: AppTheme.bodyMediumStyle.copyWith(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // timeRanges를 날짜별로 그룹화 (중복 제거)
    final Map<String, List<Map<String, dynamic>>> groupedByDate = {};
    final Set<String> seenTimeSlots = {}; // 중복 체크용

    for (final timeRange in timeRanges) {
      final dateStr = timeRange['donation_date'] ?? timeRange['date'] ?? 'N/A';
      final time = timeRange['time'] ?? '';
      final team = timeRange['team'] ?? 0;

      // 날짜+시간+팀으로 고유키 생성하여 중복 체크
      final uniqueKey = '$dateStr-$time-$team';

      if (!seenTimeSlots.contains(uniqueKey)) {
        seenTimeSlots.add(uniqueKey);
        if (!groupedByDate.containsKey(dateStr)) {
          groupedByDate[dateStr] = [];
        }
        groupedByDate[dateStr]!.add(timeRange);
      }
    }

    return Column(
      children:
          groupedByDate.entries.map((entry) {
            final dateStr = entry.key;
            final timeSlots = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200, width: 1.5),
              ),
              child: Column(
                children: [
                  // 날짜 헤더
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month, color: Colors.black, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          TimeFormatUtils.formatDateWithWeekday(dateStr),
                          style: AppTheme.bodyLargeStyle.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  // 시간대 목록
                  ...
                      timeSlots.map((timeSlot) {
                        final time = timeSlot['time'] ?? '';
                        final isSlotClosed = timeSlot['status'] == 1;

                        return InkWell(
                          onTap: () async {
                            // 헌혈마감 탭에서는 신청자 정보 표시, 다른 탭에서는 기존 로직
                            if (post['is_completion_pending'] == true) {
                              _openCompletionApplicantSheet(post);
                            } else if (_currentTabIndex == 3) {
                              // 헌혈완료 탭에서도 신청자 정보 표시
                              _openCompletionApplicantSheet(post);
                            } else if (isActive) {
                              await _showTimeSlotApplicants(
                                post['id'],
                                timeSlot['id'],
                                dateStr,
                                time,
                                timeSlot['status'],
                                post,
                                onUpdate,
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  isSlotClosed
                                      ? Colors.grey.shade100
                                      : Colors.white,
                              border: Border(
                                top: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color:
                                      isSlotClosed ? Colors.grey : Colors.black,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  TimeFormatUtils.formatTime(time),
                                  style: AppTheme.bodyMediumStyle.copyWith(
                                    color:
                                        isSlotClosed
                                            ? Colors.grey
                                            : Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                if (_currentTabIndex != 0)
                                  _buildTimeSlotStatusBadge(
                                    timeSlot['status'] ?? 0,
                                    postStatus: post['status'] as int?,
                                  ),
                                if (isActive && !(_currentTabIndex == 0 && post['status'] != 5))
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: TextButton.icon(
                                      onPressed: () async {
                                        await _showTimeSlotApplicants(
                                          post['id'],
                                          timeSlot['id'],
                                          dateStr,
                                          time,
                                          timeSlot['status'],
                                          post,
                                          onUpdate,
                                        );
                                      },
                                      icon: Icon(
                                        Icons.people_outline,
                                        size: 18,
                                        color:
                                            isSlotClosed
                                                ? Colors.grey
                                                : Colors
                                                    .black, // 마감된 경우 회색으로 표시
                                      ),
                                      label: Text(
                                        _currentTabIndex == 1 ? '신청자 관리' : '신청자 확인',
                                        style: TextStyle(
                                          color:
                                              isSlotClosed
                                                  ? Colors.grey
                                                  : Colors
                                                      .black, // 마감된 경우 회색으로 표시
                                        ),
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            isSlotClosed
                                                ? Colors.grey
                                                : Colors.black,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                                  ),
                              if (!(_currentTabIndex == 0 && post['status'] != 5))
                                Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                  color: isSlotClosed ? Colors.grey : AppTheme.textTertiary,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                ],
              ),
            );
          }).toList(),
    );
  }

  Future<void> _showTimeSlotApplicants(
    dynamic postId,
    dynamic timeSlotId,
    String date,
    String time,
    dynamic status,
    Map<String, dynamic> post,
    StateSetter onUpdate,
  ) async {
    final postIdInt =
        postId is int ? postId : int.tryParse(postId.toString()) ?? 0;
    final timeSlotIdInt =
        timeSlotId is int
            ? timeSlotId
            : int.tryParse(timeSlotId.toString()) ?? 0;
    final isSlotClosed = status == 1;
    // 헌혈모집 탭(_currentTabIndex==1)이고 시간대가 열려 있을 때만 라디오 선택 모드.
    // 그 외(헌혈마감/완료, 마감된 시간대)는 read-only.
    final isManageMode = _currentTabIndex == 1 && !isSlotClosed;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        // 시트 단위 영구 상태 — StatefulBuilder rebuild 사이에 유지.
        // applicantsFuture를 캐시해서 setState 시 refetch 방지, selectedIds는
        // 첫 fetch 응답에서 APPROVED 신청자로 자동 초기화.
        Future<List<Map<String, dynamic>>>? applicantsFuture;
        Set<int>? selectedIds;
        Set<int> initialApprovedIds = const {};

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            applicantsFuture ??=
                _fetchTimeSlotApplicants(postIdInt, timeSlotIdInt, date);
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              expand: false,
              builder: (
                BuildContext context,
                ScrollController scrollController,
              ) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      // 핸들 바
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // 헤더
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isManageMode ? '신청자 관리' : '신청자 확인',
                                    style: AppTheme.h3Style.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${TimeFormatUtils.formatDateWithWeekday(date)} ${TimeFormatUtils.formatTime(time)}',
                                    style: AppTheme.bodyMediumStyle.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.black,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              tooltip: '닫기',
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: FutureBuilder<List<Map<String, dynamic>>>(
                          future: applicantsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (snapshot.hasError) {
                              return Center(
                                child: Text(
                                  '신청자 정보를 불러오는데 실패했습니다.\n${snapshot.error}',
                                  textAlign: TextAlign.center,
                                  style: AppTheme.bodyMediumStyle.copyWith(
                                    color: Colors.red,
                                  ),
                                ),
                              );
                            }

                            final applicants = snapshot.data ?? [];

                            // 첫 응답 1회 한정 — selectedIds 초기화.
                            // 이미 APPROVED인 신청자는 자동 체크 ON.
                            if (selectedIds == null) {
                              initialApprovedIds = applicants
                                  .where((a) => a['status'] == 1)
                                  .map((a) => a['id'] as int)
                                  .toSet();
                              selectedIds =
                                  Set<int>.from(initialApprovedIds);
                            }
                            final selSet = selectedIds!;

                            // 빈 응답 처리.
                            if (applicants.isEmpty) {
                              return Column(
                                children: [
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        isSlotClosed
                                            ? '마감된 시간대입니다.'
                                            : '아직 신청자가 없습니다.',
                                        style: AppTheme.bodyMediumStyle
                                            .copyWith(color: Colors.grey[600]),
                                      ),
                                    ),
                                  ),
                                  if (isManageMode)
                                    _buildBatchCloseButton(
                                      selectedCount: 0,
                                      unselectedCount: 0,
                                      onPressed: () =>
                                          _showBatchCloseConfirmation(
                                        timeSlotId: timeSlotIdInt,
                                        date: date,
                                        time: time,
                                        post: post,
                                        onUpdate: onUpdate,
                                        applicants: applicants,
                                        selectedIds: selSet,
                                        initialApprovedIds:
                                            initialApprovedIds,
                                      ),
                                    ),
                                  if (_currentTabIndex == 1 && isSlotClosed)
                                    _buildReopenButton(
                                      onPressed: () =>
                                          _showReopenConfirmationDialog(
                                        timeSlotIdInt,
                                        date,
                                        time,
                                        post,
                                        onUpdate,
                                      ),
                                    ),
                                ],
                              );
                            }

                            return Column(
                              children: [
                                Expanded(
                                  child: ListView.separated(
                                    controller: scrollController,
                                    padding: const EdgeInsets.all(16),
                                    itemCount: applicants.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (rowContext, index) {
                                      final applicant = applicants[index];
                                      final id = applicant['id'] as int;
                                      final isSelected = selSet.contains(id);
                                      return _buildApplicantSelectableRow(
                                        rowContext: rowContext,
                                        applicant: applicant,
                                        isManageMode: isManageMode,
                                        isSelected: isSelected,
                                        onToggle: isManageMode
                                            ? () => setState(() {
                                                  if (selSet.contains(id)) {
                                                    selSet.remove(id);
                                                  } else {
                                                    selSet.add(id);
                                                  }
                                                })
                                            : null,
                                      );
                                    },
                                  ),
                                ),
                                if (isManageMode)
                                  _buildBatchCloseButton(
                                    selectedCount: selSet.length,
                                    unselectedCount:
                                        applicants.length - selSet.length,
                                    onPressed: () =>
                                        _showBatchCloseConfirmation(
                                      timeSlotId: timeSlotIdInt,
                                      date: date,
                                      time: time,
                                      post: post,
                                      onUpdate: onUpdate,
                                      applicants: applicants,
                                      selectedIds: selSet,
                                      initialApprovedIds: initialApprovedIds,
                                    ),
                                  ),
                                if (_currentTabIndex == 1 && isSlotClosed)
                                  _buildReopenButton(
                                    onPressed: () =>
                                        _showReopenConfirmationDialog(
                                      timeSlotIdInt,
                                      date,
                                      time,
                                      post,
                                      onUpdate,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Helper method to build the status badge for a time slot
  Widget _buildTimeSlotStatusBadge(dynamic status, {int? postStatus}) {
    // 헌혈완료 탭인 경우 항상 "헌혈완료" 뱃지 표시
    if (_currentTabIndex == 3) {
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          '헌혈완료',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            height: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    // 헌혈마감 탭인 경우 게시글 상태에 따라 뱃지 표시
    if (_currentTabIndex == 2 && postStatus != null) {
      // 모집마감(status=3)
      if (postStatus == 3) {
        return Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            '마감',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
            textAlign: TextAlign.center,
          ),
        );
      }
      // 완료대기(postStatus == 5)
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          '헌혈완료',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            height: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    final isClosed = (status == 1);
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // 패딩 증가
      decoration: BoxDecoration(
        color: isClosed ? Colors.red : Colors.green,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isClosed ? '모집마감' : '모집진행',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          height: 1.0, // 텍스트 높이 조정
        ),
        textAlign: TextAlign.center, // 텍스트 중앙 정렬
      ),
    );
  }

  // Method to call the API to close a time slot
  Future<void> _closeTimeSlot(
    Map<String, dynamic> post,
    int timeSlotId,
    StateSetter onUpdate,
  ) async {
    try {
      final url = Uri.parse(
        '${Config.serverUrl}/api/admin/time-slots/$timeSlotId/close',
      );
      final response = await AuthHttpClient.patch(url);

      if (response.statusCode == 200) {
        // 백엔드 응답의 post_status는 단일 시간대였다면 3(CLOSED)로 승격되어 옴.
        // updated_time_slot 필드는 더 이상 신뢰하지 않고, 호출자가 넘긴
        // timeSlotId로 직접 매칭해 status=1을 박는다 — 응답 필드 누락/id-idx
        // 키 불일치로 뱃지가 stale로 남던 케이스 차단.
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        final int postStatus =
            responseData['post_status'] ?? post['status'] ?? 1;

        // id 키가 응답마다 (id / idx / post_times_idx) 다르고 int/String도 섞여
        // 들어오므로 toString 비교로 통일 — 매칭이 빗나가서 status가 stale로
        // 남던 케이스 차단.
        final timeRanges = post['timeRanges'] as List<dynamic>? ?? [];
        final targetIdStr = timeSlotId.toString();
        final timeSlotIndex = timeRanges.indexWhere((ts) {
          final raw = ts['id'] ?? ts['idx'] ?? ts['post_times_idx'];
          return raw != null && raw.toString() == targetIdStr;
        });

        if (mounted) {
          // 상세 시트의 setState — 뱃지(모집진행 → 모집마감)와 하단 마감/
          // 재오픈 버튼이 즉시 갱신. 상세 시트는 닫지 않는다.
          onUpdate(() {
            if (timeSlotIndex != -1) {
              timeRanges[timeSlotIndex]['status'] = 1;
            }
            post['status'] = postStatus;
          });

          // 확인 시트 + 신청자 관리 시트만 닫음.
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        }

        // 부모 탭 목록도 백그라운드로 새로고침 — 단일 시간대였다면 게시글이
        // 헌혈모집 탭에서 빠지고 헌혈마감 탭으로 이동.
        if (mounted) {
          await _fetchDataForCurrentTab();
        }
      } else {
        if (mounted) {
          Navigator.of(context).pop(); // 오류 시에도 확인 창은 닫습니다.
        }
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        if (response.statusCode == 400) {
          if (mounted) {
            showDialog(
              context: context,
              builder:
                  (_) => AlertDialog(
                    title: const Text('알림'),
                    content: const Text('이미 마감된 시간대입니다.'),
                    actions: [
                      TextButton(
                        child: const Text('확인'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
            );
          }
        } else {
          throw Exception(
            'Failed to close time slot: ${errorData['message'] ?? response.statusCode}',
          );
        }
      }
    } catch (e) {
      // 오류 발생 시 로그만 출력
    }
  }

  /// 신청자 카드 — 카드 본체 탭 시 선택(녹색 강조), 하단 중앙 "더보기" 버튼은
  /// 신청자 상세 시트로 진입. read-only(헌혈마감/완료 탭 등)에서는 카드 탭도
  /// 상세 시트로 진입.
  Widget _buildApplicantSelectableRow({
    required BuildContext rowContext,
    required Map<String, dynamic> applicant,
    required bool isManageMode,
    required bool isSelected,
    required VoidCallback? onToggle,
  }) {
    final petInfo = applicant['pet_info'] as Map<String, dynamic>? ?? {};
    final lastDonationDate = petInfo['last_donation_date'];
    final lastDonationText =
        (lastDonationDate == null || lastDonationDate.toString().isEmpty)
            ? '첫 헌혈을 기다리는 중'
            : TimeFormatUtils.formatFlexibleDate(lastDonationDate);

    // 강조: 관리 모드는 선택된 행만, 읽기 전용은 status=APPROVED 행.
    final isApprovedReadOnly = !isManageMode && applicant['status'] == 1;
    final highlight = isSelected || isApprovedReadOnly;

    final bgColor = highlight
        ? AppTheme.success.withValues(alpha: 0.12)
        : AppTheme.veryLightGray;
    final borderColor =
        highlight ? AppTheme.success : AppTheme.lightGray;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(
          color: borderColor,
          width: highlight ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 카드 본체 — 탭 시 선택 토글(또는 read-only면 상세 시트).
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle ??
                () => showApplicantDetailBottomSheet(rowContext, applicant),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  PetProfileImage(
                    profileImage: petInfo['profile_image'],
                    species: petInfo['species'],
                    radius: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          applicant['nickname'] ??
                              applicant['name'] ??
                              '이름 없음',
                          style: AppTheme.bodyLargeStyle.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${petInfo['name'] ?? '이름 없음'} | ${petInfo['breed'] ?? ''} | ${petInfo['blood_type'] ?? ''}',
                          style: AppTheme.bodyMediumStyle
                              .copyWith(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '최근 헌혈일: $lastDonationText',
                          style: AppTheme.bodyMediumStyle
                              .copyWith(color: AppTheme.textTertiary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: borderColor.withValues(alpha: 0.4)),
          // 하단 중앙 "더보기" — 카드 탭과 별도 핫스팟으로 상세 시트 진입.
          Center(
            child: TextButton(
              onPressed: () =>
                  showApplicantDetailBottomSheet(rowContext, applicant),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                '더보기',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 일괄 마감 버튼 — "마감 (선정 N명 · 미선정 M명)" 카운트 라벨.
  Widget _buildBatchCloseButton({
    required int selectedCount,
    required int unselectedCount,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          '마감 (선정 $selectedCount명 · 미선정 $unselectedCount명)',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// 마감 해제 버튼 — 헌혈모집 탭에서 이미 마감된 시간대용.
  Widget _buildReopenButton({required VoidCallback onPressed}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.green,
          side: const BorderSide(color: Colors.green),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text(
          '마감 해제',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// 일괄 마감 확인 시트 — 선정/미선정 카운트와 안내 문구를 보여주고
  /// 사용자가 확정하면 [_executeBatchClose]가 diff approve/pend → close API
  /// 까지 처리. 성공 시 _closeTimeSlot이 confirmation + 신청자 시트를 모두 pop.
  void _showBatchCloseConfirmation({
    required int timeSlotId,
    required String date,
    required String time,
    required Map<String, dynamic> post,
    required StateSetter onUpdate,
    required List<Map<String, dynamic>> applicants,
    required Set<int> selectedIds,
    required Set<int> initialApprovedIds,
  }) {
    final selectedCount = selectedIds.length;
    final unselectedCount = applicants.length - selectedCount;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext confirmContext) {
        bool isProcessing = false;
        return StatefulBuilder(
          builder: (context, setConfirmState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    '마감 확인',
                    style: AppTheme.h3Style
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${TimeFormatUtils.formatDateWithWeekday(date)} ${TimeFormatUtils.formatTime(time)}',
                    style: AppTheme.bodyLargeStyle,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.veryLightGray,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '$selectedCount명',
                                style: AppTheme.h3Style.copyWith(
                                  color: AppTheme.success,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text('선정',
                                  style: AppTheme.bodySmallStyle.copyWith(
                                      color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                        Container(
                            width: 1, height: 36, color: AppTheme.lightGray),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '$unselectedCount명',
                                style: AppTheme.h3Style.copyWith(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text('미선정',
                                  style: AppTheme.bodySmallStyle.copyWith(
                                      color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    selectedCount == 0
                        ? unselectedCount == 0
                            ? '신청자가 없는 상태로 마감합니다.'
                            : '선정자 없이 마감합니다.\n미선정 $unselectedCount명은 자동으로 종결됩니다.'
                        : unselectedCount == 0
                            ? '모든 신청자가 선정되었습니다.'
                            : '미선정 $unselectedCount명은 자동으로 종결됩니다.',
                    style: AppTheme.bodyMediumStyle
                        .copyWith(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: isProcessing
                        ? null
                        : () async {
                            setConfirmState(() => isProcessing = true);
                            final ok = await _executeBatchClose(
                              timeSlotId: timeSlotId,
                              post: post,
                              onUpdate: onUpdate,
                              selectedIds: selectedIds,
                              initialApprovedIds: initialApprovedIds,
                            );
                            // 성공 시 _closeTimeSlot이 confirmation + 신청자 시트를
                            // 모두 pop. 실패 시 confirmation은 살아있으므로 버튼만
                            // 다시 활성화.
                            if (!ok && mounted) {
                              setConfirmState(() => isProcessing = false);
                            }
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.red),
                            ),
                          )
                        : const Text('마감',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 일괄 마감 실행 — 선택 diff로 APPROVE/PEND를 일괄 호출, 모두 성공하면 시간대 마감.
  /// 부분 실패 시 마감은 진행하지 않고 false 반환.
  Future<bool> _executeBatchClose({
    required int timeSlotId,
    required Map<String, dynamic> post,
    required StateSetter onUpdate,
    required Set<int> selectedIds,
    required Set<int> initialApprovedIds,
  }) async {
    final toApprove = selectedIds.difference(initialApprovedIds).toList();
    final toPend = initialApprovedIds.difference(selectedIds).toList();

    final failures = <int>[];
    for (final id in toApprove) {
      if (!await _approveSilent(id)) failures.add(id);
    }
    for (final id in toPend) {
      if (!await _pendSilent(id)) failures.add(id);
    }

    if (failures.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${failures.length}건의 신청자 상태 업데이트에 실패했습니다. 다시 시도해주세요.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    // 시간대 마감 — _closeTimeSlot이 confirmation + applicant 시트를 모두 pop하고
    // 상세 시트의 setState로 뱃지를 갱신.
    await _closeTimeSlot(post, timeSlotId, onUpdate);
    return true;
  }

  // 시간대 마감 해제 확인 다이얼로그
  void _showReopenConfirmationDialog(
    int timeSlotId,
    String date,
    String time,
    Map<String, dynamic> post,
    StateSetter onUpdate,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            '마감 해제 확인',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${TimeFormatUtils.formatDateWithWeekday(date)} ${TimeFormatUtils.formatTime(time)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '이 시간대의 마감을 해제하시겠습니까?\n승인된 신청자가 대기 상태로 변경됩니다.',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _reopenTimeSlot(timeSlotId, post, onUpdate);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('마감 해제'),
            ),
          ],
        );
      },
    );
  }

  // 시간대 마감 해제 API 호출.
  // _closeTimeSlot과 동일한 패턴 — 응답 의존(updated_time_slot) 제거하고
  // 호출자가 넘긴 timeSlotId로 직접 status=0을 박는다. 상세 시트는 닫지 않고
  // onUpdate(setState)로 뱃지/버튼만 즉시 갱신.
  Future<void> _reopenTimeSlot(
    int timeSlotId,
    Map<String, dynamic> post,
    StateSetter onUpdate,
  ) async {
    try {
      final url = Uri.parse(
        '${Config.serverUrl}/api/admin/time-slots/$timeSlotId/reopen',
      );
      final response = await AuthHttpClient.patch(url);

      if (response.statusCode == 200) {
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        final int postStatus =
            responseData['post_status'] ?? post['status'] ?? 1;

        // id 키가 응답마다 (id / idx / post_times_idx) 다르고 int/String도 섞여
        // 들어오므로 toString 비교로 통일.
        final timeRanges = post['timeRanges'] as List<dynamic>? ?? [];
        final targetIdStr = timeSlotId.toString();
        final timeSlotIndex = timeRanges.indexWhere((ts) {
          final raw = ts['id'] ?? ts['idx'] ?? ts['post_times_idx'];
          return raw != null && raw.toString() == targetIdStr;
        });

        if (mounted) {
          onUpdate(() {
            if (timeSlotIndex != -1) {
              timeRanges[timeSlotIndex]['status'] = 0;
            }
            post['status'] = postStatus;
          });

          // 신청자 관리 시트만 닫음. 상세 시트는 유지.
          Navigator.of(context).pop();
        }

        // 부모 탭 목록 백그라운드 새로고침.
        if (mounted) {
          await _fetchDataForCurrentTab();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('마감 해제에 실패했습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('마감 해제 처리 중 오류: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 상세 게시글을 새로고침하고 다시 여는 메서드
  Future<void> _refreshAndReopenPostDetail(
    Map<String, dynamic> post,
    String postStatus,
    String postType,
  ) async {
    try {
      // 1. 상세 게시글 모달 닫기
      Navigator.of(context).pop();

      // 2. 잠깐 대기 (모달 닫기 완료)
      await Future.delayed(const Duration(milliseconds: 100));

      // 3. 최신 데이터 가져오기
      await _fetchDataForCurrentTab();

      // 4. 게시글 데이터는 자식 위젯이 갱신했으므로, 호출자가 넘긴 post의 변경된
      //    필드(status 등)를 사용해 상세 모달 다시 열기.
      _openPostDetailSheet(
        post,
        _getPostStatus(post['status']),
        post['types'] == 0 ? '긴급' : '정기',
      );
    } catch (e) {
      // 게시글 새로고침 실패 시 로그 출력
      debugPrint('Failed to refresh post detail: $e');
    }
  }

  // 헌혈마감 탭에서 신청자 및 반려견 정보 표시
  /// 헌혈 자료 요청
  Future<void> _requestDocuments(int applicationId) async {
    try {
      final response = await AuthHttpClient.post(
        Uri.parse(
            '${Config.serverUrl}${ApiEndpoints.donationRequestDocuments}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'applicationId': applicationId}),
      );

      if (!mounted) return;

      String title;
      String message;
      if (response.statusCode == 200) {
        title = '자료 요청 완료';
        message = '자료 요청이 전송되었습니다.';
      } else if (response.statusCode == 409) {
        title = '자료 요청 안내';
        message = '이미 오늘 자료 요청을 보냈습니다.\n내일 다시 요청할 수 있습니다.';
      } else {
        final data = jsonDecode(response.body);
        title = '자료 요청 실패';
        message = data['detail'] ?? '자료 요청에 실패했습니다.';
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('오류'),
            content: const Text('자료 요청 중 오류가 발생했습니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    }
  }

  // 게시글 타입 결정 (헬퍼 함수)
  String _getPostType(Map<String, dynamic> post) {
    if (_currentTabIndex == 2) {
      // 헌혈마감 탭: 게시글 모집마감(3)/applied_donation 완료대기(2) 구분
      return post['status'] == 2 ? '완료대기' : '마감';
    } else if (_currentTabIndex == 1) {
      // 헌혈모집 탭: CLOSED(3)이면 [마감], 아니면 긴급/정기 (PostType 미러).
      // 모집대기 탭과 동일한 패턴 — 게시글 본질(긴급/정기)을 일관되게 노출.
      if (post['status'] == 3) return '마감';
      return post['types'] == 0 ? '긴급' : '정기';
    } else if (_currentTabIndex == 3) {
      // 헌혈완료 탭에서는 완료 뱃지 표시
      return '완료';
    } else {
      // 모집대기 탭: SUSPENDED(5)이면 [대기] 뱃지, 아니면 긴급/정기
      if (post['status'] == 5) return '대기';
      return post['types'] == 0 ? '긴급' : '정기';
    }
  }

  // 게시글 전체 마감 API 호출
  Future<void> _closeEntirePost(
    Map<String, dynamic> post,
    StateSetter onUpdate,
  ) async {
    try {
      final postIdx = post['id'];
      final url = Uri.parse(
        '${Config.serverUrl}/api/admin/posts/$postIdx/close',
      );
      final response = await AuthHttpClient.patch(url);

      if (response.statusCode == 200) {
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        final int newStatus = responseData['new_status'] ?? 3;

        // post 변수 업데이트 (호출자가 시트 재오픈 시 사용).
        if (mounted) {
          post['status'] = newStatus;
        }

        // 확인 바텀시트 닫기
        if (mounted) Navigator.of(context).pop();
        // 게시글 상세 바텀시트 닫기
        if (mounted) Navigator.of(context).pop();

        // 마감 처리 후 현재 탭 데이터 새로고침. _closeEntirePost는 Tab 1 시트에서만
        // 호출되므로 _activeTabKey로 위임.
        if (mounted) {
          await _activeTabKey.currentState?.refresh();
          if (!mounted) return;

          // SnackBar 대신 AlertDialog로 결과 안내 + 어느 탭에서 볼 수 있는지 명시.
          // newStatus == 4: 신청자 0명 → COMPLETED 직행 (헌혈완료 탭)
          // newStatus == 3: 신청자 ≥1명 → CLOSED (헌혈마감 탭)
          // 자동 탭 이동은 하지 않음 (관리자 흐름 방해 우려, 운영 결정).
          final body = newStatus == AppConstants.postStatusCompleted
              ? DialogMsg.postCloseNoApplicantBody
              : DialogMsg.postCloseWithApplicantBody;
          await showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text(DialogMsg.postCloseCompleteTitle),
              content: Text(body),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(DialogMsg.postCloseButton),
                ),
              ],
            ),
          );
        }
      } else {
        if (mounted) {
          Navigator.of(context).pop();
        }
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorData['detail'] ?? errorData['message'] ?? '마감 처리에 실패했습니다.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 게시글 전체 재오픈 API 호출
  Future<void> _reopenEntirePost(
    Map<String, dynamic> post,
    StateSetter onUpdate,
  ) async {
    try {
      final postIdx = post['id'];
      final url = Uri.parse(
        '${Config.serverUrl}/api/admin/posts/$postIdx/reopen',
      );
      final response = await AuthHttpClient.patch(url);

      if (response.statusCode == 200) {
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        final int newStatus = responseData['new_status'] ?? 1;

        // post 변수 업데이트 (호출자가 시트 재오픈 시 사용).
        if (mounted) {
          post['status'] = newStatus;
          // post의 시간대 상태도 초기화 (재오픈으로 모든 시간대가 모집중)
          final postTimeRanges = post['timeRanges'] as List<dynamic>? ?? [];
          for (var ts in postTimeRanges) {
            ts['status'] = 0;
          }
        }

        // 확인 창 닫기
        if (mounted) {
          Navigator.of(context).pop();
        }

        // 상세 게시글 새로고침
        if (mounted) {
          await _refreshAndReopenPostDetail(
            post,
            _getPostStatus(newStatus),
            post['types'] == 0 ? '긴급' : '정기',
          );
        }

        // 재오픈 처리 후 전체 데이터 새로고침
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          await _fetchDataForCurrentTab();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('게시글이 성공적으로 재오픈되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          Navigator.of(context).pop();
        }
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorData['detail'] ?? errorData['message'] ?? '재오픈 처리에 실패했습니다.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 게시글 전체 재오픈 확인 다이얼로그
  void _showReopenPostConfirmationSheet(
    Map<String, dynamic> post,
    StateSetter onUpdate,
  ) {
    bool isReopening = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '게시글 전체 재오픈',
                    style: AppTheme.h3Style.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    post['title'] ?? '제목 없음',
                    style: AppTheme.bodyLargeStyle,
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '게시글을 재오픈하면 모집중 상태로 변경되며, 승인된 신청자가 대기 상태로 변경됩니다.',
                            style: TextStyle(color: Colors.orange.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              isReopening
                                  ? null
                                  : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey,
                            side: const BorderSide(color: Colors.grey),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('취소'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              isReopening
                                  ? null
                                  : () async {
                                    setState(() {
                                      isReopening = true;
                                    });
                                    await _reopenEntirePost(post, onUpdate);
                                  },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child:
                              isReopening
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                  : const Text('재오픈 확정'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 게시글 전체 마감 확인 다이얼로그
  void _showClosePostConfirmationSheet(
    Map<String, dynamic> post,
    StateSetter onUpdate,
  ) {
    bool isClosing = false;

    // 마감 가드 완화 (백엔드 동기화 2026-04-29): 신청자 0명 / 선정 0명이어도
    // 백엔드가 마감 허용. 다이얼로그는 차단하지 않고 카운트·결과만 명확히 안내한다.
    // applicant_count / approved_count는 PostWithApplicationsResponse 정식 필드
    // (NOT NULL 보장). ?? 0은 dart type safety용 안전망일 뿐 분기 실효는 없음.
    final applicantCount = (post['applicant_count'] as num?)?.toInt() ?? 0;
    final approvedCount = (post['approved_count'] as num?)?.toInt() ?? 0;
    final hasOpenSlots = _hasOpenTimeSlots(post);

    // 신청자는 있는데 선정 0명일 때 가장 강조 (피드백 7번: 선정 안 한 채 마감)
    final bool emphasizeWarning =
        applicantCount > 0 && approvedCount == 0;
    final Color boxColor =
        emphasizeWarning ? Colors.orange.shade50 : AppTheme.lightBlue;
    final Color borderColor =
        emphasizeWarning ? Colors.orange.shade300 : AppTheme.lightGray;
    final Color textColor =
        emphasizeWarning ? Colors.orange.shade800 : AppTheme.primaryDarkBlue;
    final IconData boxIcon = emphasizeWarning
        ? Icons.warning_amber_rounded
        : Icons.info_outline;

    final String mainMessage;
    if (applicantCount == 0) {
      mainMessage = '신청자가 없는 상태로 마감됩니다.';
    } else if (approvedCount == 0) {
      mainMessage =
          '선정된 신청자 없이 마감됩니다.\n신청자 $applicantCount명은 자동으로 종결 처리됩니다.';
    } else {
      final unselected = applicantCount - approvedCount;
      mainMessage = unselected > 0
          ? '미선정 $unselected명은 자동으로 종결 처리됩니다.'
          : '모든 신청자가 선정되었습니다.';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '모든 시간대 게시글 마감',
                    style: AppTheme.h3Style.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    post['title'] ?? '제목 없음',
                    style: AppTheme.bodyLargeStyle,
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      _buildClosePostCountChip(
                        Icons.people_outline,
                        '신청 $applicantCount명',
                      ),
                      const SizedBox(width: 8),
                      _buildClosePostCountChip(
                        Icons.check_circle_outline,
                        '선정 $approvedCount명',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: boxColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(boxIcon, color: textColor, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            mainMessage,
                            style: TextStyle(color: textColor, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (hasOpenSlots) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '※ 열려 있는 시간대도 함께 마감됩니다.',
                        style: AppTheme.captionStyle.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              isClosing
                                  ? null
                                  : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black,
                            side: const BorderSide(color: Colors.black),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('취소'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              isClosing
                                  ? null
                                  : () async {
                                    setState(() {
                                      isClosing = true;
                                    });
                                    await _closeEntirePost(post, onUpdate);
                                  },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child:
                              isClosing
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.red,
                                      ),
                                    ),
                                  )
                                  : const Text('마감 확정'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildClosePostCountChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.lightGray),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTheme.bodySmallStyle.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  bool _hasOpenTimeSlots(Map<String, dynamic> post) {
    final timeRanges = post['timeRanges'] as List<dynamic>? ?? [];
    return timeRanges.any((ts) => ts['status'] == 0 || ts['status'] == null);
  }
}
