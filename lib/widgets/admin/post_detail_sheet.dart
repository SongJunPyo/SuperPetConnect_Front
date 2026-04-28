import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import '../../utils/time_format_util.dart';
import '../post_detail/post_detail_blood_type.dart';
import '../post_detail/post_detail_description.dart';
import '../post_detail/post_detail_handle_bar.dart';
import '../post_detail/post_detail_header.dart';
import '../post_detail/post_detail_meta_section.dart';
import '../post_detail/post_detail_patient_info.dart';

/// 관리자 게시글 상세 시트의 액션 묶음.
///
/// 모든 콜백은 nullable — 호출하는 탭에 해당하는 것만 채우면 됨.
/// (Tab 0 모집대기에서는 [onApprovePostTap]/[onRejectPostTap],
/// Tab 1 헌혈모집에서는 [onClosePost]/[onReopenPost],
/// Tab 2 헌혈마감에서는 [onFinalApproveCompletion])
class PostDetailSheetActions {
  /// Tab 0 모집대기 — 승인 버튼.
  final void Function(int postId, String title)? onApprovePostTap;

  /// Tab 0 모집대기 — 거절 버튼.
  final void Function(int postId, String title)? onRejectPostTap;

  /// Tab 2 헌혈마감 — 헌혈 마감 (PENDING_COMPLETION 2 → COMPLETED 3).
  final void Function(int applicationId)? onFinalApproveCompletion;

  /// Tab 1 헌혈모집 — 모든 시간대 마감.
  /// 시트 내부 [StateSetter]를 넘겨주어 시트가 즉시 갱신될 수 있도록.
  final void Function(StateSetter setState)? onClosePost;

  /// Tab 1 헌혈모집 — 게시글 전체 재오픈.
  final void Function(StateSetter setState)? onReopenPost;

  const PostDetailSheetActions({
    this.onApprovePostTap,
    this.onRejectPostTap,
    this.onFinalApproveCompletion,
    this.onClosePost,
    this.onReopenPost,
  });
}

