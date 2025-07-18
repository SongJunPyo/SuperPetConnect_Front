import 'package:flutter/material.dart';
import 'package:kpostal/kpostal.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/config.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Form 위젯의 상태를 관리하기 위한 키 (유효성 검사에 사용)
  final _formKey = GlobalKey<FormState>();
  // 입력 필드의 컨트롤러
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController(); // 이름
  final _phoneController = TextEditingController(); // 전화번호
  final _addressController = TextEditingController(); // 주소
  // 비밀번호 가림/보임 상태를 위한 변수
  bool _isObscurePassword = true;
  bool _isObscureConfirmPassword = true;

  @override
  void dispose() {
    // 리소스 해제
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose(); // 부모 클래스의 dispose() 메서드 호출
  }

  // 회원가입 버튼 클릭 시 호출될 함수
  void _register() async {
    // 폼의 현재 상태를 검증합니다.
    if (_formKey.currentState!.validate()) {
      final String email = _emailController.text;
      final String password = _passwordController.text;
      final String name = _nameController.text;
      final String phoneNumber = _phoneController.text;
      final String address = _addressController.text;

      print('회원가입 시도: 이름 - $name, 이메일 - $email');
      print('서버 URL: ${Config.serverUrl}/api/v1/register');

      try {
        final response = await http.post(
          Uri.parse('${Config.serverUrl}/api/v1/register'),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(<String, String>{
            'email': email,
            'password': password,
            'name': name,
            'phone_number': phoneNumber,
            'address': address,
          }),
        );

        print('서버 응답 코드: ${response.statusCode}');
        print('서버 응답 본문: ${response.body}');

        if (response.statusCode == 201) {
          print('회원가입 성공');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('회원가입 성공! 로그인 해주세요.')));
          Navigator.pop(context);
        } else {
          print('회원가입 실패: ${response.body}');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('회원가입 실패: ${response.body}')));
        }
      } catch (e) {
        print('서버 연결 오류: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('서버에 연결할 수 없습니다: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // 뒤로가기 버튼
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () {
            Navigator.pop(context); // 이전 화면으로 돌아가기
          },
        ),
        // 회원가입 페이지에서는 제목을 표시합니다.
        title: const Text(
          '회원가입',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true, // 제목을 중앙에 정렬
      ),
      // 키보드 오버플로우 방지를 위해 SingleChildScrollView로 감쌉니다.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey, // Form 위젯에 _formKey 할당
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20), // 상단 여백
              const Text(
                '새 계정 만들기',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 30),
              // 이메일 입력 필드
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: '이메일 주소',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                style: const TextStyle(fontSize: 16),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '이메일을 입력해주세요.';
                  }
                  // 간단한 이메일 형식 검사
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return '유효한 이메일 주소를 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // 비밀번호 입력 필드
              TextFormField(
                controller: _passwordController,
                obscureText: _isObscurePassword, // 비밀번호 가림/보임 상태
                decoration: InputDecoration(
                  hintText: '비밀번호',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isObscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _isObscurePassword = !_isObscurePassword;
                      });
                    },
                  ),
                ),
                style: const TextStyle(fontSize: 16),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '비밀번호를 입력해주세요.';
                  }
                  if (value.length < 6) {
                    return '비밀번호는 6자 이상이어야 합니다.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // 비밀번호 확인 입력 필드
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _isObscureConfirmPassword, // 비밀번호 확인 가림/보임 상태
                decoration: InputDecoration(
                  hintText: '비밀번호 확인',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isObscureConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _isObscureConfirmPassword = !_isObscureConfirmPassword;
                      });
                    },
                  ),
                ),
                style: const TextStyle(fontSize: 16),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '비밀번호를 다시 입력해주세요.';
                  }
                  if (value != _passwordController.text) {
                    return '비밀번호가 일치하지 않습니다.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // 비밀번호 확인 입력 필드
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '이름',
                  hintText: '홍길동',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                style: const TextStyle(fontSize: 16),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '이름을 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // 비밀번호 확인 입력 필드
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '전화번호',
                  hintText: '010-0000-0000',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                style: const TextStyle(fontSize: 16),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '전화번호를 입력해주세요.';
                  }
                  if (!RegExp(r'^\d{3}-\d{3,4}-\d{4}$').hasMatch(value)) {
                    return '유효한 전화번호 형식을 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // 비밀번호 확인 입력 필드
              TextFormField(
                controller: _addressController,
                // readOnly: true, // 주소 입력 필드는 읽기 전용으로 설정
                decoration: InputDecoration(
                  labelText: '주소',
                  hintText: '서울시 강남구 역삼동 123-45',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  suffixIcon: Icon(Icons.search),
                ),
                // onTap: () async {
                //   await Navigator.push(
                //     context,
                //     MaterialPageRoute(
                //       builder:
                //           (_) => KpostalView(
                //             callback: (Kpostal result) {
                //               setState(() {
                //                 // 주소 검색 결과를 화면에 표시
                //                 _addressController.text = result.address;
                //               });
                //             },
                //           ),
                //     ),
                //   );
                // },
                style: const TextStyle(fontSize: 16),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '주소를 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              // 회원가입 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '회원가입',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
}
