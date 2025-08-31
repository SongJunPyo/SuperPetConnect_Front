import 'package:flutter/material.dart';
import '../services/admin_hospital_service.dart';
import '../utils/app_theme.dart';
import 'package:intl/intl.dart';

class AdminHospitalCheck extends StatefulWidget {
  const AdminHospitalCheck({super.key});

  @override
  _AdminHospitalCheckState createState() => _AdminHospitalCheckState();
}

class _AdminHospitalCheckState extends State<AdminHospitalCheck>
    with SingleTickerProviderStateMixin {
  List<HospitalInfo> hospitals = [];
  List<HospitalInfo> filteredHospitals = [];
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();
  int currentPage = 1;
  final int pageSize = 10;
  int totalCount = 0;
  bool isSearching = false;

  // 슬라이딩 탭 관련
  TabController? _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController!.addListener(_handleTabChange);
    _loadHospitals();
  }

  void _handleTabChange() {
    if (_tabController!.indexIsChanging ||
        _tabController!.index != _currentTabIndex) {
      setState(() {
        _currentTabIndex = _tabController!.index;
        _updateFilteredHospitals();
      });
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHospitals() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      final response = await AdminHospitalService.getHospitalList(
        page: currentPage,
        pageSize: 100,
        search: searchQuery.isNotEmpty ? searchQuery : null,
        isActive: null,
        approved: true,
      );

      setState(() {
        hospitals = response.hospitals;
        _updateFilteredHospitals();
        totalCount = response.totalCount;
        isLoading = false;
      });
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
          pageSize: 50,
        ),
      );

      setState(() {
        hospitals = response.hospitals;
        _updateFilteredHospitals();
        isSearching = false;
      });
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
    });

    if (value.isEmpty) {
      _loadHospitals();
    } else {
      _searchHospitals(value);
    }
  }

  // 필터링된 병원 목록 가져오기
  void _updateFilteredHospitals() {
    filteredHospitals =
        hospitals
            .where(
              (hospital) =>
                  _currentTabIndex == 0
                      ? !hospital.columnActive
                      : hospital.columnActive,
            )
            .toList();
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
            icon: const Icon(Icons.refresh),
            onPressed: _loadHospitals,
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
                  Icon(Icons.block, size: 20),
                  SizedBox(width: 8),
                  Text('비활성화'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 20),
                  SizedBox(width: 8),
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
      body: Column(
        children: [
          // 검색 필드
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ),
            child: TextField(
              controller: searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                labelText: '병원 검색 (이름, 이메일, 주소)',
                hintText: '검색어를 입력하세요',
                prefixIcon: const Icon(Icons.search_outlined),
                suffixIcon:
                    (searchQuery.isNotEmpty || isSearching)
                        ? IconButton(
                          icon:
                              isSearching
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.clear),
                          onPressed:
                              isSearching
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
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                labelStyle: TextStyle(color: Colors.grey[700]),
              ),
            ),
          ),

          // 헤더 추가
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 8.0,
            ),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 번호 헤더
                Container(
                  width: 50,
                  alignment: Alignment.center,
                  child: Text(
                    '번호',
                    style: AppTheme.bodyMediumStyle.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                      fontSize: 13,
                    ),
                  ),
                ),
                // 병원 헤더 (닉네임으로 표시)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '병원',
                      style: AppTheme.bodyMediumStyle.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                // 칼럼권한 헤더
                Container(
                  width: 70,
                  alignment: Alignment.center,
                  child: Text(
                    '칼럼권한',
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

          // 병원 목록
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

    return RefreshIndicator(
      onRefresh: _loadHospitals,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 0),
        itemCount: filteredHospitals.length,
        itemBuilder: (context, index) {
          final hospital = filteredHospitals[index];
          return _buildHospitalListItem(hospital, index);
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
  _AdminHospitalDetailScreenState createState() =>
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('병원 정보가 업데이트되었습니다.')));
    } catch (e) {
      setState(() {
        isLoading = false;
      });

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hospitalInfo.columnActive
                ? '칼럼 작성 권한이 부여되었습니다.'
                : '칼럼 작성 권한이 취소되었습니다.',
          ),
        ),
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });

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

  Future<void> _deleteHospital() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('병원 탈퇴'),
          content: Text('정말로 이 병원을 삭제하시겠습니까?\n\n병원명: ${hospitalInfo.name}'),
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

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('병원 "${hospitalInfo.name}"이 삭제되었습니다.')),
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('삭제 실패: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
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
                                    color: _getStatusColor().withOpacity(0.15),
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
                              '요양기관기호',
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

                    // 요양기관기호 수정 카드
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
                              '요양기관기호 수정',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: hospitalCodeController,
                              decoration: InputDecoration(
                                labelText: '요양기관기호',
                                hintText: '예: 1234567890',
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
                                  activeColor: Colors.green,
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
