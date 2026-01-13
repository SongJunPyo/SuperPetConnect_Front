// lib/services/manage_pet_info.dart

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        Uri.parse('$baseUrl/pets'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.delete(
        Uri.parse('$baseUrl/pets/$petIdx'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('반려동물 정보 삭제 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('반려동물 정보 삭제 중 오류 발생: $e');
    }
  }
}
