// lib/widgets/tutorial/scene_donation_board.dart
// 슬라이드 1 — 헌혈 신청 ① 게시판 진입.
//
// 스텝 0: 대시보드 (헌혈 모집 + 헌혈 이력 + 공지/칼럼) → "헌혈 모집" 카드 탭
// 스텝 1: 헌혈 게시판 list (정기/긴급 뱃지 + 제목 + 작성일) → 첫 게시글 탭
// 스텝 2: 자세한 바텀시트 (병원 + 환자 정보 + 헌혈 예정일 + 시간대 list) → 첫 시간대 탭

import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'highlight_target.dart';
import 'tutorial_phone_frame.dart';

class DonationBoardScene extends StatefulWidget {
  final VoidCallback onComplete;

  const DonationBoardScene({super.key, required this.onComplete});

  @override
  State<DonationBoardScene> createState() => _DonationBoardSceneState();
}

class _DonationBoardSceneState extends State<DonationBoardScene> {
  // step 0: dashboard 헌혈 모집 카드 → board list
  // step 1: board list 지역 아이콘 → region bottom sheet
  // step 2: region bottom sheet 지역 선택 → board list (시트 닫힘)
  // step 3: board list 첫 게시글 카드 → post detail bottom sheet
  // step 4: post detail bottom sheet 첫 시간대 → 완료
  int _step = 0;
  bool _completed = false;
  // 디폴트로 서울 선택. 부산 탭 시 추가됨.
  final List<String> _selectedRegions = ['서울'];

  void _onDashboardCardTap() {
    if (_step != 0) return;
    setState(() => _step = 1);
  }

  void _onLocationIconTap() {
    if (_step != 1) return;
    setState(() => _step = 2);
  }

  void _onRegionRowTap() {
    if (_step != 2) return;
    setState(() {
      _selectedRegions.add('부산');
      _step = 3;
    });
  }

  void _onPostCardTap() {
    if (_step != 3) return;
    setState(() => _step = 4);
  }

  void _onTimeSlotTap() {
    if (_step != 4) return;
    setState(() {
      _step = 5;
      _completed = true;
    });
    widget.onComplete();
  }

  String get _helperText {
    switch (_step) {
      case 0:
        return '[탭] 헌혈 게시판으로 이동';
      case 1:
        return '[탭] 우측 상단 지역 아이콘으로 선호 지역을 선택해요\n(가입 시 주소 기반으로 디폴트 1개 자동 선택돼 있어요)';
      case 2:
        return '[탭] 원하는 지역을 추가 선택 (최대 5개) — "전체 지역"도 가능';
      case 3:
        return '선호 지역에 부산이 추가됐어요. [탭] 게시글을 누르면 상세 정보가 올라와요';
      case 4:
        return '[탭] 가능한 시간대를 선택합니다';
      default:
        return '시간대 선택 완료. 다음 슬라이드에서 신청 폼을 작성해요';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TutorialPhoneFrame(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _buildCurrentView(),
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),
        TutorialHelperText(text: _helperText),
      ],
    );
  }

  Widget _buildCurrentView() {
    if (_step == 0) {
      return _DashboardMock(
        key: const ValueKey('dashboard'),
        isCardActive: !_completed,
        onCardTap: _onDashboardCardTap,
      );
    }
    if (_step == 1 || _step == 3) {
      // 지역 아이콘 클릭 단계 OR 시트 닫힌 후 board list로 복귀
      return _BoardListMock(
        key: ValueKey('board_step$_step'),
        isLocationActive: _step == 1,
        isFirstPostActive: _step == 3,
        onLocationTap: _onLocationIconTap,
        onFirstPostTap: _onPostCardTap,
        selectedRegions: _selectedRegions,
      );
    }
    if (_step == 2) {
      return _RegionSheetMock(
        key: const ValueKey('region'),
        isFirstRegionActive: true,
        onRegionTap: _onRegionRowTap,
        selectedRegions: _selectedRegions,
      );
    }
    return _BottomSheetMock(
      key: const ValueKey('sheet'),
      isFirstSlotActive: !_completed,
      onFirstSlotTap: _onTimeSlotTap,
    );
  }
}

