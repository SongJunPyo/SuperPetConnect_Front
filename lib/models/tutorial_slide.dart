// lib/models/tutorial_slide.dart
// 사용자 튜토리얼 슬라이드 데이터 모델 + 정적 콘텐츠 정의.
//
// 콘텐츠 변경 시 이 파일만 수정하면 됨. UI 위젯은 lib/user/tutorial_screen.dart.

import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// 슬라이드 강조 박스 종류 — 색상/아이콘 분기에 사용.
enum HighlightType {
  /// 정보 안내 (자격 조건 등) — 파란 톤
  info,

  /// 주의 환기 (취소 불가, 자동 종결 등) — 주황 톤
  warning,
}

class HighlightBox {
  final HighlightType type;
  final String title;
  final List<String> lines;

  const HighlightBox({
    required this.type,
    required this.title,
    required this.lines,
  });

  IconData get icon =>
      type == HighlightType.warning ? Icons.warning_amber_rounded : Icons.lightbulb_outline;

  Color get accentColor =>
      type == HighlightType.warning ? AppTheme.warning : AppTheme.primaryBlue;
}

/// 단일 튜토리얼 슬라이드.
class TutorialSlide {
  /// 슬라이드 상단 큰 제목.
  final String title;

  /// 제목 아래 한 줄 부제 (선택).
  final String? subtitle;

  /// 단계 안내 (① ② ③ 형식으로 자동 번호 매김).
  final List<String> steps;

  /// 강조 박스 (선택).
  final HighlightBox? highlight;

  /// 일러스트 자리. asset 경로 지정 시 Image.asset, null이면 placeholder 표시.
  final String? illustrationAsset;

  /// placeholder용 대표 아이콘.
  final IconData placeholderIcon;

  const TutorialSlide({
    required this.title,
    this.subtitle,
    required this.steps,
    this.highlight,
    this.illustrationAsset,
    required this.placeholderIcon,
  });
}

/// 사용자 튜토리얼 콘텐츠 (3장).
///
/// 콘텐츠 박제 근거:
/// - 자격 조건: CLAUDE.md "Pet 모델 / 헌혈 자격 검증 contract" + "Pet 컬럼 분리 정책"
/// - 신청 흐름: CLAUDE.md "헌혈 사전 정보 설문 시스템" (옵션 P D-2 23:55 잠금)
/// - 신청 상태: CLAUDE.md "신청 상태" (PENDING→APPROVED→PENDING_COMPLETION→COMPLETED, CLOSED)
/// - 재심사 트리거: CLAUDE.md "재심사 화이트리스트"
class TutorialContent {
  TutorialContent._();

  static const List<TutorialSlide> userSlides = [
    // ===== 슬라이드 1: 헌혈 신청 =====
    TutorialSlide(
      title: '헌혈이 필요한 친구들에게\n도움을 주세요',
      subtitle: '헌혈 게시판에서 우리 아이가 도울 수 있는 글을 찾아보세요',
      steps: [
        '하단 "헌혈 게시판" 탭으로 이동',
        '관심 있는 게시글을 선택',
        '안내문을 정독하고 동의에 체크',
        '가능한 시간대를 선택하여 신청',
      ],
      highlight: HighlightBox(
        type: HighlightType.info,
        title: '헌혈 자격 조건',
        lines: [
          '체중 20kg 이상 (강아지 기준)',
          '직전 헌혈 후 180일 경과',
          '임신·출산 후 12개월 경과',
          '종합백신 24개월 이내 접종',
          '항체검사 12개월 이내 (백신 2년 초과 시)',
          '예방약 3개월 이내 복용',
        ],
      ),
      placeholderIcon: Icons.bloodtype_outlined,
    ),

    // ===== 슬라이드 2: 신청 후 흐름 =====
    TutorialSlide(
      title: '신청 후 어떻게 되나요?',
      subtitle: '대기 → 선정 → 사전 설문 → 헌혈 → 완료 순서로 진행돼요',
      steps: [
        '대기: 병원이 신청자를 검토',
        '선정: 헌혈 확정 — 당일 시간 맞춰 방문',
        '사전 설문: 선정 후 D-2까지 작성 (필수)',
        '헌혈 후: 병원과 관리자 검토를 거쳐 완료',
      ],
      highlight: HighlightBox(
        type: HighlightType.warning,
        title: '꼭 확인해주세요',
        lines: [
          '신청 취소는 "대기" 상태에서만 가능',
          '선정 후에는 병원 일정 때문에 직접 취소 불가',
          '선정 후 D-2(헌혈 이틀 전) 23:55까지 사전 설문을\n작성하지 않으면 신청이 자동 종결돼요',
        ],
      ),
      placeholderIcon: Icons.timeline_outlined,
    ),

    // ===== 슬라이드 3: 펫 추가/삭제 =====
    TutorialSlide(
      title: '여러 마리 등록할 수 있어요',
      subtitle: '한 계정에 여러 반려동물을 등록하고 각각 헌혈에 참여할 수 있어요',
      steps: [
        '우측 상단 "반려동물 관리" 또는\n프로필 화면에서 진입',
        '[+] 버튼으로 새로운 반려동물 추가',
        '카드 우측 메뉴에서 삭제',
      ],
      highlight: HighlightBox(
        type: HighlightType.warning,
        title: '정보 수정 시 주의',
        lines: [
          '체중·혈액형·임신/출산·중성화·예방접종 등\n자격 검증에 영향을 주는 항목을 수정하면\n관리자 재심사가 진행돼요',
          '재심사 중에는 일시적으로 헌혈 신청이 제한될 수 있어요',
          '백신·항체·예방약 일자, 외부 헌혈 횟수 등\n운영 정보는 재심사 없이 바로 반영돼요',
        ],
      ),
      placeholderIcon: Icons.pets,
    ),
  ];
}
