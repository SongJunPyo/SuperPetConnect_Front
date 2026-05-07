// lib/widgets/tutorial/scene_application_timeline.dart
// 슬라이드 3 — 신청 후 흐름 (정보 시각화).
//
// 사용자 탭 X. 진입 시 자동 재생으로 4단계 타임라인이 1.4초 간격으로 채워짐.
// 모든 단계 도달 시 onComplete 호출 + [🔄 다시 재생] 버튼 노출.
//
// 핵심 메시지: 대부분의 상태 전이는 관리자/병원이 처리.
// 사용자 능동 액션은 "사전 설문 작성" 단 하나.

import 'dart:async';
import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'tutorial_phone_frame.dart';

class ApplicationTimelineScene extends StatefulWidget {
  final VoidCallback onComplete;

  const ApplicationTimelineScene({super.key, required this.onComplete});

  @override
  State<ApplicationTimelineScene> createState() =>
      _ApplicationTimelineSceneState();
}

class _ApplicationTimelineSceneState extends State<ApplicationTimelineScene> {
  /// 현재까지 채워진 단계 수 (0 → 1 → 2 → 3 → 4).
  int _filledStages = 0;
  Timer? _timer;
  bool _completedFiredOnce = false;

  static const int _totalStages = 4;
  static const Duration _stageInterval = Duration(milliseconds: 1400);

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    setState(() => _filledStages = 0);
    _timer = Timer.periodic(_stageInterval, (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _filledStages = (_filledStages + 1).clamp(0, _totalStages));
      if (_filledStages >= _totalStages) {
        t.cancel();
        if (!_completedFiredOnce) {
          _completedFiredOnce = true;
          widget.onComplete();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TutorialPhoneFrame(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TutorialMockSubAppBar(title: '내 헌혈 신청'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _stage(
                      idx: 0,
                      label: '대기 중',
                      actor: '관리자가 신청자 검토 중',
                      userAction: '취소만 가능',
                      color: AppTheme.primaryBlue,
                      icon: Icons.hourglass_top_outlined,
                    ),
                    _stage(
                      idx: 1,
                      label: '선정 ✓',
                      actor: '관리자가 선정 완료',
                      userAction: '📋 사전 설문 작성 (D-2 23:55까지 필수!)',
                      userActionHighlight: true,
                      color: AppTheme.success,
                      icon: Icons.check_circle_outline,
                    ),
                    _stage(
                      idx: 2,
                      label: '완료 대기',
                      actor: '헌혈 후 병원이 1차 완료 처리',
                      userAction: '별도 행동 없음',
                      color: AppTheme.warning,
                      icon: Icons.pending_outlined,
                    ),
                    _stage(
                      idx: 3,
                      label: '완료 🎉',
                      actor: '관리자 최종 승인',
                      userAction: '결과 확인',
                      isLast: true,
                      color: AppTheme.error,
                      icon: Icons.celebration_outlined,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),
        // 다시 재생 버튼 (모든 단계 채워진 후 노출)
        if (_filledStages >= _totalStages)
          Center(
            child: TextButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('다시 재생'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _stage({
    required int idx,
    required String label,
    required String actor,
    required String userAction,
    required Color color,
    required IconData icon,
    bool userActionHighlight = false,
    bool isLast = false,
  }) {
    final filled = idx < _filledStages;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 350),
      opacity: filled ? 1.0 : 0.25,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 좌측 마커 + 세로선
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: filled ? color : AppTheme.lightGray,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 13, color: Colors.white),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: filled ? color.withValues(alpha: 0.3) : AppTheme.lightGray,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // 우측 정보
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTheme.bodyMediumStyle.copyWith(
                        fontWeight: FontWeight.bold,
                        color: filled ? color : AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      actor,
                      style: AppTheme.bodySmallStyle.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: userActionHighlight
                            ? AppTheme.error.withValues(alpha: 0.08)
                            : AppTheme.veryLightGray,
                        borderRadius: BorderRadius.circular(6),
                        border: userActionHighlight
                            ? Border.all(
                                color: AppTheme.error.withValues(alpha: 0.4),
                              )
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '👤 ',
                            style: TextStyle(fontSize: 10),
                          ),
                          Flexible(
                            child: Text(
                              userAction,
                              style: AppTheme.bodySmallStyle.copyWith(
                                color: userActionHighlight
                                    ? AppTheme.error
                                    : AppTheme.textPrimary,
                                fontSize: 10,
                                fontWeight: userActionHighlight
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