// ====================================================================
// 대시보드 미니어처 (스텝 0)
// 헌혈 모집 + 헌혈 이력 + 공지사항/칼럼 가짜 데이터까지 표시
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
        const TutorialMockAppBar(),
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
                  fontSize: 16,
                ),
              ),
              Text(
                '사용자 님!',
                style: AppTheme.bodyMediumStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  fontSize: 16,
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
              const SizedBox(height: 14),

              // 헌혈 모집 카드 (강조 대상)
              HighlightTarget(
                isActive: isCardActive,
                onTap: onCardTap,
                child: const _LongActionCard(
                  icon: Icons.bloodtype_outlined,
                  iconBg: Color(0xFFE53935),
                  title: '헌혈 모집',
                  subtitle: '진행 중인 헌혈 요청 모아보기',
                ),
              ),
              const SizedBox(height: 8),

              // 헌혈 이력 카드 (visual)
              const _LongActionCard(
                icon: Icons.bloodtype,
                iconBg: Color(0xFF1976D2),
                title: '헌혈 이력',
                subtitle: '헌혈 신청 및 완료 내역',
              ),
              const SizedBox(height: 14),

              // 공지사항/칼럼 탭 헤더 (실제 앱처럼 좌우 균등 분포)
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppTheme.lightGray, width: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _tab('공지사항', active: true),
                    _tab('칼럼', active: false),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // 공지/칼럼 가짜 데이터
              const _NoticeRow(title: '시스템 점검 안내', date: '2026.05.05'),
              const SizedBox(height: 4),
              const _NoticeRow(title: '5월 헌혈 캠페인', date: '2026.05.04'),
              const SizedBox(height: 4),
              const _NoticeRow(title: '협회 운영 안내', date: '2026.05.02'),
            ],
          ),
        ),
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
          width: 36,
          height: 2,
          color: active ? AppTheme.primaryBlue : Colors.transparent,
        ),
      ],
    );
  }
}

class _NoticeRow extends StatelessWidget {
  final String title;
  final String date;

  const _NoticeRow({required this.title, required this.date});

