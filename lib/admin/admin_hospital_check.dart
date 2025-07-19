import 'package:flutter/material.dart';

// 병원 데이터 모델은 그대로 유지합니다.
class Hospital {
  final String id;
  final String name;
  final String address;
  final String phoneNumber;
  final String registrationDate;
  final String manager;
  final int donationCount;
  String status; // 승인, 대기, 거절, 중단

  Hospital({
    required this.id,
    required this.name,
    required this.address,
    required this.phoneNumber,
    required this.registrationDate,
    required this.manager,
    required this.donationCount,
    required this.status,
  });
}

// 관리자용 병원 관리 화면
class AdminHospitalCheck extends StatefulWidget {
  const AdminHospitalCheck({super.key}); // Key? key -> super.key로 변경

  @override
  _AdminHospitalCheckState createState() => _AdminHospitalCheckState();
}

class _AdminHospitalCheckState extends State<AdminHospitalCheck> {
  // 샘플 병원 데이터
  final List<Hospital> hospitals = [
    Hospital(
      id: '1',
      name: 'S동물메디컬센터',
      address: '서울시 강남구 테헤란로 123',
      phoneNumber: '02-1234-5678',
      registrationDate: '2024-05-10',
      manager: '김수의',
      donationCount: 25,
      status: '승인',
    ),
    Hospital(
      id: '2',
      name: '행복동물병원',
      address: '서울시 서초구 방배로 456',
      phoneNumber: '02-2345-6789',
      registrationDate: '2024-06-15',
      manager: '박의사',
      donationCount: 12,
      status: '대기',
    ),
    Hospital(
      id: '3',
      name: '부산동물종합병원',
      address: '부산시 해운대구 해운대로 789',
      phoneNumber: '051-345-6789',
      registrationDate: '2024-07-20',
      manager: '이원장',
      donationCount: 18,
      status: '승인',
    ),
    Hospital(
      id: '4',
      name: '대구반려동물병원',
      address: '대구시 수성구 수성로 321',
      phoneNumber: '053-456-7890',
      registrationDate: '2024-08-05',
      manager: '최수의',
      donationCount: 0,
      status: '거절',
    ),
  ];

  // 검색 필터링 기능을 위한 변수
  String searchQuery = '';
  List<Hospital> filteredHospitals = [];

  @override
  void initState() {
    super.initState();
    filteredHospitals = hospitals;
  }

