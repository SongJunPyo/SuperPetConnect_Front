import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math; // min 함수 사용을 위해 추가, 필요 없다면 제거 가능
import '../utils/config.dart';
import '../utils/app_theme.dart';

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
    
    // 디버깅 정보 개선
    if (storedToken != null && storedToken.isNotEmpty) {
      print("토큰 로드 성공: ${storedToken.substring(0, math.min(20, storedToken.length))}...");
      print("토큰 길이: ${storedToken.length}");
    } else {
      print("토큰이 없거나 비어있음");
      // 저장된 다른 사용자 정보도 확인
      print("저장된 사용자 이메일: ${prefs.getString('user_email') ?? '없음'}");
      print("저장된 사용자 이름: ${prefs.getString('user_name') ?? '없음'}");
    }
    
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
      return;
    }

    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });
    }

    try {
      // 서버 측에서 제공한 새로운 API 엔드포인트 사용
      final url = Uri.parse('${Config.serverUrl}/api/admin/posts?status=wait_to_approved');
      
      print('API 요청 URL: $url');
      print('요청 헤더 - Authorization: Bearer ${token?.substring(0, math.min(20, token?.length ?? 0))}...');
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('API 응답 상태: ${response.statusCode}');
      print('API 응답 내용: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        print('게시글 목록 조회 성공: ${data.length}개의 대기 중인 게시글');
        if (mounted) {
          setState(() {
            // 서버에서 이미 대기 상태만 필터링해서 보내주므로 그대로 사용
            pendingPosts = data is List ? data : [];
            isLoading = false;
          });
        }
      } else if (response.statusCode == 401) {
        if (mounted) {
          setState(() {
            errorMessage = '인증이 만료되었습니다. 다시 로그인해주세요.';
            isLoading = false;
          });
        }
        print('401 인증 오류 - 토큰: ${token?.substring(0, math.min(10, token?.length ?? 0))}...');
      } else {
        if (mounted) {
          setState(() {
            errorMessage =
                '게시물 목록을 불러오는데 실패했습니다: ${response.statusCode}\n${utf8.decode(response.bodyBytes)}';
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = '오류가 발생했습니다: $e';
          isLoading = false;
        });
      }
      print('fetchPendingPosts Error: $e'); // 자세한 오류 로깅
    }
  }

  // 승인/거절 확인 팝업 표시
  Future<void> _showConfirmDialog(int postId, bool approve, String title) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            approve ? '게시글 승인' : '게시글 거절',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: approve ? Colors.green : Colors.red,
            ),
          ),
          content: Text(
            '정말로 "${title}" 게시글을 ${approve ? '승인' : '거절'}하시겠습니까?',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                '취소',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: approve ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(approve ? '승인' : '거절'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      approvePost(postId, approve);
    }
  }

  // 게시글 전체 승인/거부 함수로 변경
  Future<void> approvePost(int postId, bool approve) async {
    if (token == null || token!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("로그인 토큰이 없어 처리할 수 없습니다.")));
      return;
    }

    try {
      // 서버 측에서 제공한 새로운 API 엔드포인트 사용
      final url = Uri.parse('${Config.serverUrl}/api/admin/posts/$postId/approval');
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'approved': approve}),
      );

      print('승인 API 응답 상태: ${response.statusCode}');
      print('승인 API 응답 내용: ${response.body}');

      if (response.statusCode == 200) {
        // 성공적으로 처리된 경우 전체 목록 새로고침
        fetchPendingPosts();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? "게시글이 승인되었습니다." : "게시글이 거절되었습니다."),
            backgroundColor: approve ? Colors.green : Colors.orange,
          ),
        );
      } else if (response.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("인증이 만료되었습니다. 다시 로그인해주세요."),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "처리 실패: ${response.statusCode}\n${utf8.decode(response.bodyBytes)}",
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("오류 발생: $e")));
      print('approvePost Error: $e'); // 자세한 오류 로깅
    }
  }

  // 게시물 상태를 반환 (서버에서 제공하는 status 필드 사용)
  String _getPostStatus(String? status) {
    switch (status) {
      case '대기':
        return '승인 대기';
      case '승인':
        return '승인 완료';
      case '거절':
        return '거절됨';
      case '모집중':
        return '모집중';
      case '모집마감':
        return '모집마감';
      default:
        return '알 수 없음';
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
                  print('🚨 디버그: 게시글 데이터 - ${post.toString()}');
                  String postStatus = _getPostStatus(post['status']);
                  
                  // 동물 종류 표시를 위한 변환
                  String animalTypeKorean = '';
                  if (post['animalType'] == 'dog') {
                    animalTypeKorean = '강아지';
                  } else if (post['animalType'] == 'cat') {
                    animalTypeKorean = '고양이';
                  }
                  
                  // 게시글 타입 표시를 위한 변환
                  String postType = post['types'] == 1 ? '긴급' : '정기';

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
                          // 게시물 번호와 기본 정보 (제목, 상태)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 게시물 번호
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12.0,
                                  vertical: 8.0,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withAlpha(38),
                                  borderRadius: BorderRadius.circular(20.0),
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  post['title'] ?? '제목 없음',
                                  style: textTheme.titleLarge?.copyWith(
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
                                    postStatus,
                                  ).withAlpha(38),
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                child: Text(
                                  postStatus,
                                  style: textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _getStatusColor(postStatus),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // 기타 상세 정보
                          _buildDetailRow(
                            context,
                            Icons.business_outlined,
                            '병원명',
                            post['hospital_name'] ?? 'N/A',
                          ),
                          _buildDetailRow(
                            context,
                            Icons.location_on_outlined,
                            '위치',
                            post['location'] ?? 'N/A',
                          ),
                          _buildDetailRow(
                            context,
                            Icons.calendar_today_outlined,
                            '요청일',
                            post['created_at'] ?? 'N/A',
                          ),
                          _buildDetailRow(
                            context,
                            Icons.pets_outlined,
                            '동물 종류',
                            animalTypeKorean.isNotEmpty ? animalTypeKorean : 'N/A',
                          ),
                          _buildDetailRow(
                            context,
                            Icons.category_outlined,
                            '게시글 타입',
                            postType,
                          ),
                          if (post['blood_type'] != null && post['blood_type'].toString().isNotEmpty)
                            _buildDetailRow(
                              context,
                              Icons.bloodtype_outlined,
                              '혈액형',
                              post['blood_type'] ?? 'N/A',
                            ),
                          _buildDetailRow(
                            context,
                            Icons.group_outlined,
                            '신청자 수',
                            '${post['applicant_count'] ?? 0}명',
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
                            "시간대 정보",
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // 시간대 정보 표시
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: List<Widget>.from(
                              (post['timeRanges'] as List<dynamic>? ?? []).map((
                                timeRange,
                              ) {
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8.0),
                                  elevation: 0.5,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Row(
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
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          
                          // 게시글 전체 승인/거절 버튼
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    final postId = post['id'];
                                    if (postId != null) {
                                      _showConfirmDialog(
                                        postId is int ? postId : int.tryParse(postId.toString()) ?? 0, 
                                        true, 
                                        post['title'] ?? '제목 없음'
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('게시글 ID가 올바르지 않습니다.')),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: Text(
                                    "게시글 승인",
                                    style: textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    final postId = post['id'];
                                    if (postId != null) {
                                      _showConfirmDialog(
                                        postId is int ? postId : int.tryParse(postId.toString()) ?? 0, 
                                        false, 
                                        post['title'] ?? '제목 없음'
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('게시글 ID가 올바르지 않습니다.')),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colorScheme.error,
                                    foregroundColor: colorScheme.onError,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: Text(
                                    "게시글 거절",
                                    style: textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onError,
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