/// 관리자 화면에서 게시글 상세 정보를 시트로 표시.
///
/// Tab 0/1/2가 공유하는 시트. 탭 분기는 [currentTabIndex]와 [actions]의
/// 어떤 콜백이 채워졌는지로 처리.
///
/// [menuItems]는 시트 진입 시점에 호출자가 미리 빌드해서 전달
/// (Tab 0/1/2일 때만 not-null, 내부에서 ... 메뉴로 표시).
///
/// [timeSlotBuilder]는 시트 내부 [StateSetter]를 받아 시간대 드롭다운을
/// 빌드 — 시간대 신청자 fetch / 마감 / 재오픈 등이 시트 안에서 즉시
/// 갱신되어야 하기 때문.
void showPostDetailBottomSheet(
  BuildContext context, {
  required Map<String, dynamic> post,
  required String postStatus,
  required String postType,
  required int currentTabIndex,
  List<PostDetailMenuItem>? menuItems,
  required Widget Function(StateSetter setState) timeSlotBuilder,
  PostDetailSheetActions actions = const PostDetailSheetActions(),
}) {
  final animalTypeRaw = post['animalType'];
  final animalType = animalTypeRaw == 0 || animalTypeRaw == '0'
      ? 0
      : animalTypeRaw == 1 || animalTypeRaw == '1'
          ? 1
          : 0;

  final createdAt = TimeFormatUtils.parseFlexibleDate(
        post['createdDate'] ?? post['created_date'] ?? post['created_at'],
      ) ??
      DateTime.now();

  final bloodType =
      post['bloodType'] ?? post['blood_type'] ?? post['emergency_blood_type'];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    const PostDetailHandleBar(),
                    PostDetailHeader(
                      title: post['title'] ?? '제목 없음',
                      isUrgent: postType == '긴급',
                      typeText: postType,
                      profileImage: post['hospitalProfileImage'] ??
                          post['hospital_profile_image'],
                      onClose: () => Navigator.pop(context),
                      menuItems: menuItems,
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PostDetailMetaSection(
                              hospitalName: _extractHospitalName(
                                post['title'] ?? '',
                              ),
                              hospitalNickname: null,
                              hospitalProfileImage:
                                  post['hospitalProfileImage'] ??
                                      post['hospital_profile_image'],
                              location: post['location'] ?? '주소 정보 없음',
                              animalType: animalType,
                              applicantCount: post['applicantCount'] ??
                                  post['applicant_count'] ??
                                  0,
                              createdAt: createdAt,
                            ),
                            PostDetailDescription(
                              contentDelta: (post['contentDelta'] ??
                                      post['content_delta'])
                                  ?.toString(),
                              plainText: post['description']?.toString(),
                            ),
                            PostDetailPatientInfo(
                              isUrgent: post['types'] == 0,
                              patientName: post['patientName']?.toString() ??
                                  post['patient_name']?.toString(),
                              breed: post['breed']?.toString(),
                              age: post['age'] is int
                                  ? post['age']
                                  : (int.tryParse(
                                      post['age']?.toString() ?? '',
                                    )),
                              diagnosis: post['diagnosis']?.toString(),
                            ),
                            if (post['types'] == 0)
                              PostDetailBloodType(
                                bloodType: bloodType?.toString(),
                                isUrgent: postType == '긴급',
                              ),
                            Text("헌혈 일정", style: AppTheme.h4Style),
                            const SizedBox(height: 12),
                            timeSlotBuilder(setState),
                            const SizedBox(height: 16),
                            if ((post['status'] == 1 ||
                                    (post['status'] == 3 &&
                                        _hasOpenTimeSlots(post))) &&
                                post['is_completion_pending'] != true &&
                                currentTabIndex == 1 &&
                                actions.onClosePost != null)
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () =>
                                      actions.onClosePost!(setState),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('모든 시간대 게시글 마감'),
                                ),
                              ),
                            if (post['status'] == 3 &&
                                !_hasOpenTimeSlots(post) &&
                                post['is_completion_pending'] != true &&
                                currentTabIndex == 1 &&
                                actions.onReopenPost != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        actions.onReopenPost!(setState),
                                    icon: const Icon(Icons.refresh, size: 18),
                                    label: const Text('게시글 전체 재오픈'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 24),
                            if (post['is_completion_pending'] == true &&
                                post['status'] == 2 &&
                                actions.onFinalApproveCompletion != null) ...[
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    actions.onFinalApproveCompletion!(
                                      post['application_id'] ??
                                          post['id'] ??
                                          0,
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.green,
                                    side: const BorderSide(color: Colors.green),
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  child: const Text('헌혈 마감'),
                                ),
                              ),
                            ] else if (postStatus == '승인 대기' &&
                                currentTabIndex != 3 &&
                                actions.onApprovePostTap != null &&
                                actions.onRejectPostTap != null) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: _ApproveRejectButton(
                                      label: '승인',
                                      color: Colors.green,
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        final postId = post['id'];
                                        if (postId != null) {
                                          actions.onApprovePostTap!(
                                            postId is int
                                                ? postId
                                                : int.tryParse(
                                                      postId.toString(),
                                                    ) ??
                                                    0,
                                            post['title'] ?? '제목 없음',
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _ApproveRejectButton(
                                      label: '거절',
                                      color: Colors.red,
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        final postId = post['id'];
                                        if (postId != null) {
                                          actions.onRejectPostTap!(
                                            postId is int
                                                ? postId
                                                : int.tryParse(
                                                      postId.toString(),
                                                    ) ??
                                                    0,
                                            post['title'] ?? '제목 없음',
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  );
}

/// 게시글 제목의 `[병원이름]` 형식에서 병원명 추출.
String _extractHospitalName(String title) {
  final match = RegExp(r'\[(.*?)\]').firstMatch(title);
  if (match != null && match.group(1) != null) {
    return match.group(1)!;
  }
  return '병원 이름 없음';
}

/// 게시글에 열린 시간대(status 0 또는 null)가 하나라도 있는지.
bool _hasOpenTimeSlots(Map<String, dynamic> post) {
  final timeRanges = post['timeRanges'] as List<dynamic>? ?? [];
  return timeRanges.any((ts) => ts['status'] == 0 || ts['status'] == null);
}

class _ApproveRejectButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ApproveRejectButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(label),
    );
  }
}
