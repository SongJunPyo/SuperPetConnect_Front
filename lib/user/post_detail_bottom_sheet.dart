import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../models/applied_donation_model.dart';
import '../models/unified_post_model.dart';
import '../utils/app_theme.dart';
import '../utils/pet_field_icons.dart';
import '../utils/time_format_util.dart';
import '../widgets/pet_profile_image.dart';
import '../widgets/rich_text_viewer.dart';

/// 헌혈 모집글 리스트에서 행을 탭했을 때 뜨는 상세 바텀시트.
///
/// 부모([UserDonationPostsListScreen])는 `showModalBottomSheet(builder: ...)`로
/// 이 위젯을 띄우기 전에 `DashboardService.getDonationPostDetail`을 호출해서
/// `displayPost`를 준비. 위젯 자체는 stateless이며, 신청 흐름은 모두 콜백으로
/// 부모에 위임:
///
/// - [onTimeSlotApply] — 다중 시간 슬롯에서 미신청 슬롯을 탭했을 때.
/// - [onCancelApplication] — 이미 신청한 슬롯을 탭했을 때 취소 시트.
/// - [onGeneralApply] — `availableDates`가 비어있고 `donationDate`만 있는 단일
///   날짜 게시글에서 "신청 가능" 박스를 탭했을 때.
///
/// `myApplicationsMap`은 시트 오픈 시점의 스냅샷 — 시트 외부에서 신청 상태가
/// 바뀌어도 자동으로 반영되지 않음. 이는 추출 전 동작과 동일.
class PostDetailBottomSheet extends StatelessWidget {
  final UnifiedPostModel displayPost;
  final Map<int, MyApplicationInfo> myApplicationsMap;
  final void Function(
    String dateStr,
    Map<String, dynamic> timeSlot,
    String displayText,
    UnifiedPostModel post,
  ) onTimeSlotApply;
  final void Function(MyApplicationInfo application) onCancelApplication;
  final void Function(UnifiedPostModel post) onGeneralApply;

