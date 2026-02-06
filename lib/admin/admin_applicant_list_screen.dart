import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/config.dart';
import '../models/applicant_model.dart';
import '../widgets/applicant_card.dart';

class ApplicantListScreen extends StatefulWidget {
  final int timeRangeId; // 특정 timeRange에 대한 신청자 목록을 가져오기 위한 ID

  const ApplicantListScreen({
    super.key,
    required this.timeRangeId,
  }); // Key? key -> super.key로 변경

  @override
  State createState() => _ApplicantListScreenState();
}

class _ApplicantListScreenState extends State<ApplicantListScreen> {
  List<ApplicantInfo> applicants = [];
  bool isLoading = true;
  String errorMessage = '';
  String? token; // JWT 토큰을 저장할 변수

  @override
  void initState() {
    super.initState();
    _loadToken().then((_) => fetchApplicants()); // 토큰 로드 후 신청자 목록 가져오기
  }

  // SharedPreferences에서 토큰 로드
  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString('auth_token');
    setState(() {
      token = storedToken;
    });
  }

  // API에서 신청자 목록 가져오기
  Future<void> fetchApplicants() async {
    if (token == null || token!.isEmpty) {
      setState(() {
        errorMessage = '로그인이 필요합니다. (토큰 없음)';
        isLoading = false;
      });

      // Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final url = Uri.parse(
        '${Config.serverUrl}/api/admin/time-slots/${widget.timeRangeId}/applicants',
      );
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token', // JWT 토큰 포함
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          applicants =
              data
                  .map((applicantJson) => ApplicantInfo.fromJson(applicantJson))
                  .toList();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage =
              '신청자 목록을 불러오는데 실패했습니다: ${response.statusCode}\n${utf8.decode(response.bodyBytes)}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = '오류가 발생했습니다: $e';
        isLoading = false;
      });
    }
  }

  // 신청자 상태 업데이트 (승인/거절)
  Future<void> updateApplicantStatus(int applicantId, int status) async {
    if (token == null || token!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("로그인 토큰이 없어 처리할 수 없습니다.")));
      return;
    }

    try {
      final url = Uri.parse(
        '${Config.serverUrl}/api/admin/applicant/$applicantId/status',
      );
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token', // JWT 토큰 포함
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': status}),
      );

      if (response.statusCode == 200) {
        fetchApplicants(); // 목록 새로고침
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(status == 1 ? "신청자가 승인되었습니다." : "신청자가 거절되었습니다."),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "처리 실패: ${response.statusCode}\n${utf8.decode(response.bodyBytes)}",
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("오류 발생: $e")));
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        // main.dart의 AppBarTheme을 따름
        title: Text(
          "신청자 목록",
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: false, // 왼쪽 정렬
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_outlined,
              color: Colors.black87,
            ), // 아웃라인 아이콘
            tooltip: '새로고침',
            onPressed: fetchApplicants,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body:
          isLoading
              ? Center(
                child: CircularProgressIndicator(color: colorScheme.primary),
              )
              : errorMessage.isNotEmpty
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 60,
                        color: colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '데이터를 불러오는데 실패했습니다.',
                        style: textTheme.titleMedium?.copyWith(
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        errorMessage,
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
              : applicants.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.group_off_outlined,
                      size: 80,
                      color: Colors.grey[300],
                    ), // 신청자 없음 아이콘
                    const SizedBox(height: 16),
                    Text(
                      '해당 게시물에 신청자가 없습니다.',
                      style: textTheme.titleMedium?.copyWith(
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 16.0,
                ),
                itemCount: applicants.length,
                itemBuilder: (context, index) {
                  final applicant = applicants[index];
                  return ApplicantCard(
                    applicant: applicant,
                    onApprove: () => updateApplicantStatus(applicant.id, 1),
                    onReject: () => updateApplicantStatus(applicant.id, 2),
                  );
                },
              ),
    );
  }
}