  // 검색 기능
  void filterHospitals(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredHospitals = hospitals;
      } else {
        filteredHospitals =
            hospitals
                .where(
                  (hospital) =>
                      hospital.name.toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      hospital.address.toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      hospital.phoneNumber.contains(query),
                )
                .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        // main.dart의 AppBarTheme을 따름 (배경색, 그림자 등)
        title: Text(
          "병원 관리",
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: false, // 토스처럼 왼쪽 정렬 유지
      ),
      body: Column(
        children: [
          // 검색 필드
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ), // 여백 조정
            child: TextField(
              onChanged: filterHospitals,
              decoration: InputDecoration(
                labelText: '병원 검색 (이름, 주소, 연락처)',
                hintText: '검색어를 입력하세요',
                prefixIcon: const Icon(Icons.search_outlined), // 아웃라인 아이콘
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), // 더 둥근 모서리
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 2,
                  ), // 포커스 시 테마 색상
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                filled: true,
                fillColor: Colors.grey.shade50, // 아주 연한 배경색
                labelStyle: TextStyle(color: Colors.grey[700]),
              ),
            ),
          ),

          // 병원 목록
          Expanded(
            child:
                filteredHospitals.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 60,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '검색 결과가 없습니다.',
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
                        vertical: 0,
                      ), // 상하 여백 제거 또는 최소화
                      itemCount: filteredHospitals.length,
                      itemBuilder: (context, index) {
                        final hospital = filteredHospitals[index];
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
                          child: InkWell(
                            // 터치 피드백을 위해 InkWell 사용
                            borderRadius: BorderRadius.circular(12),
                            // 카드 탭 시 상세화면으로 이동
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => AdminHospitalDetailScreen(
                                        hospital: hospital,
                                      ),
                                ),
                              ).then((_) {
                                // 상세화면에서 돌아올 때 목록 갱신 (상태가 변경되었을 수 있으므로)
                                setState(() {
                                  // 실제 DB 연동 시에는 여기서 데이터를 다시 불러와야 함
                                  filterHospitals(
                                    searchQuery,
                                  ); // 현재 검색 쿼리로 다시 필터링
                                });
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0), // 내부 패딩
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          hospital.name,
                                          style: textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                          maxLines: 1, // 한 줄로 제한
                                          overflow:
                                              TextOverflow.ellipsis, // 넘치면 ...
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      // 상태 태그
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0,
                                          vertical: 4.0,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getHospitalStatusColor(
                                            hospital.status,
                                          ).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(
                                            8.0,
                                          ),
                                        ),
                                        child: Text(
                                          hospital.status,
                                          style: textTheme.bodySmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: _getHospitalStatusColor(
                                              hospital.status,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '주소: ${hospital.address}',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[700],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '연락처: ${hospital.phoneNumber}',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '담당자: ${hospital.manager}',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      // 새 병원 추가 버튼
      floatingActionButton: FloatingActionButton(
        backgroundColor: colorScheme.primary, // 테마의 주 색상 사용
        foregroundColor: colorScheme.onPrimary, // 테마의 주 색상에 대비되는 텍스트/아이콘 색상
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ), // 둥근 사각형 모양
        elevation: 4, // 그림자 추가
        onPressed: () {
          // 새 병원 추가 화면으로 이동 (실제 구현 필요)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("새 병원 추가 화면으로 이동합니다.")));
        },
        child: const Icon(Icons.add_outlined, size: 28), // 아웃라인 아이콘
      ),
    );
  }

  // 병원 상태별 색상 (그대로 유지)
  Color _getHospitalStatusColor(String status) {
    switch (status) {
      case '승인':
        return Colors.green;
      case '대기':
        return Colors.orange;
      case '거절':
        return Colors.red;
      case '중단':
        return Colors.grey;
      default:
        return Colors.black;
    }
  }
}
// Hospital 모델은 AdminHospitalCheck 파일에 정의되어 있으므로 별도 import 필요 없음.

// 병원 상세 화면
class AdminHospitalDetailScreen extends StatefulWidget {
  final Hospital hospital;

  const AdminHospitalDetailScreen({
    super.key,
    required this.hospital,
  }); // Key? key -> super.key로 변경

  @override
  _AdminHospitalDetailScreenState createState() =>
      _AdminHospitalDetailScreenState();
}

class _AdminHospitalDetailScreenState extends State<AdminHospitalDetailScreen> {
  late String hospitalStatus;
  String rejectReason = ''; // 거절 사유 저장 변수

  @override
  void initState() {
    super.initState();
    hospitalStatus = widget.hospital.status;
  }

  // 병원 상태별 색상 (AdminHospitalCheck에서 재활용)
  Color _getHospitalStatusColor(String status) {
    switch (status) {
      case '승인':
        return Colors.green;
      case '대기':
        return Colors.orange;
      case '거절':
        return Colors.red;
      case '중단':
        return Colors.grey;
      default:
        return Colors.black;
    }
  }

