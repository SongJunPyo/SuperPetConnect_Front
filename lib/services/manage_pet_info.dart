// lib/services/manage_pet_info.dart

import 'dart:convert';
import 'auth_http_client.dart';
import '../models/pet_model.dart';
import '../utils/config.dart';

// class PetService {
//   static final String baseUrl = '${Config.serverUrl}/api/v1';

//   // 반려동물 정보 조회
//   static Future<List<Pet>> fetchPets() async {
//     try {
//       final response = await http.get(Uri.parse('$baseUrl/pets'));

//       if (response.statusCode == 200) {
//         final List<dynamic> data = jsonDecode(response.body);

//         List<Pet> pets = data.map((item) => Pet.fromJson(item)).toList();
//         List<Pet> petList = pets.toList();
//         return petList;
//       } else {
//         throw Exception('반려동물 정보 조회 실패: ${response.body}');
//       }
//     } catch (e) {
//       throw Exception('반려동물 정보 조회 중 오류 발생: $e');
//     }
//   }
// }

class PetService {
  static String get baseUrl => '${Config.serverUrl}/api';

  // 반려동물 정보 조회
  static Future<List<Pet>> fetchPets() async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse('$baseUrl/pets'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((item) => Pet.fromJson(item)).toList();
      } else {
        throw Exception('반려동물 정보 조회 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('반려동물 정보 조회 중 오류 발생: $e');
    }
  }

  static Future<void> deletePet(int petIdx) async {
    try {
      final response = await AuthHttpClient.delete(
        Uri.parse('$baseUrl/pets/$petIdx'),
      );

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('반려동물 정보 삭제 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('반려동물 정보 삭제 중 오류 발생: $e');
    }
  }
}
