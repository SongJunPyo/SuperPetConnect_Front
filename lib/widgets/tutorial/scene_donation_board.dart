// lib/widgets/tutorial/scene_donation_board.dart
// 슬라이드 1 — 실제 대시보드 → 헌혈 게시판 list 흐름.
//
// 스텝 0: 대시보드 모형 + "헌혈 모집" 카드 강조 → 탭 → 게시판 list로 전환
// 스텝 1: 게시판 list + 첫 게시글 강조 → 탭 → 완료
//
// 대시보드 모형은 실제 UserDashboard의 핵심 요소를 미니어처로 재현
// (AppBar, 인사말, 헌혈 모집 카드, 탭 헤더). 가데이터.

import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'highlight_target.dart';

class DonationBoardScene extends StatefulWidget {
  final VoidCallback onComplete;

  const DonationBoardScene({super.key, required this.onComplete});

  @override
  State<DonationBoardScene> createState() => _DonationBoardSceneState();
}

class _DonationBoardSceneState extends State<DonationBoardScene> {
  int _step = 0;
  bool _completed = false;

  void _onDashboardCardTap() {
    if (_step != 0) return;
    setState(() => _step = 1);
  }

  void _onPostTap() {
    if (_step != 1) return;
    setState(() {
      _step = 2;
      _completed = true;
    });
    widget.onComplete();
  }

  String get _helperText {
    if (_step == 0) return '"헌혈 모집" 카드를 탭하면 게시판으로 이동해요';
    if (_step == 1) return '관심 있는 게시글을 탭해보세요';
    return '게시글을 골라 안내문 → 시간대 선택 → 신청 순서로 진행해요';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 미니어처 화면 (실제 phone screen 느낌으로 외곽 그림자 + 둥근 모서리)
        _PhoneFrame(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _step == 0
                ? _DashboardMock(
                    key: const ValueKey('dashboard'),
                    isCardActive: !_completed && _step == 0,
                    onCardTap: _onDashboardCardTap,
                  )
                : _BoardListMock(
                    key: const ValueKey('boardList'),
                    isFirstPostActive: !_completed && _step == 1,
                    onFirstPostTap: _onPostTap,
                  ),
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),
        TutorialHelperText(text: _helperText),
      ],
    );
  }
}

// ====================================================================
// 폰 화면 프레임 — 미니어처 느낌
// ====================================================================
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

// ====================================================================
// 대시보드 미니어처 (스텝 0)
// ====================================================================
class _DashboardMock extends StatelessWidget {
  final bool isCardActive;
  final VoidCallback onCardTap;

  const _DashboardMock({
    super.key,
    required this.isCardActive,
    required this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // AppBar 모형
        const _MockAppBar(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '안녕하세요,',
                style: AppTheme.bodyMediumStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                ),
              ),
              Text(
                '사용자 님!',
                style: AppTheme.bodyMediumStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '2026년 5월 6일 (수) 14:30',
                style: AppTheme.bodySmallStyle.copyWith(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),

              // 헌혈 모집 카드 (강조 대상)
              HighlightTarget(
                isActive: isCardActive,
                onTap: onCardTap,
                child: _DonationEntryCard(),
              ),
              const SizedBox(height: AppTheme.spacing12),

              // 탭 헤더 모형
              const _MockTabHeader(),
              const SizedBox(height: AppTheme.spacing8),

              // 탭 컨텐츠 list 모형
              const _MockTabContent(),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonationEntryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.red.shade600,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.bloodtype_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '헌혈 모집',
                  style: AppTheme.bodyMediumStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '진행 중인 헌혈 요청 모아보기',
                  style: AppTheme.bodySmallStyle.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// 게시판 list 미니어처 (스텝 1)
// ====================================================================
class _BoardListMock extends StatelessWidget {
  final bool isFirstPostActive;
  final VoidCallback onFirstPostTap;

  const _BoardListMock({
    super.key,
    required this.isFirstPostActive,
    required this.onFirstPostTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 헌혈 게시판 헤더 (간단한 AppBar 형태)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                '헌혈 게시판',
                style: AppTheme.bodyMediumStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              HighlightTarget(
                isActive: isFirstPostActive,
                onTap: onFirstPostTap,
                child: const _PostListCard(
                  urgent: true,
                  title: '강아지 헌혈 필요',
                  hospital: '행복동물병원',
                  distance: '5km',
                ),
              ),
              const SizedBox(height: 10),
              const _PostListCard(
                urgent: false,
                title: '정기 헌혈 모집',
                hospital: '사랑동물병원',
                distance: '12km',
              ),
              const SizedBox(height: 10),
              const _PostListCard(
                urgent: false,
                title: '강아지 정기 헌혈',
                hospital: '연세동물병원',
                distance: '8km',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PostListCard extends StatelessWidget {
  final bool urgent;
  final String title;
  final String hospital;
  final String distance;

  const _PostListCard({
    required this.urgent,
    required this.title,
    required this.hospital,
    required this.distance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightGray.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.bloodtype_outlined,
            color: urgent ? AppTheme.error : AppTheme.primaryBlue,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (urgent) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.error,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '긴급',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        title,
                        style: AppTheme.bodySmallStyle.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$hospital · $distance',
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
    );
  }
}

// ====================================================================
// 공용 — AppBar / 탭 헤더 / 탭 컨텐츠 모형
// ====================================================================
class _MockAppBar extends StatelessWidget {
  const _MockAppBar();

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
          Container(
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
          ),
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
}

class _MockTabHeader extends StatelessWidget {
  const _MockTabHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _tab('공지사항', active: true),
        const SizedBox(width: 16),
        _tab('칼럼', active: false),
      ],
    );
  }

  Widget _tab(String text, {required bool active}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: TextStyle(
            color: active ? AppTheme.textPrimary : AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 32,
          height: 2,
          color: active ? AppTheme.primaryBlue : Colors.transparent,
        ),
      ],
    );
  }
}

class _MockTabContent extends StatelessWidget {
  const _MockTabContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row('시스템 점검 안내', '2026.05.05'),
        const SizedBox(height: 6),
        _row('헌혈견 협회 공지사항', '2026.05.04'),
        const SizedBox(height: 6),
        _row('5월 헌혈 캠페인', '2026.05.01'),
      ],
    );
  }

  Widget _row(String title, String date) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTheme.bodySmallStyle.copyWith(
              color: AppTheme.textPrimary,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          date,
          style: AppTheme.bodySmallStyle.copyWith(
            color: AppTheme.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
