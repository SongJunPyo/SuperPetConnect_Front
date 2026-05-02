import 'package:flutter/material.dart';
import '../services/admin_hospital_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_constants.dart';
import '../utils/debouncer.dart';
import '../utils/error_display.dart';
import '../widgets/pagination_bar.dart';
import 'admin_hospital_detail_screen.dart';
import 'hospital_register_sheet.dart';

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
      builder: (ctx) => const HospitalRegisterSheet(),
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
