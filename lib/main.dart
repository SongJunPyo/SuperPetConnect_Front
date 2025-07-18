import 'package:flutter/material.dart';
import 'package:connect/auth/welcome.dart'; // 파일명 변경: welcome_screen.dart -> welcome.dart

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Super Pet Connect',
      theme: ThemeData(
        // 토스 앱처럼 깔끔하고 세련된 느낌을 위해 색상 테마를 조정합니다.
        // Material 3의 동적 색상 기능을 활용하여 기본 색상을 설정합니다.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
        // 앱 전체의 스캐폴드 배경색을 흰색으로 설정하여 깔끔함을 강조합니다.
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white, // AppBar 배경도 흰색으로 통일
          elevation: 0, // AppBar 그림자 제거
          foregroundColor: Colors.black, // AppBar 아이콘 및 텍스트 색상
        ),
      ),
      home: const WelcomeScreen(),
      debugShowCheckedModeBanner: false, // 오른쪽 상단 디버그 배너 제거
    );
  }
}
