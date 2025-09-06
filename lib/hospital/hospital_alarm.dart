import 'package:flutter/material.dart';

class HospitalAlarm extends StatefulWidget {
  const HospitalAlarm({super.key});

  @override
  State createState() => _HospitalAlarmState();
}

class _HospitalAlarmState extends State<HospitalAlarm> {
  // 알림 데이터는 그대로 유지합니다.
  List<Map<String, dynamic>> alarmList = [
    {
      "title": "모집글 요청 승인",
      "content": "게시글 #1에 대한 모집 요청이 승인되었습니다.",
      "date": "2025-03-07",
      "isRead": false,
      "type": "승인",
    },
    {
      "title": "모집글 요청 거절",
      "content": "게시글 #2에 대한 모집 요청이 거절되었습니다. 사유: 조건 불충분",
      "date": "2025-03-07",
      "isRead": false,
      "type": "거절",
    },
    {
      "title": "새로운 신청 접수",
      "content": "게시글 #1에 새로운 헌혈 신청이 접수되었습니다.",
      "date": "2025-03-06",
      "isRead": true,
      "type": "신청",
    },
    {
      "title": "시스템 공지",
      "content": "시스템 점검이 예정되어 있습니다. 자세한 내용은 공지사항을 확인해주세요.",
      "date": "2025-03-05",
      "isRead": true,
      "type": "공지",
    },
    {
      "title": "모집 마감 임박",
      "content": "게시글 #3의 모집 마감이 1일 남았습니다.",
      "date": "2025-03-04",
      "isRead": true,
      "type": "알림",
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
        // 추가 액션 버튼 (예: 모두 읽음 표시, 알림 설정 등)
        actions: [
          IconButton(
            icon: Icon(Icons.check_circle_outline, color: Colors.grey[600]),
            tooltip: '모두 읽음 표시',
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
          IconButton(
            icon: Icon(Icons.settings_outlined, color: Colors.grey[600]),
            tooltip: '알림 설정',
            onPressed: () {
              // 알림 설정 페이지로 이동하는 로직
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
                ), // 좌우 여백 20, 상하 여백 16
                itemCount: alarmList.length,
                itemBuilder: (context, index) {
                  final alarm = alarmList[index];
                  final bool isRead = alarm["isRead"] as bool;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12.0), // 카드 간격
                    elevation: 1, // 더 가벼운 그림자
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Colors.grey.shade200,
                        width: 1,
                      ), // 테두리 추가
                    ),
                    color:
                        isRead
                            ? Colors.white
                            : colorScheme.primary.withValues(
                              alpha: 0.05,
                            ), // 읽지 않은 알림은 연한 배경색
                    child: InkWell(
                      // 터치 피드백을 위해 InkWell 사용
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          alarm['isRead'] = true; // 탭하면 읽음 상태로 변경
                        });
                        // 알림 내용 상세 보기 또는 해당 게시글/페이지로 이동하는 로직
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${alarm["title"]} 클릭됨: ${alarm["content"]}',
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
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
                                  color: colorScheme.primary,
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
