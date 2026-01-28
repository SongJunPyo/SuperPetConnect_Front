// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:connect/user/pet_register.dart';
import 'package:connect/models/pet_model.dart';
import 'package:connect/models/donation_history_model.dart';
import 'package:connect/services/manage_pet_info.dart';
import 'package:connect/services/donation_history_service.dart';
import '../utils/app_theme.dart';
import '../utils/donation_eligibility.dart';

class PetManagementScreen extends StatefulWidget {
  const PetManagementScreen({super.key});

  @override
  State<PetManagementScreen> createState() => _PetManagementScreenState();
}

class _PetManagementScreenState extends State<PetManagementScreen> {
  // DB 스키마에 맞춘 Pet 객체 리스트 (예시 데이터)
  late Future<List<Pet>> _petsFuture;

  // --- 추가: 위젯이 처음 생성될 때 데이터를 불러오는 initState ---
  @override
  void initState() {
    super.initState();
    _refreshPets(); // 데이터를 불러오는 함수 호출
  }

  // --- 추가: 서버에서 펫 목록을 가져와 상태를 갱신하는 함수 ---
  void _refreshPets() {
    setState(() {
      _petsFuture = PetService.fetchPets();
    });
  }

  // 펫 등록 페이지로 이동하는 함수
  void _navigateAndRegisterPet() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PetRegisterScreen()),
    );

    if (result == true) {
      _refreshPets();
      _showSnackBar('새로운 펫이 등록되었습니다.');
    }
  }

  // 펫 수정 기능
  void _editPet(Pet pet) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PetRegisterScreen(petToEdit: pet),
      ),
    );
    if (result == true) {
      _refreshPets();
      _showSnackBar('${pet.name} 펫 정보가 수정되었습니다.');
    }
  }

  // 펫 삭제 기능
  void _deletePet(Pet pet) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('펫 삭제 확인'),
          content: Text("'${pet.name}' 펫의 정보를 정말 삭제하시겠습니까?"),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              // onPressed를 비동기(async)로 변경
              onPressed: () async {
                // petIdx가 null인 경우는 없어야 하지만, 안전을 위해 확인
                if (pet.petIdx == null) {
                  _showSnackBar('잘못된 펫 정보입니다.');
                  Navigator.of(context).pop();
                  return;
                }

                try {
                  // 1. PetService를 통해 서버에 삭제 요청
                  await PetService.deletePet(pet.petIdx!);

                  // 2. 다이얼로그 닫기
                  if (mounted) {
                    Navigator.of(context).pop();
                  }

                  // 3. 삭제 성공 메시지 표시
                  _showSnackBar('${pet.name} 펫이 삭제되었습니다.');

                  // 4. 목록 새로고침
                  _refreshPets();
                } catch (e) {
                  // 에러 처리
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                  _showSnackBar('삭제 실패: $e');
                }
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // 하단에 알림 보여주는 스낵바 함수
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '반려동물 관리',
          style: AppTheme.h3Style.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
      ),
      body: FutureBuilder<List<Pet>>(
        future: _petsFuture, // 이 Future의 상태에 따라 UI가 결정됨
        builder: (context, snapshot) {
          // 1. 로딩 중일 때
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue),
            );
          }
          // 2. 에러가 발생했을 때
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  Text(
                    '오류가 발생했습니다',
                    style: AppTheme.h3Style.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  Text(
                    '${snapshot.error}',
                    style: AppTheme.bodyMediumStyle.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacing24),
                  ElevatedButton(
                    onPressed: _refreshPets,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing24,
                        vertical: AppTheme.spacing12,
                      ),
                    ),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }
          // 3. 데이터가 없거나 비어있을 때
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          // 4. 데이터 로딩 성공 시
          final pets = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: _buildPetList(pets),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateAndRegisterPet,
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  // 펫 목록이 비어있을 때 표시할 위젯
  Widget _buildEmptyState() {
    return Center(
      heightFactor: 2.5, // 화면 중앙에 좀 더 잘 보이도록 조정
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing20),
            decoration: BoxDecoration(
              color: AppTheme.lightBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.pets, size: 60, color: AppTheme.primaryBlue),
          ),
          const SizedBox(height: AppTheme.spacing24),
          Text(
            '등록된 반려동물이 없습니다',
            style: AppTheme.h3Style.copyWith(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            '아래 + 버튼을 눌러\n소중한 가족을 등록해주세요',
            style: AppTheme.bodyLargeStyle.copyWith(
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 펫 목록을 표시할 위젯
  Widget _buildPetList(List<Pet> pets) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: pets.length,
      itemBuilder: (context, index) {
        final pet = pets[index];
        return _buildPetCard(pet); // 인덱스 대신 pet 객체를 직접 전달
      },
    );
  }

  // 각 펫의 정보를 보여주는 카드 위젯
  Widget _buildPetCard(Pet pet) {
    // 중앙화된 자격 검증 사용
    final eligibility = DonationEligibility.checkEligibility(pet);
    final canDonate = eligibility.isEligible || eligibility.needsConsultation;
    final isDog = pet.species == '강아지' || pet.species == '개';

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        side: const BorderSide(color: Colors.black, width: 1),
      ),
      child: InkWell(
        onTap: () => _showPetDetailDialog(pet),
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단: 이름, 상태 배지, 액션 버튼
              Row(
                children: [
                  // 아이콘
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacing8),
                    decoration: BoxDecoration(
                      color: isDog ? Colors.orange.shade50 : Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                    child: FaIcon(
                      isDog ? FontAwesomeIcons.dog : FontAwesomeIcons.cat,
                      color: isDog ? Colors.orange.shade600 : Colors.purple.shade600,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  // 이름
                  Expanded(
                    child: Text(
                      pet.name,
                      style: AppTheme.h4Style.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // 임신 배지
                  if (pet.pregnant)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing8,
                        vertical: AppTheme.spacing4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.pink.shade50,
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                      ),
                      child: Text(
                        '임신중',
                        style: AppTheme.captionStyle.copyWith(
                          color: Colors.pink.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: AppTheme.spacing8),
                  // 수정 버튼
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    color: AppTheme.textSecondary,
                    onPressed: () => _editPet(pet),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  // 삭제 버튼
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Colors.red.shade400,
                    onPressed: () => _deletePet(pet),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing12),
              // 중간: 기본 정보 (한 줄로 표시)
              Row(
                children: [
                  Icon(Icons.pets_outlined, size: 16, color: AppTheme.textTertiary),
                  const SizedBox(width: AppTheme.spacing4),
                  Text(
                    '${pet.species} • ${pet.age} • ${pet.weightKg}kg',
                    style: AppTheme.bodyMediumStyle.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing4),
              // 품종
              if (pet.breed != null)
                Row(
                  children: [
                    Icon(Icons.category_outlined, size: 16, color: AppTheme.textTertiary),
                    const SizedBox(width: AppTheme.spacing4),
                    Text(
                      pet.breed!,
                      style: AppTheme.bodyMediumStyle.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: AppTheme.spacing4),
              // 혈액형
              if (pet.bloodType != null)
                Row(
                  children: [
                    Icon(Icons.bloodtype_outlined, size: 16, color: AppTheme.textTertiary),
                    const SizedBox(width: AppTheme.spacing4),
                    Text(
                      pet.bloodType!,
                      style: AppTheme.bodyMediumStyle.copyWith(
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: AppTheme.spacing12),
              // 하단: 헌혈 상태 (중앙화된 자격 검증 결과 표시)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing12,
                  vertical: AppTheme.spacing8,
                ),
                decoration: BoxDecoration(
                  color: eligibility.isEligible
                      ? Colors.green.shade50
                      : eligibility.needsConsultation
                          ? Colors.orange.shade50
                          : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      eligibility.isEligible
                          ? Icons.check_circle
                          : eligibility.needsConsultation
                              ? Icons.help_outline
                              : Icons.cancel,
                      size: 16,
                      color: eligibility.isEligible
                          ? Colors.green.shade700
                          : eligibility.needsConsultation
                              ? Colors.orange.shade700
                              : Colors.red.shade700,
                    ),
                    const SizedBox(width: AppTheme.spacing4),
                    Text(
                      eligibility.summaryMessage,
                      style: AppTheme.bodySmallStyle.copyWith(
                        color: eligibility.isEligible
                            ? Colors.green.shade700
                            : eligibility.needsConsultation
                                ? Colors.orange.shade700
                                : Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  // 펫 상세 정보를 보여주는 바텀시트
  void _showPetDetailDialog(Pet pet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PetDetailBottomSheet(
        pet: pet,
        onEdit: () {
          Navigator.pop(context);
          _editPet(pet);
        },
      ),
    );
  }

  // 상세 정보 행 위젯
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTheme.bodyMediumStyle.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(value, style: AppTheme.bodyMediumStyle)),
        ],
      ),
    );
  }
}

// =============================================================================
// 반려동물 상세 바텀시트 위젯
// =============================================================================
class _PetDetailBottomSheet extends StatefulWidget {
  final Pet pet;
  final VoidCallback onEdit;

  const _PetDetailBottomSheet({
    required this.pet,
    required this.onEdit,
  });

  @override
  State<_PetDetailBottomSheet> createState() => _PetDetailBottomSheetState();
}

class _PetDetailBottomSheetState extends State<_PetDetailBottomSheet> {
  DonationHistoryResponse? _historyResponse;
  bool _isLoadingHistory = false;
  String? _historyError;
  int _currentPage = 1;
  static const int _pageLimit = 10;

  @override
  void initState() {
    super.initState();
    _loadDonationHistory();
  }

  Future<void> _loadDonationHistory({int page = 1}) async {
    if (widget.pet.petIdx == null) return;

    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });

    try {
      final response = await DonationHistoryService.getHistory(
        petIdx: widget.pet.petIdx!,
        page: page,
        limit: _pageLimit,
      );
      setState(() {
        _historyResponse = response;
        _currentPage = page;
        _isLoadingHistory = false;
      });
    } catch (e) {
      setState(() {
        _historyError = e.toString();
        _isLoadingHistory = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pet = widget.pet;
    final eligibility = DonationEligibility.checkEligibility(pet);
    final isDog = pet.species == '강아지' || pet.species == '개';

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // 핸들 바
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 헤더
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    // 아이콘
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacing12),
                      decoration: BoxDecoration(
                        color: isDog ? Colors.orange.shade50 : Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                      ),
                      child: FaIcon(
                        isDog ? FontAwesomeIcons.dog : FontAwesomeIcons.cat,
                        color: isDog ? Colors.orange.shade600 : Colors.purple.shade600,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing12),
                    // 이름과 정보
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pet.name,
                            style: AppTheme.h3Style.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${pet.species} • ${pet.age} • ${pet.weightKg}kg',
                            style: AppTheme.bodyMediumStyle.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 닫기 버튼
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              const Divider(height: 24),

              // 스크롤 가능한 컨텐츠
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // 기본 정보 섹션
                    Text(
                      '기본 정보',
                      style: AppTheme.bodyLargeStyle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing12),
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacing16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow('종류', pet.species),
                          _buildDetailRow('품종', pet.breed ?? '정보 없음'),
                          _buildDetailRow('나이', pet.age),
                          _buildDetailRow('몸무게', '${pet.weightKg}kg'),
                          _buildDetailRow('혈액형', pet.bloodType ?? '정보 없음'),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacing20),

                    // 건강 정보 섹션
                    Text(
                      '건강 정보',
                      style: AppTheme.bodyLargeStyle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing12),
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacing16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow('백신 접종', pet.vaccinated == true ? '완료' : (pet.vaccinated == false ? '미완료' : '정보 없음')),
                          _buildDetailRow('예방약 복용', pet.hasPreventiveMedication == true ? '복용' : (pet.hasPreventiveMedication == false ? '미복용' : '정보 없음')),
                          _buildDetailRow('질병 이력', pet.hasDisease == true ? '있음' : (pet.hasDisease == false ? '없음' : '정보 없음')),
                          _buildDetailRow('출산 경험', pet.hasBirthExperience == true ? '있음' : (pet.hasBirthExperience == false ? '없음' : '정보 없음')),
                          _buildDetailRow('중성화 수술', pet.isNeutered == true ? '완료' : (pet.isNeutered == false ? '없음' : '미완료')),
                        ],
                      ),
                    ),

                    // 임신 중 알림
                    if (pet.pregnant) ...[
                      const SizedBox(height: AppTheme.spacing12),
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacing12),
                        decoration: BoxDecoration(
                          color: Colors.pink.shade50,
                          borderRadius: BorderRadius.circular(AppTheme.radius8),
                          border: Border.all(color: Colors.pink.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.favorite,
                              color: Colors.pink.shade400,
                              size: 20,
                            ),
                            const SizedBox(width: AppTheme.spacing8),
                            Text(
                              '현재 임신 중입니다',
                              style: AppTheme.bodyMediumStyle.copyWith(
                                color: Colors.pink.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: AppTheme.spacing20),

                    // 헌혈 자격 섹션
                    Text(
                      '헌혈 자격',
                      style: AppTheme.bodyLargeStyle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing12),
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacing16),
                      decoration: BoxDecoration(
                        color: eligibility.isEligible
                            ? Colors.green.shade50
                            : eligibility.needsConsultation
                                ? Colors.orange.shade50
                                : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                        border: Border.all(
                          color: eligibility.isEligible
                              ? Colors.green.shade200
                              : eligibility.needsConsultation
                                  ? Colors.orange.shade200
                                  : Colors.red.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                eligibility.isEligible
                                    ? Icons.check_circle
                                    : eligibility.needsConsultation
                                        ? Icons.help_outline
                                        : Icons.cancel,
                                color: eligibility.isEligible
                                    ? Colors.green
                                    : eligibility.needsConsultation
                                        ? Colors.orange
                                        : Colors.red,
                                size: 24,
                              ),
                              const SizedBox(width: AppTheme.spacing8),
                              Text(
                                eligibility.summaryMessage,
                                style: AppTheme.bodyLargeStyle.copyWith(
                                  color: eligibility.isEligible
                                      ? Colors.green.shade700
                                      : eligibility.needsConsultation
                                          ? Colors.orange.shade700
                                          : Colors.red.shade700,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          // 헌혈 불가 사유 표시
                          if (eligibility.failedConditions.isNotEmpty) ...[
                            const SizedBox(height: AppTheme.spacing12),
                            ...eligibility.failedConditions.map(
                              (condition) => Padding(
                                padding: const EdgeInsets.only(top: AppTheme.spacing4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.red.shade600,
                                    ),
                                    const SizedBox(width: AppTheme.spacing4),
                                    Expanded(
                                      child: Text(
                                        '${condition.conditionName}: ${condition.message}',
                                        style: AppTheme.bodySmallStyle.copyWith(
                                          color: Colors.red.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          // 협의 필요 사유 표시
                          if (eligibility.consultConditions.isNotEmpty) ...[
                            const SizedBox(height: AppTheme.spacing12),
                            ...eligibility.consultConditions.map(
                              (condition) => Padding(
                                padding: const EdgeInsets.only(top: AppTheme.spacing4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.warning_amber,
                                      size: 16,
                                      color: Colors.orange.shade600,
                                    ),
                                    const SizedBox(width: AppTheme.spacing4),
                                    Expanded(
                                      child: Text(
                                        '${condition.conditionName}: ${condition.message}',
                                        style: AppTheme.bodySmallStyle.copyWith(
                                          color: Colors.orange.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacing20),

                    // 헌혈 이력 섹션
                    _buildDonationHistorySection(),

                    const SizedBox(height: AppTheme.spacing20),

                    // 헌혈 조건 안내
                    Text(
                      isDog ? '헌혈견 조건 안내' : '헌혈묘 조건 안내',
                      style: AppTheme.bodyMediumStyle.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    Text(
                      DonationEligibility.getConditionsSummary(isDog ? 0 : 1),
                      style: AppTheme.bodySmallStyle.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.left,
                    ),

                    const SizedBox(height: AppTheme.spacing24),
                  ],
                ),
              ),

              // 하단 버튼 영역
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.onEdit,
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: Colors.black,
                    ),
                    label: const Text(
                      '정보 수정',
                      style: TextStyle(color: Colors.black),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.black),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }

  // 상세 정보 행 위젯
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTheme.bodyMediumStyle.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(value, style: AppTheme.bodyMediumStyle)),
        ],
      ),
    );
  }

  // 헌혈 이력 섹션 위젯
  Widget _buildDonationHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '헌혈 이력',
              style: AppTheme.bodyLargeStyle.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton.icon(
              onPressed: () => _showAddHistoryDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('추가'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryBlue,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing12),

        // 로딩 상태
        if (_isLoadingHistory)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        // 에러 상태
        else if (_historyError != null)
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade400),
                const SizedBox(width: AppTheme.spacing8),
                Expanded(
                  child: Text(
                    '이력을 불러오지 못했습니다',
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
                TextButton(
                  onPressed: () => _loadDonationHistory(),
                  child: const Text('재시도'),
                ),
              ],
            ),
          )
        // 데이터 있음
        else if (_historyResponse != null) ...[
          // 통계 요약
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '총 헌혈',
                    '${_historyResponse!.totalCount}회',
                    Icons.bloodtype,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.red.shade200,
                ),
                Expanded(
                  child: _buildStatItem(
                    '총 헌혈량',
                    _historyResponse!.totalBloodVolumeText,
                    Icons.water_drop,
                  ),
                ),
              ],
            ),
          ),

          if (_historyResponse!.hasHistory) ...[
            const SizedBox(height: AppTheme.spacing12),
            Text(
              '첫 헌혈: ${_historyResponse!.firstDonationDateText}  •  마지막: ${_historyResponse!.lastDonationDateText}',
              style: AppTheme.bodySmallStyle.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),

            // 이력 리스트
            ...(_historyResponse!.histories.map((history) => _buildHistoryItem(history))),

            // 페이지네이션
            if (_historyResponse!.totalPages > 1) ...[
              const SizedBox(height: AppTheme.spacing16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _historyResponse!.hasPrevPage
                        ? () => _loadDonationHistory(page: _currentPage - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    '$_currentPage / ${_historyResponse!.totalPages}',
                    style: AppTheme.bodyMediumStyle,
                  ),
                  IconButton(
                    onPressed: _historyResponse!.hasNextPage
                        ? () => _loadDonationHistory(page: _currentPage + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ] else ...[
            const SizedBox(height: AppTheme.spacing16),
            Center(
              child: Text(
                '아직 헌혈 이력이 없습니다',
                style: AppTheme.bodyMediumStyle.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ]
        // 데이터 없음 (초기 상태)
        else
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            child: Center(
              child: Text(
                '헌혈 이력을 불러오는 중...',
                style: AppTheme.bodyMediumStyle.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // 통계 아이템 위젯
  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.red.shade400, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTheme.bodyLargeStyle.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.red.shade700,
          ),
        ),
        Text(
          label,
          style: AppTheme.bodySmallStyle.copyWith(
            color: Colors.red.shade600,
          ),
        ),
      ],
    );
  }

  // 개별 이력 아이템 위젯
  Widget _buildHistoryItem(DonationHistory history) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                history.isSystemRecord ? Icons.computer : Icons.edit_note,
                size: 18,
                color: history.isSystemRecord ? Colors.blue.shade400 : Colors.green.shade400,
              ),
              const SizedBox(width: AppTheme.spacing8),
              Text(
                history.dateText,
                style: AppTheme.bodyMediumStyle.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: history.isSystemRecord ? Colors.blue.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  history.isSystemRecord ? '자동' : '수동',
                  style: AppTheme.bodySmallStyle.copyWith(
                    color: history.isSystemRecord ? Colors.blue.shade600 : Colors.green.shade600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          if (history.hospitalName != null || history.bloodVolumeMl != null) ...[
            const SizedBox(height: AppTheme.spacing8),
            Row(
              children: [
                if (history.hospitalName != null) ...[
                  Icon(Icons.local_hospital, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    history.hospitalName!,
                    style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.textSecondary),
                  ),
                ],
                if (history.hospitalName != null && history.bloodVolumeMl != null)
                  Text(' • ', style: TextStyle(color: AppTheme.textSecondary)),
                if (history.bloodVolumeMl != null)
                  Text(
                    '${history.bloodVolumeMl}ml',
                    style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.textSecondary),
                  ),
              ],
            ),
          ],
          if (history.notes != null && history.notes!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacing4),
            Text(
              history.notes!,
              style: AppTheme.bodySmallStyle.copyWith(
                color: AppTheme.textTertiary,
              ),
            ),
          ],
          // 수동 입력만 수정/삭제 가능
          if (history.canEdit) ...[
            const SizedBox(height: AppTheme.spacing8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _showEditHistoryDialog(history),
                  child: const Text('수정', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _deleteHistory(history),
                  child: Text('삭제', style: TextStyle(fontSize: 12, color: Colors.red.shade400)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // 이력 추가 다이얼로그
  void _showAddHistoryDialog() {
    final dateController = TextEditingController();
    final hospitalController = TextEditingController();
    final volumeController = TextEditingController();
    final notesController = TextEditingController();
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('헌혈 이력 추가'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 날짜 선택
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2010),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    selectedDate = date;
                    dateController.text = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                  }
                },
                child: AbsorbPointer(
                  child: TextField(
                    controller: dateController,
                    decoration: const InputDecoration(
                      labelText: '헌혈 날짜 *',
                      hintText: '날짜를 선택하세요',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: hospitalController,
                decoration: const InputDecoration(
                  labelText: '병원명',
                  hintText: '선택사항',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: volumeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '헌혈량 (ml)',
                  hintText: '선택사항',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: '메모',
                  hintText: '선택사항',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (selectedDate == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('날짜를 선택해주세요')),
                );
                return;
              }

              try {
                await DonationHistoryService.addHistory(
                  petIdx: widget.pet.petIdx!,
                  request: DonationHistoryCreateRequest(
                    donationDate: dateController.text,
                    hospitalName: hospitalController.text.isNotEmpty ? hospitalController.text : null,
                    bloodVolumeMl: volumeController.text.isNotEmpty ? int.tryParse(volumeController.text) : null,
                    notes: notesController.text.isNotEmpty ? notesController.text : null,
                  ),
                );
                Navigator.pop(context);
                _loadDonationHistory();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('헌혈 이력이 추가되었습니다')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('추가 실패: $e')),
                );
              }
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  // 이력 수정 다이얼로그
  void _showEditHistoryDialog(DonationHistory history) {
    final dateController = TextEditingController(
      text: '${history.donationDate.year}-${history.donationDate.month.toString().padLeft(2, '0')}-${history.donationDate.day.toString().padLeft(2, '0')}',
    );
    final hospitalController = TextEditingController(text: history.hospitalName ?? '');
    final volumeController = TextEditingController(text: history.bloodVolumeMl?.toString() ?? '');
    final notesController = TextEditingController(text: history.notes ?? '');
    DateTime selectedDate = history.donationDate;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('헌혈 이력 수정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2010),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    selectedDate = date;
                    dateController.text = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                  }
                },
                child: AbsorbPointer(
                  child: TextField(
                    controller: dateController,
                    decoration: const InputDecoration(
                      labelText: '헌혈 날짜 *',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: hospitalController,
                decoration: const InputDecoration(labelText: '병원명'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: volumeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '헌혈량 (ml)'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: '메모'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await DonationHistoryService.updateHistory(
                  historyIdx: history.historyIdx,
                  request: DonationHistoryUpdateRequest(
                    donationDate: dateController.text,
                    hospitalName: hospitalController.text,
                    bloodVolumeMl: volumeController.text.isNotEmpty ? int.tryParse(volumeController.text) : null,
                    notes: notesController.text,
                  ),
                );
                Navigator.pop(context);
                _loadDonationHistory();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('헌혈 이력이 수정되었습니다')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('수정 실패: $e')),
                );
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  // 이력 삭제
  void _deleteHistory(DonationHistory history) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('헌혈 이력 삭제'),
        content: Text('${history.dateText} 헌혈 이력을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await DonationHistoryService.deleteHistory(historyIdx: history.historyIdx);
                Navigator.pop(context);
                _loadDonationHistory();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('헌혈 이력이 삭제되었습니다')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('삭제 실패: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}
