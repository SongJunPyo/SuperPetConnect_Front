import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../utils/app_constants.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/pagination_bar.dart';
import '../models/user_model.dart';
import '../services/user_management_service.dart';
import 'admin_user_check_bottom_sheets.dart';

class AdminUserCheck extends StatefulWidget {
  const AdminUserCheck({super.key});

  @override
  State<AdminUserCheck> createState() => _AdminUserCheckState();
}

class _AdminUserCheckState extends State<AdminUserCheck>
    with TickerProviderStateMixin {
  late TabController _tabController;

  List<User> users = []; // 현재 페이지에 표시할 사용자
  bool isLoading = true;
  String? errorMessage;

  TextEditingController searchController = TextEditingController();
  String searchQuery = '';
  int? statusFilter;

  // 서버 측 페이지네이션
  int _currentPage = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {
        users = [];
        _currentPage = 1;
        searchQuery = '';
        searchController.clear();

        switch (_tabController.index) {
          case 0:
            statusFilter = 1;
            break;
          case 1:
            statusFilter = 2;
            break;
        }
      });
      _loadUsers();
    }
  }

  Future<void> _loadData() async {
    await _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      setState(() {
        users = [];
        isLoading = true;
        errorMessage = null;
      });

      final response = await UserManagementService.getUsers(
        page: _currentPage,
        pageSize: AppConstants.detailListPageSize,
        search: searchQuery.isNotEmpty ? searchQuery : null,
        status: statusFilter,
      );

      setState(() {
        users = response.users;
        _currentPage = response.currentPage;
        _totalPages = response.totalPages;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  void _onPageChanged(int page) {
    _currentPage = page;
    _loadUsers();
  }

  void _onSearchChanged(String query) {
    setState(() {
      searchQuery = query;
      _currentPage = 1;
    });
    _loadUsers();
  }

  Future<void> _showBlacklistDialog(User user) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BlacklistBottomSheet(user: user),
    );

    if (result == true) {
      _loadData();
    }
  }

  Future<void> _showUserBottomSheet(User user) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) =>
              user.isActive
                  ? ActiveUserBottomSheet(
                    user: user,
                    onBlacklistPressed: () {
                      Navigator.of(context).pop();
                      _showBlacklistDialog(user);
                    },
                  )
                  : SuspendedUserBottomSheet(user: user),
    );

    if (result == true) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppAppBar(
        title: '사용자 관리',
        showBackButton: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          TabBar(
            controller: _tabController,
            labelColor: Colors.black87,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.black87,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, size: 20),
                    SizedBox(width: 8),
                    Text('활동'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.block, size: 20),
                    SizedBox(width: 8),
                    Text('정지'),
                  ],
                ),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildUserListView(), _buildUserListView()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: '이름, 이메일, 전화번호로 검색...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon:
              searchQuery.isNotEmpty
                  ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                  : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.lightGray),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.primaryBlue),
          ),
        ),
      ),
    );
  }

  Widget _buildUserListView() {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryBlue),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.error),
            const SizedBox(height: 16),
            Text('오류가 발생했습니다', style: AppTheme.h4Style),
            const SizedBox(height: 8),
            Text(errorMessage!, style: AppTheme.bodyMediumStyle),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _loadData, child: const Text('다시 시도')),
          ],
        ),
      );
    }

    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: AppTheme.mediumGray),
            const SizedBox(height: 16),
            Text('사용자가 없습니다', style: AppTheme.h4Style),
            if (searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('검색 결과가 없습니다', style: AppTheme.bodyMediumStyle),
            ],
          ],
        ),
      );
    }

    final int paginationBarCount = _totalPages > 1 ? 1 : 0;

    return Column(
      children: [
        // 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  '번호',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyMediumStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  '전화번호',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyMediumStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '사용자',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyMediumStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  '닉네임',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyMediumStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        // 사용자 목록
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() => _currentPage = 1);
              await _loadUsers();
            },
            color: AppTheme.primaryBlue,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 0),
              itemCount: users.length + paginationBarCount,
              itemBuilder: (context, index) {
                if (index >= users.length) {
                  return PaginationBar(
                    currentPage: _currentPage,
                    totalPages: _totalPages,
                    onPageChanged: _onPageChanged,
                  );
                }
                final user = users[index];
                final displayNumber = (_currentPage - 1) * AppConstants.detailListPageSize + index + 1;
                return _buildUserListItem(user, displayNumber);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserListItem(User user, int displayNumber) {
    return InkWell(
      onTap: () => _showUserBottomSheet(user),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 0),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        child: Row(
          children: [
            // 번호
            SizedBox(
              width: 36,
              child: Text(
                '$displayNumber',
                textAlign: TextAlign.center,
                style: AppTheme.bodyMediumStyle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ),

            // 전화번호
            Expanded(
              flex: 3,
              child: Text(
                _formatPhoneNumber(user.phoneNumber),
                textAlign: TextAlign.center,
                style: AppTheme.bodyMediumStyle.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // 사용자
            Expanded(
              flex: 2,
              child: Tooltip(
                message: user.name,
                child: Text(
                  user.name,
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyMediumStyle.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // 닉네임
            Expanded(
              flex: 3,
              child: Tooltip(
                message:
                    user.nickname?.isNotEmpty == true
                        ? user.nickname!
                        : user.name,
                child: Text(
                  user.nickname?.isNotEmpty == true
                      ? user.nickname!
                      : user.name,
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyMediumStyle.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 전화번호 포맷팅 헬퍼 메서드
  String _formatPhoneNumber(String phoneNumber) {
    if (phoneNumber.length != 11) return phoneNumber;
    return '${phoneNumber.substring(0, 3)}-${phoneNumber.substring(3, 7)}-${phoneNumber.substring(7)}';
  }
}

class _BlacklistBottomSheet extends StatefulWidget {
  final User user;

  const _BlacklistBottomSheet({required this.user});

  @override
  State<_BlacklistBottomSheet> createState() => _BlacklistBottomSheetState();
}

class _BlacklistBottomSheetState extends State<_BlacklistBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _daysController = TextEditingController(text: '7');
  bool _isLoading = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
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
            content: Text('블랙리스트에 등록되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('등록 실패: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
                '블랙리스트 지정',
                style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.user.name}님을 블랙리스트에 등록합니다.',
            style: AppTheme.bodyMediumStyle.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
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
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Text('등록'),
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
