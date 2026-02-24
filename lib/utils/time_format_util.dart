import 'package:intl/intl.dart';

/// 날짜 및 시간 포맷팅 유틸리티
/// 게시글 상세, 리스트 등에서 일관된 날짜/시간 포맷을 제공
class TimeFormatUtils {
  // Private constructor to prevent instantiation
  TimeFormatUtils._();

  // ===== 기존 시간 문자열 포맷팅 =====

  /// "14:10" -> "오후 02:10" 형태로 변환
  static String formatTime(String time24) {
    if (time24.isEmpty) return '시간 미정';

    try {
      final parts = time24.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = parts[1];
        if (hour == 0) {
          return '오전 12:$minute';
        } else if (hour < 12) {
          return '오전 ${hour.toString().padLeft(2, '0')}:$minute';
        } else if (hour == 12) {
          return '오후 12:$minute';
        } else {
          return '오후 ${(hour - 12).toString().padLeft(2, '0')}:$minute';
        }
      }
    } catch (e) {
      // 파싱 실패 시 원본 값 반환
      return time24;
    }
    return '시간 미정';
  }

  /// "14:10" 그대로 반환
  static String simple24HourTime(String time24) {
    return time24.isNotEmpty ? time24 : '미정';
  }

  // ===== DateTime 객체 포맷팅 (게시글 바텀시트용) =====

  /// 게시글 작성일 포맷: yy.MM.dd
  /// 예: 24.12.25
  static String formatPostDate(DateTime date) {
    return DateFormat('yy.MM.dd').format(date);
  }

  /// 게시글 작성일시 포맷: yyyy.MM.dd HH:mm
  /// 예: 2024.12.25 14:30
  static String formatPostDateTime(DateTime date) {
    return DateFormat('yyyy.MM.dd HH:mm').format(date);
  }

  /// 짧은 날짜 포맷: MM.dd
  /// 예: 12.25
  static String formatShortDate(DateTime date) {
    return DateFormat('MM.dd').format(date);
  }

  /// 완전한 날짜 포맷: yyyy년 MM월 dd일 EEEE
  /// 예: 2024년 12월 25일 월요일
  static String formatFullDate(DateTime date) {
    return DateFormat('yyyy년 MM월 dd일 EEEE', 'ko').format(date);
  }

  /// 시간만 포맷: HH:mm
  /// 예: 14:30
  static String formatTimeOnly(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  // ===== 유연한 파싱 (dynamic 타입 처리) =====

  /// 유연한 날짜 파싱 (String, DateTime, dynamic 모두 처리)
  /// ISO 8601, SQL datetime, 일반 날짜 문자열 모두 지원
  static DateTime? parseFlexibleDate(dynamic dateValue) {
    if (dateValue == null) return null;
    if (dateValue is DateTime) return dateValue;

    try {
      // 문자열로 변환
      final dateStr = dateValue.toString().trim();
      if (dateStr.isEmpty || dateStr == 'null' || dateStr == 'N/A') {
        return null;
      }

      // DateTime.parse()로 파싱 시도 (ISO 8601, SQL datetime 지원)
      return DateTime.parse(dateStr);
    } catch (e) {
      // 파싱 실패 시 null 반환
      return null;
    }
  }

  /// 유연한 날짜 파싱 후 포맷 (yy.MM.dd)
  /// 파싱 실패 시 기본값 반환
  static String formatFlexibleDate(
    dynamic dateValue, {
    String defaultValue = '-',
  }) {
    final parsed = parseFlexibleDate(dateValue);
    if (parsed == null) return defaultValue;
    return formatPostDate(parsed);
  }

  /// 유연한 날짜 파싱 후 포맷 (yyyy.MM.dd HH:mm)
  /// 파싱 실패 시 기본값 반환
  static String formatFlexibleDateTime(
    dynamic dateValue, {
    String defaultValue = '-',
  }) {
    final parsed = parseFlexibleDate(dateValue);
    if (parsed == null) return defaultValue;
    return formatPostDateTime(parsed);
  }
}
