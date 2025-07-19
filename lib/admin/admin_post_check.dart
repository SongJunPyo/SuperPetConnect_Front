import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math; // min 함수 사용을 위해 추가, 필요 없다면 제거 가능
// TODO: Config 파일 임포트 추가 (서버 URL 사용)
// import '../utils/config.dart';

class AdminPostCheck extends StatefulWidget {
  const AdminPostCheck({super.key}); // Key? key -> super.key로 변경

  @override
  _AdminPostCheckState createState() => _AdminPostCheckState();
}

class _AdminPostCheckState extends State<AdminPostCheck> {
  List<dynamic> pendingPosts = [];
  bool isLoading = true;
  String errorMessage = '';
  String? token;

  @override
  void initState() {
    super.initState();
    _loadToken().then((_) => fetchPendingPosts());
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

  Future<void> fetchPendingPosts() async {
    if (token == null || token!.isEmpty) {
      // 토큰이 null이거나 비어있으면 로그인 필요
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
      final url = Uri.parse(
        'http://10.100.54.176:8002/api/v1/admin/pending-posts',
      );
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          // 'pending' 상태의 게시물만 필터링하여 보여줌 (서버 응답에 따라 조정)
          pendingPosts =
              data.where((post) {
                if (post['timeRanges'] is List) {
                  // 모든 timeRange가 approved: 1이 아니거나 is_pending: true 인 경우만 포함 (서버 응답 구조에 따라 로직 변경 필요)
                  return post['timeRanges'].any((tr) => tr['approved'] != 1);
                }
                return false;
              }).toList();
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
      print('fetchPendingPosts Error: $e'); // 자세한 오류 로깅
    }
  }

  Future<void> approveTimeRange(int timeRangeId, bool approve) async {
    if (token == null || token!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("로그인 토큰이 없어 처리할 수 없습니다.")));
      return;
    }

    try {
      // TODO: Config.serverUrl 사용으로 변경
      final url = Uri.parse(
        'http://10.100.54.176:8002/api/v1/admin/approve-time-range/$timeRangeId',
      );
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'approved': approve ? 1 : 0}), // 1 (승인) 또는 0 (거절)
      );

      if (response.statusCode == 200) {
        // 성공적으로 처리된 경우 해당 timeRange만 업데이트하거나 전체 목록 새로고침
        // 여기서는 간단하게 전체 목록을 새로고침합니다.
        fetchPendingPosts();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(approve ? "시간대가 승인되었습니다." : "시간대가 거절되었습니다.")),
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
      print('approveTimeRange Error: $e'); // 자세한 오류 로깅
    }
  }

  // 게시물 전체의 승인 상태를 반환 (timeRange들의 상태에 따라)
  // 모든 timeRange가 approved:1 이면 '승인됨', 하나라도 approved:0 이면 '대기중'
  String _getOverallPostStatus(List<dynamic> timeRanges) {
    if (timeRanges.isEmpty) return '정보 없음';
    bool allApproved = timeRanges.every((tr) => tr['approved'] == 1);
    bool anyPending = timeRanges.any(
      (tr) => tr['approved'] == 0,
    ); // 0은 대기 또는 거절

    if (allApproved) {
      return '승인 완료';
    } else if (anyPending) {
      return '승인 대기';
    } else {
      return '거절됨'; // 모든 시간대가 거절되었거나 다른 상태
    }
  }

  // 상태에 따른 색상 (병원 게시물 현황 등에서 재활용된 함수)
  Color _getStatusColor(String status) {
    switch (status) {
      case '승인 완료':
        return Colors.green;
      case '승인 대기':
        return Colors.orange;
      case '거절됨':
        return Colors.red;
      case '모집중': // 기존 병원 post status와 호환
        return Colors.blue;
      case '모집마감': // 기존 병원 post status와 호환
        return Colors.grey;
      case '대기': // 기존 병원 post status와 호환
        return Colors.orange;
      case '거절': // 기존 병원 post status와 호환
        return Colors.red;
      default:
        return Colors.black;
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
          "게시물 승인 관리",
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
            onPressed: fetchPendingPosts,
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
              : pendingPosts.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 80,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '승인 대기 중인 게시물이 없습니다.',
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
                itemCount: pendingPosts.length,
                itemBuilder: (context, index) {
                  final post = pendingPosts[index];
                  String overallStatus = _getOverallPostStatus(
                    post['timeRanges'] ?? [],
                  );

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
                                  "${post['user']?['name'] ?? '알 수 없음'} - ${post['location'] ?? '알 수 없음'}", // 병원명 대신 유저이름 표시 (DB구조에 따름)
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
                                  color: _getStatusColor(
                                    overallStatus,
                                  ).withAlpha(38), // withOpacity(0.15) 대체
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                child: Text(
                                  overallStatus,
                                  style: textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _getStatusColor(overallStatus),
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
                            "세부 시간대 승인",
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // 시간대 정보 및 승인/거절 버튼
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: List<Widget>.from(
                              (post['timeRanges'] as List<dynamic>).map((
                                timeRange,
                              ) {
                                String timeRangeStatus =
                                    timeRange['approved'] == 1 ? '승인됨' : '대기 중';
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
                                                "상태: $timeRangeStatus",
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
                                        if (timeRange['approved'] ==
                                            0) // 대기 중일 때만 버튼 표시
                                          Row(
                                            children: [
                                              SizedBox(
                                                height: 36, // 버튼 높이 통일
                                                child: ElevatedButton(
                                                  onPressed:
                                                      () => approveTimeRange(
                                                        timeRange['id'],
                                                        true,
                                                      ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors
                                                            .green, // 승인 버튼은 녹색
                                                    foregroundColor:
                                                        Colors.white,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 16,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    "승인",
                                                    style: textTheme.bodySmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.white,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              SizedBox(
                                                height: 36, // 버튼 높이 통일
                                                child: ElevatedButton(
                                                  onPressed:
                                                      () => approveTimeRange(
                                                        timeRange['id'],
                                                        false,
                                                      ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        colorScheme
                                                            .error, // 거절 버튼은 테마 에러 색상
                                                    foregroundColor:
                                                        colorScheme.onError,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 16,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    "거절",
                                                    style: textTheme.bodySmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              colorScheme
                                                                  .onError,
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

  // 상세 정보 Row를 깔끔하게 보여주는 헬퍼 위젯
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
}
