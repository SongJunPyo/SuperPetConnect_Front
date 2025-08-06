import 'package:flutter/material.dart';
import '../services/admin_hospital_service.dart';
import '../utils/app_theme.dart';
import 'package:intl/intl.dart';

class AdminHospitalCheck extends StatefulWidget {
  const AdminHospitalCheck({super.key});

  @override
  _AdminHospitalCheckState createState() => _AdminHospitalCheckState();
}

class _AdminHospitalCheckState extends State<AdminHospitalCheck> {
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

  @override
  void initState() {
    super.initState();
    _loadHospitals();
  }

  @override
  void dispose() {
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
        pageSize: pageSize,
        search: searchQuery.isNotEmpty ? searchQuery : null,
        isActive: null,
        approved: null,
      );

      setState(() {
        hospitals = response.hospitals;
        filteredHospitals = response.hospitals;
        totalCount = response.totalCount;
        isLoading = false;
        hasError = false;
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
      await _loadHospitals();
      return;
    }

    setState(() {
      isSearching = true;
      hasError = false;
    });

    try {
      final searchRequest = HospitalSearchRequest(
        searchQuery: query,
        isActive: null,
        approved: null,
        page: 1,
        pageSize: 50,
      );

      final response = await AdminHospitalService.searchHospitals(searchRequest);

      setState(() {
        filteredHospitals = response.hospitals;
        isSearching = false;
        hasError = false;
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
                suffixIcon: (searchQuery.isNotEmpty || isSearching)
                    ? IconButton(
                        icon: isSearching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
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
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 2,
                  ),
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

          // 병원 목록
          Expanded(
            child: _buildHospitalList(textTheme, colorScheme),
          ),
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
            Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              '오류가 발생했습니다',
              style: textTheme.titleMedium?.copyWith(
                color: Colors.red[500],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
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
            Icon(
              Icons.inbox_outlined,
              size: 60,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              searchQuery.isNotEmpty
                  ? '검색 결과가 없습니다.'
                  : '등록된 병원이 없습니다.',
              style: textTheme.titleMedium?.copyWith(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHospitals,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(
          horizontal: 20.0,
          vertical: 0,
        ),
        itemCount: filteredHospitals.length,
        itemBuilder: (context, index) {
          final hospital = filteredHospitals[index];
          return _buildHospitalCard(hospital, textTheme, colorScheme);
        },
      ),
    );
  }

  Widget _buildHospitalCard(
    HospitalInfo hospital,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey.shade100,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminHospitalDetailScreen(
                hospital: hospital,
              ),
            ),
          ).then((_) {
            _loadHospitals();
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      hospital.name,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildStatusTag(hospital, textTheme),
                ],
              ),
              const SizedBox(height: 8),
              if (hospital.email.isNotEmpty)
                Text(
                  '이메일: ${hospital.email}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (hospital.address != null && hospital.address!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '주소: ${hospital.address}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (hospital.phoneNumber != null &&
                  hospital.phoneNumber!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '연락처: ${hospital.phoneNumber}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
              ],
              if (hospital.hospitalCode != null &&
                  hospital.hospitalCode!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '요양기관기호: ${hospital.hospitalCode}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                '가입일: ${DateFormat('yyyy-MM-dd').format(hospital.createdAt)}',
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTag(HospitalInfo hospital, TextTheme textTheme) {
    String statusText;
    Color statusColor;

    // 승인된 병원만 표시하고, 승인 대기는 표시하지 않음
    if (hospital.isActive) {
      statusText = '활성';
      statusColor = Colors.green;
    } else {
      statusText = '비활성화';
      statusColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8.0,
        vertical: 4.0,
      ),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Text(
        statusText,
        style: textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: statusColor,
        ),
      ),
    );
  }
}

class AdminHospitalDetailScreen extends StatefulWidget {
  final HospitalInfo hospital;

  const AdminHospitalDetailScreen({
    super.key,
    required this.hospital,
  });

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
    if (hospitalInfo.isActive) {
      return '활성';
    } else {
      return '비활성화';
    }
  }

  Color _getStatusColor() {
    if (hospitalInfo.isActive) {
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
        hospitalCode: hospitalCodeController.text.trim().isNotEmpty
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('병원 정보가 업데이트되었습니다.')),
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('업데이트 실패: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleHospitalActive() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      final updateRequest = HospitalUpdateRequest(
        isActive: !hospitalInfo.isActive,
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
            hospitalInfo.isActive
                ? '병원 계정이 활성화되었습니다.'
                : '병원 계정이 비활성화되었습니다.',
          ),
        ),
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('상태 변경 실패: ${e.toString().replaceAll('Exception: ', '')}'),
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
        SnackBar(
          content: Text('병원 "${hospitalInfo.name}"이 삭제되었습니다.'),
        ),
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
              style: textTheme.bodyMedium?.copyWith(
                color: Colors.black87,
              ),
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
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'delete':
                  _deleteHospital();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Text('병원 탈퇴'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: isLoading
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
                      side: BorderSide(
                        color: Colors.grey.shade100,
                        width: 1,
                      ),
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
                              const SizedBox(width: 10),
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
                          _buildDetailRow(
                            context,
                            Icons.email_outlined,
                            '이메일',
                            hospitalInfo.email,
                          ),
                          if (hospitalInfo.address != null &&
                              hospitalInfo.address!.isNotEmpty)
                            _buildDetailRow(
                              context,
                              Icons.location_on_outlined,
                              '주소',
                              hospitalInfo.address!,
                            ),
                          if (hospitalInfo.phoneNumber != null &&
                              hospitalInfo.phoneNumber!.isNotEmpty)
                            _buildDetailRow(
                              context,
                              Icons.phone_outlined,
                              '연락처',
                              hospitalInfo.phoneNumber!,
                            ),
                          if (hospitalInfo.managerName != null &&
                              hospitalInfo.managerName!.isNotEmpty)
                            _buildDetailRow(
                              context,
                              Icons.person_outline,
                              '담당자',
                              hospitalInfo.managerName!,
                            ),
                          _buildDetailRow(
                            context,
                            Icons.event_note_outlined,
                            '가입일',
                            DateFormat('yyyy-MM-dd HH:mm')
                                .format(hospitalInfo.createdAt),
                          ),
                          _buildDetailRow(
                            context,
                            Icons.business_outlined,
                            '요양기관기호',
                            hospitalInfo.hospitalCode ?? '미등록',
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
                      side: BorderSide(
                        color: Colors.grey.shade100,
                        width: 1,
                      ),
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
                                backgroundColor: AppTheme.primaryBlue,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                isLoading ? '업데이트 중...' : '업데이트',
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
                  // 계정 상태 제어 카드
                  Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 10.0,
                    ),
                    elevation: 2,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: Colors.grey.shade100,
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '계정 상태 관리',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '칼럼 작성 권한',
                                      style: textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      hospitalInfo.isActive
                                          ? '계정이 활성화되어 있어 칼럼 작성이 가능합니다.'
                                          : '계정이 비활성화되어 칼럼 작성이 불가능합니다.',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: hospitalInfo.isActive,
                                onChanged: isLoading
                                    ? null
                                    : (value) => _toggleHospitalActive(),
                                activeColor: Colors.green,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}