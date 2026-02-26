import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:kpostal/kpostal.dart';
import '../services/admin_hospital_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_constants.dart';
import '../utils/kakao_postcode_stub.dart'
    if (dart.library.html) '../utils/kakao_postcode_web.dart';
import '../widgets/pagination_bar.dart';
import 'package:intl/intl.dart';

class AdminHospitalCheck extends StatefulWidget {
  const AdminHospitalCheck({super.key});

  @override
  State createState() => _AdminHospitalCheckState();
}

class _AdminHospitalCheckState extends State<AdminHospitalCheck>
    with SingleTickerProviderStateMixin {
  List<HospitalInfo> hospitals = [];
  List<HospitalInfo> filteredHospitals = [];
  List<HospitalInfo> _pagedHospitals = []; // 현재 페이지에 표시할 병원 목록
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();
  int totalCount = 0;
  bool isSearching = false;

  // 병원 마스터 관련
  List<HospitalMaster> _masterHospitals = [];
  List<HospitalMaster> _pagedMasterHospitals = []; // 현재 페이지에 표시할 마스터 목록
  bool _isMasterLoading = true;
  bool _hasMasterError = false;
  String _masterErrorMessage = '';
  String _masterSearchQuery = '';
  final TextEditingController _masterSearchController = TextEditingController();

  // 클라이언트 측 페이지네이션 (모든 탭 공유)
  int _currentPage = 1;
  int _totalPages = 1;

  // 슬라이딩 탭 관련
  TabController? _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController!.addListener(_handleTabChange);
    _loadMasterHospitals();
    _loadHospitals();
  }

  void _handleTabChange() {
    if (_tabController!.indexIsChanging ||
        _tabController!.index != _currentTabIndex) {
      setState(() {
        _currentTabIndex = _tabController!.index;
        _currentPage = 1;
      });
      if (_currentTabIndex == 0) {
        _applyMasterPagination();
      } else {
        _updateFilteredHospitals();
      }
    }
  }

  void _onPageChanged(int page) {
    _currentPage = page;
    if (_currentTabIndex == 0) {
      _applyMasterPagination();
    } else {
      _applyHospitalPagination();
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    searchController.dispose();
    _masterSearchController.dispose();
    super.dispose();
  }

  // ===== 병원 마스터 관련 메서드 =====

  Future<void> _loadMasterHospitals() async {
    setState(() {
      _isMasterLoading = true;
      _hasMasterError = false;
    });

    try {
      final response = await AdminHospitalService.getHospitalMasterList(
        search: _masterSearchQuery.isNotEmpty ? _masterSearchQuery : null,
      );

      setState(() {
        _masterHospitals = response.hospitals;
        _isMasterLoading = false;
      });
      _applyMasterPagination();
    } catch (e) {
      setState(() {
        _isMasterLoading = false;
        _hasMasterError = true;
        _masterErrorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  /// 병원 마스터 클라이언트 페이징
  void _applyMasterPagination() {
    const pageSize = AppConstants.detailListPageSize;
    final totalPages = (_masterHospitals.length / pageSize).ceil();
    final safePage = _currentPage.clamp(1, totalPages > 0 ? totalPages : 1);
    final start = (safePage - 1) * pageSize;
    final end = (start + pageSize).clamp(0, _masterHospitals.length);

    setState(() {
      _pagedMasterHospitals = _masterHospitals.sublist(start, end);
      _currentPage = safePage;
      _totalPages = totalPages > 0 ? totalPages : 1;
    });
  }

  /// 병원 계정 클라이언트 페이징
  void _applyHospitalPagination() {
    const pageSize = AppConstants.detailListPageSize;
    final totalPages = (filteredHospitals.length / pageSize).ceil();
    final safePage = _currentPage.clamp(1, totalPages > 0 ? totalPages : 1);
    final start = (safePage - 1) * pageSize;
    final end = (start + pageSize).clamp(0, filteredHospitals.length);

    setState(() {
      _pagedHospitals = filteredHospitals.sublist(start, end);
      _currentPage = safePage;
      _totalPages = totalPages > 0 ? totalPages : 1;
    });
  }

  void _onMasterSearchChanged(String value) {
    setState(() {
      _masterSearchQuery = value;
      _currentPage = 1;
    });
    _loadMasterHospitals();
  }

  Future<void> _openAddressSearch(TextEditingController controller, void Function(void Function()) setStateCallback) async {
    if (kIsWeb) {
      openKakaoPostcode((String address) {
        setStateCallback(() {
          controller.text = address;
        });
      });
    } else {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) => Container(
          height: MediaQuery.of(sheetCtx).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: KpostalView(
              callback: (Kpostal result) {
                setStateCallback(() {
                  controller.text = result.address;
                });
              },
            ),
          ),
        ),
      );
    }
  }

  void _showRegisterDialog() {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('새 병원 등록'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: '병원명 *',
                          hintText: '예: 서울동물병원',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '병원명을 입력하세요';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: addressController,
                        readOnly: true,
                        onTap: () => _openAddressSearch(addressController, setDialogState),
                        decoration: InputDecoration(
                          labelText: '주소 *',
                          hintText: '터치하여 주소 검색',
                          prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                          suffixIcon: addressController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    setDialogState(() {
                                      addressController.clear();
                                    });
                                  },
                                )
                              : const Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '주소를 검색하여 입력하세요';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        decoration: InputDecoration(
                          labelText: '전화번호 *',
                          hintText: '예: 02-1234-5678',
                          prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '전화번호를 입력하세요';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);
                          try {
                            await AdminHospitalService.registerHospitalMaster(
                              hospitalName: nameController.text.trim(),
                              hospitalAddress: addressController.text.trim(),
                              hospitalPhone: phoneController.text.trim(),
                            );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            _loadMasterHospitals();
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(content: Text('병원이 등록되었습니다.')),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text('등록 실패: ${e.toString().replaceAll('Exception: ', '')}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('등록'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showMasterDetailSheet(HospitalMaster master) {
    final nameController = TextEditingController(text: master.hospitalName);
    final addressController = TextEditingController(text: master.hospitalAddress ?? '');
    final phoneController = TextEditingController(text: master.hospitalPhone ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        bool isUpdating = false;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          master.hospitalCode,
                          style: AppTheme.bodyMediumStyle.copyWith(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: '병원명',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressController,
                    readOnly: true,
                    onTap: () => _openAddressSearch(addressController, setSheetState),
                    decoration: InputDecoration(
                      labelText: '주소',
                      prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                      suffixIcon: addressController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                setSheetState(() {
                                  addressController.clear();
                                });
                              },
                            )
                          : const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: '전화번호',
                      prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isUpdating
                              ? null
                              : () async {
                                  setSheetState(() => isUpdating = true);
                                  try {
                                    await AdminHospitalService.updateHospitalMaster(
                                      master.hospitalCode,
                                      hospitalName: nameController.text.trim(),
                                      hospitalAddress: addressController.text.trim(),
                                      hospitalPhone: phoneController.text.trim(),
                                    );
                                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                                    _loadMasterHospitals();
                                    if (mounted) {
                                      ScaffoldMessenger.of(this.context).showSnackBar(
                                        const SnackBar(content: Text('병원 정보가 수정되었습니다.')),
                                      );
                                    }
                                  } catch (e) {
                                    setSheetState(() => isUpdating = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(this.context).showSnackBar(
                                        SnackBar(content: Text('수정 실패: ${e.toString().replaceAll('Exception: ', '')}')),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('수정'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isUpdating
                              ? null
                              : () async {
                                  final confirmed = await showDialog<bool>(
                                    context: sheetContext,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('병원 삭제'),
                                      content: Text('${master.hospitalName} (${master.hospitalCode})을 삭제하시겠습니까?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                          child: const Text('삭제'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed != true) return;
                                  setSheetState(() => isUpdating = true);
                                  try {
                                    await AdminHospitalService.deleteHospitalMaster(master.hospitalCode);
                                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                                    _loadMasterHospitals();
                                    if (mounted) {
                                      ScaffoldMessenger.of(this.context).showSnackBar(
                                        SnackBar(content: Text('${master.hospitalName}이 삭제되었습니다.')),
                                      );
                                    }
                                  } catch (e) {
                                    setSheetState(() => isUpdating = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(this.context).showSnackBar(
                                        SnackBar(content: Text('삭제 실패: ${e.toString().replaceAll('Exception: ', '')}')),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.error,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('삭제'),
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

  Future<void> _loadHospitals() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      final response = await AdminHospitalService.getHospitalList(
        page: 1,
        pageSize: 100,
        search: searchQuery.isNotEmpty ? searchQuery : null,
        isActive: null,
        approved: true,
      );

      setState(() {
        hospitals = response.hospitals;
        totalCount = response.totalCount;
        isLoading = false;
      });
      _updateFilteredHospitals();
    } catch (e) {
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _searchHospitals(String query) async {
    if (query.isEmpty) {
      return _loadHospitals();
    }

    setState(() {
      isSearching = true;
      hasError = false;
    });

    try {
      final response = await AdminHospitalService.searchHospitals(
        HospitalSearchRequest(
          searchQuery: query,
          isActive: null,
          approved: null,
          page: 1,
          pageSize: 100,
        ),
      );

      setState(() {
        hospitals = response.hospitals;
        isSearching = false;
      });
      _updateFilteredHospitals();
    } catch (e) {
      setState(() {
        isSearching = false;
        hasError = true;
        errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      searchQuery = value;
      _currentPage = 1;
    });

    if (value.isEmpty) {
      _loadHospitals();
    } else {
      _searchHospitals(value);
    }
  }

  // 필터링된 병원 목록 가져오기 (탭 1: 비활성화, 탭 2: 활성화) + 페이징 적용
  void _updateFilteredHospitals() {
    filteredHospitals =
        hospitals
            .where(
              (hospital) =>
                  _currentTabIndex == 1
                      ? !hospital.columnActive
                      : hospital.columnActive,
            )
            .toList();
    _applyHospitalPagination();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "병원 관리",
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: false,
        actions: [
          if (_currentTabIndex == 0)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showRegisterDialog,
              tooltip: '새 병원 등록',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _currentTabIndex == 0 ? _loadMasterHospitals : _loadHospitals,
            tooltip: '새로고침',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.business, size: 20),
                  SizedBox(width: 4),
                  Text('병원 등록'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block, size: 20),
                  SizedBox(width: 4),
                  Text('비활성화'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 20),
                  SizedBox(width: 4),
                  Text('활성화'),
                ],
              ),
            ),
          ],
          labelColor: Colors.black87,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black87,
        ),
      ),
      body: _currentTabIndex == 0
          ? _buildMasterTab(textTheme, colorScheme)
          : _buildAccountTab(textTheme, colorScheme),
    );
  }

  // ===== 병원 등록 탭 (마스터 데이터) =====
  Widget _buildMasterTab(TextTheme textTheme, ColorScheme colorScheme) {
    return Column(
      children: [
        // 검색 필드
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: TextField(
            controller: _masterSearchController,
            onChanged: _onMasterSearchChanged,
            decoration: InputDecoration(
              labelText: '병원 검색 (코드, 이름, 주소)',
              hintText: '검색어를 입력하세요',
              prefixIcon: const Icon(Icons.search_outlined),
              suffixIcon: _masterSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _masterSearchController.clear();
                        _onMasterSearchChanged('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
        ),
        // 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                alignment: Alignment.center,
                child: Text('번호', style: AppTheme.bodyMediumStyle.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 13)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text('병원명', style: AppTheme.bodyMediumStyle.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 13)),
                ),
              ),
              Container(
                width: 70,
                alignment: Alignment.center,
                child: Text('코드', style: AppTheme.bodyMediumStyle.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 13)),
              ),
            ],
          ),
        ),
        // 목록
        Expanded(child: _buildMasterList(textTheme)),
      ],
    );
  }

  Widget _buildMasterList(TextTheme textTheme) {
    if (_isMasterLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hasMasterError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_masterErrorMessage, style: textTheme.bodySmall),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadMasterHospitals, child: const Text('다시 시도')),
          ],
        ),
      );
    }
    if (_masterHospitals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _masterSearchQuery.isNotEmpty ? '검색 결과가 없습니다.' : '등록된 병원이 없습니다.\n우상단 + 버튼으로 병원을 등록하세요.',
              style: textTheme.titleMedium?.copyWith(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final int paginationBarCount = _totalPages > 1 ? 1 : 0;

    return RefreshIndicator(
      onRefresh: () async {
        _currentPage = 1;
        await _loadMasterHospitals();
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        itemCount: _pagedMasterHospitals.length + paginationBarCount,
        itemBuilder: (context, index) {
          // PaginationBar
          if (index >= _pagedMasterHospitals.length) {
            return PaginationBar(
              currentPage: _currentPage,
              totalPages: _totalPages,
              onPageChanged: _onPageChanged,
            );
          }

          final master = _pagedMasterHospitals[index];
          // 전체 목록 기준 번호 계산
          final displayNumber = (_currentPage - 1) * AppConstants.detailListPageSize + index + 1;
          return InkWell(
            onTap: () => _showMasterDetailSheet(master),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    alignment: Alignment.center,
                    child: Text(
                      '$displayNumber',
                      style: AppTheme.bodyMediumStyle.copyWith(fontWeight: FontWeight.w600, color: Colors.grey[600]),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            master.hospitalName,
                            style: AppTheme.bodyMediumStyle.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (master.hospitalAddress != null && master.hospitalAddress!.isNotEmpty)
                            Text(
                              master.hospitalAddress!,
                              style: AppTheme.bodySmallStyle.copyWith(color: Colors.grey[600], fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 70,
                    alignment: Alignment.center,
                    child: Text(
                      master.hospitalCode,
                      style: AppTheme.bodySmallStyle.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBlue,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===== 기존 계정 기반 탭 (비활성화/활성화) =====
  Widget _buildAccountTab(TextTheme textTheme, ColorScheme colorScheme) {
    return Column(
      children: [
        // 검색 필드
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: TextField(
            controller: searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              labelText: '병원 검색 (이름, 이메일, 주소)',
              hintText: '검색어를 입력하세요',
              prefixIcon: const Icon(Icons.search_outlined),
              suffixIcon: (searchQuery.isNotEmpty || isSearching)
                  ? IconButton(
                      icon: isSearching
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.clear),
                      onPressed: isSearching
                          ? null
                          : () {
                              searchController.clear();
                              _onSearchChanged('');
                            },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
        ),
        // 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                alignment: Alignment.center,
                child: Text('번호', style: AppTheme.bodyMediumStyle.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 13)),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                  alignment: Alignment.centerLeft,
                  child: Text('병원', style: AppTheme.bodyMediumStyle.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 13)),
                ),
              ),
              Container(
                width: 70,
                alignment: Alignment.center,
                child: Text('칼럼권한', style: AppTheme.bodyMediumStyle.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 13)),
              ),
            ],
          ),
        ),
        // 병원 목록
        Expanded(child: _buildHospitalList(textTheme, colorScheme)),
      ],
    );
  }

  Widget _buildHospitalList(TextTheme textTheme, ColorScheme colorScheme) {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('병원 목록을 불러오고 있습니다...'),
          ],
        ),
      );
    }

    if (hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              '오류가 발생했습니다',
              style: textTheme.titleMedium?.copyWith(color: Colors.red[500]),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadHospitals,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (filteredHospitals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              searchQuery.isNotEmpty ? '검색 결과가 없습니다.' : '등록된 병원이 없습니다.',
              style: textTheme.titleMedium?.copyWith(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    final int paginationBarCount = _totalPages > 1 ? 1 : 0;

    return RefreshIndicator(
      onRefresh: () async {
        _currentPage = 1;
        await _loadHospitals();
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 0),
        itemCount: _pagedHospitals.length + paginationBarCount,
        itemBuilder: (context, index) {
          // PaginationBar
          if (index >= _pagedHospitals.length) {
            return PaginationBar(
              currentPage: _currentPage,
              totalPages: _totalPages,
              onPageChanged: _onPageChanged,
            );
          }

          final hospital = _pagedHospitals[index];
          // 전체 목록 기준 번호 계산
          final displayIndex = (_currentPage - 1) * AppConstants.detailListPageSize + index;
          return _buildHospitalListItem(hospital, displayIndex);
        },
      ),
    );
  }

  Widget _buildHospitalListItem(HospitalInfo hospital, int index) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdminHospitalDetailScreen(hospital: hospital),
          ),
        ).then((_) {
          _loadHospitals();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 0),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 번호 (리스트 인덱스 + 1)
            Container(
              width: 50,
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: AppTheme.bodyMediumStyle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ),
            // 병원 (닉네임이 있으면 닉네임, 없으면 이름)
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                alignment: Alignment.centerLeft,
                child: Text(
                  hospital.nickname?.isNotEmpty == true
                      ? hospital.nickname!
                      : hospital.name, // 닉네임이 없으면 이름 표시
                  style: AppTheme.bodyMediumStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // 칼럼 활성화 상태 뱃지
            Container(
              width: 70,
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 4.0,
                ),
                decoration: BoxDecoration(
                  color:
                      hospital.columnActive
                          ? Colors.green.withAlpha(38)
                          : Colors.grey.withAlpha(38),
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: Text(
                  hospital.columnActive ? '활성화' : '비활성',
                  style: AppTheme.bodySmallStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color:
                        hospital.columnActive ? Colors.green : Colors.grey[600],
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminHospitalDetailScreen extends StatefulWidget {
  final HospitalInfo hospital;

  const AdminHospitalDetailScreen({super.key, required this.hospital});

  @override
  State<AdminHospitalDetailScreen> createState() =>
      _AdminHospitalDetailScreenState();
}

class _AdminHospitalDetailScreenState extends State<AdminHospitalDetailScreen> {
  late HospitalInfo hospitalInfo;
  bool isLoading = false;
  final TextEditingController hospitalCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    hospitalInfo = widget.hospital;
    hospitalCodeController.text = hospitalInfo.hospitalCode ?? '';
  }

  @override
  void dispose() {
    hospitalCodeController.dispose();
    super.dispose();
  }

  String _getStatusText() {
    if (hospitalInfo.columnActive) {
      return '활성화';
    } else {
      return '비활성화';
    }
  }

  Color _getStatusColor() {
    if (hospitalInfo.columnActive) {
      return Colors.green;
    } else {
      return Colors.grey;
    }
  }

  Future<void> _updateHospital() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      final updateRequest = HospitalUpdateRequest(
        hospitalCode:
            hospitalCodeController.text.trim().isNotEmpty
                ? hospitalCodeController.text.trim()
                : null,
        isActive: hospitalInfo.isActive,
      );

      final updatedHospital = await AdminHospitalService.updateHospital(
        hospitalInfo.accountIdx,
        updateRequest,
      );

      setState(() {
        hospitalInfo = updatedHospital;
        hospitalCodeController.text = hospitalInfo.hospitalCode ?? '';
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('병원 정보가 업데이트되었습니다.')));
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '업데이트 실패: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleColumnActive() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      final updateRequest = HospitalUpdateRequest(
        columnActive: !hospitalInfo.columnActive,
      );

      final updatedHospital = await AdminHospitalService.updateHospital(
        hospitalInfo.accountIdx,
        updateRequest,
      );

      setState(() {
        hospitalInfo = updatedHospital;
        hospitalCodeController.text = hospitalInfo.hospitalCode ?? '';
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hospitalInfo.columnActive
                  ? '칼럼 작성 권한이 부여되었습니다.'
                  : '칼럼 작성 권한이 취소되었습니다.',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '권한 변경 실패: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteHospital() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('병원 탈퇴'),
          content: Text('정말로 이 병원을 삭제하시겠습니까?\n\n병원명: ${hospitalInfo.nickname?.isNotEmpty == true ? hospitalInfo.nickname! : hospitalInfo.name}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      await AdminHospitalService.deleteHospital(hospitalInfo.accountIdx);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('병원 "${hospitalInfo.name}"이 삭제되었습니다.')),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '삭제 실패: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyMedium?.copyWith(color: Colors.black87),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "병원 상세정보",
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () {
              _deleteHospital();
            },
            icon: const Icon(Icons.close, color: Colors.black, size: 24),
            tooltip: '병원 탈퇴',
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('처리 중...'),
                  ],
                ),
              )
              : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 병원 기본 정보 카드
                    Card(
                      margin: const EdgeInsets.all(20.0),
                      elevation: 4,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade100, width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    hospitalInfo.name,
                                    style: textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0,
                                    vertical: 6.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor().withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  child: Text(
                                    _getStatusText(),
                                    style: textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: _getStatusColor(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            if (hospitalInfo.nickname?.isNotEmpty == true)
                              _buildDetailRow(
                                context,
                                Icons.badge_outlined,
                                '닉네임',
                                hospitalInfo.nickname!,
                              ),
                            _buildDetailRow(
                              context,
                              Icons.person_outline,
                              '이름',
                              hospitalInfo.name,
                            ),
                            _buildDetailRow(
                              context,
                              Icons.email_outlined,
                              '이메일',
                              hospitalInfo.email,
                            ),
                            if (hospitalInfo.phoneNumber != null &&
                                hospitalInfo.phoneNumber!.isNotEmpty)
                              _buildDetailRow(
                                context,
                                Icons.phone_outlined,
                                '전화번호',
                                hospitalInfo.phoneNumber!,
                              ),
                            if (hospitalInfo.address != null &&
                                hospitalInfo.address!.isNotEmpty)
                              _buildDetailRow(
                                context,
                                Icons.location_on_outlined,
                                '주소',
                                hospitalInfo.address!,
                              ),
                            _buildDetailRow(
                              context,
                              Icons.business_outlined,
                              '병원 코드',
                              hospitalInfo.hospitalCode ?? '미등록',
                            ),
                            _buildDetailRow(
                              context,
                              Icons.event_note_outlined,
                              '가입일',
                              DateFormat(
                                'yyyy-MM-dd HH:mm',
                              ).format(hospitalInfo.createdAt),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 병원 코드 수정 카드
                    Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 10.0,
                      ),
                      elevation: 2,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade100, width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '병원 코드 수정',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: hospitalCodeController,
                              decoration: InputDecoration(
                                labelText: '병원 코드',
                                hintText: '예: H0001',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: colorScheme.primary,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _updateHospital,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  isLoading ? '수정 중...' : '수정',
                                  style: textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 칼럼 작성 권한 카드
                    Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 10.0,
                      ),
                      elevation: 2,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade100, width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '칼럼 작성 권한',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            //const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        hospitalInfo.columnActive
                                            ? '칼럼 작성 권한이 부여되었습니다.'
                                            : '칼럼 작성 권한이 없습니다.',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: hospitalInfo.columnActive,
                                  onChanged:
                                      isLoading
                                          ? null
                                          : (value) => _toggleColumnActive(),
                                  activeThumbColor: Colors.green,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    //const SizedBox(height: 20),
                  ],
                ),
              ),
    );
  }
}
