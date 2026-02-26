import 'package:flutter/material.dart';

class AppTheme {
  //static const Color primaryBlue = Color(0xFF4A90E2);
  //static const Color primaryDarkBlue = Color(0xFF357ABD);
  //static const Color lightBlue = Color(0xFFF3F8FF);
  //static const Color veryLightBlue = Color(0xFFF8FBFF);
  // 기본 색상 팔레트 (블랙 테마)
  static const Color primaryBlue = Color(0xFF191F28);
  static const Color primaryDarkBlue = Color(0xFF101318);
  static const Color lightBlue = Color(0xFFF2F4F6);
  static const Color veryLightBlue = Color(0xFFF7F8FA);

  // 그레이 스케일
  static const Color black = Color(0xFF191F28);
  static const Color darkGray = Color(0xFF4E5968);
  static const Color mediumGray = Color(0xFF8B95A1);
  static const Color lightGray = Color(0xFFD1D6DB);
  static const Color veryLightGray = Color(0xFFF2F4F6);
  static const Color backgroundColor = Color(0xFFFAFBFC);

  // 시스템 색상
  static const Color success = Color(0xFF00C73C);
  static const Color warning = Color(0xFFFF8A00);
  static const Color error = Color(0xFFFF3B30);
  static const Color info = Color(0xFF007AFF);

  // 텍스트 색상
  static const Color textPrimary = black;
  static const Color textSecondary = darkGray;
  static const Color textTertiary = mediumGray;
  static const Color textDisabled = lightGray;

  // 폰트 크기
  static const double h1 = 28.0;
  static const double h2 = 24.0;
  static const double h3 = 20.0;
  static const double h4 = 18.0;
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
  static const double caption = 10.0;

  // 간격
  static const double spacing2 = 2.0;
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing40 = 40.0;
  static const double spacing48 = 48.0;

  // 모서리 반지름
  static const double radius4 = 4.0;
  static const double radius8 = 8.0;
  static const double radius12 = 12.0;
  static const double radius16 = 16.0;
  static const double radius20 = 20.0;
  static const double radius24 = 24.0;

  // 그림자
  static const List<BoxShadow> shadowSmall = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> shadowMedium = [
    BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> shadowLarge = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, 8)),
  ];

  // 텍스트 스타일
  static const TextStyle h1Style = TextStyle(
    fontSize: h1,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    height: 1.3,
  );

  static const TextStyle h2Style = TextStyle(
    fontSize: h2,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    height: 1.3,
  );

  static const TextStyle h3Style = TextStyle(
    fontSize: h3,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.4,
  );

  static const TextStyle h4Style = TextStyle(
    fontSize: h4,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.4,
  );

  static const TextStyle bodyLargeStyle = TextStyle(
    fontSize: bodyLarge,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.5,
  );

  static const TextStyle bodyMediumStyle = TextStyle(
    fontSize: bodyMedium,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.5,
  );

  static const TextStyle bodySmallStyle = TextStyle(
    fontSize: bodySmall,
    fontWeight: FontWeight.w400,
    color: textTertiary,
    height: 1.5,
  );

  static const TextStyle captionStyle = TextStyle(
    fontSize: caption,
    fontWeight: FontWeight.w400,
    color: textTertiary,
    height: 1.4,
  );

  // 버튼 높이
  static const double buttonHeightLarge = 56.0;
  static const double buttonHeightMedium = 48.0;
  static const double buttonHeightSmall = 40.0;

  // 입력 필드 높이
  static const double inputHeight = 56.0;

  // 앱바 높이
  static const double appBarHeight = 56.0;

  // 카드 패딩
  static const EdgeInsets cardPadding = EdgeInsets.all(spacing16);
  static const EdgeInsets cardMargin = EdgeInsets.symmetric(
    horizontal: spacing16,
    vertical: spacing8,
  );

  // 페이지 패딩
  static const EdgeInsets pagePadding = EdgeInsets.all(spacing24);
  static const EdgeInsets pageHorizontalPadding = EdgeInsets.symmetric(
    horizontal: spacing24,
  );
}
