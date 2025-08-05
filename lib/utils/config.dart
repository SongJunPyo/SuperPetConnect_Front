import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  // 환경변수에서 서버 URL을 가져옵니다.
  // .env 파일에서 SERVER_URL 값을 읽어옵니다.
  static String get serverUrl {
    return dotenv.env['SERVER_URL'] ?? 'http://10.100.54.176:8002';
  }
}
