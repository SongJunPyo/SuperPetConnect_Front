// lib/user/tutorial_screen.dart
// 사용자 튜토리얼 화면 — 신규 가입자가 승인 후 첫 진입 시 자동 표시 + 프로필에서 다시 보기 가능.
// 콘텐츠는 lib/models/tutorial_slide.dart::TutorialContent.userSlides 단일 원천.

import 'package:flutter/material.dart';
import '../models/tutorial_slide.dart';
import '../utils/app_theme.dart';

class TutorialScreen extends StatefulWidget {
  /// 튜토리얼 종료 시 (스킵/완료 모두) 호출되는 콜백.
  /// 자동 진입 시 플래그 저장용. 다시 보기에서는 null 전달 가능.
  final VoidCallback? onFinished;

  const TutorialScreen({super.key, this.onFinished});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<TutorialSlide> get _slides => TutorialContent.userSlides;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    widget.onFinished?.call();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 상단: 닫기(스킵) 버튼
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing16,
                    vertical: AppTheme.spacing12,
                  ),
                ),
                child: Text(
                  '건너뛰기',
                  style: AppTheme.bodyMediumStyle.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),

            // 슬라이드 영역
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                itemBuilder: (context, idx) =>
                    _SlideView(slide: _slides[idx]),
              ),
            ),

            // 페이지 인디케이터
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppTheme.spacing16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (idx) => _PageDot(active: idx == _currentPage),
                ),
              ),
            ),

            // 다음/시작하기 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing24,
                0,
                AppTheme.spacing24,
                AppTheme.spacing24,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                  child: Text(
                    isLastPage ? '시작하기' : '다음',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 슬라이드 1장의 본문.
class _SlideView extends StatelessWidget {
  final TutorialSlide slide;

  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 일러스트 자리 (placeholder: 둥근 사각형 + 큰 아이콘)
          _IllustrationPlaceholder(
            asset: slide.illustrationAsset,
            icon: slide.placeholderIcon,
          ),
          const SizedBox(height: AppTheme.spacing32),

          // 제목
          Text(
            slide.title,
            style: AppTheme.h2Style.copyWith(
              fontWeight: FontWeight.bold,
              height: 1.35,
            ),
          ),

          // 부제 (있는 경우)
          if (slide.subtitle != null) ...[
            const SizedBox(height: AppTheme.spacing12),
            Text(
              slide.subtitle!,
              style: AppTheme.bodyMediumStyle.copyWith(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],

          const SizedBox(height: AppTheme.spacing24),

          // 단계 리스트 (① ② ③ 자동 번호)
          ...List.generate(slide.steps.length, (idx) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
              child: _StepRow(
                index: idx + 1,
                text: slide.steps[idx],
              ),
            );
          }),

          // 강조 박스 (있는 경우)
          if (slide.highlight != null) ...[
            const SizedBox(height: AppTheme.spacing20),
            _HighlightBoxWidget(box: slide.highlight!),
          ],

          const SizedBox(height: AppTheme.spacing24),
        ],
      ),
    );
  }
}

class _IllustrationPlaceholder extends StatelessWidget {
  final String? asset;
  final IconData icon;

  const _IllustrationPlaceholder({this.asset, required this.icon});

  @override
  Widget build(BuildContext context) {
    if (asset != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        child: Image.asset(
          asset!,
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: AppTheme.veryLightGray,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
      ),
      child: Icon(
        icon,
        size: 80,
        color: AppTheme.primaryBlue.withValues(alpha: 0.6),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final int index;
  final String text;

  const _StepRow({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacing12),
        Expanded(
          child: Text(
            text,
            style: AppTheme.bodyMediumStyle.copyWith(
              color: AppTheme.textPrimary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _HighlightBoxWidget extends StatelessWidget {
  final HighlightBox box;

  const _HighlightBoxWidget({required this.box});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: box.accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(
          color: box.accentColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(box.icon, size: 18, color: box.accentColor),
              const SizedBox(width: AppTheme.spacing8),
              Text(
                box.title,
                style: AppTheme.bodyMediumStyle.copyWith(
                  color: box.accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          ...box.lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 8),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: box.accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      line,
                      style: AppTheme.bodySmallStyle.copyWith(
                        color: AppTheme.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageDot extends StatelessWidget {
  final bool active;

  const _PageDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: active ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? AppTheme.primaryBlue : AppTheme.lightGray,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
