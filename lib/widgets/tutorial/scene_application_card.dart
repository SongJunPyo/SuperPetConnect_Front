// lib/widgets/tutorial/scene_application_card.dart
// 슬라이드 2 — 내 신청 카드 미니 모형. 4스텝 시퀀스로 상태 전이 + 사전 설문 작성.
//
// 스텝 1: 대기 chip → 선정 (설문 행 펼쳐짐)
// 스텝 2: 설문 행 → 작성 완료 표시
// 스텝 3: 선정 chip → 완료대기
// 스텝 4: 완료대기 chip → 완료 + onComplete

import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'spotlight_stage.dart';

enum _ApplicationStatus { waiting, approved, pendingCompletion, completed }

class ApplicationCardScene extends StatefulWidget {
  final VoidCallback onComplete;

  const ApplicationCardScene({super.key, required this.onComplete});

  @override
  State<ApplicationCardScene> createState() => _ApplicationCardSceneState();
}

class _ApplicationCardSceneState extends State<ApplicationCardScene> {
  final GlobalKey _chipKey = GlobalKey();
  final GlobalKey _surveyKey = GlobalKey();

  _ApplicationStatus _status = _ApplicationStatus.waiting;
  bool _surveyDone = false;
  int _stepIndex = 0;
  bool _completed = false;

  void _advance() {
    if (_completed) return;
    setState(() {
      switch (_stepIndex) {
        case 0:
          _status = _ApplicationStatus.approved;
          _stepIndex = 1;
          break;
        case 1:
          _surveyDone = true;
          _stepIndex = 2;
          break;
        case 2:
          _status = _ApplicationStatus.pendingCompletion;
          _stepIndex = 3;
          break;
        case 3:
          _status = _ApplicationStatus.completed;
          _stepIndex = 4;
          _completed = true;
          break;
      }
    });
    if (_completed) {
      widget.onComplete();
    }
  }

  List<SpotlightStep> _buildSteps() {
    if (_completed) return const [];
    switch (_stepIndex) {
      case 0:
        return [
          SpotlightStep(
            targetKey: _chipKey,
            tooltip: '병원이 신청자를 검토 중이에요. 탭해보세요',
            onTap: _advance,
          ),
        ];
      case 1:
        return [
          SpotlightStep(
            targetKey: _surveyKey,
            tooltip: '선정됐어요! D-2까지 사전 설문 작성이 필수예요',
            onTap: _advance,
          ),
        ];
      case 2:
        return [
          SpotlightStep(
            targetKey: _chipKey,
            tooltip: '헌혈일에 방문하면 병원이 1차 완료 처리해요',
            onTap: _advance,
          ),
        ];
      case 3:
        return [
          SpotlightStep(
            targetKey: _chipKey,
            tooltip: '관리자 최종 승인 후 정식 완료돼요',
            onTap: _advance,
          ),
        ];
      default:
        return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return SpotlightStage(
      steps: _buildSteps(),
      onComplete: () {},
      child: _buildCard(),
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: AppTheme.lightGray.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🐾', style: TextStyle(fontSize: 24)),
              const SizedBox(width: AppTheme.spacing8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '초코',
                      style: AppTheme.bodyMediumStyle.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '행복동물병원 · 5/15 14:00',
                      style: AppTheme.bodySmallStyle.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          // 상태 칩
          Container(
            key: _chipKey,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: _statusColor().withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _statusColor().withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_statusIcon(), size: 14, color: _statusColor()),
                const SizedBox(width: 6),
                Text(
                  _statusLabel(),
                  style: AppTheme.bodySmallStyle.copyWith(
                    color: _statusColor(),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // 사전 설문 행 (선정 이후만 노출)
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: _showSurveyRow()
                ? Padding(
                    padding: const EdgeInsets.only(top: AppTheme.spacing12),
                    child: Container(
                      key: _surveyKey,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing12,
                        vertical: AppTheme.spacing12,
                      ),
                      decoration: BoxDecoration(
                        color: _surveyDone
                            ? AppTheme.success.withValues(alpha: 0.1)
                            : AppTheme.warning.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radius12),
                        border: Border.all(
                          color: _surveyDone
                              ? AppTheme.success.withValues(alpha: 0.4)
                              : AppTheme.warning.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _surveyDone
                                ? Icons.check_circle
                                : Icons.assignment_outlined,
                            size: 18,
                            color: _surveyDone
                                ? AppTheme.success
                                : AppTheme.warning,
                          ),
                          const SizedBox(width: AppTheme.spacing8),
                          Expanded(
                            child: Text(
                              _surveyDone
                                  ? '사전 설문 작성 완료'
                                  : '사전 설문 작성 필요',
                              style: AppTheme.bodySmallStyle.copyWith(
                                color: _surveyDone
                                    ? AppTheme.success
                                    : AppTheme.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  bool _showSurveyRow() {
    return _status == _ApplicationStatus.approved ||
        _status == _ApplicationStatus.pendingCompletion ||
        _status == _ApplicationStatus.completed;
  }

  String _statusLabel() {
    switch (_status) {
      case _ApplicationStatus.waiting:
        return '대기 중';
      case _ApplicationStatus.approved:
        return '선정';
      case _ApplicationStatus.pendingCompletion:
        return '완료 대기';
      case _ApplicationStatus.completed:
        return '완료 🎉';
    }
  }

  Color _statusColor() {
    switch (_status) {
      case _ApplicationStatus.waiting:
        return AppTheme.textSecondary;
      case _ApplicationStatus.approved:
        return AppTheme.primaryBlue;
      case _ApplicationStatus.pendingCompletion:
        return AppTheme.warning;
      case _ApplicationStatus.completed:
        return AppTheme.success;
    }
  }

  IconData _statusIcon() {
    switch (_status) {
      case _ApplicationStatus.waiting:
        return Icons.hourglass_top_outlined;
      case _ApplicationStatus.approved:
        return Icons.check_circle_outline;
      case _ApplicationStatus.pendingCompletion:
        return Icons.pending_outlined;
      case _ApplicationStatus.completed:
        return Icons.celebration_outlined;
    }
  }
}
