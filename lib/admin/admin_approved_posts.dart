import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math; // min 함수 사용을 위해 추가
import 'package:connect/admin/admin_applicant_list_screen.dart'; // 신청자 목록 화면 임포트
// TODO: Config 파일 임포트 추가 (서버 URL 사용)
// import '../utils/config.dart';

class AdminApprovedPostsScreen extends StatefulWidget {
  const AdminApprovedPostsScreen({super.key}); // Key? key -> super.key로 변경

  @override
  _AdminApprovedPostsScreenState createState() =>
      _AdminApprovedPostsScreenState();
}

class _AdminApprovedPostsScreenState extends State<AdminApprovedPostsScreen> {
  List<dynamic> approvedPosts = [];
  bool isLoading = true;
  String errorMessage = '';
  String? token;

  @override
  void initState() {
    super.initState();
    _loadToken().then((_) => fetchApprovedPosts());
  }

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

  Future<void> fetchApprovedPosts() async {
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
      // TODO: Config.serverUrl 사용으로 변경
      final response = await http.get(
        Uri.parse('http://10.100.54.176:8002/api/v1/admin/approved-posts'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      print("서버 응답 상태 코드: ${response.statusCode}");
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          approvedPosts = data;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage =
              '게시물 목록을 불러오는데 실패했습니다: ${response.statusCode}\n${utf8.decode(response.bodyBytes)}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = '오류가 발생했습니다: $e';
        isLoading = false;
      });
      print('fetchApprovedPosts Error: $e'); // 자세한 오류 로깅
    }
  }

  // 게시물 상태에 따른 색상 (다른 관리자 화면에서 재활용된 함수)
  Color _getPostStatusColor(String status) {
    switch (status) {
      case '모집중':
        return Colors.blue;
      case '모집마감':
        return Colors.grey;
      case '대기':
        return Colors.orange;
      case '거절':
        return Colors.red;
      case '승인됨': // '승인됨' 상태 추가 (timeRange approved:1)
        return Colors.green;
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
          "게시글 현황 관리",
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
            onPressed: fetchApprovedPosts,
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
              : approvedPosts.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 80,
                      color: Colors.grey[300],
                    ), // 게시물 없음 아이콘
                    const SizedBox(height: 16),
                    Text(
                      '현재 승인된 게시물이 없습니다.',
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
                itemCount: approvedPosts.length,
                itemBuilder: (context, index) {
                  final post = approvedPosts[index];
                  // 게시물의 전체 상태를 결정 (예: 모든 timeRange가 모집마감이면 '모집마감')
                  // 여기서는 간단히 '모집중' 또는 '모집마감'을 가정합니다.
                  String overallPostStatus =
                      post['status'] ?? '모집중'; // TODO: 실제 서버 응답에 따라 상태 로직 구현

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    elevation: 2, // 카드 그림자
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16), // 둥근 모서리
                      side: BorderSide(
                        color: Colors.grey.shade200,
                        width: 1,
                      ), // 테두리 추가
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0), // 내부 패딩
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 게시물 기본 정보 (제목, 상태)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  "${post['user']['name'] ?? '알 수 없음'} - ${post['location'] ?? '알 수 없음'}", // 병원명 대신 유저이름 표시 (DB구조에 따름)
                                  style: textTheme.titleLarge?.copyWith(
                                    // 제목 스타일 변경
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 10),
                              // 전체 게시물 상태 태그
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10.0,
                                  vertical: 6.0,
                                ),
                                decoration: BoxDecoration(
                                  color: _getPostStatusColor(
                                    overallPostStatus,
                                  ).withAlpha(38), // withOpacity(0.15) 대체
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                child: Text(
                                  overallPostStatus,
                                  style: textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _getPostStatusColor(
                                      overallPostStatus,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // 기타 상세 정보
                          _buildDetailRow(
                            context,
                            Icons.calendar_today_outlined,
                            '요청일',
                            post['date'] ?? 'N/A',
                          ),
                          _buildDetailRow(
                            context,
                            Icons.pets_outlined,
                            '유형',
                            post['type'] ?? 'N/A',
                          ),
                          _buildDetailRow(
                            context,
                            Icons.bloodtype_outlined,
                            '혈액형',
                            post['bloodType'] ?? 'N/A',
                          ),
                          if (post['description'] != null &&
                              post['description'].toString().isNotEmpty)
                            _buildDetailRow(
                              context,
                              Icons.description_outlined,
                              '설명',
                              post['description'] ?? 'N/A',
                            ),

                          const SizedBox(height: 24),
                          Text(
                            "승인된 시간대별 신청자 현황",
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // 시간대 정보 및 신청자 확인 버튼
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: List<Widget>.from(
                              (post['timeRanges'] as List<dynamic>).map((
                                timeRange,
                              ) {
                                // 'approved' 필드가 1인 시간대만 표시 (승인된 게시물 현황이므로)
                                if (timeRange['approved'] != 1) {
                                  return const SizedBox.shrink(); // 승인되지 않은 시간대는 숨김
                                }

                                String timeRangeStatus =
                                    timeRange['approved'] == 1
                                        ? '승인됨'
                                        : '대기 중'; // 이 화면에서는 항상 '승인됨'
                                Color timeRangeStatusColor =
                                    timeRange['approved'] == 1
                                        ? Colors.green
                                        : Colors.orange;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8.0),
                                  elevation: 0.5, // 더 가벼운 그림자
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "시간: ${timeRange['time'] ?? 'N/A'}",
                                                style: textTheme.bodyLarge
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                              Text(
                                                "필요 팀 수: ${timeRange['team'] ?? 'N/A'}팀",
                                                style: textTheme.bodyMedium,
                                              ),
                                              Text(
                                                "현재 상태: $timeRangeStatus",
                                                style: textTheme.bodyMedium
                                                    ?.copyWith(
                                                      color:
                                                          timeRangeStatusColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // 신청자 확인 버튼
                                        SizedBox(
                                          height: 36, // 버튼 높이 통일
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              // 해당 timeRangeId의 신청자 목록 화면으로 이동
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (context) =>
                                                          ApplicantListScreen(
                                                            timeRangeId:
                                                                timeRange['id'],
                                                          ),
                                                ),
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.group_outlined,
                                              size: 18,
                                            ), // 신청자 아이콘
                                            label: Text(
                                              "신청자 확인",
                                              style: textTheme.bodySmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  colorScheme
                                                      .primary, // 테마 주 색상
                                              foregroundColor:
                                                  colorScheme.onPrimary,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              elevation: 2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),
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
