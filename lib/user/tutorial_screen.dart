// lib/user/tutorial_screen.dart
// 사용자 튜토리얼 — 3장 인터랙티브 슬라이드.
//
// 각 슬라이드 = 상단 텍스트 + 가데이터 모형 + 스포트라이트 시퀀스 + 정보/주의 박스.
// 시퀀스 완료 전에는 [다음] 버튼 비활성. 완료 시 활성화.

import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/tutorial/scene_donation_board.dart';
import '../widgets/tutorial/scene_application_card.dart';
import '../widgets/tutorial/scene_pet_management.dart';

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
  final Set<int> _completedPages = <int>{};

  static const int _totalPages = 3;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _markCurrentComplete() {
    setState(() => _completedPages.add(_currentPage));
  }

  void _onNext() {
    if (!_completedPages.contains(_currentPage)) return;
    if (_currentPage < _totalPages - 1) {
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
    final isLastPage = _currentPage == _totalPages - 1;
    final canAdvance = _completedPages.contains(_currentPage);

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
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                children: [
                  _Slide1Donation(onComplete: _markCurrentComplete),
                  _Slide2Application(onComplete: _markCurrentComplete),
                  _Slide3PetManagement(onComplete: _markCurrentComplete),
                ],
              ),
            ),

            // 페이지 인디케이터
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppTheme.spacing12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _totalPages,
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
                AppTheme.spacing16,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: canAdvance ? _onNext : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.lightGray,
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                  child: Text(
                    canAdvance
                        ? (isLastPage ? '시작하기' : '다음')
                        : '안내에 따라 탭해주세요',
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

// ============================================================
// 슬라이드 1 — 헌혈 신청
// ============================================================
class _Slide1Donation extends StatelessWidget {
  final VoidCallback onComplete;

  const _Slide1Donation({required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return _SlideShell(
      title: '헌혈이 필요한 친구들에게\n도움을 주세요',
      subtitle: '헌혈 게시판에서 우리 아이가 도울 수 있는 글을 찾아보세요',
      scene: DonationBoardScene(onComplete: onComplete),
      highlight: const _HighlightInfo(
        title: '헌혈 자격 조건',
        lines: [
          '체중 20kg 이상 (강아지 기준)',
          '직전 헌혈 후 180일 경과',
          '임신·출산 후 12개월 경과',
          '종합백신 24개월 이내 / 항체 12개월',
          '예방약 3개월 이내 복용',
        ],
      ),
    );
  }
}

// ============================================================
// 슬라이드 2 — 신청 후 흐름
// ============================================================
class _Slide2Application extends StatelessWidget {
  final VoidCallback onComplete;

  const _Slide2Application({required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return _SlideShell(
      title: '신청 후 진행 상태를\n확인해요',
      subtitle: '대기 → 선정 → 사전 설문 → 헌혈 → 완료 순서로 진행돼요',
      scene: ApplicationCardScene(onComplete: onComplete),
      highlight: const _HighlightWarning(
        title: '꼭 확인해주세요',
        lines: [
          '신청 취소는 "대기" 상태에서만 가능',
          '선정 후 D-2 23:55까지 사전 설문 미작성 시\n신청이 자동 종결돼요',
        ],
      ),
    );
  }
}

// ============================================================
// 슬라이드 3 — 반려동물 관리
// ============================================================
class _Slide3PetManagement extends StatelessWidget {
  final VoidCallback onComplete;

  const _Slide3PetManagement({required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return _SlideShell(
      title: '여러 마리 등록하고\n관리할 수 있어요',
      subtitle: '한 계정에 여러 반려동물을 등록할 수 있어요',
      scene: PetManagementScene(onComplete: onComplete),
      highlight: const _HighlightWarning(
        title: '정보 수정 시 주의',
        lines: [
          '체중·혈액형·임신/출산·중성화·예방접종 등\n자격 검증 영향 항목 수정 시 재심사 진입',
          '백신·항체·예방약 일자, 외부 헌혈 횟수는\n재심사 없이 즉시 반영',
        ],
      ),
    );
  }
}

// ============================================================
// 공용 슬라이드 셸 — 제목 + scene + highlight 박스
// ============================================================
class _SlideShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget scene;
  final Widget highlight;

  const _SlideShell({
    required this.title,
    this.subtitle,
    required this.scene,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.h2Style.copyWith(
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppTheme.spacing8),
            Text(
              subtitle!,
              style: AppTheme.bodySmallStyle.copyWith(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: AppTheme.spacing16),
          scene,
          const SizedBox(height: AppTheme.spacing16),
          highlight,
        ],
      ),
    );
  }
}

// ============================================================
// 정보 / 주의 박스
// ============================================================
class _HighlightInfo extends StatelessWidget {
  final String title;
  final List<String> lines;

  const _HighlightInfo({required this.title, required this.lines});

  @override
  Widget build(BuildContext context) {
    return _HighlightBox(
      icon: Icons.lightbulb_outline,
      color: AppTheme.primaryBlue,
      title: title,
      lines: lines,
    );
  }
}

class _HighlightWarning extends StatelessWidget {
  final String title;
  final List<String> lines;

  const _HighlightWarning({required this.title, required this.lines});

  @override
  Widget build(BuildContext context) {
    return _HighlightBox(
      icon: Icons.warning_amber_rounded,
      color: AppTheme.warning,
      title: title,
      lines: lines,
    );
  }
}

class _HighlightBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final List<String> lines;

  const _HighlightBox({
    required this.icon,
    required this.color,
    required this.title,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: AppTheme.bodySmallStyle.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing8),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 6),
                    child: Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      line,
                      style: AppTheme.bodySmallStyle.copyWith(
                        color: AppTheme.textPrimary,
                        height: 1.45,
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
