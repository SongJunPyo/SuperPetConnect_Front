// user/donation_application_dialog.dart

import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../models/applied_donation_model.dart';
import '../models/donation_post_time_model.dart';
import '../models/pet_model.dart' as pet_model;
import '../services/applied_donation_service.dart';

class DonationApplicationDialog extends StatefulWidget {
  final int postIdx;
  final String postTitle;
  final String hospitalName;
  final int animalType; // 0=강아지, 1=고양이
  final List<DonationDateWithTimes> availableDatesWithTimes;
  final List<pet_model.Pet> userPets; // 사용자의 반려동물 목록

  const DonationApplicationDialog({
    super.key,
    required this.postIdx,
    required this.postTitle,
    required this.hospitalName,
    required this.animalType,
    required this.availableDatesWithTimes,
    required this.userPets,
  });

  @override
  State<DonationApplicationDialog> createState() => _DonationApplicationDialogState();
}

class _DonationApplicationDialogState extends State<DonationApplicationDialog> {
  pet_model.Pet? selectedPet;
  DonationDateWithTimes? selectedDateWithTimes;
  DonationPostTime? selectedTime;
  bool isSubmitting = false;
  Map<int, TimeSlotApplications> timeSlotStats = {};

  // 내가 신청한 시간대 정보 (postTimesIdx -> MyApplicationInfo)
  Map<int, MyApplicationInfo> myApplicationsMap = {};
  bool isLoadingMyApplications = true;

  @override
  void initState() {
    super.initState();
    _loadTimeSlotStats();
    _loadMyApplications();
  }

