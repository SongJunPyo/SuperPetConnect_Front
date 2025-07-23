import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationSettingsScreen extends StatefulWidget {
  final String regionCode; // ex: 'gyeonggi'

  const NotificationSettingsScreen({super.key, required this.regionCode});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool allUsersSubscribed = true;
  bool regionSubscribed = true;

  @override
  void initState() {
    super.initState();
    // TODO: SharedPreferences에서 저장된 값 불러오기 (원하면 구현 가능)
  }

  Future<void> _toggleAllUsers(bool value) async {
  if (value) {
    await FirebaseMessaging.instance.subscribeToTopic("all_users");
    // 전체 알림을 켜면 지역 알림은 꺼지도록
    final topic = "region_${widget.regionCode}";
    await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    setState(() {
      allUsersSubscribed = true;
      regionSubscribed = false;
    });
  } else {
    await FirebaseMessaging.instance.unsubscribeFromTopic("all_users");
    setState(() => allUsersSubscribed = false);
    // 지역 알림은 사용자가 다시 켤 수 있도록 UI가 열려 있음
  }
}

  Future<void> _toggleRegion(bool value) async {
    final topic = "region_${widget.regionCode}";
    if (value) {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
    } else {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    }
    setState(() => regionSubscribed = value);
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
          Text(
            "수신할 알림 유형을 선택하세요.",
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            title: const Text("전체 알림 수신"),
            subtitle: const Text("모든 지역의 알림을 받습니다."),
            value: allUsersSubscribed,
            onChanged: _toggleAllUsers,
          ),
          const Divider(),
          SwitchListTile(
            title: Text("내 지역 알림 수신"),
            subtitle: const Text("내 지역 알림만 받습니다. \n(주소는 프로필에서 변경하실 수 있습니다.)"),
            value: regionSubscribed,
            onChanged: allUsersSubscribed ? null : _toggleRegion, // <- 전체 알림 켜져 있으면 비활성화
          ),
        ],
      ),
    );
  }
}
