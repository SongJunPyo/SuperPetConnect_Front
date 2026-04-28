import 'package:flutter/material.dart';
import 'dart:convert';
import '../utils/app_theme.dart';
import '../utils/app_constants.dart';
import '../utils/config.dart';
import '../utils/api_endpoints.dart';
import '../services/auth_http_client.dart';
import '../models/pet_model.dart';
import '../widgets/app_search_bar.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/pet_profile_image.dart';

/// 관리자 반려동물 관리 페이지
/// 반려동물 승인/거절 및 상태별 필터링
class AdminPetManagement extends StatefulWidget {
  const AdminPetManagement({super.key});

  @override
  State<AdminPetManagement> createState() => _AdminPetManagementState();
}

class _AdminPetManagementState extends State<AdminPetManagement>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<_AdminPet> _pets = [];
  bool _isLoading = true;
  String _errorMessage = '';
  int _currentPage = 1;
  int _totalPages = 1;
  int _selectedStatus = 0; // 기본: 승인 대기
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedStatus = _tabController.index;
          _currentPage = 1;
        });
        _fetchPets();
      }
    });
    _fetchPets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      var queryStr = '${Config.serverUrl}${ApiEndpoints.adminPets}?status=$_selectedStatus&page=$_currentPage&page_size=${AppConstants.detailListPageSize}';
      if (_searchQuery.isNotEmpty) {
        queryStr += '&search=${Uri.encodeComponent(_searchQuery)}';
      }
      final url = Uri.parse(queryStr);
      final response = await AuthHttpClient.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> petsJson = data['pets'] ?? [];
        setState(() {
          _pets = petsJson.map((j) => _AdminPet.fromJson(j)).toList();
          _totalPages = data['total_pages'] ?? 1;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = '반려동물 목록을 불러오는데 실패했습니다: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _approvePet(int petIdx) async {
    try {
      final url = Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.adminPetApprove(petIdx)}',
      );
      final response = await AuthHttpClient.post(url);

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('반려동물이 승인되었습니다.')),
          );
        }
        _fetchPets();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('승인 실패: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    }
  }

  Future<void> _rejectPet(int petIdx, String reason) async {
    try {
      final url = Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.adminPetReject(petIdx)}',
      );
      final response = await AuthHttpClient.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(reason.isNotEmpty ? {'rejection_reason': reason} : {}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('반려동물이 거절되었습니다.')),
          );
        }
        _fetchPets();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('거절 실패: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    }
  }

  Future<void> _resetToPending(int petIdx) async {
    // 승인 대기로 되돌리기 - 거절 API를 사유 없이 호출 후 다시 승인 대기 상태로
    // TODO: 서버에 PUT /api/admin/pets/{petIdx}/reset-pending API 필요
    // 임시로 거절 후 상태를 0으로 변경하는 방식은 불가하므로 서버 API 필요
    try {
      final url = Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.adminPetResetPending(petIdx)}',
      );
      final response = await AuthHttpClient.post(url);

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('승인 대기 상태로 변경되었습니다.')),
          );
        }
        _fetchPets();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('상태 변경 실패: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    }
  }

  void _showRejectSheet(int petIdx, String petName) {
    final reasonController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
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
                  Text('반려동물 거절', style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing8),
              Text(petName, style: AppTheme.h4Style),
              const SizedBox(height: AppTheme.spacing16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: '거절 사유를 입력해주세요 (선택사항)\n(예: 나이 미충족, 체중 미달, 임신 중)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    final reason = reasonController.text.trim();
                    Navigator.pop(context);
                    _rejectPet(petIdx, reason);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                  child: const Text('거절 확인', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: AppTheme.spacing8),
            ],
          ),
        ),
      ),
    );
  }

  void _showPetDetailSheet(_AdminPet adminPet) {
    final pet = adminPet.pet;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
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
                PetProfileImage(
                  profileImage: pet.profileImage,
                  species: pet.species,
                  radius: 24,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(pet.name, style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.bold))),
                if (pet.approvalStatus != 0)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    tooltip: '상태 변경',
                    onSelected: (value) {
                      Navigator.pop(context);
                      switch (value) {
                        case 'approve':
                          _approvePet(pet.petIdx!);
                          break;
                        case 'reject':
                          _showRejectSheet(pet.petIdx!, pet.name);
                          break;
                        case 'pending':
                          _resetToPending(pet.petIdx!);
                          break;
                      }
                    },
                    itemBuilder: (context) {
                      final items = <PopupMenuEntry<String>>[];
                      if (pet.approvalStatus == 1) {
                        // 승인됨 → 거절로 변경, 승인 대기로 변경
                        items.add(const PopupMenuItem(
                          value: 'reject',
                          child: Row(
                            children: [
                              Icon(Icons.cancel_outlined, color: AppTheme.error, size: 18),
                              SizedBox(width: 8),
                              Text('거절로 변경'),
                            ],
                          ),
                        ));
                        items.add(const PopupMenuItem(
                          value: 'pending',
                          child: Row(
                            children: [
                              Icon(Icons.hourglass_empty, color: AppTheme.warning, size: 18),
                              SizedBox(width: 8),
                              Text('승인 대기로 변경'),
                            ],
                          ),
                        ));
                      } else if (pet.approvalStatus == 2) {
                        // 거절됨 → 승인으로 변경, 승인 대기로 변경
                        items.add(const PopupMenuItem(
                          value: 'approve',
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline, color: AppTheme.success, size: 18),
                              SizedBox(width: 8),
                              Text('승인으로 변경'),
                            ],
                          ),
                        ));
                        items.add(const PopupMenuItem(
                          value: 'pending',
                          child: Row(
                            children: [
                              Icon(Icons.hourglass_empty, color: AppTheme.warning, size: 18),
                              SizedBox(width: 8),
                              Text('승인 대기로 변경'),
                            ],
                          ),
                        ));
                      }
                      return items;
                    },
                  ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 보호자 정보
                    _buildDetailRow('보호자', adminPet.ownerName),
                    _buildDetailRow('닉네임', adminPet.ownerNickname),
                    _buildDetailRow('이메일', adminPet.ownerEmail),
                    const Divider(),
                    // 반려동물 기본 정보
                    _buildDetailRow('종', pet.species),
                    _buildDetailRow('품종', pet.breed ?? '-'),
                    _buildDetailRow('혈액형', pet.bloodType ?? '-'),
                    _buildDetailRow('생년월일', pet.birthDateWithAge),
                    _buildDetailRow('몸무게', '${pet.weightKg}kg',
                        isWarning: pet.weightKg < 1),
                    const Divider(),
                    // 건강 정보
                    _buildBoolRow('백신 접종', pet.vaccinated, failIfFalse: true),
                    _buildBoolRow('질병 이력', pet.hasDisease, failIfTrue: true),
                    _buildBoolRow('출산 경험', pet.hasBirthExperience),
                    _buildBoolRow('임신 여부', pet.pregnant, failIfTrue: true),
                    _buildBoolRow('중성화', pet.isNeutered),
                    _buildBoolRow('예방약 복용', pet.hasPreventiveMedication, failIfFalse: true),
                    if (adminPet.isReview && adminPet.previousValues != null && adminPet.previousValues!.isNotEmpty) ...[
                      const Divider(),
                      const Text('변경 내역', style: TextStyle(fontSize: AppTheme.bodyMedium, fontWeight: FontWeight.w600)),
                      const SizedBox(height: AppTheme.spacing8),
                      ...adminPet.previousValues!.entries.map((entry) {
                        final fieldName = _AdminPet.fieldNameMap[entry.key] ?? entry.key;
                        final prevValue = _AdminPet.formatValue(entry.key, entry.value);
                        final currentValue = _getCurrentValue(pet, entry.key);
                        final formattedCurrent = _AdminPet.formatValue(entry.key, currentValue);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 100,
                                child: Text(fieldName, style: const TextStyle(fontSize: AppTheme.bodyMedium, color: AppTheme.textSecondary)),
                              ),
                              Text(prevValue, style: const TextStyle(fontSize: AppTheme.bodyMedium, color: AppTheme.textTertiary, decoration: TextDecoration.lineThrough)),
                              const Text(' → ', style: TextStyle(fontSize: AppTheme.bodyMedium, color: AppTheme.textSecondary)),
                              Text(formattedCurrent, style: const TextStyle(fontSize: AppTheme.bodyMedium, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      }),
                    ] else if (adminPet.isReview) ...[
                      const Divider(),
                      _buildDetailRow('구분', '정보 수정 (재심사)'),
                    ],
                    if (pet.rejectionReason != null) ...[
                      const Divider(),
                      _buildDetailRow('이전 거절 사유', pet.rejectionReason!),
                    ],
                  ],
                ),
              ),
            ),
            if (pet.approvalStatus == 0) ...[
              const SizedBox(height: AppTheme.spacing16),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showRejectSheet(pet.petIdx!, pet.name);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.error,
                          side: const BorderSide(color: AppTheme.error),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radius12),
                          ),
                        ),
                        child: const Text('거절', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _approvePet(pet.petIdx!);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.success,
                          side: const BorderSide(color: AppTheme.success),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radius12),
                          ),
                        ),
                        child: const Text('승인', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  dynamic _getCurrentValue(Pet pet, String field) {
    switch (field) {
      case 'name': return pet.name;
      case 'species': return pet.species;
      case 'breed': return pet.breed;
      case 'birth_date': return pet.birthDate?.toIso8601String().split('T')[0];
      case 'blood_type': return pet.bloodType;
      case 'weight_kg': return pet.weightKg;
      case 'pregnant': return pet.pregnant;
      case 'vaccinated': return pet.vaccinated;
      case 'has_disease': return pet.hasDisease;
      case 'has_birth_experience': return pet.hasBirthExperience;
      case 'is_neutered': return pet.isNeutered;
      case 'neutered_date': return pet.neuteredDate?.toIso8601String().split('T')[0];
      case 'has_preventive_medication': return pet.hasPreventiveMedication;
      default: return null;
    }
  }

  Widget _buildDetailRow(String label, String value, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: isWarning ? AppTheme.error : AppTheme.textSecondary,
                fontSize: AppTheme.bodyMedium,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: AppTheme.bodyMedium,
                color: isWarning ? AppTheme.error : AppTheme.textPrimary,
                fontWeight: isWarning ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoolRow(String label, bool? value, {bool failIfTrue = false, bool failIfFalse = false}) {
    final bool isWarning;
    if (value == null) {
      isWarning = false;
    } else {
      isWarning = (failIfTrue && value) || (failIfFalse && !value);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: isWarning ? AppTheme.error : AppTheme.textSecondary,
                fontSize: AppTheme.bodyMedium,
              ),
            ),
          ),
          if (value == null)
            const Text('-', style: TextStyle(fontSize: AppTheme.bodyMedium, color: AppTheme.textTertiary))
          else
            Icon(
              value ? Icons.check_circle : Icons.cancel,
              size: 18,
              color: isWarning
                  ? AppTheme.error
                  : value
                      ? AppTheme.success
                      : AppTheme.textTertiary,
            ),
        ],
      ),
    );
  }



  Widget _buildPetCard(_AdminPet adminPet) {
    final pet = adminPet.pet;
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing4,
      ),
      child: InkWell(
        onTap: () => _showPetDetailSheet(adminPet),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 왼쪽: 프로필 사진 (크게)
                  PetProfileImage(
                    profileImage: pet.profileImage,
                    species: pet.species,
                    radius: 28,
                  ),
                  const SizedBox(width: 14),
                  // 오른쪽: 닉네임 + 반려동물 이름 + 배지
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 닉네임
                        Text(
                          adminPet.ownerNickname.isNotEmpty ? adminPet.ownerNickname : adminPet.ownerName,
                          style: const TextStyle(
                            fontSize: AppTheme.bodyLarge,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // 반려동물 이름
                        Row(
                          children: [
                            if (pet.isPrimary)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.star, size: 14, color: AppTheme.warning),
                              ),
                            Text(
                              '반려동물 이름 : ${pet.name}',
                              style: const TextStyle(
                                fontSize: AppTheme.bodyMedium,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // 거절 사유
              if (pet.approvalStatus == 2 && pet.rejectionReason != null) ...[
                const SizedBox(height: AppTheme.spacing8),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacing8),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppTheme.radius4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: AppTheme.error),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '사유: ${pet.rejectionReason}',
                          style: const TextStyle(
                            fontSize: AppTheme.bodySmall,
                            color: AppTheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _fetchPets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('반려동물 관리'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '승인 대기'),
            Tab(text: '승인됨'),
            Tab(text: '거절됨'),
          ],
          labelColor: AppTheme.textPrimary,
          unselectedLabelColor: AppTheme.textTertiary,
          indicatorColor: AppTheme.primaryBlue,
        ),
      ),
      body: Column(
        children: [
          // 검색 바
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, AppTheme.spacing12, AppTheme.spacing16, AppTheme.spacing8),
            child: AppSearchBar(
              controller: _searchController,
              hintText: '닉네임, 보호자명, 반려동물 이름 검색',
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim();
                  _currentPage = 1;
                });
                _fetchPets();
              },
              onClear: () {
                setState(() {
                  _searchQuery = '';
                  _currentPage = 1;
                });
                _fetchPets();
              },
            ),
          ),
          // 본문
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_errorMessage, textAlign: TextAlign.center),
                            const SizedBox(height: AppTheme.spacing16),
                            ElevatedButton(
                              onPressed: _fetchPets,
                              child: const Text('다시 시도'),
                            ),
                          ],
                        ),
                      )
                    : _pets.isEmpty
                        ? Center(
                            child: Text(
                              _searchQuery.isNotEmpty
                                  ? '검색 결과가 없습니다.'
                                  : _selectedStatus == 0
                                      ? '승인 대기 중인 반려동물이 없습니다.'
                                      : _selectedStatus == 1
                                          ? '승인된 반려동물이 없습니다.'
                                          : '거절된 반려동물이 없습니다.',
                              style: const TextStyle(color: AppTheme.textTertiary),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchPets,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
                              itemCount: _pets.length + (_totalPages > 1 ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index >= _pets.length) {
                                  return PaginationBar(
                                    currentPage: _currentPage,
                                    totalPages: _totalPages,
                                    onPageChanged: _onPageChanged,
                                  );
                                }
                                return _buildPetCard(_pets[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

/// 관리자용 반려동물 데이터 (보호자 정보 포함)
class _AdminPet {
  final Pet pet;
  final String ownerName;
  final String ownerNickname;
  final String ownerEmail;
  final bool isReview;
  final Map<String, dynamic>? previousValues;

  _AdminPet({
    required this.pet,
    required this.ownerName,
    required this.ownerNickname,
    required this.ownerEmail,
    required this.isReview,
    this.previousValues,
  });

  factory _AdminPet.fromJson(Map<String, dynamic> json) {
    final owner = json['owner'] as Map<String, dynamic>? ?? {};
    return _AdminPet(
      pet: Pet.fromJson(json),
      ownerName: owner['name'] ?? '',
      ownerNickname: owner['nickname'] ?? '',
      ownerEmail: owner['email'] ?? '',
      isReview: json['is_review'] == true,
      previousValues: json['previous_values'] as Map<String, dynamic>?,
    );
  }

  /// 필드명 한글 매핑
  static const Map<String, String> fieldNameMap = {
    'name': '이름',
    'species': '종',
    'breed': '품종',
    'birth_date': '생년월일',
    'blood_type': '혈액형',
    'weight_kg': '몸무게',
    'pregnant': '임신 여부',
    'vaccinated': '백신 접종',
    'has_disease': '질병 여부',
    'has_birth_experience': '출산 경험',
    'is_neutered': '중성화 여부',
    'neutered_date': '중성화 수술일',
    'has_preventive_medication': '예방약 복용',
  };

  /// Boolean 필드 목록
  static const Set<String> boolFields = {
    'pregnant', 'vaccinated', 'has_disease', 'has_birth_experience',
    'is_neutered', 'has_preventive_medication',
  };

  /// 값을 표시용 문자열로 변환
  static String formatValue(String field, dynamic value) {
    if (value == null) return '-';
    if (boolFields.contains(field)) {
      return (value == true || value == 1) ? '✅' : '❌';
    }
    if (field == 'weight_kg') return '${value}kg';
    return value.toString();
  }
}
