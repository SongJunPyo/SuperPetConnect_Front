// lib/user/tutorial_screen.dart
// 사용자 튜토리얼 — 팝업(Dialog) 형태, 7 슬라이드.
//
// 슬라이드 0: 환영 (사용 가이드 + 로고)
// 슬라이드 1: 헌혈 신청 ① 게시판 진입 (3 step)
// 슬라이드 2: 헌혈 신청 ② 폼 작성 (3 step)
// 슬라이드 3: 신청 후 흐름 (자동 재생, 0 step)
// 슬라이드 4: 사전 설문 작성 (2 step)
// 슬라이드 5: 반려동물 등록 (3 step)
// 슬라이드 6: 반려동물 삭제 (3 step)

import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/tutorial/scene_welcome.dart';
import '../widgets/tutorial/scene_donation_board.dart';
import '../widgets/tutorial/scene_donation_form.dart';
import '../widgets/tutorial/scene_application_timeline.dart';
import '../widgets/tutorial/scene_survey.dart';
import '../widgets/tutorial/scene_pet_register.dart';
import '../widgets/tutorial/scene_pet_delete.dart';

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

  static const int _totalPages = 7;

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
                  _SlideShellPlain(
                    child: WelcomeScene(onComplete: _markCurrentComplete),
                  ),
                  _Slide1BoardEntry(onComplete: _markCurrentComplete),
                  _Slide2Form(onComplete: _markCurrentComplete),
                  _Slide3Timeline(onComplete: _markCurrentComplete),
                  _Slide4Survey(onComplete: _markCurrentComplete),
                  _Slide5PetRegister(onComplete: _markCurrentComplete),
                  _Slide6PetDelete(onComplete: _markCurrentComplete),
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
// 헤더 — 페이지 닷 + 닫기
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
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                totalPages,
                (idx) => _PageDot(active: idx == currentPage),
              ),
            ),
          ),
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
      margin: const EdgeInsets.only(right: 5),
      width: active ? 18 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: active ? AppTheme.primaryBlue : AppTheme.lightGray,
        borderRadius: BorderRadius.circular(3),
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
      subtitle: '신청이 완료되면 관리자가 검토 후 선정 여부를 결정해요',
      scene: DonationFormScene(onComplete: onComplete),
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
          '선정 후 D-2 23:55까지 사전 설문 미작성 시 신청이 자동 종결돼요',
        ],
      ),
    );
  }
}

// ============================================================
// 슬라이드 4 — 사전 설문 작성
// ============================================================
class _Slide4Survey extends StatelessWidget {
  final VoidCallback onComplete;
  const _Slide4Survey({required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return _SlideShell(
      title: '사전 설문 작성\n(선정 후 필수)',
      subtitle: '동의 5개 + 펫/병원 관련 설문 항목들. 헌혈일 D-2 23:55까지 제출하면 돼요',
      scene: SurveyScene(onComplete: onComplete),
    );
  }
}

// ============================================================
// 슬라이드 5 — 반려동물 등록
// ============================================================
class _Slide5PetRegister extends StatelessWidget {
  final VoidCallback onComplete;
  const _Slide5PetRegister({required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return _SlideShell(
      title: '반려동물 등록',
      subtitle: '대시보드 → 반려동물 관리 → [+] → 정보 입력 → 등록',
      scene: PetRegisterScene(onComplete: onComplete),
      highlight: const _HighlightWarning(
        title: '등록 후',
        lines: [
          '관리자 승인 후 헌혈 신청에 사용 가능',
          '체중·혈액형·접종 등 자격 검증 영향 항목 수정 시\n재심사 진입',
        ],
      ),
    );
  }
}

// ============================================================
// 슬라이드 6 — 반려동물 삭제
// ============================================================
class _Slide6PetDelete extends StatelessWidget {
  final VoidCallback onComplete;
  const _Slide6PetDelete({required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return _SlideShell(
      title: '반려동물 삭제',
      subtitle: '카드 ⋮ 메뉴 → "삭제" → 확인 다이얼로그',
      scene: PetDeleteScene(onComplete: onComplete),
    );
  }
}

// ============================================================
// 공용 — 슬라이드 셸 (scene + 옵션 highlight)
// ============================================================
class _SlideShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget scene;
  final Widget? highlight;

  const _SlideShell({
    required this.title,
    this.subtitle,
    required this.scene,
    this.highlight,
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
          if (highlight != null) ...[
            const SizedBox(height: AppTheme.spacing16),
            highlight!,
          ],
        ],
      ),
    );
  }
}

/// 환영 페이지(슬라이드 0) 전용 — 폰 프레임 / 미니어처 없는 단순 셸.
class _SlideShellPlain extends StatelessWidget {
  final Widget child;

  const _SlideShellPlain({required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: child,
    );
  }
}

// ============================================================
// 정보 / 주의 박스
// ============================================================
class _HighlightWarning extends StatelessWidget {
  final String title;
  final List<String> lines;

  const _HighlightWarning({required this.title, required this.lines});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: AppTheme.warning,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: AppTheme.bodySmallStyle.copyWith(
                  color: AppTheme.warning,
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
                        color: AppTheme.warning,
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
