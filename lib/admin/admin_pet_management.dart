import 'package:flutter/material.dart';
import 'dart:convert';
import '../utils/app_theme.dart';
import '../utils/app_constants.dart';
import '../utils/config.dart';
import '../utils/api_endpoints.dart';
import '../utils/pet_field_icons.dart';
import '../utils/phone_formatter.dart';
import '../services/auth_http_client.dart';
import '../models/pet_model.dart';
import '../widgets/app_search_bar.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/pet_profile_image.dart';
import '../widgets/pet_status_row.dart';

/// 관리자 반려동물 관리 페이지
/// 반려동물 승인/거절 및 상태별 필터링
class AdminPetManagement extends StatefulWidget {
  /// 알림 진입 시 자동으로 상세 시트를 열 펫 pet_idx.
  /// 승인 대기 탭(0)의 fetched 리스트에서 매칭 후 _showPetDetailSheet 자동 호출.
  /// pet_review_request / new_pet_registration / pet_profile_image_review_request
  /// 알림은 모두 승인 대기 탭에 노출되므로 탭 0 fetch만으로 커버됨.
  final int? initialPetIdx;

  const AdminPetManagement({super.key, this.initialPetIdx});

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

  // initState에서 시작한 첫 fetch를 await할 수 있도록 보관.
  // _maybeAutoOpenDetailSheet가 별도 _fetchPets()를 또 호출하면 두 fetch가 race되어
  // 늦게 끝나는 setState가 모달 시트 표시 직후 호출되며, 웹에서 시트가 영향을 받는다.
  Future<void>? _initialFetchFuture;

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
    _initialFetchFuture = _fetchPets();

