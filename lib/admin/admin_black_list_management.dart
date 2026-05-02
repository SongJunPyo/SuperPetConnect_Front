// admin/admin_black_list_management.dart

import 'package:flutter/material.dart';
import '../utils/app_constants.dart';
import '../utils/app_theme.dart';
import '../utils/pet_field_icons.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/pagination_bar.dart';
import '../models/black_list_model.dart';
import '../services/black_list_service.dart';
import 'package:intl/intl.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_search_bar.dart';
import '../widgets/info_row.dart';
import '../widgets/state_view.dart';

class AdminBlackListManagementScreen extends StatefulWidget {
  const AdminBlackListManagementScreen({super.key});

  @override
  State<AdminBlackListManagementScreen> createState() =>
      _AdminBlackListManagementScreenState();
}

class _AdminBlackListManagementScreenState
    extends State<AdminBlackListManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  List<BlackList> blackLists = [];
  bool isLoading = true;
  String? errorMessage;

  // 검색 및 필터링
  TextEditingController searchController = TextEditingController();
  String searchQuery = '';
  bool? currentFilter; // null: 전체, true: 정지 중, false: 해제됨

  // 페이징
  int currentPage = 1;
  int totalPages = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        currentPage = 1;
        searchQuery = '';
        searchController.clear();

        // 탭에 따라 필터 설정
        switch (_tabController.index) {
          case 0: // 전체
            currentFilter = null;
            break;
          case 1: // 정지 중
            currentFilter = true;
            break;
          case 2: // 해제됨
            currentFilter = false;
            break;
        }
      });
      _loadBlackLists();
    }
  }

  Future<void> _loadData() async {
    await _loadBlackLists();
  }

  Future<void> _loadBlackLists() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      const pageSize = AppConstants.detailListPageSize;
      final response = await BlackListService.getBlackLists(
        page: currentPage,
        pageSize: pageSize,
        search: searchQuery.isNotEmpty ? searchQuery : null,
        activeOnly: currentFilter,
      );

      setState(() {
        blackLists = response.blackLists;
        totalPages = response.totalCount == 0
            ? 1
            : (response.totalCount / pageSize).ceil();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      searchQuery = query;
      currentPage = 1;
    });
    _loadBlackLists();
  }

  void _onPageChanged(int page) {
    setState(() => currentPage = page);
    _loadBlackLists();
  }

  Future<void> _showCreateDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _CreateBlackListDialog(),
    );

    if (result == true) {
      _loadData();
    }
  }

  Future<void> _showEditDialog(BlackList blackList) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _EditBlackListDialog(blackList: blackList),
    );

    if (result == true) {
      _loadData();
    }
  }

  Future<void> _showDetailDialog(BlackList blackList) async {
    await showDialog(
      context: context,
      builder: (context) => _DetailBlackListDialog(blackList: blackList),
    );
  }

  Future<void> _releaseBlackList(BlackList blackList) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: '즉시 해제',
      message: '${blackList.userName}님을 즉시 해제하시겠습니까?\n\n'
          '남은 정지 일수: ${blackList.dDay}일',
      confirmLabel: '해제',
    );

    if (confirmed != true) return;

    try {
      await BlackListService.releaseBlackList(blackList.blackUserIdx);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('블랙리스트에서 해제되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('해제 실패: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteBlackList(BlackList blackList) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: '블랙리스트 삭제',
      message: '${blackList.userName}님의 블랙리스트 기록을 완전히 삭제하시겠습니까?\n\n'
          '⚠️ 이 작업은 되돌릴 수 없습니다.',
      confirmLabel: '삭제',
      isDestructive: true,
    );

    if (confirmed != true) return;

    try {
      await BlackListService.deleteBlackList(blackList.blackUserIdx);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('블랙리스트가 삭제되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('삭제 실패: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppAppBar(
        title: '블랙리스트 관리',
        showBackButton: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateDialog,
            tooltip: '블랙리스트 등록',
          ),
        ],
      ),
      body: Column(
        children: [
          // 검색창
          _buildSearchBar(),

          // 탭바
          TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryBlue,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primaryBlue,
            tabs: [Tab(text: '전체'), Tab(text: '정지 중'), Tab(text: '해제됨')],
          ),

          // 목록
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBlackListView(), // 전체
                _buildBlackListView(), // 정지 중
                _buildBlackListView(), // 해제됨
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AppSearchBar(
        controller: searchController,
        hintText: '이름, 이메일, 전화번호로 검색...',
        onChanged: _onSearchChanged,
        onClear: () => _onSearchChanged(''),
      ),
    );
  }

  Widget _buildBlackListView() {
    if (isLoading) {
      return const StateView.loading();
    }

    if (errorMessage != null) {
      return StateView.error(message: errorMessage!, onRetry: _loadData);
    }

    if (blackLists.isEmpty) {
      return StateView.empty(
        icon: Icons.block,
        message: '블랙리스트가 없습니다',
        subtitle: searchQuery.isNotEmpty ? '검색 결과가 없습니다' : null,
      );
    }

    final int paginationBarCount = totalPages > 1 ? 1 : 0;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: blackLists.length + paginationBarCount,
      itemBuilder: (context, index) {
        if (index >= blackLists.length) {
          return PaginationBar(
            currentPage: currentPage,
            totalPages: totalPages,
            onPageChanged: _onPageChanged,
          );
        }
        final blackList = blackLists[index];
        return _buildBlackListCard(blackList);
      },
    );
  }

  Widget _buildBlackListCard(BlackList blackList) {
    final isActive = blackList.isActive && blackList.dDay > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isActive
                  ? AppTheme.error.withValues(alpha: 0.3)
                  : AppTheme.lightGray,
          width: isActive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetailDialog(blackList),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          blackList.userName,
                          style: AppTheme.h4Style.copyWith(
                            color:
                                isActive
                                    ? AppTheme.error
                                    : AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          blackList.userEmail,
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 상태 뱃지
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isActive
                              ? AppTheme.error.withValues(alpha: 0.1)
                              : AppTheme.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      blackList.remainingDaysText,
                      style: AppTheme.bodySmallStyle.copyWith(
                        color: isActive ? AppTheme.error : AppTheme.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // 메뉴 버튼
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _showEditDialog(blackList);
                          break;
                        case 'release':
                          _releaseBlackList(blackList);
                          break;
                        case 'delete':
                          _deleteBlackList(blackList);
                          break;
                      }
                    },
                    itemBuilder:
                        (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20),
                                SizedBox(width: 8),
                                Text('수정'),
                              ],
                            ),
                          ),
                          if (isActive)
                            const PopupMenuItem(
                              value: 'release',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 20,
                                    color: Colors.green,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '즉시 해제',
                                    style: TextStyle(color: Colors.green),
                                  ),
                                ],
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text('삭제', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                blackList.content,
                style: AppTheme.bodyMediumStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(PetFieldIcons.phone, size: 16, color: AppTheme.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    blackList.userPhone,
                    style: AppTheme.bodySmallStyle.copyWith(
                      color: AppTheme.textTertiary,
                    ),
                  ),
                  const Spacer(),
                  if (blackList.createdAt != null)
                    Text(
                      DateFormat('yy.MM.dd HH:mm').format(blackList.createdAt!),
                      style: AppTheme.bodySmallStyle.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}

// 블랙리스트 등록 대화상자
class _CreateBlackListDialog extends StatefulWidget {
  @override
  State createState() => _CreateBlackListDialogState();
}

class _CreateBlackListDialogState extends State<_CreateBlackListDialog> {
  final _formKey = GlobalKey<FormState>();
  final _accountIdxController = TextEditingController();
  final _contentController = TextEditingController();
  final _dDayController = TextEditingController(text: '7');
  bool _isLoading = false;

  @override
  void dispose() {
    _accountIdxController.dispose();
    _contentController.dispose();
    _dDayController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final request = BlackListCreateRequest(
        accountIdx: int.parse(_accountIdxController.text),
        content: _contentController.text.trim(),
        dDay: int.parse(_dDayController.text),
      );

      await BlackListService.createBlackList(request);

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
    return AlertDialog(
      title: const Text('블랙리스트 등록'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _accountIdxController,
              decoration: const InputDecoration(
                labelText: '사용자 ID',
                hintText: '등록할 사용자의 계정 ID',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '사용자 ID를 입력하세요';
                }
                if (int.tryParse(value) == null) {
                  return '올바른 숫자를 입력하세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: '정지 사유',
                hintText: '블랙리스트 등록 사유를 입력하세요',
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
            TextFormField(
              controller: _dDayController,
              decoration: const InputDecoration(
                labelText: '정지 일수',
                hintText: '정지할 일수를 입력하세요',
                suffix: Text('일'),
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child:
              _isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('등록'),
        ),
      ],
    );
  }
}

// 블랙리스트 수정 대화상자
class _EditBlackListDialog extends StatefulWidget {
  final BlackList blackList;

  const _EditBlackListDialog({required this.blackList});

  @override
  State createState() => _EditBlackListDialogState();
}

class _EditBlackListDialogState extends State<_EditBlackListDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _contentController;
  late TextEditingController _dDayController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.blackList.content);
    _dDayController = TextEditingController(
      text: widget.blackList.dDay.toString(),
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    _dDayController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final request = BlackListUpdateRequest(
        content: _contentController.text.trim(),
        dDay: int.parse(_dDayController.text),
      );

      await BlackListService.updateBlackList(
        widget.blackList.blackUserIdx,
        request,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('블랙리스트가 수정되었습니다.'),
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
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.blackList.userName} 수정'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: '정지 사유',
                hintText: '블랙리스트 사유를 입력하세요',
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
            TextFormField(
              controller: _dDayController,
              decoration: const InputDecoration(
                labelText: '정지 일수',
                hintText: '정지할 일수를 입력하세요',
                suffix: Text('일'),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '정지 일수를 입력하세요';
                }
                final days = int.tryParse(value);
                if (days == null || days < 0) {
                  return '0일 이상 입력하세요';
                }
                if (days > 365) {
                  return '365일 이하로 입력하세요';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child:
              _isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('수정'),
        ),
      ],
    );
  }
}

