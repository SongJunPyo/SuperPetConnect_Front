import 'package:flutter/material.dart';

class HospitalDashboard extends StatelessWidget {
  const HospitalDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('병원 대시보드 (임시)'),
        backgroundColor: Colors.purple,
        centerTitle: true,
      ),
      body: const Center(
        child: Text('병원 페이지입니다.', style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
