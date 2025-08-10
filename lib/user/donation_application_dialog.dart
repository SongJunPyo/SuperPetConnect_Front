// user/donation_application_dialog.dart

import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../models/applied_donation_model.dart';
import '../models/donation_post_time_model.dart';
import '../services/applied_donation_service.dart';

class DonationApplicationDialog extends StatefulWidget {
  final int postIdx;
  final String postTitle;
  final String hospitalName;
  final List<DonationDateWithTimes> availableDatesWithTimes;
  final List<Pet> userPets; // 사용자의 반려동물 목록

  const DonationApplicationDialog({
    super.key,
    required this.postIdx,
    required this.postTitle,
    required this.hospitalName,
    required this.availableDatesWithTimes,
    required this.userPets,
  });

  @override
  State<DonationApplicationDialog> createState() => _DonationApplicationDialogState();
}

class _DonationApplicationDialogState extends State<DonationApplicationDialog> {
  Pet? selectedPet;
  DonationDateWithTimes? selectedDateWithTimes;
  DonationPostTime? selectedTime;
  bool isSubmitting = false;
  Map<int, TimeSlotApplications> timeSlotStats = {};

  @override
  void initState() {
    super.initState();
    _loadTimeSlotStats();
  }

  Future<void> _loadTimeSlotStats() async {
    try {
      final Map<int, TimeSlotApplications> stats = {};
      
      for (final dateWithTimes in widget.availableDatesWithTimes) {
        for (final time in dateWithTimes.times) {
          if (time.postTimesId != null) {
            try {
              final slotStats = await AppliedDonationService.getTimeSlotApplications(
                time.postTimesId!
              );
              stats[time.postTimesId!] = slotStats;
            } catch (e) {
              print('시간대 ${time.postTimesId} 통계 로드 실패: $e');
            }
          }
        }
      }
      
      if (mounted) {
        setState(() {
          timeSlotStats = stats;
        });
      }
    } catch (e) {
      print('시간대 통계 로드 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
        padding: const EdgeInsets.all(AppTheme.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 제목
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '헌혈 신청하기',
                        style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.postTitle,
                        style: AppTheme.bodyMediumStyle.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing20),

            // 반려동물 선택
            Text(
              '신청할 반려동물',
              style: AppTheme.bodyLargeStyle.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.lightGray),
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Pet>(
                  value: selectedPet,
                  hint: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('반려동물을 선택하세요'),
                  ),
                  isExpanded: true,
                  items: widget.userPets.map((pet) {
                    return DropdownMenuItem<Pet>(
                      value: pet,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(pet.displayInfo),
                      ),
                    );
                  }).toList(),
                  onChanged: (pet) {
                    setState(() {
                      selectedPet = pet;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacing20),

            // 날짜 선택
            Text(
              '헌혈 날짜 선택',
              style: AppTheme.bodyLargeStyle.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.availableDatesWithTimes.length,
                itemBuilder: (context, index) {
                  final dateWithTimes = widget.availableDatesWithTimes[index];
                  return _buildDateCard(dateWithTimes);
                },
              ),
            ),

            // 시간 선택
            if (selectedDateWithTimes != null) ...[
              const SizedBox(height: AppTheme.spacing20),
              Text(
                '헌혈 시간 선택',
                style: AppTheme.bodyLargeStyle.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.spacing8),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: selectedDateWithTimes!.times.length,
                  itemBuilder: (context, index) {
                    final time = selectedDateWithTimes!.times[index];
                    return _buildTimeCard(time);
                  },
                ),
              ),
            ],

            const Spacer(),

            // 신청 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canSubmit() ? _submitApplication : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                ),
                child: isSubmitting 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('헌혈 신청하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateCard(DonationDateWithTimes dateWithTimes) {
    final isSelected = selectedDateWithTimes == dateWithTimes;
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.lightBlue.withOpacity(0.2) : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(
          color: isSelected ? AppTheme.primaryBlue : AppTheme.lightGray,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              selectedDateWithTimes = dateWithTimes;
              selectedTime = null; // 날짜 변경시 선택된 시간 초기화
            });
          },
          borderRadius: BorderRadius.circular(AppTheme.radius8),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing12),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: isSelected ? AppTheme.primaryBlue : AppTheme.textSecondary,
                ),
                const SizedBox(width: AppTheme.spacing8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateWithTimes.dateOnly,
                        style: AppTheme.bodyMediumStyle.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSelected ? AppTheme.primaryBlue : AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '${dateWithTimes.times.length}개 시간대 가능',
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
      ),
    );
  }

  Widget _buildTimeCard(DonationPostTime time) {
    final isSelected = selectedTime == time;
    final stats = timeSlotStats[time.postTimesId];
    final isFullyBooked = stats?.isFullyBooked(5) ?? false; // 기본 수용인원 5명
    final applicationsCount = stats?.totalApplications ?? 0;
    
    return Container(
      decoration: BoxDecoration(
        color: isSelected 
            ? AppTheme.primaryBlue.withOpacity(0.1)
            : isFullyBooked 
                ? Colors.grey.shade100
                : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(
          color: isSelected 
              ? AppTheme.primaryBlue
              : isFullyBooked 
                  ? Colors.grey
                  : AppTheme.lightGray,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isFullyBooked ? null : () {
            setState(() {
              selectedTime = time;
            });
          },
          borderRadius: BorderRadius.circular(AppTheme.radius8),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  time.formatted12Hour,
                  style: AppTheme.bodyMediumStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isFullyBooked 
                        ? Colors.grey
                        : isSelected 
                            ? AppTheme.primaryBlue 
                            : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isFullyBooked 
                      ? '마감' 
                      : applicationsCount > 0 
                          ? '$applicationsCount명 신청'
                          : '신청 가능',
                  style: AppTheme.captionStyle.copyWith(
                    color: isFullyBooked 
                        ? Colors.red
                        : applicationsCount > 0 
                            ? Colors.orange.shade700
                            : Colors.green.shade700,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _canSubmit() {
    return selectedPet != null && 
           selectedTime != null && 
           !isSubmitting;
  }

  Future<void> _submitApplication() async {
    if (!_canSubmit()) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      // 신청 가능 여부 검증
      final validation = await AppliedDonationService.validateApplicationEligibility(
        selectedPet!.petIdx!,
        selectedTime!.postTimesId!,
      );

      if (!validation['canApply']) {
        throw Exception(validation['reason']);
      }

      // 헌혈 신청 생성
      final application = await AppliedDonationService.createApplication(
        selectedPet!.petIdx!,
        selectedTime!.postTimesId!,
      );

      if (mounted) {
        Navigator.of(context).pop(true); // 성공 결과와 함께 다이얼로그 닫기
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('헌혈 신청이 완료되었습니다!\n${selectedPet!.name}의 신청이 접수되었습니다.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('헌혈 신청 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}