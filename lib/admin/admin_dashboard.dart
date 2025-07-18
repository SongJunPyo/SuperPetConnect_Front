import 'package:flutter/material.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('관리자 대시보드 (임시)'),
        backgroundColor: Colors.red,
        centerTitle: true,
      ),
      body: const Center(
        child: Text('관리자 페이지입니다.', style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