    if (widget.initialPetIdx != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeAutoOpenDetailSheet();
      });
    }
  }

  /// 알림 진입 시 첫 fetch 완료 후 매칭 펫의 상세 시트 자동 오픈.
  ///
  /// 알림(`new_pet_registration` 등)은 등록 시점에는 PENDING이지만, admin이 알림
  /// 클릭 전에 이미 승인/거절했을 수 있어 PENDING 탭에 없을 수 있다. 이 경우
  /// 승인됨/거절됨 탭으로 fallback 검색해 시트를 열어준다.
  Future<void> _maybeAutoOpenDetailSheet() async {
    await _initialFetchFuture;
    if (!mounted) return;
    final id = widget.initialPetIdx;
    if (id == null) return;

    // 1) PENDING 탭(기본)에서 매칭
    var adminPet = _pets.where((p) => p.pet.petIdx == id).firstOrNull;
    if (adminPet != null) {
      _showPetDetailSheet(adminPet);
      return;
    }

    // 2) 이미 처리된 케이스 — 승인됨(1) / 거절됨(2) 탭 순회
    for (final status in const [1, 2]) {
      if (!mounted) return;
      setState(() {
        _selectedStatus = status;
        _currentPage = 1;
      });
      await _fetchPets();
      if (!mounted) return;
      adminPet = _pets.where((p) => p.pet.petIdx == id).firstOrNull;
      if (adminPet != null) {
        // 탭 UI 동기화 (listener가 한 번 더 _fetchPets를 호출하지만 동일 status라 무해)
        _tabController.index = status;
        _showPetDetailSheet(adminPet);
        return;
      }
    }
    // 모든 탭에서 못 찾으면 펫이 삭제됐거나 페이지 범위 밖 — silent fail.
    // 반려동물 관리 화면에는 진입했으므로 사용자가 수동 조회 가능.
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
      if (_selectedStatus == 0) {
        // 승인 대기 탭: 정보 검토 + 사진 검토 두 API 병렬 호출 후 pet_idx 기준 merge.
        // 사진 검토는 검색 미지원이라 검색어 입력 시에는 정보 검토 결과만 사용.
        final results = await Future.wait([
          _fetchInfoReviewPets(),
          if (_searchQuery.isEmpty)
            _fetchPhotoReviewPets()
          else
            Future.value(<_AdminPet>[]),
        ]);
        final infoPets = results[0];
        final photoPets = results[1];

        final merged = <int, _AdminPet>{};
        for (final p in infoPets) {
          final idx = p.pet.petIdx;
          if (idx != null) merged[idx] = p;
        }
        for (final p in photoPets) {
          final idx = p.pet.petIdx;
          if (idx == null) continue;
          final existing = merged[idx];
          merged[idx] = existing == null ? p : existing.mergeWith(p);
        }

        final mergedList = merged.values.toList()
          ..sort((a, b) => (b.pet.petIdx ?? 0).compareTo(a.pet.petIdx ?? 0));

        setState(() {
          _pets = mergedList;
          _totalPages = 1;
          _currentPage = 1;
          _isLoading = false;
        });
      } else {
        // 승인됨/거절됨 탭: 기존 서버 페이지네이션 그대로
        var queryStr = '${Config.serverUrl}${ApiEndpoints.adminPets}'
            '?status=$_selectedStatus&page=$_currentPage'
            '&page_size=${AppConstants.detailListPageSize}';
        if (_searchQuery.isNotEmpty) {
          queryStr += '&search=${Uri.encodeComponent(_searchQuery)}';
        }
        final response = await AuthHttpClient.get(Uri.parse(queryStr));

        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          final List<dynamic> petsJson = data['pets'] ?? [];
          setState(() {
            _pets = petsJson
                .map((j) => _AdminPet.fromInfoReviewJson(j))
                .toList();
            _totalPages = data['total_pages'] ?? 1;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage =
                '반려동물 목록을 불러오는데 실패했습니다: ${response.statusCode}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = '오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  /// 정보 검토 대기 펫 (승인 대기 탭 전용, page_size=50으로 한 번에 가져옴).
  Future<List<_AdminPet>> _fetchInfoReviewPets() async {
    var queryStr =
        '${Config.serverUrl}${ApiEndpoints.adminPets}?status=0&page=1&page_size=50';
    if (_searchQuery.isNotEmpty) {
      queryStr += '&search=${Uri.encodeComponent(_searchQuery)}';
    }
    final response = await AuthHttpClient.get(Uri.parse(queryStr));
    if (response.statusCode != 200) {
      throw Exception('정보 검토 목록 조회 실패: ${response.statusCode}');
    }
    final data = json.decode(utf8.decode(response.bodyBytes));
    final List<dynamic> petsJson = data['pets'] ?? [];
    return petsJson.map((j) => _AdminPet.fromInfoReviewJson(j)).toList();
  }

  /// 사진 검토 대기 펫 (`/api/admin/pets/profile-images/pending`).
  /// 백엔드 contract: search 미지원, 정렬 pet_idx desc, page_size 1~50.
  Future<List<_AdminPet>> _fetchPhotoReviewPets() async {
    final url = Uri.parse(
      '${Config.serverUrl}${ApiEndpoints.adminPetsProfileImagesPending}'
      '?page=1&page_size=50',
    );
    final response = await AuthHttpClient.get(url);
    if (response.statusCode != 200) {
      throw Exception('사진 검토 목록 조회 실패: ${response.statusCode}');
    }
    final data = json.decode(utf8.decode(response.bodyBytes));
    final List<dynamic> petsJson = data['pets'] ?? [];
    return petsJson.map((j) => _AdminPet.fromPhotoReviewJson(j)).toList();
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

  /// 펫 프로필 사진 검토 승인 (`POST /api/admin/pets/{idx}/profile-image/approve`).
  Future<void> _approvePhoto(int petIdx) async {
    try {
      final url = Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.adminPetProfileImageApprove(petIdx)}',
      );
      final response = await AuthHttpClient.post(url);

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('프로필 사진이 승인되었습니다.')),
          );
        }
        _fetchPets();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('사진 승인 실패: ${response.statusCode}')),
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

  /// 펫 프로필 사진 검토 거절 (`POST /api/admin/pets/{idx}/profile-image/reject`).
  /// [reason]은 비어 있으면 사유 없이 거절. 백엔드 contract: snake_case `rejection_reason`.
  Future<void> _rejectPhoto(int petIdx, String reason) async {
    try {
      final url = Uri.parse(
        '${Config.serverUrl}${ApiEndpoints.adminPetProfileImageReject(petIdx)}',
      );
      final response = await AuthHttpClient.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(
          reason.isNotEmpty ? {'rejection_reason': reason} : {},
        ),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('프로필 사진이 거절되었습니다.')),
          );
        }
        _fetchPets();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('사진 거절 실패: ${response.statusCode}')),
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

  /// 정보+사진 통합 승인 — 펜딩된 워크플로우만 순차 호출.
  Future<void> _approveAll(_AdminPet adminPet) async {
    final petIdx = adminPet.pet.petIdx;
    if (petIdx == null) return;
    if (adminPet.hasInfoReview) {
      await _approvePet(petIdx);
    }
    if (adminPet.hasPhotoReview) {
      await _approvePhoto(petIdx);
    }
  }

  /// 정보+사진 통합 거절 시트 — 단일 사유를 펜딩된 양쪽 워크플로우에 모두 전달.
  void _showUnifiedRejectSheet(_AdminPet adminPet) {
    final petIdx = adminPet.pet.petIdx;
    if (petIdx == null) return;
    final reasonController = TextEditingController();
    final petName = adminPet.pet.name;
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
                  Text(
                    '거절',
                    style:
                        AppTheme.h3Style.copyWith(fontWeight: FontWeight.bold),
                  ),
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
                  hintText: '거절 사유를 입력해주세요 (선택사항)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () async {
                    final reason = reasonController.text.trim();
                    Navigator.pop(context);
                    if (adminPet.hasInfoReview) {
                      await _rejectPet(petIdx, reason);
                    }
                    if (adminPet.hasPhotoReview) {
                      await _rejectPhoto(petIdx, reason);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                  child: const Text('거절 확인',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: AppTheme.spacing8),
            ],
          ),
        ),
      ),
    );
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
                    // 보호자 정보 — 아이콘은 PetFieldIcons 단일 진실.
                    _buildDetailRow(
                      icon: PetFieldIcons.userName,
                      label: '보호자',
                      value: adminPet.ownerName,
                    ),
                    _buildDetailRow(
                      icon: PetFieldIcons.nickname,
                      label: '닉네임',
                      value: adminPet.ownerNickname,
                    ),
                    _buildDetailRow(
                      icon: PetFieldIcons.email,
                      label: '이메일',
                      value: adminPet.ownerEmail,
                    ),
                    _buildDetailRow(
                      icon: PetFieldIcons.phone,
                      label: '연락처',
                      value: adminPet.ownerPhone.isNotEmpty
                          ? formatPhoneNumber(adminPet.ownerPhone)
                          : null,
                      statusIcon: adminPet.ownerPhone.isEmpty
                          ? Icons.cancel_outlined
                          : null,
                    ),
                    // 사진 변경 요청 (있을 때만): 큼직한 좌우 비교
                    if (adminPet.hasPhotoReview) ...[
                      const Divider(),
                      _buildPhotoReviewSection(pet, adminPet.pendingProfileImage),
                    ],
                    const Divider(),
                    // 펫 정보 표시 순서 (회원가입 관리와 정합, 2026-05-02 확정):
                    // 종류 → 품종 → 성별 → 혈액형 → 체중 → 생년월일 → 최근 헌혈일 →
                    // 접종 → 예방약 → 중성화 → 질병 → 임신/출산
                    // (이름은 시트 헤더에 이미 표시되어 detail 행에서 제외)
                    _buildDetailRow(
                      icon: PetFieldIcons.species,
                      label: '종류',
                      value: pet.species,
                    ),
                    if (pet.breed?.isNotEmpty == true)
                      _buildDetailRow(
                        icon: PetFieldIcons.breed,
                        label: '품종',
                        value: pet.breed,
                      )
                    else
                      const PetStatusRow(
                        icon: PetFieldIcons.breed,
                        label: '품종',
                        labelWidth: 90,
                        status: PetStatusType.neutral,
                      ),
                    _buildDetailRow(
                      icon: PetFieldIcons.sex(pet.sex),
                      label: '성별',
                      value: pet.sex == 0 ? '암컷' : '수컷',
                    ),
                    if (pet.bloodType != null)
                      _buildDetailRow(
                        icon: PetFieldIcons.bloodType,
                        label: '혈액형',
                        value: pet.bloodType,
                      )
                    else
                      const PetStatusRow(
                        icon: PetFieldIcons.bloodType,
                        label: '혈액형',
                        labelWidth: 90,
                        status: PetStatusType.neutral,
                      ),
                    _buildDetailRow(
                      icon: PetFieldIcons.weight,
                      label: '체중',
                      value: '${pet.weightKg}kg',
                      isWarning: pet.weightKg < 1,
                    ),
                    // 생년월일: 미입력 시 주황 ⚠ (정보 미입력 = 주의)
                    if (pet.birthDate != null)
                      _buildDetailRow(
                        icon: PetFieldIcons.birthDate,
                        label: '생년월일',
                        value: pet.birthDateWithAge,
                      )
                    else
                      const PetStatusRow(
                        icon: PetFieldIcons.birthDate,
                        label: '생년월일',
                        labelWidth: 90,
                        status: PetStatusType.warning,
                      ),
                    // 최근 헌혈일: 미입력 시 회색 — (첫 헌혈 = 자연스러운 부재)
                    if (pet.prevDonationDate != null)
                      _buildDetailRow(
                        icon: PetFieldIcons.prevDonationDate,
                        label: '최근 헌혈일',
                        value:
                            '${pet.prevDonationDate!.year}.${pet.prevDonationDate!.month.toString().padLeft(2, '0')}.${pet.prevDonationDate!.day.toString().padLeft(2, '0')}',
                      )
                    else
                      const PetStatusRow(
                        icon: PetFieldIcons.prevDonationDate,
                        label: '최근 헌혈일',
                        labelWidth: 90,
                        status: PetStatusType.neutral,
                      ),
                    // 건강 정보 — 4단계 상태 시스템 (PetStatusRow 단일 진실).
                    // 펫 기본 정보와 같은 그룹이라 divider 없이 이어서 표시.
                    PetStatusRow(
                      icon: PetFieldIcons.vaccinated,
                      label: '접종',
                      labelWidth: 90,
                      status: pet.vaccinated == true
                          ? PetStatusType.positive
                          : PetStatusType.critical,
                    ),
                    PetStatusRow(
                      icon: PetFieldIcons.medication,
                      label: '예방약',
                      labelWidth: 90,
                      status: pet.hasPreventiveMedication == true
                          ? PetStatusType.positive
                          : PetStatusType.critical,
                    ),
                    PetStatusRow(
                      icon: PetFieldIcons.isNeutered,
                      label: '중성화',
                      labelWidth: 90,
                      status: pet.isNeutered == true
                          ? PetStatusType.positive
                          : PetStatusType.neutral,
                    ),
                    PetStatusRow(
                      icon: PetFieldIcons.hasDisease,
                      label: '질병',
                      labelWidth: 90,
                      status: pet.hasDisease == true
                          ? PetStatusType.critical
                          : PetStatusType.neutral,
                    ),
                    // 임신/출산 (마지막):
                    //   status=2 + 종료일 → 텍스트 "출산 YYYY.MM.DD"
                    //   status=1(임신중) → 주황 ⚠
                    //   status=0(해당없음) → 회색 —
                    if (pet.pregnancyBirthStatus == 2 &&
                        pet.lastPregnancyEndDate != null)
                      _buildDetailRow(
                        icon: PetFieldIcons.pregnancyBirth,
                        label: '임신/출산',
                        value: _formatPregnancyBirth(pet),
                      )
                    else
                      PetStatusRow(
                        icon: PetFieldIcons.pregnancyBirth,
                        label: '임신/출산',
                        labelWidth: 90,
                        status: pet.pregnancyBirthStatus == 1
                            ? PetStatusType.warning
                            : PetStatusType.neutral,
                      ),
                    if (adminPet.isReview && adminPet.previousValues != null && adminPet.previousValues!.isNotEmpty) ...[
                      const SizedBox(height: AppTheme.spacing16),
                      _buildChangeHistoryCard(pet, adminPet.previousValues!),
                    ] else if (adminPet.isReview) ...[
                      const SizedBox(height: AppTheme.spacing16),
                      _buildChangeHistoryCard(pet, const {}),
                    ],
                    if (pet.rejectionReason != null) ...[
                      const Divider(),
                      _buildDetailRow(
                        icon: PetFieldIcons.userStatus,
                        label: '이전 거절 사유',
                        value: pet.rejectionReason!,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // 결정 버튼: 정보/사진 검토를 한 번에 처리하는 단일 거절/승인.
            // 백엔드는 여전히 별개 endpoint이지만 UX를 단순화 — 승인은 양쪽 모두
            // 호출, 거절은 단일 사유로 양쪽에 전달.
            if (adminPet.hasInfoReview || adminPet.hasPhotoReview) ...[
              const SizedBox(height: AppTheme.spacing16),
              _buildDecisionRow(
                onReject: () {
                  Navigator.pop(context);
                  _showUnifiedRejectSheet(adminPet);
                },
                onApprove: () {
                  Navigator.pop(context);
                  _approveAll(adminPet);
                },
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
      case 'sex': return pet.sex;
      case 'pregnancy_birth_status': return pet.pregnancyBirthStatus;
      case 'last_pregnancy_end_date':
        return pet.lastPregnancyEndDate?.toIso8601String().split('T')[0];
      case 'vaccinated': return pet.vaccinated;
      case 'has_disease': return pet.hasDisease;
      case 'is_neutered': return pet.isNeutered;
      case 'neutered_date': return pet.neuteredDate?.toIso8601String().split('T')[0];
      case 'has_preventive_medication': return pet.hasPreventiveMedication;
      default: return null;
    }
  }

  /// 임신/출산 상태 표시 텍스트 (CLAUDE.md PregnancyBirthStatus 미러).
  /// 해당없음(0) / 출산이력 종료일 미입력은 null 반환 → X 아이콘으로 대체.
  String? _formatPregnancyBirth(Pet pet) {
    switch (pet.pregnancyBirthStatus) {
      case 1:
        return '임신중';
      case 2:
        if (pet.lastPregnancyEndDate == null) return null;
        final d = pet.lastPregnancyEndDate!;
        return '출산 ${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
      default:
        return null;
    }
  }

  /// 라벨 좌측 아이콘 + 라벨 + (선택적) 상태 아이콘 + (선택적) 값 텍스트.
  /// [value]가 null이면 텍스트는 그리지 않고 [statusIcon]만 노출 — "나이 미상/
  /// 해당 없음" 등 부재 상태를 텍스트 대신 X 아이콘으로 대체하기 위함.
  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    String? value,
    IconData? statusIcon,
    Color? statusColor,
    bool isWarning = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                color: isWarning ? AppTheme.error : AppTheme.textSecondary,
                fontSize: AppTheme.bodyMedium,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                if (statusIcon != null) ...[
                  Icon(
                    statusIcon,
                    size: 18,
                    color: statusColor ?? AppTheme.textTertiary,
                  ),
                  if (value != null) const SizedBox(width: 6),
                ],
                if (value != null)
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: AppTheme.bodyMedium,
                        color:
                            isWarning ? AppTheme.error : AppTheme.textPrimary,
                        fontWeight:
                            isWarning ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 상세 시트 내 사진 변경 비교 섹션 (큼직한 좌우 + 화살표).
  Widget _buildPhotoReviewSection(Pet pet, String? pendingImage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.photo_camera,
                size: 16,
                color: _photoReviewColor,
              ),
              const SizedBox(width: 6),
              const Text(
                '프로필 사진 변경 요청',
                style: TextStyle(
                  fontSize: AppTheme.bodyMedium,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  PetProfileImage(
                    profileImage: pet.profileImage,
                    species: pet.species,
                    radius: 48,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '현재',
                    style: TextStyle(
                      fontSize: AppTheme.bodySmall,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Icon(
                  Icons.arrow_forward,
                  size: 24,
                  color: AppTheme.textTertiary,
                ),
              ),
              Column(
                children: [
                  PetProfileImage(
                    profileImage: pendingImage,
                    species: pet.species,
                    radius: 48,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '변경 후',
                    style: TextStyle(
                      fontSize: AppTheme.bodySmall,
                      color: _photoReviewColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 정보 수정 재심사 변경 내역 카드.
  /// [previousValues]가 비어있어도 "변경 내역 없음" 안내 카드로 표시.
  Widget _buildChangeHistoryCard(Pet pet, Map<String, dynamic> previousValues) {
    final hasChanges = previousValues.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing12,
              vertical: AppTheme.spacing8,
            ),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radius12),
                topRight: Radius.circular(AppTheme.radius12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.history, size: 16, color: AppTheme.warning),
                const SizedBox(width: 6),
                Text(
                  hasChanges
                      ? '정보 수정 재심사 · ${previousValues.length}건 변경'
                      : '정보 수정 재심사',
                  style: AppTheme.bodyMediumStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warning,
                  ),
                ),
              ],
            ),
          ),
          // 항목들 (또는 빈 상태)
          if (hasChanges)
            ...previousValues.entries.map((entry) {
              final fieldName = _AdminPet.fieldNameMap[entry.key] ?? entry.key;
              final prevValue = _AdminPet.formatValue(entry.key, entry.value);
              final currentValue = _getCurrentValue(pet, entry.key);
              final formattedCurrent =
                  _AdminPet.formatValue(entry.key, currentValue);
              return _buildChangeRow(
                entry.key,
                fieldName,
                prevValue,
                formattedCurrent,
              );
            })
          else
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              child: Text(
                '변경 내역 정보가 없습니다.',
                style: AppTheme.bodySmallStyle.copyWith(
                  color: AppTheme.textTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 변경 내역 한 행: [아이콘] 필드명  이전(취소선) → 새 값(강조).
  /// 박스 없는 단일 라인 — 긴 값은 ellipsis 처리.
  Widget _buildChangeRow(
    String fieldKey,
    String label,
    String before,
    String after,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            _iconForField(fieldKey),
            size: 16,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTheme.bodySmallStyle.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              before,
              style: AppTheme.bodySmallStyle.copyWith(
                color: AppTheme.textTertiary,
                decoration: TextDecoration.lineThrough,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              Icons.arrow_forward,
              size: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          Flexible(
            child: Text(
              after,
              style: AppTheme.bodySmallStyle.copyWith(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// 변경 내역 행 좌측 아이콘 매핑 (필드 키 → IconData).
  /// PetFieldIcons.forField에 위임 — 매핑은 단일 진실에서 관리.
  IconData _iconForField(String key) => PetFieldIcons.forField(key);

  /// 거절/승인 단일 버튼 행 — 정보+사진 검토를 한 번에 처리.
  Widget _buildDecisionRow({
    required VoidCallback onReject,
    required VoidCallback onApprove,
  }) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: onReject,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.error,
                side: const BorderSide(color: AppTheme.error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
              ),
              child: const Text(
                '거절',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: onApprove,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.success,
                side: const BorderSide(color: AppTheme.success),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
              ),
              child: const Text(
                '승인',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 사진 검토 카드 색상 (티어). [unified_notification_page]의 review request 컬러와 동일.
  static const Color _photoReviewColor = Color(0xFF14B8A6);

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
                            Expanded(
                              child: Text(
                                '반려동물 이름 : ${pet.name}',
                                style: const TextStyle(
                                  fontSize: AppTheme.bodyMedium,
                                  color: AppTheme.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        // 검토 종류 뱃지 (정보 검토 / 사진 변경)
                        if (_buildReviewBadges(adminPet).isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: _buildReviewBadges(adminPet),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              // 사진 변경 요청: 좌(현재) → 우(변경 후) 미니 썸네일
              if (adminPet.hasPhotoReview) ...[
                const SizedBox(height: AppTheme.spacing12),
                _buildPhotoMiniCompare(pet, adminPet.pendingProfileImage),
              ],
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
              // 카드 하단 중앙 "더보기" 버튼 — 카드 자체 onTap과 별도로 명시적
              // 진입 핫스팟. 신청자 카드와 동일 패턴.
              const SizedBox(height: AppTheme.spacing4),
              Center(
                child: TextButton(
                  onPressed: () => _showPetDetailSheet(adminPet),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '더보기',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 카드에 표시할 검토 종류 뱃지 목록.
  /// - hasInfoReview + isReview=false → [신규]
  /// - hasInfoReview + isReview=true + previousValues 비어있지 않음 → [정보 수정]
  ///   (실제 변경 내역이 없으면 "정보 수정" 뱃지를 숨겨 혼란 방지 — 백엔드가
  ///    isReview=true로 표시했더라도 previousValues가 비어 있으면 사용자가
  ///    인지 가능한 변경이 없음)
  /// - hasPhotoReview                 → [사진 변경]
  List<Widget> _buildReviewBadges(_AdminPet adminPet) {
    final badges = <Widget>[];
    if (adminPet.hasInfoReview) {
      if (adminPet.isReview) {
        final hasChanges = adminPet.previousValues != null &&
            adminPet.previousValues!.isNotEmpty;
        if (hasChanges) {
          badges.add(_buildBadge('정보 수정', AppTheme.warning));
        }
      } else {
        badges.add(_buildBadge('신규', AppTheme.primaryBlue));
      }
    }
    if (adminPet.hasPhotoReview) {
      badges.add(_buildBadge('사진 변경', _photoReviewColor));
    }
    return badges;
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 카드 내 사진 변경 미니 비교 (현재 → 변경 후).
  /// 카드 onTap이 동작하도록 IgnorePointer로 내부 GestureDetector 차단.
  Widget _buildPhotoMiniCompare(Pet pet, String? pendingImage) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing8),
      decoration: BoxDecoration(
        color: _photoReviewColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Row(
        children: [
          const Icon(Icons.photo_camera, size: 14, color: _photoReviewColor),
          const SizedBox(width: 8),
          IgnorePointer(
            child: Column(
              children: [
                PetProfileImage(
                  profileImage: pet.profileImage,
                  species: pet.species,
                  radius: 22,
                ),
                const SizedBox(height: 2),
                const Text(
                  '현재',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.arrow_forward,
              size: 16,
              color: AppTheme.textTertiary,
            ),
          ),
          IgnorePointer(
            child: Column(
              children: [
                PetProfileImage(
                  profileImage: pendingImage,
                  species: pet.species,
                  radius: 22,
                ),
                const SizedBox(height: 2),
                const Text(
                  '변경 후',
                  style: TextStyle(
                    fontSize: 10,
                    color: _photoReviewColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
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
            Tab(text: '대기'),
            Tab(text: '승인'),
            Tab(text: '거절'),
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
                                      ? '대기 중인 반려동물이 없습니다.'
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

/// 관리자용 반려동물 데이터 (보호자 정보 + 검토 종류 플래그)
///
/// 정보 검토(`/api/admin/pets?status=0`)와 사진 검토
/// (`/api/admin/pets/profile-images/pending`)는 백엔드상 별개 결정 단위이며,
/// 같은 `pet_idx`가 양쪽에 동시 등장 가능. 프론트는 두 응답을 [mergeWith]로
/// 합쳐 카드 1개에 두 결정 버튼을 같이 노출.
class _AdminPet {
  final Pet pet;
  final String ownerName;
  final String ownerNickname;
  final String ownerEmail;
  final String ownerPhone;

  // 정보 검토
  final bool hasInfoReview;
  final bool isReview;
  final Map<String, dynamic>? previousValues;

  // 사진 검토
  final bool hasPhotoReview;
  final String? pendingProfileImage;

  _AdminPet({
    required this.pet,
    required this.ownerName,
    required this.ownerNickname,
    required this.ownerEmail,
    required this.ownerPhone,
    required this.hasInfoReview,
    required this.isReview,
    this.previousValues,
    required this.hasPhotoReview,
    this.pendingProfileImage,
  });

  /// 정보 검토 응답(`/api/admin/pets?status=...`)에서 변환.
  factory _AdminPet.fromInfoReviewJson(Map<String, dynamic> json) {
    final owner = json['owner'] as Map<String, dynamic>? ?? {};
    final pet = Pet.fromJson(json);
    return _AdminPet(
      pet: pet,
      ownerName: owner['name'] ?? '',
      ownerNickname: owner['nickname'] ?? '',
      ownerEmail: owner['email'] ?? '',
      ownerPhone: owner['phone_number'] ?? '',
      // 정보 검토는 PENDING(0) 상태에서만 결정 대상. 승인/거절 탭의 펫은
      // 이미 결정된 상태이므로 결정 버튼/배지 노출 안 함 (PopupMenu의
      // "거절로 변경" / "승인 대기로 변경"으로 상태 전환은 가능).
      hasInfoReview: pet.approvalStatus == 0,
      isReview: json['is_review'] == true,
      previousValues: json['previous_values'] as Map<String, dynamic>?,
      hasPhotoReview: false,
      pendingProfileImage: null,
    );
  }

  /// 사진 검토 응답(`/api/admin/pets/profile-images/pending`)에서 변환.
  factory _AdminPet.fromPhotoReviewJson(Map<String, dynamic> json) {
    final owner = json['owner'] as Map<String, dynamic>? ?? {};
    return _AdminPet(
      pet: Pet.fromJson(json),
      ownerName: owner['name'] ?? '',
      ownerNickname: owner['nickname'] ?? '',
      ownerEmail: owner['email'] ?? '',
      ownerPhone: owner['phone_number'] ?? '',
      hasInfoReview: false,
      isReview: false,
      previousValues: null,
      hasPhotoReview: true,
      pendingProfileImage: json['pending_profile_image'] as String?,
    );
  }

  /// 같은 `pet_idx`의 정보 검토 + 사진 검토 데이터를 병합.
  _AdminPet mergeWith(_AdminPet other) {
    return _AdminPet(
      pet: hasInfoReview ? pet : other.pet,
      ownerName: ownerName.isNotEmpty ? ownerName : other.ownerName,
      ownerNickname:
          ownerNickname.isNotEmpty ? ownerNickname : other.ownerNickname,
      ownerEmail: ownerEmail.isNotEmpty ? ownerEmail : other.ownerEmail,
      ownerPhone: ownerPhone.isNotEmpty ? ownerPhone : other.ownerPhone,
      hasInfoReview: hasInfoReview || other.hasInfoReview,
      isReview: isReview || other.isReview,
      previousValues: previousValues ?? other.previousValues,
      hasPhotoReview: hasPhotoReview || other.hasPhotoReview,
      pendingProfileImage: pendingProfileImage ?? other.pendingProfileImage,
    );
  }

  /// 필드명 한글 매핑
  static const Map<String, String> fieldNameMap = {
    'name': '이름',
    'species': '종류',
    'breed': '품종',
    'birth_date': '생년월일',
    'blood_type': '혈액형',
    'weight_kg': '체중',
    'sex': '성별',
    'pregnancy_birth_status': '임신/출산',
    'last_pregnancy_end_date': '출산 종료일',
    'vaccinated': '접종',
    'has_disease': '질병',
    'is_neutered': '중성화',
    'neutered_date': '중성화 일자',
    'has_preventive_medication': '예방약',
  };

  /// Boolean 필드 목록
  static const Set<String> boolFields = {
    'vaccinated', 'has_disease', 'is_neutered', 'has_preventive_medication',
  };

  /// 값을 표시용 문자열로 변환
  static String formatValue(String field, dynamic value) {
    if (value == null) return '-';
    if (boolFields.contains(field)) {
      return (value == true || value == 1) ? '✅' : '❌';
    }
    if (field == 'sex') {
      return value == 0 ? '암컷' : '수컷';
    }
    if (field == 'pregnancy_birth_status') {
      switch (value) {
        case 1: return '임신중';
        case 2: return '출산 이력';
        default: return '해당 없음';
      }
    }
    if (field == 'weight_kg') return '${value}kg';
    return value.toString();
  }
}
