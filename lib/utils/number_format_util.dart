class NumberFormatUtil {
  /// 큰 숫자를 축약해서 표시하는 함수 (박스 크기에 최적화)
  /// 최대 4-5글자까지 표시 가능하도록 설계
  /// 
  /// 표시 예시:
  /// - 1234 -> "1234" (4글자)
  /// - 9999 -> "9999" (4글자)
  /// - 12345 -> "12.3K" (5글자)
  /// - 999000 -> "999K" (4글자)
  /// - 1234567 -> "1.2M" (4글자)
  /// - 999000000 -> "999M" (4글자)
  /// - 1234567890 -> "1.2B" (4글자)
  /// - 999000000000 -> "999B" (4글자)
  /// - 1234567890123 -> "1.2T" (4글자)
  /// - 999999999999999+ -> "999T" (4글자, 최대치)
  static String formatViewCount(int number) {
    // 음수는 0으로 처리
    if (number < 0) return '0';
    
    // 4자리까지는 그대로 표시 (9999까지)
    if (number < 10000) {
      return number.toString();
    } 
    // 5자리 이상부터 축약 시작
    else if (number < 1000000) {
      // 1만 ~ 99만: K 단위 (10.0K ~ 999K)
      double thousands = number / 1000.0;
      if (thousands >= 100) {
        return '${thousands.round()}K';  // 100K ~ 999K (4글자)
      } else {
        return '${thousands.toStringAsFixed(1)}K';  // 10.0K ~ 99.9K (5글자)
      }
    } 
    else if (number < 1000000000) {
      // 100만 ~ 9억 9999만: M 단위 (1.0M ~ 999M)
      double millions = number / 1000000.0;
      if (millions >= 100) {
        return '${millions.round()}M';  // 100M ~ 999M (4글자)
      } else if (millions >= 10) {
        return '${millions.toStringAsFixed(0)}M';  // 10M ~ 99M (3-4글자)
      } else {
        return '${millions.toStringAsFixed(1)}M';  // 1.0M ~ 9.9M (4글자)
      }
    } 
    else if (number < 1000000000000) {
      // 10억 ~ 9999억: B 단위 (1.0B ~ 999B)
      double billions = number / 1000000000.0;
      if (billions >= 100) {
        return '${billions.round()}B';  // 100B ~ 999B (4글자)
      } else if (billions >= 10) {
        return '${billions.toStringAsFixed(0)}B';  // 10B ~ 99B (3-4글자)
      } else {
        return '${billions.toStringAsFixed(1)}B';  // 1.0B ~ 9.9B (4글자)
      }
    } 
    else {
      // 1조 이상: T 단위 (1.0T ~ 999T, 999T에서 최대치)
      double trillions = number / 1000000000000.0;
      if (trillions >= 999) {
        return '999T';  // 999조 이상은 모두 999T로 표시 (4글자)
      } else if (trillions >= 100) {
        return '${trillions.round()}T';  // 100T ~ 999T (4글자)
      } else if (trillions >= 10) {
        return '${trillions.toStringAsFixed(0)}T';  // 10T ~ 99T (3-4글자)
      } else {
        return '${trillions.toStringAsFixed(1)}T';  // 1.0T ~ 9.9T (4글자)
      }
    }
  }

  /// 한국식 단위로 표시하는 함수 (선택사항)
  /// 예: 1234 -> "1.2천", 1234567 -> "123만", 100000000 -> "1억"
  static String formatViewCountKorean(int number) {
    if (number < 1000) {
      return number.toString();
    } else if (number < 10000) {
      // 1천 ~ 9천
      double thousands = number / 1000.0;
      return '${thousands.toStringAsFixed(1)}천';
    } else if (number < 100000000) {
      // 1만 ~ 9999만
      double tenThousands = number / 10000.0;
      if (tenThousands >= 1000) {
        return '${(tenThousands / 1000).toStringAsFixed(0)}천만';
      } else if (tenThousands >= 100) {
        return '${tenThousands.toStringAsFixed(0)}만';
      } else if (tenThousands >= 10) {
        return '${tenThousands.toStringAsFixed(0)}만';
      } else {
        return '${tenThousands.toStringAsFixed(1)}만';
      }
    } else {
      // 1억 이상
      double hundredMillions = number / 100000000.0;
      if (hundredMillions >= 10) {
        return '${hundredMillions.toStringAsFixed(0)}억';
      } else {
        return '${hundredMillions.toStringAsFixed(1)}억';
      }
    }
  }
}