  const PostDetailBottomSheet({
    super.key,
    required this.displayPost,
    required this.myApplicationsMap,
    required this.onTimeSlotApply,
    required this.onCancelApplication,
    required this.onGeneralApply,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
              Container(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    if (displayPost.hospitalProfileImage != null) ...[
                      PetProfileImage(
                        profileImage: displayPost.hospitalProfileImage,
                        radius: 20,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        displayPost.title,
                        style: AppTheme.h3Style.copyWith(
                          color: displayPost.isUrgent
                              ? Colors.red
                              : AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // 전체 콘텐츠 (스크롤 가능)
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 메타 정보 (닉네임, 주소, 설명글 순서)
                      // 병원 닉네임
                      Row(
                        children: [
                          Icon(
                            PetFieldIcons.hospital,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '병원명: ',
                            style: AppTheme.bodyMediumStyle.copyWith(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                          Expanded(
                            child: Text(
                              (displayPost.hospitalNickname?.isNotEmpty ??
                                      false)
                                  ? displayPost.hospitalNickname!
                                  : displayPost.hospitalName.isNotEmpty
                                  ? displayPost.hospitalName
                                  : '병원',
                              style: AppTheme.bodyMediumStyle.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      const SizedBox(height: 8),
                      // 주소
                      Row(
                        children: [
                          Icon(
                            PetFieldIcons.postLocation,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              displayPost.location,
                              style: AppTheme.bodyMediumStyle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 동물 종류
                      Row(
                        children: [
                          Icon(
                            displayPost.animalType == 0
                                ? FontAwesomeIcons.dog
                                : FontAwesomeIcons.cat,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '동물 종류: ',
                            style: AppTheme.bodyMediumStyle.copyWith(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                          Expanded(
                            child: Text(
                              displayPost.animalType == 0 ? '강아지' : '고양이',
                              style: AppTheme.bodyMediumStyle.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 신청자 수
                      Row(
                        children: [
                          Icon(
                            Icons.group_outlined,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '신청자 수: ',
                            style: AppTheme.bodyMediumStyle.copyWith(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${displayPost.applicantCount}명',
                              style: AppTheme.bodyMediumStyle.copyWith(
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // 설명글 (있는 경우만)
                      if ((displayPost.contentDelta != null &&
                              displayPost.contentDelta!.isNotEmpty) ||
                          displayPost.description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppTheme.veryLightGray,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.lightGray.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          child: RichTextViewer(
                            contentDelta: displayPost.contentDelta,
                            plainText: displayPost.description,
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                      // 혈액형 정보
                      if (displayPost.bloodType != null &&
                          displayPost.bloodType!.isNotEmpty) ...[
                        Text('필요 혈액형', style: AppTheme.h4Style),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                displayPost.isUrgent
                                    ? Colors.red.shade50
                                    : AppTheme.lightBlue,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  displayPost.isUrgent
                                      ? Colors.red.shade200
                                      : AppTheme.lightGray,
                            ),
                          ),
                          child: Text(
                            displayPost.displayBloodType,
                            style: AppTheme.h3Style.copyWith(
                              color:
                                  displayPost.isUrgent
                                      ? Colors.red
                                      : AppTheme.primaryBlue,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // 헌혈 날짜 정보
                      Text('헌혈 예정일', style: AppTheme.h4Style),
                      const SizedBox(height: 12),
                      if (displayPost.availableDates != null &&
                          displayPost.availableDates!.isNotEmpty) ...[
                        // 새로운 드롭다운 형태의 날짜/시간 선택 UI
                        _buildDateTimeDropdown(displayPost),
                      ] else if (displayPost.donationDate != null) ...[
                        // 단일 날짜인 경우에도 클릭 가능하게 만들기.
                        // 단, 헌혈일이 지났으면 disabled 상태로 표시 (당일 신청 허용).
                        Builder(builder: (context) {
                          final isPast = isDonationDateTimePast(
                            displayPost.donationDate,
                          );
                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: isPast
                                    ? null
                                    : () {
                                        // 단일 날짜의 경우 바로 일반 신청 다이얼로그 표시
                                        onGeneralApply(displayPost);
                                      },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isPast
                                        ? Colors.grey.shade100
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today_outlined,
                                        size: 20,
                                        color: isPast
                                            ? AppTheme.textTertiary
                                            : Colors.black,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              DateFormat(
                                                'yyyy년 MM월 dd일 EEEE',
                                                'ko',
                                              ).format(
                                                displayPost.donationDate!,
                                              ),
                                              style: AppTheme.bodyLargeStyle
                                                  .copyWith(
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    color: isPast
                                                        ? AppTheme
                                                              .textTertiary
                                                        : null,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '예정 시간: ${TimeFormatUtils.formatTimeOfDate(displayPost.donationDate!)}',
                                              style: AppTheme.bodyMediumStyle
                                                  .copyWith(
                                                    color: AppTheme
                                                        .textSecondary,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isPast
                                              ? Colors.grey.shade300
                                              : AppTheme.success.withValues(
                                                  alpha: 0.1,
                                                ),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          isPast ? '마감된 일정' : '신청 가능',
                                          style: AppTheme.bodySmallStyle
                                              .copyWith(
                                                color: isPast
                                                    ? AppTheme.textSecondary
                                                    : AppTheme.success,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                      if (!isPast) ...[
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.keyboard_arrow_right,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.shade200,
                            ),
                          ),
                          child: Text(
                            '헌혈 날짜가 아직 확정되지 않았습니다',
                            style: AppTheme.bodyMediumStyle.copyWith(
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 날짜별 그룹화된 확장 가능한 드롭다운 UI
  Widget _buildDateTimeDropdown(UnifiedPostModel post) {
    if (post.availableDates == null || post.availableDates!.isEmpty) {
      return const SizedBox.shrink();
    }

    // 중복 제거 + 과거 일자 필터링 처리 (당일 신청 허용 — donation_date >= today).
    final Map<String, List<Map<String, dynamic>>> uniqueDates = {};
    final Set<String> seenTimeSlots = {}; // 중복 체크용

    for (final entry in post.availableDates!.entries) {
      final dateStr = entry.key;
      final timeSlots = entry.value;

      if (isDonationDatePast(dateStr)) continue;

      uniqueDates[dateStr] = [];

      for (final timeSlot in timeSlots) {
        final time = timeSlot['time'] ?? '';
        final team = timeSlot['team'] ?? 0;

        // 날짜+시간+팀으로 고유키 생성하여 중복 체크
        final uniqueKey = '$dateStr-$time-$team';

        if (!seenTimeSlots.contains(uniqueKey)) {
          seenTimeSlots.add(uniqueKey);
          uniqueDates[dateStr]!.add(timeSlot);
        }
      }
    }

    if (uniqueDates.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          '신청 가능한 일정이 없습니다 (모든 일정이 지났습니다)',
          style: AppTheme.bodyMediumStyle.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children:
          uniqueDates.entries.map((entry) {
            final dateStr = entry.key;
            final timeSlots = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200, width: 1.5),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_month,
                          color: Colors.black,
                          size: 24,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            TimeFormatUtils.formatDateWithWeekday(dateStr),
                            style: AppTheme.h4Style.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...timeSlots.map<Widget>((timeSlot) {
                        // 내가 이미 신청한 시간대인지 확인
                        final postTimesIdx = timeSlot['post_times_idx'] ?? 0;
                        final myApplication = myApplicationsMap[postTimesIdx];
                        final isAlreadyApplied = myApplication != null;

                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 4,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                if (isAlreadyApplied) {
                                  // 이미 신청한 시간대 클릭 시 취소 바텀시트 표시
                                  onCancelApplication(myApplication);
                                } else {
                                  // 신청하지 않은 시간대 클릭 시 신청 페이지 표시
                                  final displayText =
                                      '${TimeFormatUtils.formatDateWithWeekday(dateStr)} ${TimeFormatUtils.formatTime(timeSlot['time'] ?? '')}';
                                  onTimeSlotApply(
                                    dateStr,
                                    timeSlot,
                                    displayText,
                                    post,
                                  );
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isAlreadyApplied
                                          ? Colors.red.shade50
                                          : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color:
                                        isAlreadyApplied
                                            ? Colors.red
                                            : Colors.black,
                                    width: isAlreadyApplied ? 2.0 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      color:
                                          isAlreadyApplied
                                              ? Colors.red
                                              : Colors.black,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            TimeFormatUtils.formatTime(timeSlot['time'] ?? ''),
                                            style: AppTheme.bodyLargeStyle
                                                .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      isAlreadyApplied
                                                          ? Colors.red
                                                          : Colors.black,
                                                ),
                                          ),
                                          if (isAlreadyApplied)
                                            Text(
                                              '신청완료 (${myApplication.status})',
                                              style: AppTheme.captionStyle
                                                  .copyWith(
                                                    color: Colors.red,
                                                    fontSize: 11,
                                                  ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      isAlreadyApplied
                                          ? Icons.edit_outlined
                                          : Icons.keyboard_arrow_right,
                                      color:
                                          isAlreadyApplied
                                              ? Colors.red
                                              : Colors.black,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                  const SizedBox(height: 12),
                ],
              ),
            );
          }).toList(),
    );
  }
}
