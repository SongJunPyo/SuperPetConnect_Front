import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  // 모든 지역 코드 및 표시 이름
  final Map<String, String> regions = {
    'seoul': '서울특별시',
    'gyeonggi': '경기도',
    'busan': '부산광역시',
    'daegu': '대구광역시',
    'incheon': '인천광역시',
    'gwangju': '광주광역시',
    'daejeon': '대전광역시',
    'ulsan': '울산광역시',
    'gangwon': '강원도',
    'chungbuk': '충청북도',
    'chungnam': '충청남도',
    'jeonbuk': '전라북도',
    'jeonnam': '전라남도',
    'gyeongbuk': '경상북도',
    'gyeongnam': '경상남도',
    'jeju': '제주특별자치도',
  };

  bool allUsersSubscribed = false;
  Map<String, bool> regionSubscriptions = {}; // ex: {'seoul': true, 'busan': false}

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    // 초기 상태 로딩 (예: SharedPreferences 또는 서버에서 설정 불러오기)
    // 여기서는 모두 true로 초기화
    setState(() {
      regionSubscriptions = {
        for (var code in regions.keys) code: true,
      };
    });
  }

  Future<void> _toggleAllUsers(bool value) async {
  if (value) {
    await FirebaseMessaging.instance.subscribeToTopic("all_users");

    // 모든 지역 토픽 구독
    for (var code in regions.keys) {
      await FirebaseMessaging.instance.subscribeToTopic("region_$code");
    }

    setState(() {
      allUsersSubscribed = true;
      for (var code in regions.keys) {
        regionSubscriptions[code] = true;
      }
    });
  } else {
    await FirebaseMessaging.instance.unsubscribeFromTopic("all_users");

    // 모든 지역 토픽 해제
    for (var code in regions.keys) {
      await FirebaseMessaging.instance.unsubscribeFromTopic("region_$code");
    }

    setState(() {
      allUsersSubscribed = false;
      // 지역 알림은 모두 OFF로 초기화
      for (var code in regions.keys) {
        regionSubscriptions[code] = false;
      }
    });
  }
}


  Future<void> _toggleRegion(String code, bool value) async {
    final topic = "region_$code";
    if (value) {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
    } else {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    }
    setState(() {
      regionSubscriptions[code] = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("알림 설정"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text("수신할 알림 유형을 선택하세요.", style: textTheme.titleMedium),
          const SizedBox(height: 20),
          SwitchListTile(
            title: const Text("전체 알림 수신"),
            subtitle: const Text("모든 지역의 알림을 받습니다."),
            value: allUsersSubscribed,
            onChanged: _toggleAllUsers,
          ),
          const Divider(),
          const SizedBox(height: 12),
          Text("지역별 알림 설정", style: textTheme.titleSmall),
          const SizedBox(height: 10),
          ...regions.entries.map((entry) {
            final code = entry.key;
            final name = entry.value;
            final isEnabled = !allUsersSubscribed; // 전체 알림 켜져 있으면 비활성화
            return SwitchListTile(
              title: Text(name),
              value: regionSubscriptions[code] ?? false,
              onChanged: isEnabled ? (val) => _toggleRegion(code, val) : null,
            );
          }).toList(),
        ],
      ),
    );
  }
}