  /// 내 신청 목록 로드 (이 게시글에 대한 신청만)
  Future<void> _loadMyApplications() async {
    debugPrint('[DonationDialog] 내 신청 목록 로드 시작 - postIdx: ${widget.postIdx}');

    try {
      final applications = await AppliedDonationService.getMyApplicationsForPost(widget.postIdx);

      debugPrint('[DonationDialog] API 응답 - 신청 수: ${applications.length}');
      for (final app in applications) {
        debugPrint('[DonationDialog] - 신청 ID: ${app.applicationId}, postTimesIdx: ${app.postTimesIdx}, status: ${app.statusCode} (${app.status}), shouldShowBorder: ${app.shouldShowAppliedBorder}');
      }

      if (mounted) {
        setState(() {
          myApplicationsMap = {
            for (final app in applications)
              if (app.shouldShowAppliedBorder) app.postTimesIdx: app
          };
          isLoadingMyApplications = false;
        });
      }

      debugPrint('[DonationDialog] 빨간 테두리 표시할 시간대: ${myApplicationsMap.keys.toList()}');
    } catch (e) {
      debugPrint('[DonationDialog] 내 신청 목록 로드 실패: $e');
      if (mounted) {
        setState(() {
          isLoadingMyApplications = false;
        });
      }
    }
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
              // 시간대별 통계 로딩 실패 시 로그 출력
              debugPrint('Failed to load stats for time slot: $e');
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
      // 전체 통계 로딩 실패 시 로그 출력
      debugPrint('Failed to load time slot statistics: $e');
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
            
            // 헌혈 가능한 반려동물 필터링
            Builder(builder: (context) {
              final availablePets = widget.userPets.where((pet) {
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
                
                return animalTypeMatch;
              }).toList();
              
              if (availablePets.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                    border: Border.all(color: AppTheme.lightGray),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.animalType == 0 ? Icons.pets : Icons.cruelty_free,
                        color: AppTheme.mediumGray,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '이 헌혈 요청에 참여할 수 있는 ${widget.animalType == 0 ? "강아지" : "고양이"}가 없습니다',
                          style: AppTheme.bodyMediumStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              return Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.lightGray),
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<pet_model.Pet>(
                    value: selectedPet,
                    hint: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('반려동물을 선택하세요'),
                    ),
                    isExpanded: true,
                    items: availablePets.map((pet) {
                      return DropdownMenuItem<pet_model.Pet>(
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
              );
            }),

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
        color: isSelected ? AppTheme.lightBlue.withValues(alpha: 0.2) : Colors.white,
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
    final isClosed = time.isClosed; // 시간대 마감 여부 (status = 1)

    // 내가 이미 신청한 시간대인지 확인
    final myApplication = time.postTimesId != null
        ? myApplicationsMap[time.postTimesId!]
        : null;
    final isAlreadyApplied = myApplication != null;

    // 디버그 로그
    debugPrint('[TimeCard] postTimesId: ${time.postTimesId}, isAlreadyApplied: $isAlreadyApplied, myApplicationsMap keys: ${myApplicationsMap.keys.toList()}');

    final isDisabled = isClosed || isFullyBooked; // 마감되었거나 정원 초과

    return Container(
      decoration: BoxDecoration(
        color: isAlreadyApplied
            ? Colors.red.shade50  // 이미 신청한 시간대는 연한 빨간 배경
            : isSelected
                ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                : isDisabled
                    ? Colors.grey.shade100
                    : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(
          color: isAlreadyApplied
              ? Colors.red  // 빨간 테두리
              : isSelected
                  ? AppTheme.primaryBlue
                  : isDisabled
                      ? Colors.grey
                      : AppTheme.lightGray,
          width: isAlreadyApplied ? 2 : (isSelected ? 2 : 1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isAlreadyApplied
              ? () => _showCancelBottomSheet(myApplication) // 취소 바텀시트 표시
              : isDisabled
                  ? () {
                      // 마감된 시간대 클릭 시 안내 메시지 표시
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isClosed ? '이미 마감된 시간대입니다.' : '정원이 마감된 시간대입니다.'),
                          backgroundColor: Colors.orange.shade700,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  : () {
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
                    color: isAlreadyApplied
                        ? Colors.red
                        : isDisabled
                            ? Colors.grey
                            : isSelected
                                ? AppTheme.primaryBlue
                                : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isAlreadyApplied
                      ? '신청완료 (${myApplication.status})'
                      : isClosed
                          ? '마감'
                          : isFullyBooked
                              ? '마감'
                              : applicationsCount > 0
                                  ? '$applicationsCount명 신청'
                                  : '신청 가능',
                  style: AppTheme.captionStyle.copyWith(
                    color: isAlreadyApplied
                        ? Colors.red
                        : isDisabled
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

  /// 취소 바텀시트 표시
  void _showCancelBottomSheet(MyApplicationInfo application) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _CancelApplicationBottomSheet(
        application: application,
        onCancelSuccess: () {
          // 취소 성공 후 목록 새로고침
          _loadMyApplications();
          _loadTimeSlotStats();
        },
      ),
    );
  }

  bool _canSubmit() {
    // 헌혈 가능한 반려동물 필터링
    final availablePets = widget.userPets.where((pet) {
      // 동물 종류 매칭 (새로운 animal_type 필드 사용)
      bool animalTypeMatch = pet.animalType == widget.animalType;

      // animal_type이 null인 경우 기존 species로 매칭 (하위 호환성)
      if (pet.animalType == null) {
        if (widget.animalType == 0) { // 강아지
          animalTypeMatch = pet.species == '강아지' || pet.species == '개';
        } else if (widget.animalType == 1) { // 고양이
          animalTypeMatch = pet.species == '고양이';
        }
      }

      return animalTypeMatch;
    }).toList();

    return availablePets.isNotEmpty &&
           selectedPet != null &&
           selectedTime != null &&
           !selectedTime!.isClosed && // 마감된 시간대는 신청 불가
           !isSubmitting;
  }

  Future<void> _submitApplication() async {
    if (!_canSubmit()) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      // 헌혈 신청 생성 (서버에서 중복 체크)
      await AppliedDonationService.createApplication(
        selectedPet!.petIdx!,
        selectedTime!.postTimesId!,
      );

      if (mounted) {
        Navigator.of(context).pop(true); // 성공 결과와 함께 다이얼로그 닫기

        // 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('헌혈 신청이 완료되었습니다.'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });

        // 에러 메시지 추출
        String errorMessage = e.toString();
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11);
        }

        debugPrint('[DonationDialog] 에러 발생: $errorMessage');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

/// 신청 취소 바텀시트
class _CancelApplicationBottomSheet extends StatefulWidget {
  final MyApplicationInfo application;
  final VoidCallback onCancelSuccess;

  const _CancelApplicationBottomSheet({
    required this.application,
    required this.onCancelSuccess,
  });

  @override
  State<_CancelApplicationBottomSheet> createState() => _CancelApplicationBottomSheetState();
}

class _CancelApplicationBottomSheetState extends State<_CancelApplicationBottomSheet> {
  bool isCancelling = false;

  @override
  Widget build(BuildContext context) {
    final canCancel = widget.application.canCancel;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 핸들바
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 제목
          Row(
            children: [
              Icon(
                canCancel ? Icons.cancel_outlined : Icons.info_outline,
                color: canCancel ? Colors.red : Colors.orange,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                canCancel ? '신청 취소' : '신청 정보',
                style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 신청 정보 카드
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('게시글', widget.application.postTitle),
                const SizedBox(height: 8),
                _buildInfoRow('반려동물', '${widget.application.petName} (${widget.application.speciesText})'),
                const SizedBox(height: 8),
                _buildInfoRow('헌혈 시간', widget.application.donationTime),
                const SizedBox(height: 8),
                _buildInfoRow('상태', widget.application.status,
                    statusColor: _getStatusColor(widget.application.statusCode)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 취소 가능/불가 메시지
          if (!canCancel) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.application.cancelBlockMessage,
                      style: AppTheme.bodyMediumStyle.copyWith(
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 버튼들
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('닫기'),
                ),
              ),
              if (canCancel) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isCancelling ? null : _handleCancel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isCancelling
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('신청 취소'),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? statusColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: AppTheme.bodyMediumStyle.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTheme.bodyMediumStyle.copyWith(
              fontWeight: FontWeight.w500,
              color: statusColor ?? AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(int statusCode) {
    switch (statusCode) {
      case AppliedDonationStatus.pending:
        return Colors.orange;
      case AppliedDonationStatus.approved:
        return Colors.blue;
      case AppliedDonationStatus.rejected:
        return Colors.grey;
      case AppliedDonationStatus.completed:
      case AppliedDonationStatus.finalCompleted:
        return Colors.green;
      case AppliedDonationStatus.cancelled:
        return Colors.grey;
      case AppliedDonationStatus.pendingCompletion:
        return Colors.purple;
      case AppliedDonationStatus.pendingCancellation:
        return Colors.orange;
      default:
        return AppTheme.textPrimary;
    }
  }

  Future<void> _handleCancel() async {
    setState(() {
      isCancelling = true;
    });

    try {
      await AppliedDonationService.cancelApplicationToServer(
          widget.application.applicationId);

      if (mounted) {
        Navigator.pop(context);
        widget.onCancelSuccess();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('신청이 취소되었습니다.'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isCancelling = false;
        });

        String errorMessage = e.toString();
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}