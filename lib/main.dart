import 'package:flutter/material.dart';
import 'package:connect/auth/welcome.dart'; // 파일명 변경: welcome_screen.dart -> welcome.dart
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 환경변수 관리
import 'package:provider/provider.dart'; // 상태 관리
import 'package:flutter_localizations/flutter_localizations.dart'; // 한글 로케일

import 'package:firebase_core/firebase_core.dart'; // Firebase Core 임포트
import 'package:connect/firebase_options.dart'; // Firebase 설정 파일 임포트 (필요 시)
import 'package:firebase_messaging/firebase_messaging.dart'; // FCM 메시징 임포트

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/date_symbol_data_local.dart'; // 로케일 데이터 초기화용
import 'dart:convert';
import 'dart:io'; // Platform 확인을 위해 추가
import 'package:flutter/foundation.dart';

// 웹 전용 라우팅 및 레이아웃
import 'package:connect/web/web_router.dart';
// 알림 서비스
import 'package:connect/services/notification_service.dart';
// Provider
import 'package:connect/providers/notification_provider.dart';
// 관리자 페이지
import 'package:connect/admin/admin_post_management_page.dart';
// 병원 페이지
import 'package:connect/hospital/hospital_dashboard.dart';
// 프로필 관리
import 'package:connect/auth/profile_management.dart';

// 로컬 알림 플러그인 인스턴스
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 백그라운드 핸들러 내에서도 Firebase 초기화는 필수
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (message.notification != null) {
    _showLocalNotification(message);
  }
}

Future<void> _showLocalNotification(RemoteMessage message) async {
  try {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription:
              'This channel is used for important notifications.',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
          icon: '@mipmap/ic_launcher',
          enableVibration: true,
          playSound: true,
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
  } catch (e) {
    // 로컬 알림 표시 오류 발생
  }
}

// 전역적으로 사용할 수 있도록 함수 노출
Future<void> showGlobalLocalNotification(RemoteMessage message) async {
  await _showLocalNotification(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 release 모드에서도 print() 로그 보이게
  const bool kReleaseMode = bool.fromEnvironment('dart.vm.product');
  if (kReleaseMode) {
    // ignore: avoid_print
    debugPrint = (String? message, {int? wrapWidth}) => print(message);
  }
  // 0. 환경변수 로드 (가장 먼저)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // .env 파일이 없어도 앱이 동작하도록 기본값 사용
  }

  // 1. Firebase 초기화 (가장 먼저)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // 초기화 실패 시 앱을 계속 실행할지, 오류 화면을 보여줄지 결정
    // 여기서는 오류 발생 시 앱 종료를 고려할 수도 있습니다.
    // return; // 앱 종료
  }

  // 2. 백그라운드 메시지 핸들러 등록 (Firebase 초기화 후, 웹에서는 스킵)
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // 3. 타임존 설정 (웹에서는 조건부 처리)
  tz.initializeTimeZones();
  try {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    } else {
      tz.setLocalLocation(tz.UTC);
    }
  } catch (e) {
    tz.setLocalLocation(tz.UTC);
  }

  // 3-1. 한국어 로케일 데이터 초기화
  await initializeDateFormatting('ko_KR', null);

  // 4. 로컬 알림 플러그인 초기화 (모바일에서만)
  if (!kIsWeb) {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (
        NotificationResponse notificationResponse,
      ) async {
        // NotificationService의 핸들러 호출
        NotificationService.handleLocalNotificationTap(
          notificationResponse.payload,
        );
      },
    );

    // Android 알림 채널 생성 (API 26+ 에서 필요)
    if (!kIsWeb && Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'Super Pet Connect 중요 알림',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
      );

      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      await androidPlugin?.createNotificationChannel(channel);
    }
  }

  // 5. 알림 권한 요청 (Firebase 초기화 및 로컬 알림 초기화 후, 모바일에서만)
  if (!kIsWeb) {
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
        // 사용자에게 알림 권한이 허용됨
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        // 사용자에게 임시 알림 권한이 허용됨
      } else {
        // 사용자에게 알림 권한이 거부됨
      }
    } catch (e) {
      // FCM 알림 권한 요청 중 오류 발생
    }
  }

  // 6. 알림 서비스 초기화 (FCM 메시지 리스너 포함)
  await NotificationService.initialize();

  // 7. Provider와 함께 앱 실행
  // (알림 시스템은 로그인 후 NotificationProvider.initialize()에서 초기화됨)
  runApp(
    ChangeNotifierProvider(
      create: (_) => NotificationProvider(),
      child: const MyApp(),
    ),
  );
}

// SnackBar를 표시하기 위해 Navigator의 context를 전역적으로 접근하기 위한 Key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Super Pet Connect',
      // 한글 로케일 설정
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'), // 한국어
        Locale('en', 'US'), // 영어
      ],
      locale: const Locale('ko', 'KR'), // 기본 로케일을 한국어로 설정
      theme: ThemeData(
        // Material 3의 동적 색상 기능을 활용하여 기본 색상을 설정합니다.
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF191F28)),
        useMaterial3: true,
        // 앱 전체의 스캐폴드 배경색을 흰색으로 설정하여 깔끔함을 강조합니다.
        scaffoldBackgroundColor:
            kIsWeb ? const Color(0xfff5f5f5) : Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white, // AppBar 배경도 흰색으로 통일
          elevation: kIsWeb ? 1 : 0, // 웹에서는 약간의 그림자, 모바일에서는 제거
          foregroundColor: Colors.black, // AppBar 아이콘 및 텍스트 색상
        ),
      ),
      // 웹에서는 라우팅 기반 네비게이션 사용
      initialRoute: kIsWeb ? WebRouter.getInitialRoute() : null,
      onGenerateRoute: kIsWeb ? WebRouter.generateRoute : null,
      routes:
          kIsWeb
              ? {}
              : {
                '/admin/post-management': (context) {
                  final args =
                      ModalRoute.of(context)?.settings.arguments
                          as Map<String, dynamic>?;
                  return AdminPostManagementPage(
                    postId: args?['postId'],
                    initialTab: args?['initialTab'],
                    highlightPostId: args?['highlightPost'],
                  );
                },
                '/hospital/dashboard': (context) {
                  final args =
                      ModalRoute.of(context)?.settings.arguments
                          as Map<String, dynamic>?;
                  return HospitalDashboard(
                    highlightPostId: args?['highlightPostId'],
                    showPostDetail: args?['showPostDetail'] ?? false,
                  );
                },
                '/hospital/columns': (context) {
                  final args =
                      ModalRoute.of(context)?.settings.arguments
                          as Map<String, dynamic>?;
                  // 병원 대시보드에 칼럼 탭으로 이동
                  return HospitalDashboard(
                    highlightColumnId: args?['highlightColumnId'],
                    initialTab: 'columns',
                  );
                },
                '/profile_management': (context) => const ProfileManagement(),
              },
      home: kIsWeb ? null : const WelcomeScreen(),
      debugShowCheckedModeBanner: false, // 오른쪽 상단 디버그 배너 제거
      navigatorKey: NotificationService.navigatorKey,
    );
  }
}
