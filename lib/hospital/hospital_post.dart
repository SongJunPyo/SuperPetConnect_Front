import 'package:flutter/material.dart';
import 'package:interval_time_picker/interval_time_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import '../utils/config.dart';

class HospitalPost extends StatefulWidget {
  // PostCreationPage -> HospitalPost로 클래스명 변경
  const HospitalPost({super.key});

  @override
  _HospitalPostState createState() => _HospitalPostState();
}

class _HospitalPostState extends State<HospitalPost> {
  List<Map<String, dynamic>> timeEntries = [];
  DateTime selectedDate = DateTime.now();
  String selectedRegion = "울산"; // 초기값을 울산으로 변경
  String selectedType = "정기"; // 초기값을 정기로 변경
  String selectedBlood = "A형";
  String additionalDescription = ""; // nullable 제거, 빈 문자열로 초기화

  // 토큰 가져오는 함수 수정 - 디버깅 정보 추가
  Future<String> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    print(
      'Retrieved token: ${token.isNotEmpty ? "Token exists" : "Token is empty"}',
    );

    if (token.isEmpty) {
      print('No token found, please login first');
      return '';
    }
    return token;
  }

  // 사용자 정보 가져오기
  Future<Map<String, dynamic>> _getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'email': prefs.getString('user_email') ?? '',
      'name': prefs.getString('user_name') ?? '',
      'phone_number': prefs.getString('user_phone') ?? '',
      'address': prefs.getString('user_address') ?? '',
      'user_id': prefs.getInt('user_id') ?? 0,
    };
  }

  Future<void> _submitPost() async {
    if (timeEntries.isEmpty) {
      // 시간대가 없으면 경고 메시지 표시
      _showAlertDialog('알림', '최소 하나 이상의 시간대를 추가해주세요.');
      return;
    }

    try {
      final token = await _getAuthToken();
      if (token.isEmpty) {
        _showAlertDialog('로그인 필요', '로그인이 필요합니다.', () {
          Navigator.of(context).pop(); // 다이얼로그 닫기
          Navigator.pushReplacementNamed(context, '/login'); // 로그인 페이지로 이동
        });
        return;
      }

      final userInfo = await _getUserInfo();

      List<Map<String, dynamic>> timeRanges =
          timeEntries.map((entry) {
            return {"time": entry["timeRange"], "team": entry["teamNumber"]};
          }).toList();

      final postData = {
        "date":
            "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}",
        "timeRanges": timeRanges,
        "location": selectedRegion,
        "type": selectedType == "긴급" ? 1 : 2,
        "bloodType": selectedBlood,
        "description": additionalDescription,
      };

      print('Sending post data: ${json.encode(postData)}');
      print('Using token: ${token.substring(0, min(10, token.length))}...');

      final url = Uri.parse('${Config.serverUrl}/api/v1/hospital/post');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(postData),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201) {
        _showAlertDialog('성공', '게시글이 성공적으로 등록되었습니다.', () {
          Navigator.of(context).pop(); // 다이얼로그 닫기
          Navigator.of(context).pop(); // 게시글 작성 페이지 닫기
        });
      } else {
        _showAlertDialog('등록 실패', '게시글 등록에 실패했습니다: ${response.body}');
      }
    } catch (e) {
      print('Error in _submitPost: $e');
      _showAlertDialog('오류 발생', '오류가 발생했습니다: $e');
    }
  }

  // 공통 Alert Dialog 함수
  void _showAlertDialog(
    String title,
    String content, [
    VoidCallback? onOkPressed,
  ]) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onOkPressed?.call(); // 확인 버튼 콜백 실행
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "새로운 모집글 작성", // 제목 변경
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: false, // 토스처럼 왼쪽 정렬 유지
        // iconTheme은 main.dart의 AppBarTheme을 따름
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 20.0,
            vertical: 16.0,
          ), // 좌우 여백 20, 상하 여백 16
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 날짜 및 시간대 선택 섹션
              Text(
                "헌혈 일시 선택",
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "날짜: ${selectedDate.year}년 ${selectedDate.month}월 ${selectedDate.day}일",
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          OutlinedButton.icon(
                            // OutlinedButton으로 변경
                            onPressed: () async {
                              DateTime? pickedDate = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2100),
                                helpText: '헌혈 날짜 선택', // 헬프 텍스트 추가
                                confirmText: '선택',
                                cancelText: '취소',
                                builder: (context, child) {
                                  // 테마 적용
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: ColorScheme.light(
                                        primary:
                                            colorScheme
                                                .primary, // AppBar 색상과 일치
                                        onPrimary: colorScheme.onPrimary,
                                        onSurface: Colors.black87, // 텍스트 색상
                                      ),
                                      textButtonTheme: TextButtonThemeData(
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              colorScheme.primary, // 버튼 텍스트 색상
                                        ),
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (pickedDate != null) {
                                setState(() {
                                  selectedDate = pickedDate;
                                });
                              }
                            },
                            icon: Icon(Icons.calendar_today_outlined, size: 18),
                            label: const Text("날짜 선택"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colorScheme.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              side: BorderSide(
                                color: colorScheme.primary.withOpacity(0.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        // ElevatedButton.icon으로 변경
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder:
                                (context) => _TimeEntryDialog(
                                  onSave: (timeRange, teamNumber) {
                                    setState(() {
                                      timeEntries.add({
                                        "timeRange": timeRange,
                                        "teamNumber": teamNumber,
                                      });
                                    });
                                  },
                                ),
                          );
                        },
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        label: const Text("시간대 추가"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary, // 테마 색상 사용
                          foregroundColor: colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          minimumSize: const Size(double.infinity, 48), // 버튼 크기
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (timeEntries.isNotEmpty)
                        Text(
                          "추가된 시간대",
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: 8),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: timeEntries.length,
                        itemBuilder: (context, index) {
                          final entry = timeEntries[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 1, // 더 가벼운 그림자
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "${entry['timeRange']}",
                                        style: textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text("필요 팀: ${entry['teamNumber']}팀"),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.edit_outlined,
                                          color: Colors.grey[600],
                                        ),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder:
                                                (context) => _EditEntryDialog(
                                                  entry: entry,
                                                  onSave: (updatedEntry) {
                                                    setState(() {
                                                      timeEntries[index] =
                                                          updatedEntry;
                                                    });
                                                  },
                                                ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete_outline,
                                          color: colorScheme.error,
                                        ), // 삭제 아이콘 색상 변경
                                        onPressed: () {
                                          setState(() {
                                            timeEntries.removeAt(index);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32), // 섹션 간 간격
              // 기타 정보 섹션
              Text(
                "기타 정보 입력",
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // 지역 선택
                      DropdownButtonFormField<String>(
                        value: selectedRegion,
                        items:
                            [
                                  "서울",
                                  "부산",
                                  "대구",
                                  "인천",
                                  "광주",
                                  "대전",
                                  "울산",
                                  "세종",
                                  "제주",
                                  "경남",
                                ]
                                .map(
                                  (region) => DropdownMenuItem(
                                    value: region,
                                    child: Text(region),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedRegion = value ?? "울산";
                          });
                        },
                        decoration: _buildInputDecoration(
                          context,
                          "지역 선택",
                          Icons.location_on_outlined,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 타입 선택
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        items:
                            ["긴급", "정기"]
                                .map(
                                  (type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(type),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedType = value ?? "정기";
                          });
                        },
                        decoration: _buildInputDecoration(
                          context,
                          "게시글 타입",
                          Icons.category_outlined,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 혈액형 선택
                      DropdownButtonFormField<String>(
                        value: selectedBlood,
                        items:
                            [
                                  "A형",
                                  "B형",
                                  "C형",
                                  "AB형",
                                  "DEA 1.1 Negative",
                                  "기타",
                                ] // 혈액형 옵션 추가
                                .map(
                                  (type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(type),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedBlood = value ?? "A형";
                          });
                        },
                        decoration: _buildInputDecoration(
                          context,
                          "필요 혈액형",
                          Icons.bloodtype_outlined,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 추가 설명 입력
                      TextField(
                        onChanged: (value) {
                          setState(() {
                            additionalDescription = value;
                          });
                        },
                        maxLines: 4, // 여러 줄 입력 가능하도록
                        minLines: 1,
                        decoration: _buildInputDecoration(
                          context,
                          "추가 설명 (선택 사항)",
                          Icons.description_outlined,
                        ),
                        keyboardType: TextInputType.multiline, // 멀티라인 키보드 타입
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // 등록 버튼
              SizedBox(
                width: double.infinity,
                height: 56, // 버튼 높이 고정
                child: ElevatedButton(
                  onPressed: _submitPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3, // 버튼 그림자
                  ),
                  child: Text(
                    "모집글 등록하기",
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20), // 하단 여백
            ],
          ),
        ),
      ),
    );
  }

  // InputDecoration 공통 스타일
  InputDecoration _buildInputDecoration(
    BuildContext context,
    String labelText,
    IconData icon,
  ) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(icon, color: Colors.grey[600]), // 아이콘 추가
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: colorScheme.primary,
          width: 2,
        ), // 포커스 시 테마 색상
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      filled: true,
      fillColor: Colors.grey.shade50, // 아주 연한 배경색
      labelStyle: TextStyle(color: Colors.grey[700]),
    );
  }
}

class _TimeEntryDialog extends StatefulWidget {
  final Function(String timeRange, int teamNumber) onSave;

  const _TimeEntryDialog({super.key, required this.onSave}); // const 생성자 추가

  @override
  _TimeEntryDialogState createState() => _TimeEntryDialogState();
}

class _TimeEntryDialogState extends State<_TimeEntryDialog> {
  TimeOfDay startTimeOfDay = const TimeOfDay(hour: 9, minute: 0); // 기본 시작 시간
  TimeOfDay endTimeOfDay = const TimeOfDay(hour: 9, minute: 30); // 기본 종료 시간
  int teamNumber = 1;

  String get _formattedStartTime =>
      '${startTimeOfDay.hour.toString().padLeft(2, '0')}:${startTimeOfDay.minute.toString().padLeft(2, '0')}';
  String get _formattedEndTime =>
      '${endTimeOfDay.hour.toString().padLeft(2, '0')}:${endTimeOfDay.minute.toString().padLeft(2, '0')}';

  // 시간 비교 함수 (클래스 내부에 정의하여 재사용 가능하도록)
  bool _isTimeBefore(TimeOfDay time1, TimeOfDay time2) {
    int minutes1 = time1.hour * 60 + time1.minute;
    int minutes2 = time2.hour * 60 + time2.minute;
    return minutes1 < minutes2;
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showIntervalTimePicker(
      context: context,
      initialTime: isStartTime ? startTimeOfDay : endTimeOfDay,
      interval: 5, // 5분 단위로 설정
      builder: (context, child) {
        // 테마 적용
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary, // AppBar 색상과 일치
              onPrimary: Theme.of(context).colorScheme.onPrimary,
              onSurface: Colors.black87, // 텍스트 색상
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor:
                    Theme.of(context).colorScheme.primary, // 버튼 텍스트 색상
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          startTimeOfDay = picked;
          // 시작 시간 변경 시 종료 시간이 시작 시간보다 이전이면 조정
          if (_isTimeBefore(endTimeOfDay, startTimeOfDay)) {
            endTimeOfDay = TimeOfDay(
              hour: startTimeOfDay.hour,
              minute: startTimeOfDay.minute + 30,
            ); // 30분 후로 설정 예시
            if (endTimeOfDay.minute >= 60) {
              endTimeOfDay = TimeOfDay(
                hour: (endTimeOfDay.hour + 1) % 24,
                minute: endTimeOfDay.minute % 60,
              );
            }
          }
        } else {
          // 종료 시간이 시작 시간보다 이전인지 확인
          if (_isTimeBefore(picked, startTimeOfDay)) {
            _showAlertDialog('시간 오류', '종료 시간은 시작 시간보다 이후여야 합니다.');
          } else {
            endTimeOfDay = picked;
          }
        }
      });
    }
  }

  void _showAlertDialog(
    String title,
    String content, [
    VoidCallback? onOkPressed,
  ]) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onOkPressed?.call();
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text("시간대 추가", style: textTheme.titleLarge),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTimeSelectionTile(
            context,
            label: "시작 시간",
            time: _formattedStartTime,
            onTap: () => _selectTime(context, true),
          ),
          const Divider(height: 24),
          _buildTimeSelectionTile(
            context,
            label: "종료 시간",
            time: _formattedEndTime,
            onTap: () => _selectTime(context, false),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text("필요 팀 수:", style: textTheme.titleMedium),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: teamNumber,
                  items:
                      List.generate(10, (index) => index + 1)
                          .map(
                            (num) => DropdownMenuItem(
                              value: num,
                              child: Text("$num팀"),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        teamNumber = value;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
          child: const Text("취소"),
        ),
        ElevatedButton(
          onPressed: () {
            if (_isTimeBefore(endTimeOfDay, startTimeOfDay)) {
              _showAlertDialog('시간 오류', '종료 시간은 시작 시간보다 이후여야 합니다.');
              return;
            }
            widget.onSave(
              "$_formattedStartTime~$_formattedEndTime",
              teamNumber,
            );
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 2,
          ),
          child: const Text(
            "추가하기",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // 시간 선택 타일 공통 위젯
  Widget _buildTimeSelectionTile(
    BuildContext context, {
    required String label,
    required String time,
    required VoidCallback onTap,
  }) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$label: ', style: textTheme.titleMedium),
            Row(
              children: [
                Text(
                  time,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.access_time_outlined, color: Colors.grey[600]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EditEntryDialog extends StatefulWidget {
  final Map<String, dynamic> entry;
  final Function(Map<String, dynamic>) onSave;

  const _EditEntryDialog({
    super.key,
    required this.entry,
    required this.onSave,
  }); // const 생성자 추가

  @override
  State<_EditEntryDialog> createState() => _EditEntryDialogState();
}

class _EditEntryDialogState extends State<_EditEntryDialog> {
  late DateTime selectedDate;
  late TimeOfDay startTimeOfDay;
  late TimeOfDay endTimeOfDay;
  late int teamNumber;

  String get _formattedDate =>
      "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
  String get _formattedStartTime =>
      '${startTimeOfDay.hour.toString().padLeft(2, '0')}:${startTimeOfDay.minute.toString().padLeft(2, '0')}';
  String get _formattedEndTime =>
      '${endTimeOfDay.hour.toString().padLeft(2, '0')}:${endTimeOfDay.minute.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();

    // 날짜 처리 (기존 로직 그대로 유지)
    if (widget.entry['date'] != null) {
      try {
        selectedDate = DateTime.parse(widget.entry['date']);
      } catch (e) {
        selectedDate = DateTime.now();
      }
    } else {
      selectedDate = DateTime.now();
    }

    // 시간 문자열 파싱 (기존 로직 그대로 유지)
    final timeRange = widget.entry['timeRange'] ?? "00:00~00:30";
    final times = timeRange.split('~');

    startTimeOfDay = _parseTimeString(times[0]);
    endTimeOfDay = _parseTimeString(times[1]);

    teamNumber = widget.entry['teamNumber'] ?? 1;
  }

  TimeOfDay _parseTimeString(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  // 시간 비교 함수 (_TimeEntryDialogState와 동일하게 정의)
  bool _isTimeBefore(TimeOfDay time1, TimeOfDay time2) {
    int minutes1 = time1.hour * 60 + time1.minute;
    int minutes2 = time2.hour * 60 + time2.minute;
    return minutes1 < minutes2;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      helpText: '헌혈 날짜 선택',
      confirmText: '선택',
      cancelText: '취소',
      builder: (context, child) {
        // 테마 적용
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary, // AppBar 색상과 일치
              onPrimary: Theme.of(context).colorScheme.onPrimary,
              onSurface: Colors.black87, // 텍스트 색상
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor:
                    Theme.of(context).colorScheme.primary, // 버튼 텍스트 색상
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate != null) {
      setState(() {
        selectedDate = pickedDate;
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showIntervalTimePicker(
      // showTimePicker -> showIntervalTimePicker 변경
      context: context,
      initialTime: isStartTime ? startTimeOfDay : endTimeOfDay,
      interval: 5, // 5분 단위
      builder: (context, child) {
        // 테마 적용
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Theme.of(context).colorScheme.onPrimary,
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          startTimeOfDay = picked;
          // 시작 시간 변경 시 종료 시간이 시작 시간보다 이전이면 조정
          if (_isTimeBefore(endTimeOfDay, startTimeOfDay)) {
            endTimeOfDay = TimeOfDay(
              hour: startTimeOfDay.hour,
              minute: startTimeOfDay.minute + 30,
            ); // 30분 후로 설정 예시
            if (endTimeOfDay.minute >= 60) {
              endTimeOfDay = TimeOfDay(
                hour: (endTimeOfDay.hour + 1) % 24,
                minute: endTimeOfDay.minute % 60,
              );
            }
          }
        } else {
          // 종료 시간이 시작 시간보다 이전인지 확인
          if (_isTimeBefore(picked, startTimeOfDay)) {
            _showAlertDialog('시간 오류', '종료 시간은 시작 시간보다 이후여야 합니다.');
          } else {
            endTimeOfDay = picked;
          }
        }
      });
    }
  }

  void _showAlertDialog(
    String title,
    String content, [
    VoidCallback? onOkPressed,
  ]) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onOkPressed?.call();
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text("시간대 수정", style: textTheme.titleLarge),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 날짜 선택 버튼
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _selectDate(context),
              icon: Icon(Icons.calendar_today_outlined, size: 18),
              label: Text("날짜 선택: $_formattedDate"),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: BorderSide(color: colorScheme.primary.withOpacity(0.5)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildTimeSelectionTile(
            context,
            label: "시작 시간",
            time: _formattedStartTime,
            onTap: () => _selectTime(context, true),
          ),
          const Divider(height: 24),
          _buildTimeSelectionTile(
            context,
            label: "종료 시간",
            time: _formattedEndTime,
            onTap: () => _selectTime(context, false),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text("필요 팀 수:", style: textTheme.titleMedium),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: teamNumber,
                  items:
                      List.generate(10, (index) => index + 1)
                          .map(
                            (num) => DropdownMenuItem(
                              value: num,
                              child: Text("$num팀"),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        teamNumber = value;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
          child: const Text("취소"),
        ),
        ElevatedButton(
          onPressed: () {
            if (_isTimeBefore(endTimeOfDay, startTimeOfDay)) {
              _showAlertDialog('시간 오류', '종료 시간은 시작 시간보다 이후여야 합니다.');
              return;
            }
            widget.onSave({
              "date": _formattedDate, // 수정된 날짜 반영
              "timeRange": "$_formattedStartTime~$_formattedEndTime",
              "teamNumber": teamNumber,
            });
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 2,
          ),
          child: const Text(
            "저장하기",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // 시간 선택 타일 공통 위젯 (_TimeEntryDialogState와 동일)
  Widget _buildTimeSelectionTile(
    BuildContext context, {
    required String label,
    required String time,
    required VoidCallback onTap,
  }) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$label: ', style: textTheme.titleMedium),
            Row(
              children: [
                Text(
                  time,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.access_time_outlined, color: Colors.grey[600]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
