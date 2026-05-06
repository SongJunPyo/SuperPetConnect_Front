// lib/widgets/tutorial/tutorial_phone_frame.dart
// 튜토리얼 미니어처 화면의 공용 컴포넌트.
// - TutorialPhoneFrame: 폰 화면 외곽 (rounded + 그림자)
// - TutorialMockAppBar: 대시보드 AppBar 모형 (알림/반려동물 관리/프로필)
// - TutorialMockSubAppBar: 일반 화면 AppBar 모형 (← 뒤로가기 + 제목)

import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

/// 폰 화면 외곽 프레임.
class TutorialPhoneFrame extends StatelessWidget {
  final Widget child;

  const TutorialPhoneFrame({super.key, required this.child});

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

/// 대시보드용 AppBar 모형. 알림 / 반려동물 관리 / 프로필 3개 액션.
/// petButton에 widget을 주입하면 강조 wrap 가능.
class TutorialMockAppBar extends StatelessWidget {
  /// "반려동물 관리" 영역에 들어갈 위젯. null이면 기본 모양.
  final Widget? petButton;

  const TutorialMockAppBar({super.key, this.petButton});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.lightGray)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.notifications_none,
            size: 20,
            color: AppTheme.textPrimary,
          ),
          const SizedBox(width: 4),
          petButton ?? _defaultPetButton(),
          const Spacer(),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.veryLightGray,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_outline,
              size: 18,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultPetButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pets, size: 16, color: AppTheme.textPrimary),
          const SizedBox(width: 4),
          Text(
            '반려동물 관리',
            style: AppTheme.bodySmallStyle.copyWith(
              color: AppTheme.textPrimary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// 서브 화면 AppBar 모형 — 뒤로가기 + 제목.
class TutorialMockSubAppBar extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const TutorialMockSubAppBar({
    super.key,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.lightGray)),
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
            title,
            style: AppTheme.bodyMediumStyle.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
              fontSize: 15,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
