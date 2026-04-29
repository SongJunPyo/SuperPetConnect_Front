import 'package:flutter/material.dart';
import 'dart:convert';
import '../utils/app_theme.dart';
import '../utils/config.dart';
import '../utils/api_endpoints.dart';
import '../utils/phone_formatter.dart';
import '../models/user_model.dart';
import '../models/pet_model.dart';
import '../services/user_management_service.dart';
import '../services/auth_http_client.dart';
import '../models/unified_post_model.dart';
import '../widgets/app_dialog.dart';
import '../widgets/info_row.dart';
import '../widgets/post_type_badge.dart';
import '../widgets/pet_profile_image.dart';
import 'package:intl/intl.dart';

// 정지된 사용자용 바텀시트
class SuspendedUserBottomSheet extends StatefulWidget {
  final User user;
  final VoidCallback? onDeletePressed;

  const SuspendedUserBottomSheet({super.key, required this.user, this.onDeletePressed});

  @override
  State<SuspendedUserBottomSheet> createState() =>
      _SuspendedUserBottomSheetState();
}

class _SuspendedUserBottomSheetState extends State<SuspendedUserBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _daysController = TextEditingController();
  bool _isActivating = false;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _reasonController.text = widget.user.blacklistReason ?? '';
    _daysController.text = widget.user.remainingDays?.toString() ?? '7';
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  Future<void> _activateUser() async {
    final confirmed = await AppDialog.confirm(
      context,
      title: '계정 활성화',
      message: '${widget.user.name}님의 계정을 활성화하시겠습니까?',
      confirmLabel: '활성화',
    );

    if (confirmed != true) return;

    setState(() {
      _isActivating = true;
    });

    try {
      // Status 1 for 'Active'
      await UserManagementService.updateUserStatus(widget.user.accountIdx, 1);

      if (mounted) {
        Navigator.of(context).pop(true); // Pop bottom sheet and signal success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('계정이 활성화되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('활성화 실패: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isActivating = false;
        });
      }
    }
  }

  Future<void> _updateBlacklist() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final request = BlacklistRequest(
        accountIdx: widget.user.accountIdx,
        reason: _reasonController.text.trim(),
        suspensionDays: int.parse(_daysController.text),
      );

      await UserManagementService.blacklistUser(request);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('정지 정보가 수정되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('수정 실패: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '정지된 사용자',
                style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (widget.onDeletePressed != null)
                IconButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onDeletePressed!();
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: '계정 삭제',
                ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 사용자 기본 정보
          InfoRow(
            label: '이름',
            value: widget.user.name,
            padding: const EdgeInsets.only(bottom: 8),
          ),
          if (widget.user.nickname?.isNotEmpty == true)
            InfoRow(
              label: '닉네임',
              value: widget.user.nickname!,
              padding: const EdgeInsets.only(bottom: 8),
            ),
          InfoRow(
            label: '이메일',
            value: widget.user.email,
            padding: const EdgeInsets.only(bottom: 8),
          ),
          InfoRow(
            label: '전화번호',
            value: formatPhoneNumber(widget.user.phoneNumber),
            padding: const EdgeInsets.only(bottom: 8),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isActivating || _isUpdating ? null : _activateUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child:
                  _isActivating
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Text('계정 활성화'),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          Text(
            '정지 정보 수정',
            style: AppTheme.h4Style.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('정지 사유', style: AppTheme.bodyMediumStyle),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _reasonController,
                  decoration: InputDecoration(
                    hintText: '정지 사유를 입력하세요',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '정지 사유를 입력하세요';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text('정지 일수', style: AppTheme.bodyMediumStyle),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _daysController,
                  decoration: InputDecoration(
                    hintText: '정지할 일수를 입력하세요',
                    suffix: const Text('일'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '정지 일수를 입력하세요';
                    }
                    final days = int.tryParse(value);
                    if (days == null || days < 1) {
                      return '1일 이상 입력하세요';
                    }
                    if (days > 365) {
                      return '365일 이하로 입력하세요';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _isActivating || _isUpdating ? null : _updateBlacklist,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        _isUpdating
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Text('수정'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}

// 활성 사용자용 바텀시트 (탭 구조: 반려동물 / 신청내역)
class ActiveUserBottomSheet extends StatefulWidget {
  final User user;
  final VoidCallback? onBlacklistPressed;
  final VoidCallback? onDeletePressed;

  const ActiveUserBottomSheet({
    super.key,
    required this.user,
    this.onBlacklistPressed,
    this.onDeletePressed,
  });

  @override
  State<ActiveUserBottomSheet> createState() => _ActiveUserBottomSheetState();
}

class _ActiveUserBottomSheetState extends State<ActiveUserBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 신청내역 관련
  List<Map<String, dynamic>> _applications = [];
  bool _isLoadingApplications = false;
  String _selectedStatus = 'all';
  int _appCurrentPage = 1;
  int _appTotalPages = 1;
  final TextEditingController _appSearchController = TextEditingController();
  String _appSearchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;

  static const Map<String, String> _statusFilters = {
    'all': '전체',
    '0': '대기',
    '1': '승인',
    '7': '완료',
    '4': '취소',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _applications.isEmpty && !_isLoadingApplications) {
        _fetchApplications();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _appSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchApplications() async {
    setState(() => _isLoadingApplications = true);
    try {
      var queryStr = '${Config.serverUrl}${ApiEndpoints.adminUserApplications(widget.user.accountIdx)}?status=$_selectedStatus&page=$_appCurrentPage&page_size=10';
      if (_appSearchQuery.isNotEmpty) {
        queryStr += '&search=${Uri.encodeComponent(_appSearchQuery)}';
      }
      if (_startDate != null) {
        queryStr += '&start_date=${DateFormat('yyyy-MM-dd').format(_startDate!)}';
      }
      if (_endDate != null) {
        queryStr += '&end_date=${DateFormat('yyyy-MM-dd').format(_endDate!)}';
      }
      final url = Uri.parse(queryStr);
      final response = await AuthHttpClient.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _applications = List<Map<String, dynamic>>.from(data['applications'] ?? []);
          _appTotalPages = data['total_pages'] ?? 1;
          _isLoadingApplications = false;
        });
      } else {
        setState(() => _isLoadingApplications = false);
      }
    } catch (e) {
      setState(() => _isLoadingApplications = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Text(
                  '사용자 정보',
                  style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (widget.onDeletePressed != null)
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onDeletePressed!();
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: '계정 삭제',
                  ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          // 대표 반려동물 프로필 사진
          if (widget.user.pets.isNotEmpty) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: PetProfileImage(
                  profileImage: widget.user.pets
                      .where((p) => p.isPrimary)
                      .firstOrNull
                      ?.profileImage ??
                      widget.user.pets.first.profileImage,
                  species: widget.user.pets.first.species,
                  radius: 36,
                ),
              ),
            ),
          ],
          // 사용자 기본 정보
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                InfoRow(
                  label: '이름',
                  value: widget.user.name,
                  padding: const EdgeInsets.only(bottom: 12),
                ),
                if (widget.user.nickname?.isNotEmpty == true)
                  InfoRow(
                    label: '닉네임',
                    value: widget.user.nickname!,
                    padding: const EdgeInsets.only(bottom: 12),
                  ),
                InfoRow(
                  label: '이메일',
                  value: widget.user.email,
                  padding: const EdgeInsets.only(bottom: 12),
                ),
                InfoRow(
                  label: '전화번호',
                  value: formatPhoneNumber(widget.user.phoneNumber),
                  padding: const EdgeInsets.only(bottom: 12),
                ),
                InfoRow(
                  label: '주소',
                  value: widget.user.address,
                  padding: const EdgeInsets.only(bottom: 12),
                ),
                InfoRow(
                  label: '상태',
                  value: widget.user.statusText,
                  padding: const EdgeInsets.only(bottom: 12),
                ),
                if (widget.user.createdAt != null)
                  InfoRow(
                    label: '가입일',
                    value: DateFormat('yyyy-MM-dd HH:mm:ss')
                        .format(widget.user.createdAt!),
                    padding: const EdgeInsets.only(bottom: 12),
                  ),
              ],
            ),
          ),
          // 탭 바
          TabBar(
            controller: _tabController,
            labelColor: AppTheme.textPrimary,
            unselectedLabelColor: AppTheme.textTertiary,
            indicatorColor: AppTheme.primaryBlue,
            tabs: const [
              Tab(text: '반려동물'),
              Tab(text: '신청내역'),
            ],
          ),
          // 탭 뷰
          Flexible(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPetsTab(),
                _buildApplicationsTab(),
              ],
            ),
          ),
          // 블랙리스트 버튼
          if (widget.onBlacklistPressed != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onBlacklistPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('블랙리스트 지정'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 반려동물 탭
  Widget _buildPetsTab() {
    if (widget.user.pets.isEmpty) {
      return const Center(
        child: Text('등록된 반려동물이 없습니다.', style: TextStyle(color: AppTheme.textTertiary)),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: widget.user.pets.map((pet) => _buildPetInfo(pet)).toList(),
    );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      locale: const Locale('ko', 'KR'),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _appCurrentPage = 1;
      });
      _fetchApplications();
    }
  }

  // 신청내역 탭
  Widget _buildApplicationsTab() {
    return Column(
      children: [
        // 검색 + 기간 필터
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _appSearchController,
                    decoration: InputDecoration(
                      hintText: '병원명, 게시글 검색',
                      hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                      prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textTertiary),
                      suffixIcon: _appSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _appSearchController.clear();
                                setState(() {
                                  _appSearchQuery = '';
                                  _appCurrentPage = 1;
                                });
                                _fetchApplications();
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                      ),
                    ),
                    style: const TextStyle(fontSize: 12),
                    onChanged: (value) {
                      setState(() {
                        _appSearchQuery = value.trim();
                        _appCurrentPage = 1;
                      });
                      _fetchApplications();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.calendar_today, size: 14),
                  label: Text(
                    _startDate != null && _endDate != null
                        ? '${DateFormat('MM.dd').format(_startDate!)}~${DateFormat('MM.dd').format(_endDate!)}'
                        : '기간',
                    style: const TextStyle(fontSize: 11),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _startDate != null ? AppTheme.primaryBlue : AppTheme.textSecondary,
                    side: BorderSide(
                      color: _startDate != null ? AppTheme.primaryBlue : Colors.grey.shade300,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              if (_startDate != null) ...[
                const SizedBox(width: 4),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.close, size: 14, color: AppTheme.textTertiary),
                    onPressed: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                        _appCurrentPage = 1;
                      });
                      _fetchApplications();
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        // 필터 칩
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: _statusFilters.entries.map((entry) {
              final isSelected = _selectedStatus == entry.key;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ChoiceChip(
                    label: SizedBox(
                      width: double.infinity,
                      child: Text(entry.value, textAlign: TextAlign.center),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedStatus = entry.key;
                        _appCurrentPage = 1;
                      });
                      _fetchApplications();
                    },
                    selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
                    showCheckmark: false,
                    labelPadding: EdgeInsets.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: isSelected ? AppTheme.primaryBlue : AppTheme.textSecondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        // 목록
        Expanded(
          child: _isLoadingApplications
              ? const Center(child: CircularProgressIndicator())
              : _applications.isEmpty
                  ? const Center(
                      child: Text('신청내역이 없습니다.', style: TextStyle(color: AppTheme.textTertiary)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _applications.length,
                      itemBuilder: (context, index) => _buildApplicationCard(_applications[index]),
                    ),
        ),
        // 페이지네이션
        if (_appTotalPages > 1)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _appCurrentPage > 1
                      ? () {
                          setState(() => _appCurrentPage--);
                          _fetchApplications();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_left, size: 20),
                ),
                Text('$_appCurrentPage / $_appTotalPages', style: const TextStyle(fontSize: 12)),
                IconButton(
                  onPressed: _appCurrentPage < _appTotalPages
                      ? () {
                          setState(() => _appCurrentPage++);
                          _fetchApplications();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_right, size: 20),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> app) {
    final status = app['status'] as int? ?? 0;
    final statusKr = app['status_kr'] as String? ?? '';
    final pet = app['pet'] as Map<String, dynamic>? ?? {};
    final post = app['post'] as Map<String, dynamic>? ?? {};
    final donationDateRaw = app['donation_date'] as String? ?? '';
    final completed = app['completed'] as Map<String, dynamic>?;
    final cancelled = app['cancelled'] as Map<String, dynamic>?;
    final postIdx = post['post_idx'] as int?;

    // 날짜에서 시간 부분 제거
    final donationDate = donationDateRaw.contains(' ')
        ? donationDateRaw.split(' ')[0]
        : donationDateRaw.contains('T')
            ? donationDateRaw.split('T')[0]
            : donationDateRaw;

    Color statusColor;
    switch (status) {
      case 0: statusColor = AppTheme.warning; break;
      case 1: statusColor = AppTheme.info; break;
      case 2: statusColor = Colors.orange; break;
      case 3: statusColor = AppTheme.success; break;
      case 4: statusColor = AppTheme.error; break;
      default: statusColor = AppTheme.textTertiary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.veryLightGray,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 게시글 이동 영역 (날짜, 제목, 반려동물 정보, 완료 정보)
          GestureDetector(
            onTap: postIdx != null ? () => _navigateToPost(postIdx) : null,
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 날짜 + 상태
                Row(
                  children: [
                    Text(
                      donationDate,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusKr,
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // 게시글 제목
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        post['title'] ?? '',
                        style: AppTheme.bodyMediumStyle.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (postIdx != null)
                      const Icon(Icons.chevron_right, size: 16, color: AppTheme.textTertiary),
                  ],
                ),
                const SizedBox(height: 4),
                // 반려동물 정보
                Text(
                  '${pet['name'] ?? ''} | ${pet['blood_type'] ?? ''}',
                  style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.textSecondary),
                ),
                // 완료 정보
                if (completed != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '채혈량: ${completed['blood_volume']}ml',
                    style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.success),
                  ),
                ],
              ],
            ),
          ),
          // 헌혈완료 — 자료 요청 버튼 (카드 탭과 분리)
          if (status == 3) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _requestDocuments(
                  app['applied_donation_idx'] as int? ?? 0,
                ),
                icon: const Icon(Icons.description_outlined, size: 16),
                label: const Text('자료 요청'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textPrimary,
                  side: BorderSide(color: AppTheme.mediumGray),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
          // 취소 정보
          if (cancelled != null) ...[
            const SizedBox(height: 4),
            Text(
              '사유: ${cancelled['cancelled_reason'] ?? ''} (${cancelled['cancelled_subject_kr'] ?? ''})',
              style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.error),
            ),
          ],
        ],
      ),
    );
  }

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

  Future<void> _navigateToPost(int postIdx) async {
    // 관리자용 API 사용 (완료/취소 상태 게시글도 조회 가능)
    UnifiedPostModel? post;
    try {
      final response = await AuthHttpClient.get(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.adminPosts}/$postIdx'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        post = UnifiedPostModel.fromJson(data);
      }
    } catch (_) {}
    if (!mounted || post == null) return;
    final postData = post;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                      children: [
                        PostTypeBadge(type: postData.isUrgent ? '긴급' : '정기'),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            postData.title,
                            style: AppTheme.h3Style.copyWith(
                              color: postData.isUrgent ? Colors.red : AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // 콘텐츠
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 기본 정보
                          _postDetailRow(Icons.business, '병원명', postData.hospitalNickname ?? postData.hospitalName),
                          const SizedBox(height: 8),
                          _postDetailRow(Icons.location_on, '주소', postData.location),
                          const SizedBox(height: 8),
                          _postDetailRow(Icons.pets, '동물 종류', postData.animalType == 0 ? '강아지' : '고양이'),
                          const SizedBox(height: 8),
                          if (postData.bloodType != null && postData.bloodType!.isNotEmpty) ...[
                            _postDetailRow(Icons.bloodtype, '혈액형', postData.bloodType!),
                            const SizedBox(height: 8),
                          ],
                          _postDetailRow(Icons.calendar_today, '게시일', postData.createdDate.toString().split(' ')[0]),
                          // 헌혈 날짜
                          if (postData.donationDate != null) ...[
                            const SizedBox(height: 8),
                            _postDetailRow(Icons.event, '헌혈 날짜', postData.donationDate.toString().split(' ')[0]),
                          ],
                          // 수혈환자 정보 (긴급)
                          if (postData.isUrgent) ...[
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),
                            const Text('수혈환자 정보', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            if (postData.patientName != null)
                              _postDetailRow(Icons.pets, '환자명', postData.patientName!),
                            if (postData.breed != null) ...[
                              const SizedBox(height: 8),
                              _postDetailRow(Icons.category, '품종', postData.breed!),
                            ],
                            if (postData.age != null) ...[
                              const SizedBox(height: 8),
                              _postDetailRow(Icons.cake, '나이', '${postData.age}살'),
                            ],
                            if (postData.diagnosis != null) ...[
                              const SizedBox(height: 8),
                              _postDetailRow(Icons.medical_services, '진단', postData.diagnosis!),
                            ],
                          ],
                          // 시간대 정보
                          if (postData.timeRanges != null && postData.timeRanges!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),
                            const Text('시간대', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            ...postData.timeRanges!.map((tr) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time, size: 14, color: AppTheme.textTertiary),
                                  const SizedBox(width: 8),
                                  Text(
                                    tr.time,
                                    style: AppTheme.bodySmallStyle,
                                  ),
                                ],
                              ),
                            )),
                          ],
                          // 본문
                          if (postData.description.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),
                            const Text('상세 내용', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Text(postData.description, style: AppTheme.bodyMediumStyle),
                          ],
                          // 통계
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _statChip(Icons.visibility, '조회 ${postData.viewCount}'),
                              const SizedBox(width: 12),
                              _statChip(Icons.people, '신청 ${postData.applicantCount}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _statChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.veryLightGray,
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textTertiary),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _postDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Text('$label: ', style: AppTheme.bodyMediumStyle.copyWith(fontWeight: FontWeight.w500, color: Colors.grey[700])),
        Expanded(child: Text(value, style: AppTheme.bodyMediumStyle)),
      ],
    );
  }

  Widget _buildPetInfo(Pet pet) {
    Color badgeColor;
    String badgeText;
    switch (pet.approvalStatus) {
      case 1:
        badgeColor = AppTheme.success;
        badgeText = '승인됨';
        break;
      case 2:
        badgeColor = AppTheme.error;
        badgeText = '거절됨';
        break;
      default:
        badgeColor = AppTheme.warning;
        badgeText = '승인 대기';
    }

    return GestureDetector(
      onTap: pet.petIdx != null ? () => _showPetHistory(pet) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.veryLightGray,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PetProfileImage(
                  profileImage: pet.profileImage,
                  species: pet.species,
                  radius: 16,
                ),
                const SizedBox(width: 8),
                if (pet.isPrimary)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.star, size: 14, color: AppTheme.warning),
                  ),
                Expanded(
                  child: Text(
                    pet.name,
                    style: AppTheme.bodyMediumStyle.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 16, color: AppTheme.textTertiary),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              pet.summaryLine,
              style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.textSecondary),
            ),
            if (pet.approvalStatus == 2 && pet.rejectionReason != null) ...[
              const SizedBox(height: 4),
              Text(
                '사유: ${pet.rejectionReason}',
                style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showPetHistory(Pet pet) async {
    List<Map<String, dynamic>> petApplications = [];
    bool isLoading = true;
    int totalBloodVolume = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            if (isLoading) {
              _fetchPetApplications(pet.petIdx!).then((result) {
                setSheetState(() {
                  petApplications = result;
                  isLoading = false;
                  for (final app in petApplications) {
                    final completed = app['completed'] as Map<String, dynamic>?;
                    if (completed != null && app['status'] == 3) {
                      totalBloodVolume += ((completed['blood_volume'] ?? 0) as num).toInt();
                    }
                  }
                });
              });
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${pet.name} 헌혈 이력',
                        style: AppTheme.h4Style.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Text(pet.summaryLine, style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  if (!isLoading)
                    Wrap(
                      spacing: 8,
                      children: [
                        _statChip(Icons.check_circle, '완료 ${petApplications.where((a) => a['status'] == 3).length}건'),
                        if (totalBloodVolume > 0)
                          _statChip(Icons.bloodtype, '총 ${totalBloodVolume}ml'),
                      ],
                    ),
                  const SizedBox(height: 12),
                  const Divider(),
                  Flexible(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : petApplications.isEmpty
                            ? const Center(child: Text('헌혈 이력이 없습니다.', style: TextStyle(color: AppTheme.textTertiary)))
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: petApplications.length,
                                itemBuilder: (ctx, index) => _buildApplicationCard(petApplications[index]),
                              ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchPetApplications(int petIdx) async {
    try {
      final url = Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.adminUserApplications(widget.user.accountIdx)}?page=1&page_size=50',
      );
      final response = await AuthHttpClient.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final allApps = List<Map<String, dynamic>>.from(data['applications'] ?? []);
        return allApps.where((app) {
          final petData = app['pet'] as Map<String, dynamic>?;
          final appPetIdx = petData?['pet_idx'] as int?;
          final status = app['status'] as int?;
          return appPetIdx == petIdx && status == 3;
        }).toList();
      }
    } catch (_) {}
    return [];
  }

}
