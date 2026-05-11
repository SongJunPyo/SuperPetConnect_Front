import 'package:intl/intl.dart';

/// 헌혈 일자가 "오늘 이전"인지 검사 (당일 신청 허용 — donation_date >= today).
///
/// 입력은 "YYYY-MM-DD" 또는 ISO 8601 문자열. 파싱 실패 시 false (보수적으로 통과).
/// 비교는 캘린더 day 단위 — 시각은 무시 (당일 자정 이후라도 today로 간주).
///
/// 사용처:
/// - [PostDetailBottomSheet] 시간대 dropdown 필터링
/// - [DonationApplicationPage] submit 직전 safety check
/// - [UserDonationPostsListScreen] auto-apply 시간대 선택 시 past 스킵
bool isDonationDatePast(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return false;
  try {
    final parsed = DateTime.parse(dateStr);
    final donationDay = DateTime(parsed.year, parsed.month, parsed.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return donationDay.isBefore(today);
  } catch (_) {
    return false;
  }
}

/// DateTime 버전 — [isDonationDatePast]의 String 오버로드와 동작 동일.
bool isDonationDateTimePast(DateTime? date) {
  if (date == null) return false;
  final donationDay = DateTime(date.year, date.month, date.day);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return donationDay.isBefore(today);
}

/// 날짜 및 시간 포맷팅 유틸리티
/// 게시글 상세, 리스트 등에서 일관된 날짜/시간 포맷을 제공
class TimeFormatUtils {
  // Private constructor to prevent instantiation
  TimeFormatUtils._();

  // ===== 기존 시간 문자열 포맷팅 =====

  /// "16:00" → "오후 16:00" — 오전/오후 라벨 + 24시간 숫자 그대로.
  /// 12시간제 변환 안 함 (운영 결정 2026-05).
  /// 예시:
  /// - 00:00 → 오전 00:00 (자정)
  /// - 09:00 → 오전 09:00
  /// - 12:00 → 오후 12:00 (정오)
  /// - 16:00 → 오후 16:00
  /// - 23:00 → 오후 23:00
  /// "14:10:00" 같은 초 포함도 허용.
  static String formatTime(String time24) {
    if (time24.isEmpty) return '시간 미정';

    try {
      final parts = time24.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = parts[1];
        final period = hour < 12 ? '오전' : '오후';
        return '$period ${hour.toString().padLeft(2, '0')}:$minute';
      }
    } catch (e) {
      // 파싱 실패 시 원본 값 반환
      return time24;
    }
    return '시간 미정';
  }

  /// DateTime의 시간 부분을 [formatTime] 새 포맷으로 변환.
  /// 헌혈 시간 표시(donation_time)가 DateTime 객체일 때 사용.
  static String formatTimeOfDate(DateTime date) {
    return formatTime(
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
    );
  }

  /// "14:10" 그대로 반환
  static String simple24HourTime(String time24) {
    return time24.isNotEmpty ? time24 : '미정';
  }

  /// 날짜 문자열을 요일로 변환 ("2024-12-25" -> "수")
  /// 파싱 실패 시 빈 문자열 반환
  static String getWeekday(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
      return weekdays[date.weekday - 1];
    } catch (e) {
      return '';
    }
  }

  /// 날짜 문자열을 "YYYY년 M월 D일 O요일" 형태로 포맷팅
  /// 파싱 실패 시 원본 반환
  static String formatDateWithWeekday(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final weekday = getWeekday(dateStr);
      return '${date.year}년 ${date.month}월 ${date.day}일 $weekday요일';
    } catch (e) {
      return dateStr;
    }
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

  /// 유연한 날짜 파싱 후 짧은 포맷 (MM.dd)
  /// 파싱 실패 시 기본값 반환
  static String formatFlexibleShortDate(
    dynamic dateValue, {
    String defaultValue = '-',
  }) {
    final parsed = parseFlexibleDate(dateValue);
    if (parsed == null) return defaultValue;
    return formatShortDate(parsed);
  }

  /// 한국어 풀 포맷 (요일 포함): yyyy년 MM월 dd일 (E) 오후 HH:mm
  /// 예: 2024년 12월 25일 (수) 오후 14:30
  /// 헌혈 마감 일정 등 시간대 맥락 표시에 사용.
  /// 시간 부분은 [formatTime] 새 포맷 (오전/오후 + 24시간) 적용.
  static String formatKoreanDateTimeWithWeekday(
    dynamic dateValue, {
    String defaultValue = '일정 정보 없음',
  }) {
    final parsed = parseFlexibleDate(dateValue);
    if (parsed == null) return defaultValue;
    final dateStr = DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(parsed);
    return '$dateStr ${formatTimeOfDate(parsed)}';
  }

  /// 한국어 날짜+시간 포맷 (요일 없음): yyyy년 MM월 dd일 오후 HH:mm
  /// 예: 2024년 12월 25일 오후 14:30
  /// 처리 시각 등 단순 타임스탬프 표시에 사용.
  /// 시간 부분은 [formatTime] 새 포맷 (오전/오후 + 24시간) 적용.
  static String formatKoreanDateTime(
    dynamic dateValue, {
    String defaultValue = '',
  }) {
    final parsed = parseFlexibleDate(dateValue);
    if (parsed == null) return defaultValue;
    final dateStr = DateFormat('yyyy년 MM월 dd일', 'ko_KR').format(parsed);
    return '$dateStr ${formatTimeOfDate(parsed)}';
  }
}
