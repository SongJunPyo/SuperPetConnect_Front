// lib/widgets/tutorial/scene_application_card.dart
// 슬라이드 2 — 내 신청 화면 미니어처. 4스텝 시퀀스로 상태 전이 + 사전 설문.
//
// 스텝 0: 대기 chip → 선정 (설문 행 펼쳐짐)
// 스텝 1: 설문 행 → 작성 완료 표시
// 스텝 2: 선정 chip → 완료대기
// 스텝 3: 완료대기 chip → 완료 + onComplete

import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'highlight_target.dart';

enum _ApplicationStatus { waiting, approved, pendingCompletion, completed }

class ApplicationCardScene extends StatefulWidget {
  final VoidCallback onComplete;

  const ApplicationCardScene({super.key, required this.onComplete});

  @override
  State<ApplicationCardScene> createState() => _ApplicationCardSceneState();
}

class _ApplicationCardSceneState extends State<ApplicationCardScene> {
  _ApplicationStatus _status = _ApplicationStatus.waiting;
  bool _surveyDone = false;
  int _step = 0;
  bool _completed = false;

  void _advance() {
    if (_completed) return;
    setState(() {
      switch (_step) {
        case 0:
          _status = _ApplicationStatus.approved;
          _step = 1;
          break;
        case 1:
          _surveyDone = true;
          _step = 2;
          break;
        case 2:
          _status = _ApplicationStatus.pendingCompletion;
          _step = 3;
          break;
        case 3:
          _status = _ApplicationStatus.completed;
          _step = 4;
          _completed = true;
          break;
      }
    });
    if (_completed) widget.onComplete();
  }

  String get _helperText {
    if (_completed) return '🎉 완료! 헌혈이 정식으로 인정됐어요';
    switch (_step) {
      case 0:
        return '"대기 중" 칩을 탭해 선정 단계로 이동해보세요';
      case 1:
        return '"사전 설문 작성 필요" 영역을 탭해보세요 (D-2까지 필수)';
      case 2:
        return '"선정" 칩을 탭하면 헌혈 후 흐름으로 이동해요';
      case 3:
        return '"완료 대기" 칩을 탭하면 관리자 최종 승인 → 완료';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 미니어처 — 내 신청 화면
        _PhoneFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // AppBar 모형 - "내 신청"
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: AppTheme.lightGray),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_back_ios_new,
                      size: 16,
                      color: AppTheme.textPrimary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '내 헌혈 신청',
                      style: AppTheme.bodyMediumStyle.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              // 필터 chip 영역 (visual)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    _filterChip('전체', active: true),
                    const SizedBox(width: 8),
                    _filterChip('진행 중', active: false),
                    const SizedBox(width: 8),
                    _filterChip('완료', active: false),
                  ],
                ),
              ),
              // 신청 카드
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildApplicationCard(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),
        TutorialHelperText(text: _helperText),
      ],
    );
  }

  Widget _filterChip(String text, {required bool active}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? AppTheme.primaryBlue.withValues(alpha: 0.1)
            : AppTheme.veryLightGray,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: active ? AppTheme.primaryBlue : AppTheme.textSecondary,
          fontSize: 11,
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildApplicationCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightGray.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🐾', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '초코',
                      style: AppTheme.bodyMediumStyle.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '행복동물병원 · 5/15 14:00',
                      style: AppTheme.bodySmallStyle.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 상태 칩 (스텝 0/2/3에서 강조)
          Align(
            alignment: Alignment.centerLeft,
            child: HighlightTarget(
              isActive: !_completed && (_step == 0 || _step == 2 || _step == 3),
              onTap: _advance,
              borderRadius: 20,
              child: _statusChip(),
            ),
          ),
          // 사전 설문 행 (선정 이후만 노출, 스텝 1에서 강조)
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: _showSurveyRow()
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: HighlightTarget(
                      isActive: !_completed && _step == 1,
                      onTap: _advance,
                      child: _surveyRow(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _statusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _statusColor().withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _statusColor().withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(), size: 13, color: _statusColor()),
          const SizedBox(width: 5),
          Text(
            _statusLabel(),
            style: AppTheme.bodySmallStyle.copyWith(
              color: _statusColor(),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _surveyRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _surveyDone
            ? AppTheme.success.withValues(alpha: 0.1)
            : AppTheme.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _surveyDone
              ? AppTheme.success.withValues(alpha: 0.4)
              : AppTheme.warning.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _surveyDone ? Icons.check_circle : Icons.assignment_outlined,
            size: 16,
            color: _surveyDone ? AppTheme.success : AppTheme.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _surveyDone ? '사전 설문 작성 완료' : '사전 설문 작성 필요',
              style: AppTheme.bodySmallStyle.copyWith(
                color: _surveyDone ? AppTheme.success : AppTheme.warning,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
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

// 폰 화면 프레임 (slide 1과 동일 디자인 — 별도 export 안 하고 각 scene에 복사)
class _PhoneFrame extends StatelessWidget {
  final Widget child;

  const _PhoneFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.lightGray, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: child,
      ),
    );
  }
}
