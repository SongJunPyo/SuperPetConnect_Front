import 'package:flutter/material.dart';
import '../models/pet_model.dart';
import '../services/donation_application_service.dart';
import '../services/manage_pet_info.dart';
import '../utils/app_theme.dart';
import '../utils/donation_eligibility.dart';
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
  State<DonationApplicationScreen> createState() =>
      _DonationApplicationScreenState();
}

class _DonationApplicationScreenState extends State<DonationApplicationScreen> {
  List<Pet> allMatchingPets = []; // 동물 종류가 일치하는 모든 반려동물
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

      // 동물 종류와 혈액형이 일치하는 반려동물만 필터링 (헌혈 가능/불가능 모두 포함)
      final matchingPets =
          allPets.where((pet) {
            // 동물 종류 매칭
            if (!DonationEligibility.matchesAnimalType(
              pet,
              widget.animalType,
            )) {
              return false;
            }

            // 혈액형 매칭
            if (!DonationEligibility.matchesBloodType(pet, widget.bloodType)) {
              return false;
            }

            return true;
          }).toList();

      setState(() {
        allMatchingPets = matchingPets;
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('헌혈할 반려동물을 선택해주세요.')));
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
          style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body:
          isLoading
              ? Center(
                child: CircularProgressIndicator(color: AppTheme.primaryBlue),
              )
              : errorMessage != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: AppTheme.error),
                    const SizedBox(height: 16),
                    Text('오류가 발생했습니다', style: AppTheme.h4Style),
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

                    if (allMatchingPets.isEmpty)
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
                                widget.animalType == 0
                                    ? Icons.pets
                                    : Icons.cruelty_free,
                                size: 48,
                                color: AppTheme.mediumGray,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '등록된 ${widget.animalType == 0 ? "강아지" : "고양이"}가 없습니다',
                                style: AppTheme.bodyLargeStyle.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color:
                                      widget.animalType == 0
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
                                          color:
                                              widget.animalType == 0
                                                  ? Colors.blue.shade600
                                                  : Colors.purple.shade600,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '헌혈 조건',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color:
                                                widget.animalType == 0
                                                    ? Colors.blue.shade600
                                                    : Colors.purple.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      DonationEligibility.getConditionsSummary(
                                        widget.animalType,
                                      ),
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
                                  Navigator.of(context)
                                      .push(
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  const PetRegisterScreen(),
                                        ),
                                      )
                                      .then((result) {
                                        if (result == true) {
                                          _loadAvailablePets();
                                        }
                                      });
                                },
                                icon: const Icon(Icons.add_circle_outline),
                                label: Text(
                                  '${widget.animalType == 0 ? "강아지" : "고양이"} 등록하기',
                                ),
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
                      ...allMatchingPets.map((pet) {
                        final eligibility =
                            DonationEligibility.checkEligibility(pet);
                        final isSelectable =
                            eligibility.isEligible ||
                            eligibility.needsConsultation;
                        final isSelected = selectedPet?.petIdx == pet.petIdx;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12.0),
                          elevation: isSelected ? 3 : 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color:
                                  !isSelectable
                                      ? Colors.grey.shade300
                                      : isSelected
                                      ? AppTheme.primaryBlue
                                      : Colors.grey.shade200,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap:
                                isSelectable
                                    ? () {
                                      setState(() {
                                        selectedPet = pet;
                                      });
                                    }
                                    : null,
                            child: Opacity(
                              opacity: isSelectable ? 1.0 : 0.7,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (isSelectable)
                                          RadioGroup<Pet>(
                                            groupValue: selectedPet,
                                            onChanged: (Pet? value) {
                                              setState(() {
                                                selectedPet = value;
                                              });
                                            },
                                            child: Radio<Pet>(
                                              value: pet,
                                              activeColor: AppTheme.primaryBlue,
                                            ),
                                          )
                                        else
                                          const Padding(
                                            padding: EdgeInsets.all(12.0),
                                            child: Icon(
                                              Icons.block,
                                              color: Colors.red,
                                              size: 24,
                                            ),
                                          ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      pet.name,
                                                      style: AppTheme
                                                          .bodyLargeStyle
                                                          .copyWith(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color:
                                                                isSelectable
                                                                    ? AppTheme
                                                                        .textPrimary
                                                                    : AppTheme
                                                                        .textSecondary,
                                                          ),
                                                    ),
                                                  ),
                                                  if (eligibility
                                                      .needsConsultation)
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Colors
                                                                .orange
                                                                .shade100,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        '협의 필요',
                                                        style: AppTheme
                                                            .bodySmallStyle
                                                            .copyWith(
                                                              color:
                                                                  Colors
                                                                      .orange
                                                                      .shade800,
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                      ),
                                                    ),
                                                  if (!isSelectable)
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Colors.red.shade100,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        '헌혈 불가',
                                                        style: AppTheme
                                                            .bodySmallStyle
                                                            .copyWith(
                                                              color:
                                                                  Colors
                                                                      .red
                                                                      .shade800,
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${pet.species} • ${pet.age} • ${pet.weightKg}kg',
                                                style: AppTheme.bodyMediumStyle
                                                    .copyWith(
                                                      color:
                                                          AppTheme
                                                              .textSecondary,
                                                    ),
                                              ),
                                              if (pet.bloodType != null)
                                                Text(
                                                  '혈액형: ${pet.bloodType}',
                                                  style: AppTheme
                                                      .bodyMediumStyle
                                                      .copyWith(
                                                        color:
                                                            isSelectable
                                                                ? AppTheme
                                                                    .primaryBlue
                                                                : AppTheme
                                                                    .textSecondary,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    // 헌혈 불가능 이유 표시
                                    if (!isSelectable &&
                                        eligibility
                                            .failedConditions
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '헌혈 불가 사유',
                                              style: AppTheme.bodySmallStyle
                                                  .copyWith(
                                                    color: Colors.red.shade700,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                            const SizedBox(height: 6),
                                            ...eligibility.failedConditions.map((
                                              condition,
                                            ) {
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 4,
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(
                                                      Icons.close,
                                                      size: 14,
                                                      color:
                                                          Colors.red.shade600,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        '${condition.conditionName}: ${condition.message}',
                                                        style: AppTheme
                                                            .bodySmallStyle
                                                            .copyWith(
                                                              color:
                                                                  Colors
                                                                      .red
                                                                      .shade700,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 32),

                    // 신청 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            selectedPet != null && !isSubmitting
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
                        child:
                            isSubmitting
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
