import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math; // min 함수 사용을 위해 추가
import 'package:connect/admin/admin_applicant_list_screen.dart'; // 신청자 목록 화면 임포트
import '../utils/config.dart';
import '../utils/app_theme.dart';

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

  // 필터링 상태 변수
  String selectedFilter = 'recruiting'; // 기본: 모집 진행
  String selectedDateFilter = 'registration'; // 'registration' 또는 'donation'
  DateTime? startDate;
  DateTime? endDate;

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

    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });
    }

    try {
      String requestUrl =
          '${Config.serverUrl}/api/admin/posts?status=$selectedFilter';

      // 날짜 필터 추가
      if (startDate != null) {
        final startDateStr =
            '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}';
        if (selectedDateFilter == 'registration') {
          requestUrl += '&start_registration_date=$startDateStr';
        } else {
          requestUrl += '&start_donation_date=$startDateStr';
        }
      }
      if (endDate != null) {
        final endDateStr =
            '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}';
        if (selectedDateFilter == 'registration') {
          requestUrl += '&end_registration_date=$endDateStr';
        } else {
          requestUrl += '&end_donation_date=$endDateStr';
        }
      }
      print('🚨 디버그: 실제 호출하는 URL: $requestUrl');

      final response = await http.get(
        Uri.parse(requestUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      print("서버 응답 상태 코드: ${response.statusCode}");
      print("서버 응답 내용: ${response.body}");
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            approvedPosts = data;
            isLoading = false;
          });
        }
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
      print('fetchApprovedPosts Error: $e'); // 자세한 오류 로깅
    }
  }

  // 승인 취소 함수
  Future<void> _cancelApproval(int postId, String title) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            '승인 취소',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          content: Text(
            '정말로 "$title" 게시글의 승인을 취소하시겠습니까?\n상태가 "대기"로 변경됩니다.',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('승인 취소'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      try {
        final response = await http.put(
          Uri.parse('${Config.serverUrl}/api/admin/posts/$postId/approval'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'approved': false}), // 승인 취소 = false
        );

        if (response.statusCode == 200) {
          fetchApprovedPosts(); // 목록 새로고침
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('승인이 취소되었습니다. 게시글이 대기 상태로 변경되었습니다.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('승인 취소에 실패했습니다: ${response.statusCode}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('오류가 발생했습니다: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // 게시물 상태에 따른 색상 (다른 관리자 화면에서 재활용된 함수)
  Color _getPostStatusColor(String status) {
    switch (status) {
      case '모집 진행':
        return Colors.blue;
      case '모집 마감':
        return Colors.grey;
      case '모집 대기':
        return Colors.orange;
      case '모집 거절':
        return Colors.red;
      case '모집 승인':
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
      body: Column(
        children: [
          // 필터링 UI
          _buildFilterSection(),

          // 메인 컨텐츠
          Expanded(
            child:
                isLoading
                    ? Center(
                      child: CircularProgressIndicator(
                        color: colorScheme.primary,
                      ),
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
                        // 여기서는 간단히 '모집 진행' 또는 '모집 마감'을 가정합니다.
                        String overallPostStatus = post['status'] ?? '모집 진행';

                        // 상태에 따른 테두리 색상
                        Color borderColor;
                        switch (overallPostStatus) {
                          case 'recruiting':
                          case '모집중':
                          case '모집 진행':
                            borderColor = AppTheme.primaryBlue;
                            break;
                          case 'end':
                          case '모집마감':
                          case '모집 마감':
                            borderColor = AppTheme.darkGray;
                            break;
                          case 'rejected':
                          case '거절':
                          case '모집 거절':
                            borderColor = AppTheme.error;
                            break;
                          default:
                            borderColor = AppTheme.lightGray;
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16.0),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: borderColor, width: 2),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0), // 내부 패딩
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 게시물 번호와 기본 정보 (제목, 상태)
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 게시물 번호 (원 모양)
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryBlue.withAlpha(
                                          38,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: textTheme.bodyLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryBlue,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '[${post['hospitalName'] ?? '병원'}]',
                                            style: textTheme.bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.primaryBlue,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${post['animalType'] == 'dog' ? '강아지' : '고양이'} ${post['types'] == 1 ? '긴급' : '정기'} 헌혈${post['bloodType'] != null ? ' (${post['bloodType']})' : ''}',
                                            style: textTheme.titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // 승인 취소 버튼
                                    SizedBox(
                                      height: 36,
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          final postId = post['id'];
                                          if (postId != null) {
                                            _cancelApproval(
                                              postId is int
                                                  ? postId
                                                  : int.tryParse(
                                                        postId.toString(),
                                                      ) ??
                                                      0,
                                              post['title'] ?? '제목 없음',
                                            );
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.cancel_outlined,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                        label: Text(
                                          '승인 취소',
                                          style: textTheme.bodySmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppTheme
                                                  .warning, // 병원 메인 페이지와 동일한 warning 색상
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          elevation: 1,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
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
                                  Icons.business_outlined,
                                  '병원명',
                                  post['hospitalName'] ?? 'N/A',
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
                                  '헌혈 날짜',
                                  post['date'] ?? 'N/A',
                                ),
                                _buildDetailRow(
                                  context,
                                  Icons.calendar_today_outlined,
                                  '등록 날짜',
                                  post['registrationDate'] ?? 'N/A',
                                ),
                                _buildDetailRow(
                                  context,
                                  post['animalType'] == 'dog'
                                      ? FontAwesomeIcons.dog
                                      : FontAwesomeIcons.cat,
                                  '동물 종류',
                                  post['animalType'] == 'dog' ? '강아지' : '고양이',
                                ),
                                _buildDetailRow(
                                  context,
                                  Icons.bloodtype_outlined,
                                  '게시글 유형',
                                  post['types'] == 1 ? '긴급' : '정기',
                                ),
                                _buildDetailRow(
                                  context,
                                  Icons.bloodtype_outlined,
                                  '혈액형',
                                  post['bloodType'] ?? 'N/A',
                                ),
                                _buildDetailRow(
                                  context,
                                  Icons.group_outlined,
                                  '신청자 수',
                                  '${post['applicantCount'] ?? 0}명',
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
                                  "시간대별 신청자 현황",
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
                                      // 승인된 게시글이므로 모든 시간대를 표시
                                      String timeRangeStatus = '승인됨';
                                      Color timeRangeStatusColor = Colors.green;

                                      return Card(
                                        margin: const EdgeInsets.only(
                                          bottom: 8.0,
                                        ),
                                        elevation: 0.5, // 더 가벼운 그림자
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
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
                                                      "신청자 수: ${timeRange['team'] ?? 'N/A'}팀",
                                                      style:
                                                          textTheme.bodyMedium,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // 신청자 확인 버튼 (오른쪽 배치)
                                              SizedBox(
                                                height: 36,
                                                child: ElevatedButton.icon(
                                                  onPressed:
                                                      timeRange['id'] != null
                                                          ? () {
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder:
                                                                    (
                                                                      context,
                                                                    ) => ApplicantListScreen(
                                                                      timeRangeId:
                                                                          timeRange['id'],
                                                                    ),
                                                              ),
                                                            );
                                                          }
                                                          : null,
                                                  icon: const Icon(
                                                    Icons.group_outlined,
                                                    size: 16,
                                                    color: Colors.white,
                                                  ),
                                                  label: Text(
                                                    "신청자 확인",
                                                    style: textTheme.bodySmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.white,
                                                        ),
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        AppTheme.primaryBlue,
                                                    foregroundColor:
                                                        Colors.white,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                    ),
                                                    elevation: 1,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 6,
                                                        ),
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
          ),
        ],
      ),
    );
  }

  // 필터링 섹션 빌드
  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상태 필터 버튼 (균등 배치)
          Row(
            children: [
              Expanded(
                child: _buildFilterButton(
                  '모집 진행',
                  'recruiting',
                  AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterButton('모집 마감', 'end', AppTheme.darkGray),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterButton('모집 거절', 'rejected', AppTheme.error),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 날짜 필터 타입 선택
          Row(
            children: [
              Expanded(child: _buildDateFilterButton('등록 기준', 'registration')),
              const SizedBox(width: 8),
              Expanded(child: _buildDateFilterButton('헌혈 기준', 'donation')),
            ],
          ),
          const SizedBox(height: 12),
          // 날짜 필터
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectDate(true), // 시작일
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        startDate != null
                            ? '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}'
                            : '검색 시작일',
                        style: TextStyle(
                          color:
                              startDate != null
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade600,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectDate(false), // 종료일
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        endDate != null
                            ? '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}'
                            : '검색 종료일',
                        style: TextStyle(
                          color:
                              endDate != null
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade600,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 돋보기 아이콘 (검색)
              Container(
                width: 44,
                height: 44,
                child: ElevatedButton(
                  onPressed: fetchApprovedPosts,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.zero,
                    elevation: 1,
                  ),
                  child: const Icon(Icons.search, size: 20),
                ),
              ),
              const SizedBox(width: 8),
              // X 버튼 (초기화)
              Container(
                width: 44,
                height: 44,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      startDate = null;
                      endDate = null;
                    });
                    fetchApprovedPosts();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.zero,
                    elevation: 0,
                  ),
                  child: const Icon(Icons.close, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 필터 버튼 빌드
  Widget _buildFilterButton(String text, String value, Color color) {
    final isSelected = selectedFilter == value;
    return SizedBox(
      height: 40, // 고정 높이
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            selectedFilter = value;
          });
          fetchApprovedPosts();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? color : Colors.white,
          foregroundColor: isSelected ? Colors.white : color,
          side: BorderSide(color: color, width: 1.5),
          elevation: isSelected ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // 날짜 필터 버튼 빌드
  Widget _buildDateFilterButton(String text, String value) {
    final isSelected = selectedDateFilter == value;
    return SizedBox(
      height: 36,
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            selectedDateFilter = value;
            // 날짜 필터 타입이 바뀌면 선택된 날짜 초기화
            startDate = null;
            endDate = null;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? AppTheme.success : Colors.white,
          foregroundColor: isSelected ? Colors.white : AppTheme.success,
          side: BorderSide(color: AppTheme.success, width: 1.5),
          elevation: isSelected ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // 날짜 선택
  Future<void> _selectDate(bool isStartDate) async {
    DateTime? picked;

    try {
      picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppTheme.primaryBlue,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black87,
              ),
            ),
            child: child!,
          );
        },
      );
    } catch (e) {
      print('Date picker error: $e');
      return;
    }

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          startDate = picked;
          // 시작일이 종료일보다 늦으면 종료일 초기화
          if (endDate != null && picked!.isAfter(endDate!)) {
            endDate = null;
          }
        } else {
          // 종료일이 시작일보다 빠르면 시작일 초기화
          if (startDate != null && picked!.isBefore(startDate!)) {
            startDate = null;
          }
          endDate = picked;
        }
      });
      // 날짜 선택 후 자동으로 검색하지 않고 돋보기 버튼을 눌러야 검색
      // fetchApprovedPosts(); // 주석 처리
    }
  }
}
