// lib/user/tutorial_screen.dart
// 사용자 튜토리얼 — 팝업(Dialog) 형태, 4 슬라이드.
//
// 슬라이드 1: 헌혈 신청 ① 게시판 진입 (3 step 인터랙티브)
// 슬라이드 2: 헌혈 신청 ② 폼 작성 (3 step 인터랙티브)
// 슬라이드 3: 신청 후 흐름 (정보 시각화, 자동 재생, 0 step)
// 슬라이드 4: 반려동물 추가/삭제 (3 step 인터랙티브)

import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/tutorial/scene_donation_board.dart';
import '../widgets/tutorial/scene_donation_form.dart';
import '../widgets/tutorial/scene_application_timeline.dart';
import '../widgets/tutorial/scene_pet_management.dart';

class TutorialScreen extends StatefulWidget {
  /// 튜토리얼 종료 시 (스킵/완료 모두) 호출.
  final VoidCallback? onFinished;

  const TutorialScreen({super.key, this.onFinished});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final Set<int> _completedPages = <int>{};

  static const int _totalPages = 4;

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
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _totalPages - 1;
    final canAdvance = _completedPages.contains(_currentPage);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius16),
      ),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            _Header(
              currentPage: _currentPage,
              totalPages: _totalPages,
              onClose: _finish,
            ),
            const Divider(height: 1, thickness: 1),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                children: [
                  _Slide1BoardEntry(onComplete: _markCurrentComplete),
                  _Slide2Form(onComplete: _markCurrentComplete),
                  _Slide3Timeline(onComplete: _markCurrentComplete),
                  _Slide4PetManagement(onComplete: _markCurrentComplete),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing16,
                AppTheme.spacing12,
                AppTheme.spacing16,
                AppTheme.spacing16,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
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
                      fontSize: 15,
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
// 헤더
// ============================================================
class _Header extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback onClose;

  const _Header({
    required this.currentPage,
    required this.totalPages,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing12,
        AppTheme.spacing8,
        AppTheme.spacing12,
      ),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              totalPages,
              (idx) => _PageDot(active: idx == currentPage),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onClose,
            icon: Icon(
              Icons.close,
              color: AppTheme.textSecondary,
              size: 22,
            ),
            visualDensity: VisualDensity.compact,
            tooltip: '건너뛰기',
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
      margin: const EdgeInsets.only(right: 6),
      width: active ? 22 : 7,
      height: 7,
      decoration: BoxDecoration(
        color: active ? AppTheme.primaryBlue : AppTheme.lightGray,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ============================================================
// 슬라이드 1 — 헌혈 신청 ① 게시판 진입
// ============================================================
class _Slide1BoardEntry extends StatelessWidget {
  final VoidCallback onComplete;
  const _Slide1BoardEntry({required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return _SlideShell(
      title: '헌혈 신청 ①\n게시판에서 시간대를 선택해요',
      subtitle: '대시보드 → 헌혈 모집 → 게시글 → 시간대 선택',
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
// 슬라이드 2 — 헌혈 신청 ② 폼 작성
// ============================================================
class _Slide2Form extends StatelessWidget {
  final VoidCallback onComplete;
  const _Slide2Form({required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return _SlideShell(
      title: '헌혈 신청 ②\n반려동물 선택 + 안내사항 동의',
      subtitle: '시간대를 선택하면 신청 폼이 열려요',
      scene: DonationFormScene(onComplete: onComplete),
      highlight: const _HighlightInfo(
        title: '신청 후',
        lines: [
          '관리자가 신청자를 검토 후 선정 여부를 결정해요',
          '선정되면 사전 설문 작성 단계로 진행돼요 (다음 슬라이드)',
        ],
      ),
    );
  }
}

// ============================================================
// 슬라이드 3 — 신청 후 흐름
// ============================================================
class _Slide3Timeline extends StatelessWidget {
  final VoidCallback onComplete;
  const _Slide3Timeline({required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return _SlideShell(
      title: '신청 후 진행 상태를\n확인해요',
      subtitle: '대부분의 단계는 관리자/병원이 처리. 사용자가 직접 하는 건 사전 설문 작성 한 번',
      scene: ApplicationTimelineScene(onComplete: onComplete),
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
// 슬라이드 4 — 반려동물 관리
// ============================================================
class _Slide4PetManagement extends StatelessWidget {
  final VoidCallback onComplete;
  const _Slide4PetManagement({required this.onComplete});

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
// 공용 슬라이드 셸
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
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing12,
        AppTheme.spacing16,
        AppTheme.spacing16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.h3Style.copyWith(
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
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
