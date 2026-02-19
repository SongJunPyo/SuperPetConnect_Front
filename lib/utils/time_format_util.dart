// 시간 포맷팅 유틸리티 클래스
class TimeFormatUtils {
  // "14:10" -> "오후 02:10" 형태로 변환
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

  // "14:10" 그대로 반환
  static String simple24HourTime(String time24) {
    return time24.isNotEmpty ? time24 : '미정';
  }
}
