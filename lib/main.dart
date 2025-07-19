import 'package:flutter/material.dart';
import 'package:connect/auth/welcome.dart'; // 파일명 변경: welcome_screen.dart -> welcome.dart

import 'package:firebase_core/firebase_core.dart'; // Firebase Core 임포트
import 'package:connect/firebase_options.dart'; // Firebase 설정 파일 임포트 (필요 시)
import 'package:firebase_messaging/firebase_messaging.dart'; // FCM 메시징 임포트

// 백그라운드 메시지 핸들러 (앱이 백그라운드에 있거나 종료되었을 때 호출)
// 이 함수는 앱의 메인 isolate 외부에서 실행되므로, UI나 context에 직접 접근할 수 없음
// 반드시 최상위 함수(top-level function)여야함
@pragma('vm:entry-point') // Flutter 3.3+에서 백그라운드 메시지 처리를 위해 필요
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase 초기화 (백그라운드에서만 호출됨)
  print("백그라운드 메시지 수신: ${message.messageId}");
  print("백그라운드 알림 제목: ${message.notification?.title}");
  print("백그라운드 알림 내용: ${message.notification?.body}");
  print("백그라운드 데이터: ${message.data}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Flutter 엔진 초기화 보장

  // 백그라운드 메시지 핸들러 등록 (앱 시작 시 한 번만 호출)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform, // Firebase 프로젝트 설정 사용
    );
    print('Firebase 초기화 성공!');

    // 포그라운드 메시지 수신 리스너 등록 (앱이 실행 중일 때)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("포그라운드 메시지 수신: ${message.messageId}");
      print("포그라운드 알림 제목: ${message.notification?.title}");
      print("포그라운드 알림 내용: ${message.notification?.body}");
      print("포그라운드 데이터: ${message.data}");

      // 포그라운드에서 알림을 받았을 때 사용자에게 표시 (예: SnackBar, Dialog, Local Notification)
      // 여기서는 간단히 SnackBar로 표시합니다.
      if (message.notification != null) {
        // ScaffoldMessenger가 사용 가능한지 확인 후 SnackBar 표시
        if (navigatorKey.currentState != null &&
            navigatorKey.currentState!.overlay != null) {
          ScaffoldMessenger.of(navigatorKey.currentState!.context).showSnackBar(
            SnackBar(
              content: Text(
                '${message.notification!.title ?? '알림'}: ${message.notification!.body ?? ''}',
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    });

    // 앱이 종료된 상태에서 알림을 탭하여 앱이 열렸을 때 메시지 가져오기
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        print("종료 상태에서 앱 시작 메시지: ${message.messageId}");
        // TODO: 알림을 통해 앱이 열렸을 때 특정 화면으로 이동하는 로직 추가
      }
    });

    // 앱이 백그라운드 상태에서 알림을 탭하여 앱이 포그라운드로 전환될 때 메시지 가져오기
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("백그라운드에서 앱 열림 메시지: ${message.messageId}");
      // TODO: 알림을 탭했을 때 특정 화면으로 이동하는 로직 추가
    });
  } catch (e) {
    print('Firebase 초기화 실패: $e');
    // 초기화 실패 시 앱을 계속 실행할지, 오류 화면을 보여줄지 결정
  }

  runApp(const MyApp());
}

// SnackBar를 표시하기 위해 Navigator의 context를 전역적으로 접근하기 위한 Key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Super Pet Connect',
      theme: ThemeData(
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
