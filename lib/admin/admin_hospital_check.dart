import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:kpostal/kpostal.dart';
import '../services/admin_hospital_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_constants.dart';
import '../utils/debouncer.dart';
import '../utils/error_display.dart';
import '../utils/phone_formatter.dart';
import '../utils/kakao_postcode_stub.dart'
    if (dart.library.html) '../utils/kakao_postcode_web.dart';
import '../widgets/app_dialog.dart';
import '../widgets/pagination_bar.dart';
import 'package:intl/intl.dart';

class AdminHospitalCheck extends StatefulWidget {
  const AdminHospitalCheck({super.key});

  @override
  State createState() => _AdminHospitalCheckState();
}

class _AdminHospitalCheckState extends State<AdminHospitalCheck> {
  List<HospitalInfo> hospitals = [];
  List<HospitalInfo> filteredHospitals = [];
  List<HospitalInfo> _pagedHospitals = [];
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();
  final Debouncer _searchDebouncer = Debouncer();
  int totalCount = 0;

  int _currentPage = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _loadHospitals();
  }

  @override
  void dispose() {
    searchController.dispose();
    _searchDebouncer.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    _currentPage = page;
    _applyHospitalPagination();
  }

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
        errorMessage = formatErrorMessage(e);
      });
    }
  }

  Future<void> _searchHospitals(String query) async {
    if (query.isEmpty) {
      return _loadHospitals();
    }

    setState(() {
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
      });
      _updateFilteredHospitals();
    } catch (e) {
      setState(() {
        hasError = true;
        errorMessage = formatErrorMessage(e);
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchDebouncer(() {
      if (!mounted) return;
      final trimmed = value.trim();
      setState(() {
        searchQuery = trimmed;
        _currentPage = 1;
      });
      if (trimmed.isEmpty) {
        _loadHospitals();
      } else {
        _searchHospitals(trimmed);
      }
    });
  }

  // 활성/비활성 상태 구분 없이 모든 병원 계정 표시 (코드 컬럼으로 식별)
  void _updateFilteredHospitals() {
    filteredHospitals = List.from(hospitals);
    _applyHospitalPagination();
  }

  Future<void> _showRegisterSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _HospitalRegisterSheet(),
    );
    // 마스터 등록 자체는 계정 목록(이 화면)에 영향을 주지 않으므로
    // 닫힌 후 별도 새로고침은 불필요. (가입 승인 화면에서 매칭 시 사용됨)
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
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showRegisterSheet,
            tooltip: '새 병원 등록',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHospitals,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Column(
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
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchDebouncer.cancel();
                          searchController.clear();
                          setState(() {
                            searchQuery = '';
                            _currentPage = 1;
                          });
                          _loadHospitals();
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
          // 헤더 (번호 | 병원명+주소 | 이름 | 코드)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 35,
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
                  width: 65,
                  alignment: Alignment.center,
                  child: Text('이름', style: AppTheme.bodyMediumStyle.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 13)),
                ),
                Container(
                  width: 65,
                  alignment: Alignment.center,
                  child: Text('코드', style: AppTheme.bodyMediumStyle.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 13)),
                ),
              ],
            ),
          ),
          Expanded(child: _buildHospitalList(textTheme, colorScheme)),
        ],
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        itemCount: _pagedHospitals.length + paginationBarCount,
        itemBuilder: (context, index) {
          if (index >= _pagedHospitals.length) {
            return PaginationBar(
              currentPage: _currentPage,
              totalPages: _totalPages,
              onPageChanged: _onPageChanged,
            );
          }

          final hospital = _pagedHospitals[index];
          final displayIndex = (_currentPage - 1) * AppConstants.detailListPageSize + index;
          return _buildHospitalListItem(hospital, displayIndex);
        },
      ),
    );
  }

  Widget _buildHospitalListItem(HospitalInfo hospital, int index) {
    // 같은 hospital_code를 공유하는 여러 직원이 각각 행으로 나오는 구조.
    // 병원명(nickname=마스터에서 복사된 값)은 동일하고 이름(name)으로 개인을 구분.
    final hospitalName = hospital.nickname?.isNotEmpty == true
        ? hospital.nickname!
        : '-';
    final personName = hospital.name.isNotEmpty ? hospital.name : '-';
    final hasCode = hospital.hospitalCode?.isNotEmpty == true;
    final hasAddress = hospital.address?.isNotEmpty == true;
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
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 35,
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: AppTheme.bodyMediumStyle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0, right: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hospitalName,
                      style: AppTheme.bodyMediumStyle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasAddress)
                      Text(
                        hospital.address!,
                        style: AppTheme.bodySmallStyle.copyWith(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
            Container(
              width: 65,
              alignment: Alignment.center,
              child: Text(
                personName,
                style: AppTheme.bodySmallStyle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              width: 65,
              alignment: Alignment.center,
              child: Text(
                hasCode ? hospital.hospitalCode! : '미등록',
                style: AppTheme.bodySmallStyle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: hasCode ? AppTheme.primaryBlue : Colors.grey[500],
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
        showErrorToast(
          context,
          e,
          prefix: '업데이트 실패',
          backgroundColor: Colors.red,
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
        showErrorToast(
          context,
          e,
          prefix: '권한 변경 실패',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<void> _deleteHospital() async {
    final confirmed = await AppDialog.confirm(
      context,
      title: '병원 탈퇴',
      message:
          '정말 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.\n\n병원명: ${hospitalInfo.nickname?.isNotEmpty == true ? hospitalInfo.nickname! : hospitalInfo.name}',
      confirmLabel: '삭제',
      isDestructive: true,
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
        showErrorToast(
          context,
          e,
          prefix: '삭제 실패',
          backgroundColor: Colors.red,
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
            icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 24),
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
                                formatPhoneNumber(hospitalInfo.phoneNumber!),
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

// 병원 등록 바텀시트 — 마스터 검색 + 신규 등록을 한 시트에 통합.
// 사용자가 검색해보고 없으면 "새 병원 등록" 버튼으로 폼 모드로 전환.
class _HospitalRegisterSheet extends StatefulWidget {
  const _HospitalRegisterSheet();

  @override
  State<_HospitalRegisterSheet> createState() => _HospitalRegisterSheetState();
}

class _HospitalRegisterSheetState extends State<_HospitalRegisterSheet> {
  // 검색/목록 상태
  final TextEditingController _searchCtrl = TextEditingController();
  final Debouncer _debouncer = Debouncer();
  String _query = '';
  int _page = 1;
  static const int _pageSize = 20;
  List<HospitalMaster> _results = [];
  int _total = 0;
  int _totalPages = 1;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMsg = '';

  // 모드 (false: 검색, true: 신규 등록 폼)
  bool _showForm = false;

  // 등록 폼 상태
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _addrCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debouncer.dispose();
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final response = await AdminHospitalService.getHospitalMasterList(
        page: _page,
        pageSize: _pageSize,
        search: _query.isEmpty ? null : _query,
      );
      final totalPages =
          (response.totalCount / _pageSize).ceil().clamp(1, 1 << 30);
      // 페이지 오버플로우 자동 폴백 — admin_hospital_check 메인 목록과 동일 패턴.
      final isOverflow = _page > totalPages ||
          (response.totalCount > 0 && response.hospitals.isEmpty);
      if (isOverflow && response.totalCount > 0 && _page != 1) {
        _page = 1;
        return _load();
      }
      setState(() {
        _results = response.hospitals;
        _total = response.totalCount;
        _totalPages = totalPages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMsg = formatErrorMessage(e);
      });
    }
  }

  void _onSearchChanged(String value) {
    _debouncer(() {
      if (!mounted) return;
      setState(() {
        _query = value.trim();
        _page = 1;
      });
      _load();
    });
  }

  void _onPageChanged(int page) {
    _page = page;
    _load();
  }

  void _enterFormMode() {
    setState(() {
      _showForm = true;
      // 검색해보고 없어서 신규 등록하는 시나리오 — 검색어를 병원명에 자동 채움
      if (_query.isNotEmpty && _nameCtrl.text.isEmpty) {
        _nameCtrl.text = _query;
      }
    });
  }

  void _exitFormMode() {
    setState(() {
      _showForm = false;
    });
  }

  Future<void> _openAddressSearch() async {
    if (kIsWeb) {
      openKakaoPostcode((String address) {
        setState(() {
          _addrCtrl.text = address;
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
                setState(() {
                  _addrCtrl.text = result.address;
                });
              },
            ),
          ),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await AdminHospitalService.registerHospitalMaster(
        hospitalName: _nameCtrl.text.trim(),
        hospitalAddress: _addrCtrl.text.trim(),
        hospitalPhone: _phoneCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('병원이 등록되었습니다.')),
      );
      _nameCtrl.clear();
      _addrCtrl.clear();
      _phoneCtrl.clear();
      setState(() {
        _isSubmitting = false;
        _showForm = false;
        _page = 1;
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorToast(context, e, prefix: '등록 실패', backgroundColor: Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 헤더
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                child: Row(
                  children: [
                    if (_showForm)
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: _isSubmitting ? null : _exitFormMode,
                        tooltip: '검색으로 돌아가기',
                      ),
                    Text(
                      _showForm ? '새 병원 등록' : '병원 등록',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _showForm
                    ? _buildForm(scrollCtrl)
                    : _buildSearchView(scrollCtrl),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchView(ScrollController scrollCtrl) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              labelText: '병원 검색 (코드, 이름, 주소)',
              hintText: '먼저 등록 여부를 확인하세요',
              prefixIcon: const Icon(Icons.search_outlined),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _debouncer.cancel();
                        _searchCtrl.clear();
                        setState(() {
                          _query = '';
                          _page = 1;
                        });
                        _load();
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
        // 마스터 목록 헤더 (메인 화면과 컬럼 폭 통일)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
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
                  padding: const EdgeInsets.only(left: 8),
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
        Expanded(child: _buildResults(scrollCtrl)),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _enterFormMode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('새 병원 등록'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResults(ScrollController scrollCtrl) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 12),
            Text(_errorMsg),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('다시 시도')),
          ],
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.business_outlined, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(
                _query.isNotEmpty
                    ? '검색 결과가 없습니다.\n아래 "새 병원 등록" 버튼으로 등록하세요.'
                    : (_total == 0
                        ? '등록된 병원이 없습니다.\n아래 버튼으로 첫 병원을 등록하세요.'
                        : '이 페이지에는 병원이 없습니다.'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    final paginationCount = _totalPages > 1 ? 1 : 0;
    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _results.length + paginationCount,
      itemBuilder: (context, idx) {
        if (idx >= _results.length) {
          return PaginationBar(
            currentPage: _page,
            totalPages: _totalPages,
            onPageChanged: _onPageChanged,
          );
        }
        final m = _results[idx];
        final displayNo = (_page - 1) * _pageSize + idx + 1;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                alignment: Alignment.center,
                child: Text(
                  '$displayNo',
                  style: AppTheme.bodyMediumStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.hospitalName,
                        style: AppTheme.bodyMediumStyle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (m.hospitalAddress != null &&
                          m.hospitalAddress!.isNotEmpty)
                        Text(
                          m.hospitalAddress!,
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
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
                  m.hospitalCode,
                  style: AppTheme.bodySmallStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryBlue,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildForm(ScrollController scrollCtrl) {
    return Form(
      key: _formKey,
      child: ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        children: [
          TextFormField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: '병원명 *',
              hintText: '예: 서울동물병원',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? '병원명을 입력하세요' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _addrCtrl,
            readOnly: true,
            onTap: _openAddressSearch,
            decoration: InputDecoration(
              labelText: '주소 *',
              hintText: '터치하여 주소 검색',
              prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
              suffixIcon: _addrCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _addrCtrl.clear();
                        });
                      },
                    )
                  : const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? '주소를 검색하여 입력하세요' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneCtrl,
            decoration: InputDecoration(
              labelText: '전화번호 *',
              hintText: '예: 02-1234-5678',
              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            keyboardType: TextInputType.phone,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? '전화번호를 입력하세요' : null,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSubmitting ? null : _exitFormMode,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
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
        ],
      ),
    );
  }
}