  // 승인 버튼 → 상태: "승인"
  void _approveHospital() {
    setState(() {
      hospitalStatus = '승인';
      widget.hospital.status = '승인'; // 부모 위젯의 데이터도 업데이트
    });
    Navigator.pop(context); // 상태 변경 후 이전 화면으로 돌아가기
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("병원 '${widget.hospital.name}'이(가) 승인 처리되었습니다.")),
    );
  }

  // 거절 버튼 → 사유 입력 다이얼로그 표시 → 상태: "거절"
  void _rejectHospital() {
    final TextEditingController reasonController = TextEditingController();
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        // BuildContext 이름을 dialogContext로 변경하여 충돌 방지
        return AlertDialog(
          title: Text('거절 사유 입력', style: textTheme.titleLarge),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '거절 사유를 입력해주세요. 해당 내용은 병원에 전달됩니다.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  hintText: '예: 필수 서류가 미비합니다.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                maxLines: 3,
                keyboardType: TextInputType.multiline,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // 다이얼로그 닫기
              },
              style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    // dialogContext 사용
                    const SnackBar(content: Text("거절 사유를 입력해주세요.")),
                  );
                } else {
                  setState(() {
                    hospitalStatus = '거절';
                    widget.hospital.status = '거절';
                    rejectReason = reasonController.text.trim();
                  });
                  Navigator.of(dialogContext).pop(); // 다이얼로그 닫기
                  Navigator.pop(context); // 상세 화면도 닫고 이전 목록 화면으로 돌아가기
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "병원 '${widget.hospital.name}'이(가) 거절 처리되었습니다.\n사유: $rejectReason",
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  // 중단 버튼 → 사유 입력 다이얼로그 표시 → 상태: "중단"
  void _suspendHospital() {
    final TextEditingController reasonController = TextEditingController();
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        // BuildContext 이름을 dialogContext로 변경
        return AlertDialog(
          title: Text('중단 사유 입력', style: textTheme.titleLarge),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '병원 서비스 중단 사유를 입력해주세요. 해당 내용은 병원에 통보됩니다.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  hintText: '예: 위생 규정 위반으로 인한 서비스 일시 중단',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                maxLines: 3,
                keyboardType: TextInputType.multiline,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text("중단 사유를 입력해주세요.")),
                  );
                } else {
                  setState(() {
                    hospitalStatus = '중단';
                    widget.hospital.status = '중단';
                  });
                  Navigator.of(dialogContext).pop();
                  Navigator.pop(context); // 상세 화면도 닫고 이전 목록 화면으로 돌아가기
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "병원 '${widget.hospital.name}' 서비스가 중단 처리되었습니다.\n사유: ${reasonController.text.trim()}",
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade600, // 중단은 회색 계열로
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('확인'),
            ),
          ],
        );
      },
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

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        // main.dart의 AppBarTheme을 따름
        title: Text(
          "병원 상세정보",
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: false, // 왼쪽 정렬
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 병원 정보 상단 카드
            Card(
              margin: const EdgeInsets.all(20.0), // 여백
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0), // 내부 패딩
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            widget.hospital.name,
                            style: textTheme.headlineSmall?.copyWith(
                              // 더 큰 제목 스타일
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // 상태 태그
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10.0,
                            vertical: 6.0,
                          ),
                          decoration: BoxDecoration(
                            color: _getHospitalStatusColor(
                              hospitalStatus,
                            ).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12.0), // 더 둥글게
                          ),
                          child: Text(
                            hospitalStatus,
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _getHospitalStatusColor(hospitalStatus),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      context,
                      Icons.location_on_outlined,
                      '주소',
                      widget.hospital.address,
                    ),
                    _buildDetailRow(
                      context,
                      Icons.phone_outlined,
                      '연락처',
                      widget.hospital.phoneNumber,
                    ),
                    _buildDetailRow(
                      context,
                      Icons.person_outline,
                      '담당자',
                      widget.hospital.manager,
                    ),
                    _buildDetailRow(
                      context,
                      Icons.event_note_outlined,
                      '등록일',
                      widget.hospital.registrationDate,
                    ),
                  ],
                ),
              ),
            ),

            // 상태 변경 버튼들
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _approveHospital,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        "승인",
                        style: textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _rejectHospital,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.error, // 테마 에러 색상
                        foregroundColor: colorScheme.onError,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        "거절",
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onError,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _suspendHospital,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade600, // 중단은 회색
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        "중단",
                        style: textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 추가 정보 및 실적 섹션
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                '세부 정보 및 실적',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Card(
              margin: const EdgeInsets.all(20.0),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                      context,
                      Icons.info_outline,
                      '헌혈 진행 횟수',
                      '${widget.hospital.donationCount}회',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '시설 정보',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      context,
                      Icons.person_outline,
                      '수의사 인원',
                      '5명',
                    ),
                    _buildDetailRow(
                      context,
                      Icons.person_outline,
                      '간호사 인원',
                      '8명',
                    ),
                    _buildDetailRow(
                      context,
                      Icons.space_dashboard_outlined,
                      '헌혈 가능 공간',
                      '2실',
                    ),
                    _buildDetailRow(
                      context,
                      Icons.medical_services_outlined,
                      '혈액 보관 시설',
                      '보유',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '최근 헌혈 실적',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(context, Icons.timeline, '2025년 2월', '4회'),
                    _buildDetailRow(context, Icons.timeline, '2025년 1월', '3회'),
                    _buildDetailRow(context, Icons.timeline, '2024년 12월', '5회'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20), // 하단 여백
          ],
        ),
      ),
    );
  }
}
