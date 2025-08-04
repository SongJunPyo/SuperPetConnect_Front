import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math; // min 함수 사용을 위해 추가
import '../utils/config.dart';

// 신청자 데이터 모델
class Applicant {
  final int id;
  final String name;
  final String contact;
  final String dogInfo;
  final String lastDonationDate;
  final int approvalCount; // 총 헌혈 승인 횟수
  int status; // 0: 대기, 1: 승인, 2: 거절, 3: 취소 (사용자 측에서 취소)

  Applicant({
    required this.id,
    required this.name,
    required this.contact,
    required this.dogInfo,
    required this.lastDonationDate,
    required this.approvalCount,
    required this.status,
  });

  factory Applicant.fromJson(Map<String, dynamic> json) {
    return Applicant(
      id: json['id'],
      name: json['name'],
      contact: json['contact'],
      dogInfo: json['dog_info'],
      lastDonationDate: json['last_donation_date'],
      approvalCount: json['approval_count'],
      status: json['status'], // 서버에서 넘어오는 status 그대로 사용 (0, 1, 2, 3)
    );
  }
}

class ApplicantListScreen extends StatefulWidget {
  final int timeRangeId; // 특정 timeRange에 대한 신청자 목록을 가져오기 위한 ID

  const ApplicantListScreen({
    super.key,
    required this.timeRangeId,
  }); // Key? key -> super.key로 변경

  @override
  _ApplicantListScreenState createState() => _ApplicantListScreenState();
}

class _ApplicantListScreenState extends State<ApplicantListScreen> {
  List<Applicant> applicants = [];
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
    print(
      "불러온 토큰: ${storedToken?.substring(0, math.min(10, storedToken.length)) ?? '없음'}...",
    ); // 디버그 출력 간결화
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
      // TODO: 로그인 페이지로 강제 이동 로직 추가 (필요 시)
      // Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final url = Uri.parse(
        '${Config.serverUrl}/api/admin/time-range/${widget.timeRangeId}/applicants',
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
                  .map((applicantJson) => Applicant.fromJson(applicantJson))
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
      print('fetchApplicants Error: $e'); // 자세한 오류 로깅
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 1 ? "신청자가 승인되었습니다." : "신청자가 거절되었습니다."),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "처리 실패: ${response.statusCode}\n${utf8.decode(response.bodyBytes)}",
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("오류 발생: $e")));
      print('updateApplicantStatus Error: $e');
    }
  }

  // 상태 코드에 따른 텍스트 반환
  String getStatusText(int status) {
    switch (status) {
      case 0:
        return '대기';
      case 1:
        return '승인';
      case 2:
        return '거절';
      case 3:
        return '취소'; // 사용자 측에서 취소
      default:
        return '알 수 없음';
    }
  }

  // 상태 코드에 따른 색상 반환
  Color getStatusColor(int status) {
    switch (status) {
      case 0:
        return Colors.orange; // 대기
      case 1:
        return Colors.green; // 승인
      case 2:
        return Colors.red; // 거절
      case 3:
        return Colors.grey; // 취소
      default:
        return Colors.black;
    }
  }

  // 상세 정보 Row를 깔끔하게 보여주는 헬퍼 위젯 (다른 관리자 화면에서 재활용)
  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyMedium?.copyWith(color: Colors.black87),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
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
                ), // 여백 통일
                itemCount: applicants.length,
                itemBuilder: (context, index) {
                  final applicant = applicants[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12.0), // 카드 간격
                    elevation: 1, // 더 가벼운 그림자
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12), // 둥근 모서리
                      side: BorderSide(
                        color: Colors.grey.shade200,
                        width: 1,
                      ), // 테두리 추가
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0), // 내부 패딩
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 신청자 이름 및 상태 태그
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  applicant.name,
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 4.0,
                                ),
                                decoration: BoxDecoration(
                                  color: getStatusColor(
                                    applicant.status,
                                  ).withAlpha(38), // withOpacity(0.15) 대체
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                child: Text(
                                  getStatusText(applicant.status),
                                  style: textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: getStatusColor(applicant.status),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // 신청자 상세 정보
                          _buildDetailRow(
                            context,
                            Icons.phone_outlined,
                            '연락처',
                            applicant.contact,
                          ),
                          _buildDetailRow(
                            context,
                            Icons.pets_outlined,
                            '반려동물',
                            applicant.dogInfo,
                          ),
                          _buildDetailRow(
                            context,
                            Icons.calendar_today_outlined,
                            '직전 헌혈일',
                            applicant.lastDonationDate,
                          ),
                          _buildDetailRow(
                            context,
                            Icons.favorite_border_outlined,
                            '총 승인 횟수',
                            '${applicant.approvalCount}회',
                          ),

                          const SizedBox(height: 16), // 정보와 버튼 사이 간격
                          // 승인/거절 버튼 (대기 상태일 때만 표시)
                          if (applicant.status == 0) // 0: 대기 상태일 때만 버튼 표시
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceAround, // 버튼 간격 균등 분배
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    // 버튼 높이 고정
                                    height: 40,
                                    child: ElevatedButton(
                                      onPressed:
                                          () => updateApplicantStatus(
                                            applicant.id,
                                            1,
                                          ), // 1: 승인
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        elevation: 2,
                                      ),
                                      child: Text(
                                        "승인",
                                        style: textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12), // 버튼 사이 간격
                                Expanded(
                                  child: SizedBox(
                                    // 버튼 높이 고정
                                    height: 40,
                                    child: ElevatedButton(
                                      onPressed:
                                          () => updateApplicantStatus(
                                            applicant.id,
                                            2,
                                          ), // 2: 거절
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: colorScheme.error,
                                        foregroundColor: colorScheme.onError,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        elevation: 2,
                                      ),
                                      child: Text(
                                        "거절",
                                        style: textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
