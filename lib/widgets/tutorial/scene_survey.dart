// lib/widgets/tutorial/scene_survey.dart
// 슬라이드 5 — 사전 설문 작성 (대략).
//
// 선정(APPROVED) 후 D-2 23:55까지 작성해야 하는 설문 화면 미니어처.
// 카페 운영진 정책에 따라 동의 5개 + 설문 본문(텍스트/객관식)이 있지만
// 튜토리얼은 핵심만 — 동의 5개 + 설문 항목 일부 visual.
//
// 스텝 0: "전체 동의" 체크박스 탭 → 5개 모두 체크됨
// 스텝 1: [제출] 버튼 탭 → 완료 토스트 + onComplete

import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'highlight_target.dart';
import 'tutorial_phone_frame.dart';

class SurveyScene extends StatefulWidget {
  final VoidCallback onComplete;

  const SurveyScene({super.key, required this.onComplete});

  @override
  State<SurveyScene> createState() => _SurveySceneState();
}

class _SurveySceneState extends State<SurveyScene> {
  int _step = 0;
  bool _completed = false;
  bool _allAgreed = false;
  bool _showToast = false;

  void _onAgreeAllTap() {
    if (_step != 0) return;
    setState(() {
      _allAgreed = true;
      _step = 1;
    });
  }

  void _onSubmitTap() {
    if (_step != 1) return;
    setState(() {
      _showToast = true;
      _completed = true;
      _step = 2;
    });
    widget.onComplete();
  }

  String get _helperText {
    switch (_step) {
      case 0:
        return '[탭] "전체 동의"로 5개 항목을 한 번에 체크할 수 있어요';
      case 1:
        return '[탭] 제출하면 관리자가 검토합니다';
      default:
        return '🎉 설문 제출 완료. 헌혈일까지 대기하면 돼요';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TutorialPhoneFrame(
          child: Stack(
            children: [
              _buildSurveyView(),
              if (_showToast)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: const _SurveySubmittedToast(),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),
        TutorialHelperText(text: _helperText),
      ],
    );
  }

  Widget _buildSurveyView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const TutorialMockSubAppBar(title: '사전 설문 작성'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 헌혈 정보 헤더
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 14,
                      color: AppTheme.primaryBlue,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '초코 · 5/15 (월) 14:00',
                        style: AppTheme.bodySmallStyle.copyWith(
                          color: AppTheme.primaryBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 동의 5개
              Text(
                '필수 동의 항목',
                style: AppTheme.bodySmallStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              _checkLine('안내문을 정독했어요', _allAgreed),
              _checkLine('가족과 상의·공유했어요', _allAgreed),
              _checkLine('헌혈 전 충분히 휴식했어요', _allAgreed),
              _checkLine('협회 협력에 동의해요', _allAgreed),
              _checkLine('운영 방식을 이해했어요', _allAgreed),
              const SizedBox(height: 8),

              // 전체 동의 체크박스 (스텝 0 강조)
              HighlightTarget(
                isActive: !_completed && _step == 0,
                onTap: _onAgreeAllTap,
                borderRadius: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _allAgreed
                        ? AppTheme.success.withValues(alpha: 0.08)
                        : AppTheme.veryLightGray,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _allAgreed
                          ? AppTheme.success
                          : AppTheme.lightGray.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _allAgreed
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 18,
                        color: _allAgreed
                            ? AppTheme.success
                            : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '전체 동의',
                        style: AppTheme.bodySmallStyle.copyWith(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 설문 본문 (visual — 항목 일부만)
              Text(
                '설문 항목 (예시)',
                style: AppTheme.bodySmallStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              _surveyItem('병원 신청 이유'),
              const SizedBox(height: 4),
              _surveyItem('과거 병력'),
              const SizedBox(height: 4),
              _surveyItem('생활 환경 (실내/실외)'),
              const SizedBox(height: 4),
              _surveyItem('동반 반려동물 수'),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  '⋯ 외 다수',
                  style: AppTheme.bodySmallStyle.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 제출 버튼 (스텝 1 강조)
              HighlightTarget(
                isActive: !_completed && _step == 1,
                onTap: _onSubmitTap,
                child: Container(
                  width: double.infinity,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '제출하기',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _checkLine(String text, bool checked) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            checked ? Icons.check_circle : Icons.circle_outlined,
            size: 14,
            color: checked ? AppTheme.success : AppTheme.textSecondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: AppTheme.bodySmallStyle.copyWith(
                color: checked ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _surveyItem(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.lightGray.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.edit_note_outlined,
            size: 13,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: AppTheme.bodySmallStyle.copyWith(
                color: AppTheme.textPrimary,
                fontSize: 11,
              ),
            ),
          ),
          Text(
            '미작성',
            style: AppTheme.bodySmallStyle.copyWith(
              color: AppTheme.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _SurveySubmittedToast extends StatelessWidget {
  const _SurveySubmittedToast();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.success.withValues(alpha: 0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 18, color: AppTheme.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '설문이 제출됐어요',
              style: AppTheme.bodySmallStyle.copyWith(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
