import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class Config {
  // 환경변수에서 서버 URL을 가져옵니다.
  // .env 파일에서 SERVER_URL 값을 읽어옵니다.
  static String get serverUrl {
    // 웹에서는 CORS 문제로 인해 프록시 또는 다른 URL 사용 가능
    if (kIsWeb) {
      // 웹에서는 상대 경로 또는 프록시 URL 사용
      return dotenv.env['WEB_SERVER_URL'] ?? dotenv.env['SERVER_URL'] ?? 'https://62099daef838.ngrok-free.app';
    }
    
    return dotenv.env['SERVER_URL'] ?? 'https://62099daef838.ngrok-free.app';
  }
}
