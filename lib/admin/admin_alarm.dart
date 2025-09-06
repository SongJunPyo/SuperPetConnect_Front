import 'package:flutter/material.dart';

class AdminAlarm extends StatefulWidget {
  const AdminAlarm({super.key}); // Key? key -> super.key로 변경

  @override
  State createState() => _AdminAlarmState();
}

class _AdminAlarmState extends State<AdminAlarm> {
  // 관리자 알림 목록 예시 (isRead 필드 추가)
  final List<Map<String, dynamic>> alarmList = [
    {
      "title": "새 게시글 신청",
      "content": "새로운 헌혈 모집 게시글이 등록되었습니다. 승인이 필요합니다.",
      "date": "2025-03-10",
      "isRead": false,
      "type": "게시글",
    },
    {
      "title": "회원가입 승인 요청",
      "content": "새로운 사용자의 회원가입 승인이 필요합니다.",
      "date": "2025-03-09",
      "isRead": false,
      "type": "회원가입",
    },
    {
      "title": "게시글 #1 승인 완료",
      "content": "게시글 '급구! A형 강아지 헌혈자'가 승인되었습니다.",
      "date": "2025-03-07",
      "isRead": true,
      "type": "게시글",
    },
    {
      "title": "병원 #2 정보 변경",
      "content": "행복동물병원의 프로필 정보가 업데이트되었습니다.",
      "date": "2025-03-06",
      "isRead": true,
      "type": "병원",
    },
    {
      "title": "시스템 점검 공지",
      "content": "다음 주 시스템 정기 점검이 예정되어 있습니다.",
      "date": "2025-03-05",
      "isRead": true,
      "type": "공지",
    },
    {
      "title": "사용자 #10 탈퇴",
      "content": "사용자 '김철수'님이 회원 탈퇴를 완료했습니다.",
      "date": "2025-03-04",
      "isRead": true,
      "type": "사용자",
    },
  ];

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        // main.dart의 AppBarTheme을 따름 (배경색, 그림자 등)
        title: Text(
          "알림", // 제목을 간결하게 변경
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: false, // 토스처럼 왼쪽 정렬 유지
        actions: [
          // 모두 읽음 표시 버튼
          IconButton(
            icon: Icon(
              Icons.mark_chat_read_outlined,
              color: Colors.black87,
            ), // 읽음 표시 아이콘
            tooltip: '모두 읽음으로 표시',
            onPressed: () {
              setState(() {
                for (var alarm in alarmList) {
                  alarm['isRead'] = true;
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('모든 알림을 읽음 처리했습니다.')),
              );
            },
          ),
          // 알림 설정 버튼
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: Colors.black87,
            ), // 설정 아이콘
            tooltip: '알림 설정',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('알림 설정 페이지로 이동 (미구현)')),
              );
            },
          ),
          const SizedBox(width: 8), // 오른쪽 여백
        ],
      ),
      body:
          alarmList.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_off_outlined,
                      size: 80,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '새로운 알림이 없어요.',
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
                itemCount: alarmList.length,
                itemBuilder: (context, index) {
                  final alarm = alarmList[index];
                  final bool isRead = alarm["isRead"] as bool;

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
                    color:
                        isRead
                            ? Colors.white
                            : colorScheme.primary.withAlpha(
                              13,
                            ), // Colors.blueAccent.withValues(alpha: 0.05) 대체
                    child: InkWell(
                      // 터치 피드백을 위해 InkWell 사용
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          alarm['isRead'] = true; // 탭하면 읽음 상태로 변경
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${alarm["title"]} 클릭됨: ${alarm["content"]}',
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0), // 내부 패딩
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 읽지 않은 알림 표시 (파란 점)
                            if (!isRead)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(
                                  right: 12,
                                  top: 4,
                                ), // 점과 텍스트 간격
                                decoration: BoxDecoration(
                                  color: colorScheme.primary, // 테마 주 색상
                                  shape: BoxShape.circle,
                                ),
                              )
                            else
                              const SizedBox(width: 20), // 읽은 알림은 공간만 차지하도록

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      // 알림 제목
                                      Expanded(
                                        child: Text(
                                          alarm["title"],
                                          style: textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color:
                                                isRead
                                                    ? Colors.black87
                                                    : colorScheme
                                                        .primary, // 읽지 않은 알림은 강조색
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      // 날짜
                                      Text(
                                        alarm["date"],
                                        style: textTheme.bodySmall?.copyWith(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  // 알림 내용
                                  Text(
                                    alarm["content"],
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[700],
                                      fontWeight:
                                          isRead
                                              ? FontWeight.normal
                                              : FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