  @override
  Widget build(BuildContext context) {
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

class _LongActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;

  const _LongActionCard({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightGray.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodyMediumStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
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
            size: 12,
            color: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// 게시판 list 미니어처 (스텝 1, 3)
// 우측 상단에 지역 선택 아이콘(location_on_outlined) — 스텝 1에서 강조,
// 첫 게시글 카드 — 스텝 3에서 강조.
// ====================================================================
class _BoardListMock extends StatelessWidget {
  final bool isLocationActive;
  final bool isFirstPostActive;
  final VoidCallback onLocationTap;
  final VoidCallback onFirstPostTap;
  final List<String> selectedRegions;

  const _BoardListMock({
    super.key,
    required this.isLocationActive,
    required this.isFirstPostActive,
    required this.onLocationTap,
    required this.onFirstPostTap,
    required this.selectedRegions,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 헤더 — 뒤로가기 + 제목 + 우측 액션 (지역 아이콘 + 새로고침)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                '헌혈 모집 게시글',
                style: AppTheme.bodyMediumStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              // 지역 선택 아이콘 — 디폴트 선택 있으면 파란색
              HighlightTarget(
                isActive: isLocationActive,
                onTap: onLocationTap,
                shape: HighlightShape.circle,
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.location_on_outlined,
                    size: 20,
                    color: AppTheme.primaryBlue, // 서울 선택돼 있어 파란색
                  ),
                ),
              ),
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                child: Icon(
                  Icons.refresh_outlined,
                  size: 18,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        // 지역 필터 표시
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: AppTheme.veryLightGray,
          child: Row(
            children: [
              Icon(Icons.place, size: 12, color: AppTheme.primaryBlue),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  selectedRegions.isEmpty
                      ? '선호 지역: 전체'
                      : '선호 지역: ${selectedRegions.join(", ")}',
                  style: AppTheme.bodySmallStyle.copyWith(
                    color: AppTheme.primaryBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
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
                  title: '강아지 긴급 헌혈 필요',
                  date: '2026.05.05',
                ),
              ),
              const SizedBox(height: 8),
              const _PostListCard(
                urgent: false,
                title: '정기 헌혈 모집',
                date: '2026.05.04',
              ),
              const SizedBox(height: 8),
              const _PostListCard(
                urgent: false,
                title: '강아지 정기 헌혈',
                date: '2026.05.02',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ====================================================================
// 선호 지역 선택 바텀시트 (스텝 2)
// 헤더 + 선택된 칩 + "전체 지역" + 17개 시도. 가입 주소 디폴트로 서울 선택.
// 사용자가 다른 지역(예: 부산) 탭하면 → 추가 → 시트 닫힘.
// ====================================================================
class _RegionSheetMock extends StatelessWidget {
  final bool isFirstRegionActive;
  final VoidCallback onRegionTap;
  final List<String> selectedRegions;

  const _RegionSheetMock({
    super.key,
    required this.isFirstRegionActive,
    required this.onRegionTap,
    required this.selectedRegions,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const TutorialMockSubAppBar(title: '헌혈 모집 게시글'),
        // 짧은 dim peek
        Container(height: 24, color: Colors.black.withValues(alpha: 0.06)),
        // 시트 본문
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 6,
                offset: Offset(0, -2),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 핸들바
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.lightGray,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // 헤더
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '선호 지역 선택',
                          style: AppTheme.bodyMediumStyle.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '다중 선택 가능 (최대 5개)',
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Icon(
                      Icons.close,
                      size: 18,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
              ),
              // 선택된 지역 칩 (애니메이션으로 부산 추가됨)
              if (selectedRegions.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  alignment: Alignment.centerLeft,
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: selectedRegions
                          .map((r) => _selectedChip(r))
                          .toList(),
                    ),
                  ),
                ),
              const Divider(height: 1),
              // 지역 목록 (전체 + 일부 시도)
              _regionRow('전체 지역', selected: selectedRegions.isEmpty),
              _regionRow('서울특별시', selected: selectedRegions.contains('서울')),
              // 부산 — 강조 대상 (사용자가 추가 선택할 지역)
              HighlightTarget(
                isActive: isFirstRegionActive,
                onTap: onRegionTap,
                child: _regionRow(
                  '부산광역시',
                  selected: selectedRegions.contains('부산'),
                ),
              ),
              _regionRow('대구광역시', selected: selectedRegions.contains('대구')),
              _regionRow('인천광역시', selected: selectedRegions.contains('인천')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _selectedChip(String name) {
    // 칩 라벨은 시도 풀네임 (서울 → 서울특별시 등)
    const fullName = {
      '서울': '서울특별시',
      '부산': '부산광역시',
      '대구': '대구광역시',
      '인천': '인천광역시',
      '광주': '광주광역시',
      '대전': '대전광역시',
      '울산': '울산광역시',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            fullName[name] ?? name,
            style: AppTheme.bodySmallStyle.copyWith(
              color: AppTheme.primaryBlue,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.close, size: 12, color: AppTheme.primaryBlue),
        ],
      ),
    );
  }

  Widget _regionRow(
    String name, {
    required bool selected,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? AppTheme.primaryBlue.withValues(alpha: 0.06) : null,
      ),
      child: Row(
        children: [
          Icon(
            selected ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: selected ? AppTheme.primaryBlue : AppTheme.textTertiary,
          ),
          const SizedBox(width: 10),
          Text(
            name,
            style: AppTheme.bodySmallStyle.copyWith(
              color: selected ? AppTheme.primaryBlue : AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _PostListCard extends StatelessWidget {
  final bool urgent;
  final String title;
  final String date;

  const _PostListCard({
    required this.urgent,
    required this.title,
    required this.date,
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: urgent
                  ? AppTheme.error
                  : AppTheme.primaryBlue.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              urgent ? '긴급' : '정기',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
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
          const SizedBox(width: 6),
          Text(
            date,
            style: AppTheme.bodySmallStyle.copyWith(
              color: AppTheme.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// 자세한 바텀시트 미니어처 (스텝 2)
// 병원 + 환자 정보 + 헌혈 예정일 + 시간대 list (신청자 수 X).
// 뒤편 dim 패턴 폐기 — 콘텐츠 전체 가시성 우선.
// 폰 프레임 안에서 바텀시트 외관 유지 + 내부 스크롤로 모든 정보 노출.
// ====================================================================
class _BottomSheetMock extends StatelessWidget {
  final bool isFirstSlotActive;
  final VoidCallback onFirstSlotTap;

  const _BottomSheetMock({
    super.key,
    required this.isFirstSlotActive,
    required this.onFirstSlotTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const TutorialMockSubAppBar(title: '헌혈 모집'),
        // 짧은 dim 영역 (바텀시트가 올라온 느낌)
        Container(
          height: 30,
          color: Colors.black.withValues(alpha: 0.06),
        ),
        // 바텀시트 본문 — grab handle + 헤더 + 정보 + 시간대
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 6,
                offset: Offset(0, -2),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // grab handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.lightGray,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // 게시글 헤더 (긴급 뱃지 + 제목)
              Row(
                children: [
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
                  Flexible(
                    child: Text(
                      '강아지 긴급 헌혈 필요',
                      style: AppTheme.bodyMediumStyle.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 병원/주소
              _infoLine(Icons.local_hospital_outlined, '행복동물병원'),
              const SizedBox(height: 3),
              _infoLine(Icons.location_on_outlined, '서울 강남구 테헤란로 123'),
              const SizedBox(height: 10),

              // 수혈 환자 정보 — 카드 안에 별도 행
              Text(
                '수혈 환자 정보',
                style: AppTheme.bodySmallStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.textPrimary, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _patientRow('환자 이름', '멍멍이'),
                    const SizedBox(height: 4),
                    _patientRow('품종', '보더콜리'),
                    const SizedBox(height: 4),
                    _patientRow('나이', '7'),
                    const SizedBox(height: 4),
                    _patientRow('병명·증상', '빈혈로 인한 수혈 필요'),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 필요 혈액형 — 별도 컬러 박스
              Text(
                '필요 혈액형',
                style: AppTheme.bodySmallStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  'DEA 1.1+',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyMediumStyle.copyWith(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 헌혈 예정일 + 시간대
              Row(
                children: [
                  Icon(Icons.event, size: 13, color: AppTheme.primaryBlue),
                  const SizedBox(width: 4),
                  Text(
                    '헌혈 예정일 · 5/15 (월)',
                    style: AppTheme.bodySmallStyle.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              HighlightTarget(
                isActive: isFirstSlotActive,
                onTap: onFirstSlotTap,
                child: const _TimeSlotRow(time: '14:00'),
              ),
              const SizedBox(height: 6),
              const _TimeSlotRow(time: '15:00'),
              const SizedBox(height: 6),
              const _TimeSlotRow(time: '16:00'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoLine(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: AppTheme.bodySmallStyle.copyWith(
              color: AppTheme.textPrimary,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _patientRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            '$label:',
            style: AppTheme.bodySmallStyle.copyWith(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTheme.bodySmallStyle.copyWith(
              color: AppTheme.textPrimary,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

class _TimeSlotRow extends StatelessWidget {
  final String time;

  const _TimeSlotRow({required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.veryLightGray,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time,
            size: 14,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            time,
            style: AppTheme.bodySmallStyle.copyWith(
              color: AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Icon(
            Icons.arrow_forward_ios,
            size: 12,
            color: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }
}
