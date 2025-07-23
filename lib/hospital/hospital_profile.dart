import 'package:flutter/material.dart';

class HospitalProfile extends StatefulWidget {
  const HospitalProfile({super.key});

  @override
  _HospitalProfileState createState() => _HospitalProfileState();
}

class _HospitalProfileState extends State<HospitalProfile> {
  // 초기 데이터는 그대로 유지합니다.
  final TextEditingController nicknameController = TextEditingController(
    text: "동물병원",
  );
  final TextEditingController nameController = TextEditingController(
    text: "차은우",
  );
  final TextEditingController phoneController = TextEditingController(
    text: "02-123-4567",
  );
  final TextEditingController addressController = TextEditingController(
    text: "서울특별시 강남구",
  );

  @override
  void dispose() {
    // 컨트롤러는 사용 후 dispose 해주어야 메모리 누수를 방지할 수 있습니다.
    nicknameController.dispose();
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    super.dispose();
  }

  // 공통 입력 필드 InputDecoration 스타일
  InputDecoration _buildInputDecoration(
    BuildContext context,
    String labelText,
    IconData icon,
    int maxLength,
    TextEditingController controller,
  ) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(icon, color: Colors.grey[600]), // 아이콘 추가
      suffixText: "${controller.text.length}/$maxLength", // 입력된 글자 수 / 최대 글자 수
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
      contentPadding: const EdgeInsets.symmetric(
        vertical: 16.0,
        horizontal: 12.0,
      ), // 내부 패딩 조절
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        // main.dart의 AppBarTheme을 따름 (배경색, 그림자 등)
        title: Text(
          "내 프로필", // 제목을 더 친근하게 변경
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: false, // 토스처럼 왼쪽 정렬 유지
        actions: [
          // 저장 버튼
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Icon(
                Icons.save_outlined,
                color: colorScheme.primary,
              ), // 테마 색상 적용 및 아웃라인 아이콘
              onPressed: () {
                // 저장 기능 추가:
                // 여기에서 nicknameController.text, nameController.text 등의 값을
                // 서버로 전송하거나 로컬에 저장하는 로직을 구현합니다.
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('프로필 정보가 저장되었습니다.')));
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 20.0,
          vertical: 24.0,
        ), // 전체 여백 조정
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center, // 중앙 정렬 유지
          children: [
            // 프로필 사진 섹션
            Stack(
              alignment: Alignment.bottomRight, // 카메라 아이콘 위치 변경 (오른쪽 아래)
              children: [
                CircleAvatar(
                  radius: 60, // 프로필 사진 크기 키움
                  backgroundColor: Colors.grey.shade200, // 연한 회색 배경
                  child: Icon(
                    Icons.local_hospital_outlined,
                    size: 50,
                    color: Colors.grey[600],
                  ), // 병원 아이콘
                  // backgroundImage: NetworkImage('https://placehold.co/120x120/E0E0E0/616161?text=Hospital'), // 실제 이미지 사용 시
                ),
                Positioned(
                  bottom: 0,
                  right: 0, // 오른쪽 아래로 이동
                  child: GestureDetector(
                    onTap: () {
                      // 사진 변경 기능 추가:
                      // 이미지 피커(image_picker) 라이브러리 등을 사용하여
                      // 갤러리 또는 카메라에서 사진을 선택하는 로직을 구현합니다.
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('사진 변경 기능 (미구현)')));
                    },
                    child: CircleAvatar(
                      radius: 22, // 카메라 아이콘 크기 조절
                      backgroundColor: colorScheme.primary, // 테마의 기본 색상 사용
                      child: Icon(
                        Icons.camera_alt_outlined,
                        color: colorScheme.onPrimary,
                        size: 20,
                      ), // 아웃라인 아이콘
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              nicknameController.text, // 닉네임 컨트롤러의 텍스트 사용
              style: textTheme.headlineSmall?.copyWith(
                // 더 큰 제목 스타일
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 32), // 간격 증가
            // 정보 입력 필드 섹션 (Card로 감싸서 깔끔하게)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start, // 입력 필드 레이블 왼쪽 정렬
                  children: [
                    // 닉네임 입력 필드
                    TextField(
                      controller: nicknameController,
                      maxLength: 20,
                      decoration: _buildInputDecoration(
                        context,
                        "병원명 (닉네임)",
                        Icons.local_hospital_outlined,
                        20,
                        nicknameController,
                      ),
                      onChanged:
                          (value) => setState(() {}), // suffixText 업데이트를 위해
                    ),
                    const SizedBox(height: 20),
                    // 담당자 이름 입력 필드
                    TextField(
                      controller: nameController,
                      maxLength: 10,
                      decoration: _buildInputDecoration(
                        context,
                        "담당자 이름",
                        Icons.person_outline,
                        10,
                        nameController,
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                    const SizedBox(height: 20),
                    // 전화번호 입력 필드
                    TextField(
                      controller: phoneController,
                      maxLength: 13,
                      keyboardType: TextInputType.phone, // 전화번호 키보드
                      decoration: _buildInputDecoration(
                        context,
                        "전화번호",
                        Icons.phone_outlined,
                        13,
                        phoneController,
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                    const SizedBox(height: 20),
                    // 주소 입력 필드
                    TextField(
                      controller: addressController,
                      maxLength: 50,
                      maxLines: 2, // 주소는 여러 줄일 수 있으므로
                      minLines: 1,
                      decoration: _buildInputDecoration(
                        context,
                        "병원 주소",
                        Icons.location_on_outlined,
                        50,
                        addressController,
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // 회원 탈퇴 버튼
            SizedBox(
              width: double.infinity,
              height: 56, // 버튼 높이 고정
              child: ElevatedButton(
                onPressed: () {
                  // 회원 탈퇴 기능 추가:
                  // 사용자에게 한 번 더 확인하는 다이얼로그를 띄우는 것이 좋습니다.
                  // 예: _showConfirmDialog(context, '회원 탈퇴', '정말로 회원 탈퇴하시겠습니까?');
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('회원 탈퇴 기능 (미구현)')));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.error, // 에러 색상 (빨간색) 사용
                  foregroundColor: colorScheme.onError, // 에러 색상에 대비되는 텍스트 색상
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3, // 버튼 그림자
                ),
                child: Text(
                  "회원 탈퇴",
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
    );
  }
}
