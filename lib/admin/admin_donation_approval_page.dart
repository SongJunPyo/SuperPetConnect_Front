// admin/admin_donation_approval_page.dart

import 'package:flutter/material.dart';
import '../services/admin_donation_approval_service.dart';
import '../utils/app_theme.dart';
import '../widgets/pet_profile_image.dart';
import 'package:intl/intl.dart';

class AdminDonationApprovalPage extends StatefulWidget {
  const AdminDonationApprovalPage({super.key});

  @override
  State<AdminDonationApprovalPage> createState() =>
      _AdminDonationApprovalPageState();
}

class _AdminDonationApprovalPageState extends State<AdminDonationApprovalPage> {
  DateTime selectedDate = DateTime.now();
  bool isLoading = false;
  Map<String, dynamic>? pendingData;
  Map<String, dynamic>? statsData;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadStats();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final result = await AdminDonationApprovalService.getPendingByDate(
        selectedDate,
      );
      if (result['success']) {
        setState(() {
          pendingData = result;
        });
      } else {
        _showError(result['message'] ?? '데이터 로드 실패');
      }
    } catch (e) {
      _showError('데이터 로드 중 오류: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadStats() async {
    try {
      final result = await AdminDonationApprovalService.getApprovalStats();
      if (result['success']) {
        setState(() {
          statsData = result;
        });
      }
    } catch (e) {
      // 통계 로딩 실패는 무시 (페이지 기본 기능에 영향 없음)
    }
  }

  Future<void> _processFinalApproval(int postTimesIdx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('최종 승인 확인'),
            content: const Text('해당 시간대를 최종 완료 처리하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: const Text('확인'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    setState(() {
      isLoading = true;
    });

    try {
      final result = await AdminDonationApprovalService.finalApproval(
        postTimesIdx: postTimesIdx,
      );

      if (result['success']) {
        _showSuccess(
          '${result['message']}\n처리된 신청: ${result['affected_applications']}건',
        );
        _loadData(); // 데이터 새로고침
        _loadStats(); // 통계 새로고침
      } else {
        _showError(result['message'] ?? '처리 실패');
      }
    } catch (e) {
      _showError('처리 중 오류: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('헌혈 최종 승인 관리'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 통계 카드
          if (statsData != null)
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '승인 대기 현황',
                        style: AppTheme.h3Style.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            '오늘 완료 대기',
                            statsData!['todayPendingCompletions'].toString(),
                            AppTheme.primaryBlue,
                          ),
                          _buildStatItem(
                            '전체 대기중',
                            (statsData!['totalPendingCompletions'] ?? 0)
                                .toString(),
                            Colors.purple,
                          ),
                          _buildStatItem(
                            '오늘 처리 완료',
                            (statsData!['todayProcessed'] ?? 0).toString(),
                            AppTheme.success,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 날짜 선택
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      selectedDate = selectedDate.subtract(
                        const Duration(days: 1),
                      );
                    });
                    _loadData();
                  },
                  icon: const Icon(Icons.chevron_left),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 30),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (picked != null) {
                      setState(() {
                        selectedDate = picked;
                      });
                      _loadData();
                    }
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    DateFormat('yyyy년 MM월 dd일').format(selectedDate),
                    style: AppTheme.bodyLargeStyle.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      selectedDate = selectedDate.add(const Duration(days: 1));
                    });
                    _loadData();
                  },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),

          // 시간대별 대기 목록
          Expanded(
            child:
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildPendingList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: AppTheme.h2Style.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppTheme.spacing4),
        Text(
          label,
          style: AppTheme.bodySmallStyle.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPendingList() {
    if (pendingData == null || pendingData!['pendingByTimeSlot'] == null) {
      return const Center(child: Text('승인 대기중인 헌혈이 없습니다.'));
    }

    final timeSlots = pendingData!['pendingByTimeSlot'] as List;

    if (timeSlots.isEmpty) {
      return const Center(child: Text('승인 대기중인 헌혈이 없습니다.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      itemCount: timeSlots.length,
      itemBuilder: (context, index) {
        final slot = timeSlots[index];
        final postTimesIdx = slot['post_times_idx'];
        // 백엔드 동기화 2026-04-29: time → donation_time / donation_date 분리
        final donationTime = slot['donation_time'] ?? '';
        final postTitle = slot['post_title'] ?? '';
        final hospitalName = slot['hospital_name'] ?? '';
        final pendingCompletions = slot['pending_completions'] ?? 0;
        final applications = slot['applications'] ?? [];

        return Card(
          margin: const EdgeInsets.only(bottom: AppTheme.spacing16),
          child: ExpansionTile(
            title: Text(
              '$donationTime - $postTitle',
              style: AppTheme.bodyLargeStyle.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              '$hospitalName | 완료대기: $pendingCompletions',
            ),
            children: [
              // 신청자 목록
              if (applications.isNotEmpty)
                ...applications.map<Widget>((app) {
                  final petName = app['pet_name'] ?? '이름 없음';
                  final bloodVolume = app['blood_volume'];

                  return ListTile(
                    leading: PetProfileImage(
                      profileImage: app['pet_profile_image'],
                      species: app['pet_species'],
                      radius: 20,
                    ),
                    title: Text(petName),
                    subtitle: Text(
                      '완료대기 - 헌혈량: ${bloodVolume}mL',
                    ),
                  );
                }).toList(),

              // 승인 버튼
              if (pendingCompletions > 0)
                Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  child: Center(
                    child: ElevatedButton.icon(
                      onPressed: () => _processFinalApproval(postTimesIdx),
                      icon: const Icon(Icons.check_circle),
                      label: Text('완료 승인 ($pendingCompletions건)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
