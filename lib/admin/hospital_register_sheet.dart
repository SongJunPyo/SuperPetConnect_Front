import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:kpostal/kpostal.dart';
import '../services/admin_hospital_service.dart';
import '../utils/app_theme.dart';
import '../utils/debouncer.dart';
import '../utils/error_display.dart';
import '../utils/kakao_postcode_stub.dart'
    if (dart.library.html) '../utils/kakao_postcode_web.dart';
import '../widgets/pagination_bar.dart';

// 병원 등록 바텀시트 — 마스터 검색 + 신규 등록을 한 시트에 통합.
// 사용자가 검색해보고 없으면 "새 병원 등록" 버튼으로 폼 모드로 전환.
class HospitalRegisterSheet extends StatefulWidget {
  const HospitalRegisterSheet({super.key});

  @override
  State<HospitalRegisterSheet> createState() => _HospitalRegisterSheetState();
}

class _HospitalRegisterSheetState extends State<HospitalRegisterSheet> {
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
