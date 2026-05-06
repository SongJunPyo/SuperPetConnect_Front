// lib/widgets/tutorial/scene_welcome.dart
// 슬라이드 0 — 환영 페이지.
//
// 한국헌혈견협회 로고 + "사용 가이드" 제목.
// 인터랙션 없음. 진입 시 즉시 onComplete 호출 → [다음] 활성.

import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class WelcomeScene extends StatefulWidget {
  final VoidCallback onComplete;

  const WelcomeScene({super.key, required this.onComplete});

  @override
  State<WelcomeScene> createState() => _WelcomeSceneState();
}

class _WelcomeSceneState extends State<WelcomeScene> {
  @override
  void initState() {
    super.initState();
    // 환영 페이지는 단순 정보 — 진입 즉시 완료 처리해서 [다음] 버튼 활성.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing24,
        vertical: AppTheme.spacing32,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 로고
          Image.asset(
            'lib/images/한국헌혈견협회 로고.png',
            width: 160,
            height: 160,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: AppTheme.spacing32),
          Text(
            '사용 가이드',
            textAlign: TextAlign.center,
            style: AppTheme.h1Style.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            'Super Pet Connect를 처음 사용하시나요?\n주요 기능을 안내해 드릴게요.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMediumStyle.copyWith(
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppTheme.spacing32),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: AppTheme.spacing12,
            ),
            decoration: BoxDecoration(
              color: AppTheme.veryLightGray,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 18,
                  color: AppTheme.primaryBlue,
                ),
                const SizedBox(width: AppTheme.spacing8),
                Flexible(
                  child: Text(
                    '안내에 따라 화면을 직접 탭해보며 익혀보세요',
                    style: AppTheme.bodySmallStyle.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
