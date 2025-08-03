import 'package:flutter/material.dart';
import 'package:connect/auth/welcome.dart'; // 파일명 변경: welcome_screen.dart -> welcome.dart

import 'package:firebase_core/firebase_core.dart'; // Firebase Core 임포트
import 'package:connect/firebase_options.dart'; // Firebase 설정 파일 임포트 (필요 시)
import 'package:firebase_messaging/firebase_messaging.dart'; // FCM 메시징 임포트

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/date_symbol_data_local.dart'; // 로케일 데이터 초기화용
import 'dart:convert';
import 'dart:io'; // Platform 확인을 위해 추가

// 로컬 알림 플러그인 인스턴스
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 백그라운드 핸들러 내에서도 Firebase 초기화는 필수
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  print("백그라운드 메시지 수신: ${message.messageId}");
  if (message.notification != null) {
    _showLocalNotification(message);
  }
}

Future<void> _showLocalNotification(RemoteMessage message) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
        icon: '@mipmap/ic_launcher',
      );
  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
  );

  await flutterLocalNotificationsPlugin.show(
    message.hashCode,
    message.notification?.title,
    message.notification?.body,
    platformChannelSpecifics,
    payload: jsonEncode(message.data),
  );
  print("로컬 알림 표시 시도 완료: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Firebase 초기화 (가장 먼저)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase 초기화 성공!');
  } catch (e) {
    print('Firebase 초기화 실패: $e');
    // 초기화 실패 시 앱을 계속 실행할지, 오류 화면을 보여줄지 결정
    // 여기서는 오류 발생 시 앱 종료를 고려할 수도 있습니다.
    // return; // 앱 종료
  }

  // 2. 백그라운드 메시지 핸들러 등록 (Firebase 초기화 후)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 3. 타임존 설정
  tz.initializeTimeZones();
  try {
    if (Platform.isAndroid || Platform.isIOS) {
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    } else {
      tz.setLocalLocation(tz.UTC);
    }
    print('타임존 설정 완료: Asia/Seoul');
  } catch (e) {
    print('타임존 설정 실패, UTC로 fallback: $e');
    tz.setLocalLocation(tz.UTC);
  }

  // 3-1. 한국어 로케일 데이터 초기화
  await initializeDateFormatting('ko_KR', null);
  print('한국어 로케일 초기화 완료');

  // 4. 로컬 알림 플러그인 초기화
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (
      NotificationResponse notificationResponse,
    ) async {
      print('알림 탭! Payload: ${notificationResponse.payload}');
      // TODO: payload를 파싱하여 해당 화면으로 이동하는 로직 추가
    },
  );

  // 5. 알림 권한 요청 (Firebase 초기화 및 로컬 알림 초기화 후)
  try {
    NotificationSettings settings = await FirebaseMessaging.instance
        .requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('사용자에게 알림 권한이 허용되었습니다.');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print('사용자에게 임시 알림 권한이 허용되었습니다.');
    } else {
      print('사용자에게 알림 권한이 거부되었습니다.');
      // TODO: 사용자에게 알림 권한 설정 페이지로 이동하도록 안내하는 UI 표시
    }
  } catch (e) {
    print('FCM 알림 권한 요청 중 오류 발생: $e');
  }

  // 6. FCM 메시지 리스너 등록 (Firebase 초기화 후)
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print("포그라운드 메시지 수신: ${message.messageId}");
    if (message.notification != null) {
      _showLocalNotification(message);
    }
  });

  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      print("종료 상태에서 앱 시작 메시지: ${message.messageId}");
      // TODO: 알림을 통해 앱이 열렸을 때 특정 화면으로 이동하는 로직 추가
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print("백그라운드에서 앱 열림 메시지: ${message.messageId}");
    // TODO: 알림을 탭했을 때 특정 화면으로 이동하는 로직 추가
  });

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
