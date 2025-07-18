import 'package:flutter/material.dart';
import 'register.dart';
import '../hospital/hospital_dashboard.dart';
import '../user/user_dashboard.dart';
import '../admin/admin_dashboard.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>(); // Form
  // 텍스트 필드의 입력을 제어하기 위한 컨트롤러
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // 로그인 버튼 클릭 시 호출될 함수 (나중에 실제 로그인 로직 추가)
  void _login() async {
    if (_formKey.currentState!.validate()) {
      // 모든 입력값이 유효할 때만 이 블록이 실행됨
      // 입력값이 모두 올바른지(빈칸이 없는지, 이메일 형식이 맞는지 등) 검사
      try {
        // 로딩 표시
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => const Center(child: CircularProgressIndicator()),
        );

        // API 요청
        final response = await http.post(
          // final 변수는 한 번 선언하면 변경 불가, await는 비동기 때 사용하며 서버 응답이 올 때 까지 기다림
          //Uri.parse('http://10.100.54.176:8002/api/v1/login'),
          Uri.parse('${Config.serverUrl}/api/v1/login'),
          headers: {
            // 서버에 보내는 데이터의 형식을 알려줌
            // 폼 데이터(키-값 쌍)를 URL 인코딩 방식으로 서버에 전송할 때 사용하는 타입
            // 여기가 보안적으로 괜찮은지는 살펴봐야 할 것 같음
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            // 실제로 서버에 보내는 데이터(로그인 정보)
            'username': _emailController.text,
            'password': _passwordController.text,
          },
        );
        // response 변수에는 서버가 로그인 결과(성공/실패)를 응답으로 보내줌

        // 로딩 닫기
        Navigator.pop(context);

        // await를 사용했기 때문에 여기서 부터는 서버의 응답이 올 때 까지 기다렸다가 오면 아래 코드 실행됨
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          // 토큰 저장 코드 추가 필요
          // SharedPreferences는 앱 내에 간단한 데이터를 파일로 저장할 수 있는 기능
          final prefs = await SharedPreferences.getInstance();
          // 로그인에 성공하면 서버가 준 access_token을 'auth_token'이라는 이름으로 저장
          // 이렇게 하면 앱을 껐다 켜도 토큰이 남아있어 자동 로그인 등에 쓸 수 있음
          // 근데 아직 구현 못함
          await prefs.setString('auth_token', data['access_token']);

          // 사용자 정보도 저장
          // setString(key, value)는key라는 이름으로 value값을 저장하는 함수
          await prefs.setString('user_email', data['email'] ?? '');
          await prefs.setString('user_name', data['name'] ?? '');
          // 기타 필요한 사용자 정보 저장
          // 로그인 할 때 최대한 많은 정보를 가져와서 SharedPreferences 여기에 저장해야할지는 고민해봐야함

          // 승인 여부 확인
          if (data['approved'] == false) {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('승인 대기 중'),
                  content: const Text('관리자의 승인을 기다리고 있습니다. \n승인 후 로그인이 가능합니다.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('확인'),
                    ),
                  ],
                );
              },
            );
            return;
          }

          print('디버그!!!!!!: ${data['account_type']}');

          // 사용자 유형에 따라 적절한 화면으로 이동
          switch (data['account_type']) {
            case 1: // 관리자
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AdminDashboard()),
              );
              break;
            case 2: // 병원
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const HospitalDashboard(),
                ),
              );
              break;
            case 3: // 일반 사용자
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const UserDashboard()),
              );
              break;
            default:
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('오류'),
                    content: const Text('알 수 없는 사용자 유형입니다.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('확인'),
                      ),
                    ],
                  );
                },
              );
          }
        } else if (response.statusCode == 403) {
          // 승인되지 않은 계정인 경우
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('승인 대기 중'),
                content: const Text('관리자의 승인을 기다리고 있습니다. \n승인 후 로그인이 가능합니다.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('확인'),
                  ),
                ],
              );
            },
          );
        } else if (response.statusCode == 401) {
          // 인증 실패 (이메일 또는 비밀번호 오류)
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('로그인 실패'),
                content: const Text('이메일 또는 비밀번호가 올바르지 않습니다.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('확인'),
                  ),
                ],
              );
            },
          );
        } else {
          // 기타 서버 오류
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('오류 발생'),
                content: const Text('서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('확인'),
                  ),
                ],
              );
            },
          );
        }
      } catch (e) {
        Navigator.pop(context); // 에러 발생 시 로딩 닫기
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('연결 오류'),
              content: const Text('서버 연결 오류가 발생했습니다. 네트워크 상태를 확인해주세요.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ],
            );
          },
        );
      }
    }
  }

  // 회원가입 버튼 클릭 시 호출될 함수 (나중에 회원가입 페이지로 이동 로직 추가)
  void _signUp() {
    print('회원가입 페이지로 이동');
    // TODO: 회원가입 페이지로 이동하는 Navigator 로직 추가
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('회원가입 기능은 나중에 구현됩니다!')));
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
  }

  // 비밀번호 찾기 버튼 클릭 시 호출될 함수
  void _forgotPassword() {
    print('비밀번호 찾기 페이지로 이동');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('비밀번호 찾기 기능은 나중에 구현됩니다!')));
  }

  @override
  //TextEditingController와 같은 리소스(메모리, 이벤트 리스너 등)를 해제하여 메모리 누수(leak)를 방지하기 위해서
  void dispose() {
    // 위젯이 화면에서 완전히 사라질 때 호출, (화면 전환, 앱 종료)
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose(); // 부모 클래스의 dispose() 메서드 호출
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // 로그인 페이지에서는 로그인 아이콘이 필요 없으므로 AppBar의 title을 비웁니다.
        // 뒤로가기 버튼을 추가하여 WelcomeScreen으로 돌아갈 수 있게 합니다.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () {
            Navigator.pop(context); // 이전 화면으로 돌아가기
          },
        ),
        title: const SizedBox.shrink(), // 로그인 아이콘 대신 빈 위젯으로 대체
      ),
      // 키보드가 올라올 때 화면이 오버플로우되는 문제를 해결하기 위해 SingleChildScrollView로 감쌉니다.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40), // 상단 여백
              const Text(
                '로그인',
                style: TextStyle(
                  fontSize: 32,
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
                  fillColor: Colors.grey[100], // 배경색
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), // 둥근 모서리
                    borderSide: BorderSide.none, // 테두리 없음
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
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // 비밀번호 입력 필드
              TextFormField(
                controller: _passwordController,
                obscureText: true, // 비밀번호 숨김
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
                ),
                style: const TextStyle(fontSize: 16),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '비밀번호를 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              // 로그인 버튼
              SizedBox(
                width: double.infinity, // 너비를 최대로
                child: ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent, // 버튼 배경색
                    foregroundColor: Colors.white, // 버튼 글자색
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12), // 둥근 모서리
                    ),
                    elevation: 0, // 그림자 없음
                  ),
                  child: const Text(
                    '로그인',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // 회원가입 버튼 또는 텍스트
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: _signUp,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blueAccent, // 글자색
                    padding: const EdgeInsets.all(10),
                  ),
                  child: const Text(
                    '회원가입',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              // 키보드 오버플로우 방지를 위한 추가 공간 (필요에 따라 조절)
              const SizedBox(height: 20),

              // 개발용 임시 이동 버튼 섹션 (새로 추가된 부분)
              const SizedBox(height: 40), // 추가 여백
              const Text(
                '개발용 임시 이동 버튼', // 임시 버튼임을 명시
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent, // 눈에 띄는 색상
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const UserDashboard(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange, // 임시 버튼 색상
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('사용자'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HospitalDashboard(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('병원'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminDashboard(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('관리자'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20), // 마지막 여백
            ],
          ),
        ),
      ),
    );
  }
}
