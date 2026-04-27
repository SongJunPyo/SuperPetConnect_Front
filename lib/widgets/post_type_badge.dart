import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// 게시글 타입 뱃지 (긴급/정기/마감/완료대기/중단대기 등)
///
/// 모든 화면(사용자, 병원, 관리자)에서 통일된 스타일로 사용합니다.
/// 스타일: 연한 배경 + 색상 글씨 (아웃라인 스타일)
class PostTypeBadge extends StatelessWidget {
  final String type;

  const PostTypeBadge({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final color = _textColor(type);
    final bgColor = _backgroundColor(type);
    final isTwoLine = type == '완료대기' || type == '중단대기';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: isTwoLine
          ? Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  type == '완료대기' ? '완료' : '중단',
                  style: AppTheme.bodySmallStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontSize: 11,
                    height: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  '대기',
                  style: AppTheme.bodySmallStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontSize: 11,
                    height: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            )
          : Text(
              type,
              style: AppTheme.bodySmallStyle.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
    );
  }

  // ===== 색상 정의 (중앙 관리) =====

  /// 정기 헌혈 파란색
  static const Color regularBlue = Color(0xFF4A90E2);

  /// 뱃지 텍스트 색상
  static Color _textColor(String type) {
    switch (type) {
      case '긴급':
        return Colors.red;
      case '정기':
        return regularBlue;
      case '완료대기':
        return Colors.green;
      case '중단대기':
        return Colors.pink;
      case '진행':
        return Colors.green;
      case '마감':
        return Colors.orange.shade700;
      case '완료':
        return regularBlue;
      case '중단':
        return Colors.grey.shade700;
      case '거절':
        return Colors.red;
      case '대기':
        return Colors.purple;
      default:
        return regularBlue;
    }
  }

  /// 뱃지 배경색
  static Color _backgroundColor(String type) {
    switch (type) {
      case '긴급':
        return Colors.red.withAlpha(38);
      case '정기':
        return regularBlue.withAlpha(38);
      case '완료대기':
        return Colors.green.withAlpha(38);
      case '중단대기':
        return Colors.pink.withAlpha(38);
      case '진행':
        return Colors.green.withAlpha(38);
      case '마감':
        return Colors.orange.withAlpha(38);
      case '완료':
        return regularBlue.withAlpha(38);
      case '중단':
        return Colors.grey.withAlpha(38);
      case '거절':
        return Colors.red.withAlpha(38);
      case '대기':
        return Colors.purple.withAlpha(38);
      default:
        return regularBlue.withAlpha(38);
    }
  }

  /// 외부에서 색상만 필요할 때 사용하는 헬퍼
  static Color getTextColor(String type) => _textColor(type);
  static Color getBackgroundColor(String type) => _backgroundColor(type);
}
