import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// 펫 정보 행의 bool/상태 값을 의미별 4단계 아이콘으로 표시하는 단일 진실 위젯.
///
/// 펫 정보를 보여주는 모든 화면(회원가입 관리 / 관리자 펫 관리 / 모집마감 시트 등)이
/// 같은 의미 매핑을 사용해 admin이 어느 화면에서 펫을 봐도 시각적 해석이 일관됨.
///
/// 4단계 의미 매핑 (CLAUDE.md "아이콘 시스템 — 상태 표시" 섹션 미러):
/// - **positive** (초록 ✓ `check_circle_outline`) — 능동 행위 완료
///   예: 접종 완료, 예방약 복용, 중성화 완료
/// - **critical** (빨강 ! `error_outline`) — 능동 행위 미수행 / 적극적 위험
///   예: 접종 안됨, 예방약 미복용, 질병 있음
/// - **warning** (주황 ⚠ `warning_amber_rounded`) — 신경써야 할 컨텍스트
///   예: 임신중, 생년월일 미입력
/// - **neutral** (회색 — `remove_circle_outline`) — 자연스러운 부재
///   예: 질병 없음, 중성화 미시행, 첫 헌혈(헌혈 이력 없음)
///
/// 빨강과 주황의 차이: "의료 행위 미수행"은 빨강(critical), "정보 미입력 / 컨텍스트 주의"는 주황.
/// 회색과 빨강의 차이: "없어서 좋은 것"은 회색(중립), "있어서 나쁜 것"은 빨강.
enum PetStatusType { positive, critical, warning, neutral }

class PetStatusRow extends StatelessWidget {
  /// 행 좌측 라벨 아이콘 (PetFieldIcons.xxx 사용 권장).
  final IconData icon;

  /// 라벨 텍스트 (예: "접종", "중성화").
  final String label;

  /// 의미 분기.
  final PetStatusType status;

  /// 라벨 컬럼 고정 너비. null이면 `label: ` 형태로 라벨 폭에 따라 가변.
  /// 다른 정보 행과 값 정렬을 맞추고 싶으면 90 등 고정값 지정.
  final double? labelWidth;

  /// 행 padding (기본 vertical 4). `_buildDetailRow`와 정렬할 때 6으로 줄 수도 있음.
  final EdgeInsetsGeometry padding;

  const PetStatusRow({
    super.key,
    required this.icon,
    required this.label,
    required this.status,
    this.labelWidth,
    this.padding = const EdgeInsets.symmetric(vertical: AppTheme.spacing4),
  });

  @override
  Widget build(BuildContext context) {
    final IconData statusIcon;
    final Color statusColor;
    switch (status) {
      case PetStatusType.positive:
        statusIcon = Icons.check_circle_outline;
        statusColor = AppTheme.success;
        break;
      case PetStatusType.critical:
        statusIcon = Icons.error_outline;
        statusColor = AppTheme.error;
        break;
      case PetStatusType.warning:
        statusIcon = Icons.warning_amber_rounded;
        statusColor = AppTheme.warning;
        break;
      case PetStatusType.neutral:
        statusIcon = Icons.remove_circle_outline;
        // textTertiary(0xFF8B95A1)는 outlined 아이콘이 웹에서 거의 안 보일 정도로 옅어
        // leading 아이콘과 동일한 textSecondary(0xFF4E5968)로 톤 맞춤. 다른 상태 색(빨강/주황/초록)이
        // 전부 강한 색이라 회색만 옅으면 균형이 안 맞기도 함.
        statusColor = AppTheme.textSecondary;
        break;
    }

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: AppTheme.spacing8),
          if (labelWidth != null)
            SizedBox(
              width: labelWidth,
              child: Text(
                label,
                style: AppTheme.bodyMediumStyle.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            )
          else
            Text(
              '$label: ',
              style: AppTheme.bodyMediumStyle.copyWith(
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          Icon(statusIcon, size: 18, color: statusColor),
        ],
      ),
    );
  }
}
