import 'package:flutter/material.dart';
import '../models/pet_model.dart';
import '../services/donation_application_service.dart';
import '../services/manage_pet_info.dart';
import '../utils/app_theme.dart';
import 'pet_register.dart'; // PetRegisterScreen import 추가

/// 헌혈 신청 화면 (사용자용)
class DonationApplicationScreen extends StatefulWidget {
  final int postId;
  final String postTitle;
  final String hospitalName;
  final String bloodType;
  final int animalType; // 0=강아지, 1=고양이

  const DonationApplicationScreen({
    super.key,
    required this.postId,
    required this.postTitle,
    required this.hospitalName,
    required this.bloodType,
    required this.animalType,
  });

  @override
  State<DonationApplicationScreen> createState() => _DonationApplicationScreenState();
}

class _DonationApplicationScreenState extends State<DonationApplicationScreen> {
  List<Pet> availablePets = [];
  Pet? selectedPet;
  bool isLoading = true;
  bool isSubmitting = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAvailablePets();
  }

  Future<void> _loadAvailablePets() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final allPets = await PetService.fetchPets();
      
      // 헌혈 가능한 반려동물 필터링
      final filteredPets = allPets.where((pet) {
        // 동물 종류 매칭 (새로운 animal_type 필드 사용)
        bool animalTypeMatch = pet.animalType == widget.animalType;
        
        // animal_type이 null인 경우 기존 species로 매칭 (하위 호환성)
        if (pet.animalType == null) {
          if (widget.animalType == 0) { // 강아지
            animalTypeMatch = pet.species == '강아지';
          } else if (widget.animalType == 1) { // 고양이
            animalTypeMatch = pet.species == '고양이';
          }
        }

        // 혈액형 매칭 (혈액형이 지정된 경우만)
        bool bloodTypeMatch = widget.bloodType.isEmpty || 
                             widget.bloodType.toLowerCase() == 'all' ||
                             pet.bloodType == widget.bloodType;

        // 기본 헌혈 조건 (나이, 체중 등)
        bool basicConditions = pet.ageNumber >= 1 && 
                              pet.ageNumber <= 8 && 
                              pet.weightKg >= 20 &&
                              !pet.pregnant &&
                              (pet.vaccinated ?? false) &&
                              !(pet.hasDisease ?? false);

        return animalTypeMatch && bloodTypeMatch && basicConditions;
      }).toList();

      setState(() {
        availablePets = filteredPets;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _submitApplication() async {
    if (selectedPet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('헌혈할 반려동물을 선택해주세요.')),
      );
      return;
    }

    try {
      setState(() {
        isSubmitting = true;
      });

      await UserApplicationService.createApplication(
        widget.postId,
        selectedPet!.petIdx!,
      );

      if (mounted) {
        // 성공 시 별도의 스낵바 메시지 표시하지 않음
        Navigator.of(context).pop(true); // 성공 결과 반환
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('신청 실패: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '헌혈 신청',
          style: AppTheme.h3Style.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryBlue,
              ),
            )
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppTheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '오류가 발생했습니다',
                        style: AppTheme.h4Style,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        errorMessage!,
                        style: AppTheme.bodyMediumStyle,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadAvailablePets,
                        icon: const Icon(Icons.refresh),
                        label: const Text('다시 시도'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 게시글 정보
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '신청할 헌혈 게시글',
                                style: AppTheme.h4Style.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.postTitle,
                                style: AppTheme.bodyLargeStyle.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '병원: ${widget.hospitalName}',
                                style: AppTheme.bodyMediumStyle,
                              ),
                              if (widget.bloodType.isNotEmpty)
                                Text(
                                  '필요 혈액형: ${widget.bloodType}',
                                  style: AppTheme.bodyMediumStyle,
                                ),
                              Text(
                                '대상: ${widget.animalType == 0 ? "강아지" : "고양이"}',
                                style: AppTheme.bodyMediumStyle,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 반려동물 선택
                      Text(
                        '헌혈할 반려동물 선택',
                        style: AppTheme.h4Style.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (availablePets.isEmpty)
                        Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              children: [
                                Icon(
                                  widget.animalType == 0 ? Icons.pets : Icons.cruelty_free,
                                  size: 48,
                                  color: AppTheme.mediumGray,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '이 헌혈 요청에 참여할 수 있는\n${widget.animalType == 0 ? "강아지" : "고양이"}가 없습니다',
                                  style: AppTheme.bodyLargeStyle.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: widget.animalType == 0 
                                        ? Colors.blue.shade50 
                                        : Colors.purple.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            size: 20,
                                            color: widget.animalType == 0 
                                                ? Colors.blue.shade600 
                                                : Colors.purple.shade600,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '헌혈 조건',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: widget.animalType == 0 
                                                  ? Colors.blue.shade600 
                                                  : Colors.purple.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '• ${widget.animalType == 0 ? "강아지" : "고양이"} 종류 일치\n• 나이: 1-8세\n• 체중: 20kg 이상\n• 건강한 상태 (질병 없음)\n• 예방접종 완료\n• 임신하지 않은 상태',
                                        style: AppTheme.bodyMediumStyle.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                        textAlign: TextAlign.left,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => const PetRegisterScreen(),
                                      ),
                                    ).then((result) {
                                      if (result == true) {
                                        _loadAvailablePets(); // 새로운 펫 등록 후 목록 새로고침
                                      }
                                    });
                                  },
                                  icon: const Icon(Icons.add_circle_outline),
                                  label: Text('${widget.animalType == 0 ? "강아지" : "고양이"} 등록하기'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryBlue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...availablePets.map((pet) => Card(
                              margin: const EdgeInsets.only(bottom: 12.0),
                              elevation: selectedPet?.petIdx == pet.petIdx ? 3 : 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: selectedPet?.petIdx == pet.petIdx
                                      ? AppTheme.primaryBlue
                                      : Colors.grey.shade200,
                                  width: selectedPet?.petIdx == pet.petIdx ? 2 : 1,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  setState(() {
                                    selectedPet = pet;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      Radio<Pet>(
                                        value: pet,
                                        groupValue: selectedPet,
                                        onChanged: (Pet? value) {
                                          setState(() {
                                            selectedPet = value;
                                          });
                                        },
                                        activeColor: AppTheme.primaryBlue,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              pet.name,
                                              style: AppTheme.bodyLargeStyle.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${pet.species == 'dog' ? '반려견' : '반려묘'} • ${pet.age} • ${pet.weightKg}kg',
                                              style: AppTheme.bodyMediumStyle,
                                            ),
                                            if (pet.bloodType != null)
                                              Text(
                                                '혈액형: ${pet.bloodType}',
                                                style: AppTheme.bodyMediumStyle.copyWith(
                                                  color: AppTheme.primaryBlue,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            if (pet.breed != null)
                                              Text(
                                                '품종: ${pet.breed}',
                                                style: AppTheme.bodySmallStyle.copyWith(
                                                  color: AppTheme.textSecondary,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )),

                      const SizedBox(height: 32),

                      // 신청 버튼
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: availablePets.isNotEmpty && !isSubmitting
                              ? _submitApplication
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  '헌혈 신청하기',
                                  style: AppTheme.bodyLargeStyle.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 안내사항
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: AppTheme.lightGray,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 20,
                                  color: AppTheme.primaryBlue,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '헌혈 신청 안내',
                                  style: AppTheme.bodyLargeStyle.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '• 신청 후 병원에서 검토를 거쳐 승인/거절이 결정됩니다.\n'
                              '• 승인된 경우 병원에서 연락드립니다.\n'
                              '• 헌혈 전 반려동물의 건강 상태를 다시 한 번 확인합니다.\n'
                              '• 헌혈은 안전한 환경에서 전문 수의사가 진행합니다.',
                              style: AppTheme.bodyMediumStyle.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}