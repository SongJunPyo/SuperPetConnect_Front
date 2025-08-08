import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:connect/user/pet_register.dart';
import 'package:connect/models/pet_model.dart';
import 'package:connect/services/manage_pet_info.dart';
import '../utils/app_theme.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/app_card.dart';

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
                  Navigator.of(context).pop();

                  // 3. 삭제 성공 메시지 표시
                  _showSnackBar('${pet.name} 펫이 삭제되었습니다.');

                  // 4. 목록 새로고침
                  _refreshPets();
                } catch (e) {
                  // 에러 처리
                  Navigator.of(context).pop();
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
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더 섹션
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacing20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('반려동물 관리', style: AppTheme.h2Style),
                      const SizedBox(height: AppTheme.spacing8),
                      Text(
                        '총 ${pets.length}마리의 반려동물이 등록되어 있습니다',
                        style: AppTheme.bodyLargeStyle.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildPetList(pets), // 가져온 데이터로 리스트를 그림
              ],
            ),
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
    // 헌혈 가능 여부 체크 (Pet 모델의 canDonate 사용)
    final canDonate = pet.canDonate;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing16),
      child: Material(
        color: canDonate ? Colors.lightGreen.shade50 : Colors.pink.shade50,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        child: InkWell(
          onTap: () => _showPetDetailDialog(pet),
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radius12),
              border: Border.all(
                color:
                    canDonate
                        ? Colors.lightGreen.shade200
                        : Colors.pink.shade200,
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 왼쪽: 아이콘과 기본 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 이름과 아이콘
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppTheme.spacing8),
                            decoration: BoxDecoration(
                              color:
                                  canDonate
                                      ? Colors.lightGreen.shade100
                                      : Colors.pink.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              pet.species == '강아지' || pet.species == '개'
                                  ? FontAwesomeIcons.dog
                                  : FontAwesomeIcons.cat,
                              color:
                                  canDonate
                                      ? Colors.green.shade600
                                      : Colors.pink.shade400,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacing12),
                          Text(
                            pet.name,
                            style: AppTheme.h4Style.copyWith(height: 1.3),
                          ),
                          if (pet.pregnant) ...[
                            const SizedBox(width: AppTheme.spacing8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spacing8,
                                vertical: AppTheme.spacing2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.pinkAccent,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius8,
                                ),
                              ),
                              child: Text(
                                '임신중',
                                style: AppTheme.bodySmallStyle.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacing12),
                      // 정보들을 한 줄씩 표시
                      Text(
                        '종류: ${pet.species}',
                        style: AppTheme.bodyMediumStyle.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing4),
                      Text(
                        '품종: ${pet.breed ?? '정보 없음'}',
                        style: AppTheme.bodyMediumStyle.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing4),
                      Text(
                        '나이: ${pet.age}',
                        style: AppTheme.bodyMediumStyle.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing4),
                      Text(
                        '몸무게: ${pet.weightKg}kg',
                        style: AppTheme.bodyMediumStyle.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing4),
                      Text(
                        '혈액형: ${pet.bloodType ?? '정보 없음'}',
                        style: AppTheme.bodyMediumStyle.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing4),
                      // 이전 헌혈 일자 정보
                      Text(
                        pet.prevDonationDate != null
                            ? '이전 헌혈: ${pet.prevDonationDate!.year}년 ${pet.prevDonationDate!.month}월 ${pet.prevDonationDate!.day}일'
                            : '헌혈 이력: 첫 헌혈 예정',
                        style: AppTheme.bodyMediumStyle.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing8),
                      // 헌혈 가능 여부 표시
                      Row(
                        children: [
                          Icon(
                            canDonate ? Icons.check_circle : Icons.cancel,
                            size: 16,
                            color:
                                canDonate ? Colors.green : Colors.red.shade400,
                          ),
                          const SizedBox(width: AppTheme.spacing4),
                          Text(
                            pet.donationStatusText,
                            style: AppTheme.bodySmallStyle.copyWith(
                              color:
                                  canDonate
                                      ? Colors.green
                                      : Colors.red.shade400,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 오른쪽: 수정/삭제 버튼 세로 배치
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 수정 버튼
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        color: AppTheme.textSecondary,
                        onPressed: () => _editPet(pet),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 18,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    // 삭제 버튼
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        color: Colors.red.shade400,
                        onPressed: () => _deletePet(pet),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 헌혈 가능 여부 체크 함수
  bool _checkDonationEligibility(Pet pet) {
    // 강아지가 아닌 경우 헌혈 불가
    if (pet.species != '개' && pet.species != '강아지') return false;

    // 나이 체크 (2살~8살)
    if (pet.ageNumber < 2 || pet.ageNumber > 8) return false;

    // 몸무게 체크 (20kg 이상)
    if (pet.weightKg < 20) return false;

    // 임신 중인 경우 헌혈 불가
    if (pet.pregnant) return false;

    // 백신 접종하지 않은 경우 헌혈 불가
    if (pet.vaccinated != true) return false;

    // 질병 이력이 있는 경우 헌혈 불가
    if (pet.hasDisease == true) return false;

    // 출산 경험이 있는 경우 헌혈 불가 (1년 이내)
    if (pet.hasBirthExperience == true) return false;

    return true;
  }

  // 펫 상세 정보를 보여주는 다이얼로그
  void _showPetDetailDialog(Pet pet) {
    final canDonate = pet.canDonate;
    final donationReasons = _getDonationIneligibilityReasons(pet);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing8),
                decoration: BoxDecoration(
                  color:
                      canDonate
                          ? Colors.lightGreen.shade100
                          : Colors.pink.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  pet.species == '강아지' || pet.species == '개'
                      ? Icons.pets
                      : Icons.cruelty_free,
                  color:
                      canDonate ? Colors.green.shade600 : Colors.pink.shade400,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Text(pet.name, style: AppTheme.h3Style),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('종류', pet.species),
                _buildDetailRow('품종', pet.breed ?? '정보 없음'),
                _buildDetailRow('나이', pet.age),
                _buildDetailRow('몸무게', '${pet.weightKg}kg'),
                _buildDetailRow('혈액형', pet.bloodType ?? '정보 없음'),
                _buildDetailRow('백신 접종', pet.vaccinated == true ? '완료' : '미완료'),
                _buildDetailRow('질병 이력', pet.hasDisease == true ? '있음' : '없음'),
                _buildDetailRow(
                  '출산 경험',
                  pet.hasBirthExperience == true ? '있음' : '없음',
                ),
                if (pet.pregnant)
                  Container(
                    margin: const EdgeInsets.only(top: AppTheme.spacing12),
                    padding: const EdgeInsets.all(AppTheme.spacing8),
                    decoration: BoxDecoration(
                      color: Colors.pinkAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                      border: Border.all(color: Colors.pinkAccent, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.pinkAccent,
                          size: 16,
                        ),
                        const SizedBox(width: AppTheme.spacing8),
                        Text(
                          '현재 임신 중입니다',
                          style: AppTheme.bodyMediumStyle.copyWith(
                            color: Colors.pinkAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppTheme.spacing16),
                // 헌혈 가능 여부 섹션
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacing12),
                  decoration: BoxDecoration(
                    color:
                        canDonate ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                    border: Border.all(
                      color:
                          canDonate
                              ? Colors.green.shade200
                              : Colors.red.shade200,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            canDonate ? Icons.check_circle : Icons.cancel,
                            color: canDonate ? Colors.green : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: AppTheme.spacing8),
                          Text(
                            canDonate ? '헌혈 가능' : '헌혈 불가',
                            style: AppTheme.bodyLargeStyle.copyWith(
                              color: canDonate ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (!canDonate && donationReasons.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.spacing8),
                        ...donationReasons.map(
                          (reason) => Padding(
                            padding: const EdgeInsets.only(
                              top: AppTheme.spacing4,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '• ',
                                  style: TextStyle(color: Colors.red),
                                ),
                                Expanded(
                                  child: Text(
                                    reason,
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
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacing12),
                // 헌혈견 조건 안내
                ExpansionTile(
                  title: Text(
                    '헌혈견 조건 안내',
                    style: AppTheme.bodyMediumStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  tilePadding: EdgeInsets.zero,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacing12),
                      decoration: BoxDecoration(
                        color: AppTheme.veryLightGray,
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            '✓ 2살(18개월)~8살 / 20kg 이상',
                            style: TextStyle(fontSize: 12),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '✓ 매월 심장사상충과 내외부구충 예방',
                            style: TextStyle(fontSize: 12),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '✓ 정기적인 종합백신 접종',
                            style: TextStyle(fontSize: 12),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '✓ 질병 이력이 없는 건강한 반려견',
                            style: TextStyle(fontSize: 12),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '✓ 임신 경험이 있다면 1년 경과 필요',
                            style: TextStyle(fontSize: 12),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '✓ 헌혈 2주 전부터 치료약 복용 금지',
                            style: TextStyle(fontSize: 12),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '✓ 헌혈 당일 8시간 전 금식 (물은 가능)',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                '닫기',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('수정', style: TextStyle(color: AppTheme.primaryBlue)),
              onPressed: () {
                Navigator.of(context).pop();
                _editPet(pet);
              },
            ),
          ],
        );
      },
    );
  }

  // 헌혈 불가 사유를 반환하는 함수
  List<String> _getDonationIneligibilityReasons(Pet pet) {
    List<String> reasons = [];

    if (pet.species != '개' && pet.species != '강아지') {
      reasons.add('강아지만 헌혈이 가능합니다');
    }

    if (pet.ageNumber < 2) {
      reasons.add('2살 미만입니다 (현재: ${pet.age})');
    } else if (pet.ageNumber > 8) {
      reasons.add('8살을 초과했습니다 (현재: ${pet.age})');
    }

    if (pet.weightKg < 20) {
      reasons.add('체중이 20kg 미만입니다 (현재: ${pet.weightKg}kg)');
    }

    if (pet.pregnant) {
      reasons.add('현재 임신 중입니다');
    }

    if (pet.vaccinated != true) {
      reasons.add('정기 백신 접종을 하지 않았습니다');
    }

    if (pet.hasDisease == true) {
      reasons.add('질병 이력이 있습니다');
    }

    if (pet.hasBirthExperience == true) {
      reasons.add('출산 경험이 있습니다 (1년 이내 출산 시 헌혈 불가)');
    }

    return reasons;
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