// 블랙리스트 상세 정보 대화상자
class _DetailBlackListDialog extends StatelessWidget {
  final BlackList blackList;

  const _DetailBlackListDialog({required this.blackList});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(blackList.userName),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 아이콘은 PetFieldIcons 단일 진실에서 가져옴.
            InfoRow(
              icon: PetFieldIcons.email,
              label: '이메일',
              value: blackList.userEmail,
              padding: const EdgeInsets.only(bottom: 8),
            ),
            InfoRow(
              icon: PetFieldIcons.phone,
              label: '전화번호',
              value: blackList.userPhone,
              padding: const EdgeInsets.only(bottom: 8),
            ),
            InfoRow(
              icon: PetFieldIcons.userStatus,
              label: '상태',
              value: blackList.statusText,
              padding: const EdgeInsets.only(bottom: 8),
            ),
            InfoRow(
              icon: Icons.timer_outlined,
              label: '남은 일수',
              value: '${blackList.dDay}일',
              padding: const EdgeInsets.only(bottom: 8),
            ),
            const SizedBox(height: 16),
            const Text('정지 사유', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(blackList.content),
            const SizedBox(height: 16),
            if (blackList.createdAt != null)
              InfoRow(
                icon: PetFieldIcons.userCreatedAt,
                label: '작성일',
                value: DateFormat('yyyy-MM-dd HH:mm:ss')
                    .format(blackList.createdAt!),
                padding: const EdgeInsets.only(bottom: 8),
              ),
            if (blackList.updatedAt != null &&
                blackList.updatedAt != blackList.createdAt)
              InfoRow(
                icon: Icons.edit_calendar_outlined,
                label: '수정일',
                value: DateFormat('yyyy-MM-dd HH:mm:ss')
                    .format(blackList.updatedAt!),
                padding: const EdgeInsets.only(bottom: 8),
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
  }

}
