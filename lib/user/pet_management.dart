// import 'package:flutter/material.dart';
// import 'package:connect/user/pet_register.dart'; // 펫 등록 페이지 import
//
// class PetManagementScreen extends StatefulWidget {
//   const PetManagementScreen({super.key});
//
//   @override
//   State<PetManagementScreen> createState() => _PetManagementScreenState();
// }
//
// class _PetManagementScreenState extends State<PetManagementScreen> {
//   // 임시 반려동물 목록 (나중에 서버 또는 로컬 DB에서 가져올 데이터)
//   // 현재는 메모리에서 관리하며, 수정/삭제 시 setState로 UI 업데이트
//   final List<Map<String, String>> _pets = [
//     {
//       'name': '멍멍이',
//       'breed': '푸들',
//       'age': '3살',
//       'weight': '5kg',
//       'bloodType': 'DEA 1.1+',
//       'gender': '남아',
//     },
//     {
//       'name': '냥냥이',
//       'breed': '코숏',
//       'age': '2살',
//       'weight': '4kg',
//       'bloodType': 'AB',
//       'gender': '여아',
//     },
//     {
//       'name': '왈왈이',
//       'breed': '시바견',
//       'age': '5살',
//       'weight': '10kg',
//       'bloodType': 'DEA 1.1-',
//       'gender': '중성',
//     },
//   ];
//
//   // 펫 수정 기능
//   void _editPet(int index) async {
//     // PetRegisterScreen으로 현재 펫 정보를 넘겨주어 수정 모드로 진입하게 합니다.
//     // PetRegisterScreen은 petToEdit와 petIndex를 받을 수 있도록 수정되어야 합니다.
//     final result = await Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder:
//             (context) => PetRegisterScreen(
//               petToEdit: _pets[index], // 수정할 펫 데이터 전달
//               petIndex: index, // 수정할 펫의 인덱스 전달
//             ),
//       ),
//     );
//
//     // PetRegisterScreen에서 수정된 데이터가 반환되었을 경우
//     if (result != null && result is Map<String, String>) {
//       setState(() {
//         _pets[index] = result; // 목록에서 해당 펫 정보 업데이트
//       });
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('${result['name']} 펫 정보가 수정되었습니다.')),
//       );
//       print('펫 수정 완료: ${result['name']}');
//       // TODO: 실제로는 서버에 펫 수정 API 호출 로직 추가
//     } else if (result == false) {
//       // 사용자가 수정을 취소했거나 변경사항이 없을 경우
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text('펫 수정이 취소되었습니다.')));
//     }
//   }
//
//   // 펫 삭제 기능
//   void _deletePet(int index) {
//     final petName = _pets[index]['name'];
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: const Text('펫 삭제 확인'),
//           content: Text('$petName 펫을 정말 삭제하시겠습니까?'),
//           actions: <Widget>[
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(), // 다이얼로그 닫기
//               child: const Text('취소'),
//             ),
//             TextButton(
//               onPressed: () {
//                 setState(() {
//                   _pets.removeAt(index); // 목록에서 펫 삭제
//                 });
//                 Navigator.of(context).pop(); // 다이얼로그 닫기
//                 ScaffoldMessenger.of(
//                   context,
//                 ).showSnackBar(SnackBar(content: Text('$petName 펫이 삭제되었습니다.')));
//                 print('펫 삭제 완료: $petName');
//                 // TODO: 실제 서버에서 펫 삭제 API 호출 로직 추가
//               },
//               child: const Text('삭제', style: TextStyle(color: Colors.red)),
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
//           onPressed: () {
//             Navigator.pop(context); // 이전 화면으로 돌아가기 (UserDashboard)
//           },
//         ),
//         // 상단바에 제목을 제거합니다.
//         title: const SizedBox.shrink(),
//         centerTitle: true, // 제목이 없어도 중앙 정렬 속성은 유지합니다.
//       ),
//       body: SingleChildScrollView(
//         // 전체 화면이 스크롤 가능하도록 SingleChildScrollView로 감쌉니다.
//         padding: const EdgeInsets.all(24.0), // 전체 패딩
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start, // 왼쪽 정렬
//           children: [
//             const SizedBox(height: 20), // 상단 여백
//             // 펫 등록 페이지와 유사한 스타일의 제목 추가
//             const Text(
//               '반려동물 관리',
//               style: TextStyle(
//                 fontSize: 28,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.black87,
//               ),
//             ),
//             const SizedBox(height: 30), // 제목과 목록 사이 간격
//
//             _pets.isEmpty
//                 ? Center(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Icon(Icons.pets, size: 80, color: Colors.grey[300]),
//                       const SizedBox(height: 20),
//                       Text(
//                         '등록된 반려동물이 없습니다.',
//                         style: TextStyle(fontSize: 18, color: Colors.grey[600]),
//                       ),
//                       const SizedBox(height: 10),
//                       Text(
//                         '아래 + 버튼을 눌러 반려동물을 등록해주세요!',
//                         style: TextStyle(fontSize: 16, color: Colors.grey[500]),
//                       ),
//                     ],
//                   ),
//                 )
//                 : ListView.builder(
//                   // ListView.builder가 SingleChildScrollView 안에 있을 때
//                   // 높이 제약이 없으면 오류가 발생하므로, shrinkWrap과 physics를 사용합니다.
//                   shrinkWrap: true,
//                   physics:
//                       const NeverScrollableScrollPhysics(), // ListView 자체 스크롤 비활성화
//                   itemCount: _pets.length,
//                   itemBuilder: (context, index) {
//                     final pet = _pets[index];
//                     return Card(
//                       margin: const EdgeInsets.only(bottom: 12.0),
//                       elevation: 2,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: Padding(
//                         padding: const EdgeInsets.all(16.0),
//                         child: Row(
//                           children: [
//                             // 펫 아이콘 (예시)
//                             CircleAvatar(
//                               radius: 25,
//                               backgroundColor: Colors.blueAccent.withOpacity(
//                                 0.1,
//                               ),
//                               child: Icon(Icons.pets, color: Colors.blueAccent),
//                             ),
//                             const SizedBox(width: 16),
//                             Expanded(
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     pet['name']!,
//                                     style: const TextStyle(
//                                       fontSize: 18,
//                                       fontWeight: FontWeight.bold,
//                                       color: Colors.black87,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 4),
//                                   Text(
//                                     '${pet['breed']} / ${pet['age']} / ${pet['weight']}',
//                                     style: TextStyle(
//                                       fontSize: 14,
//                                       color: Colors.grey[700],
//                                     ),
//                                   ),
//                                   if (pet['bloodType'] != null &&
//                                       pet['bloodType']!.isNotEmpty)
//                                     Text(
//                                       '혈액형: ${pet['bloodType']}',
//                                       style: TextStyle(
//                                         fontSize: 14,
//                                         color: Colors.grey[700],
//                                       ),
//                                     ),
//                                   if (pet['gender'] != null &&
//                                       pet['gender']!.isNotEmpty)
//                                     Text(
//                                       '성별: ${pet['gender']}',
//                                       style: TextStyle(
//                                         fontSize: 14,
//                                         color: Colors.grey[700],
//                                       ),
//                                     ),
//                                 ],
//                               ),
//                             ),
//                             // 수정 버튼
//                             IconButton(
//                               icon: const Icon(
//                                 Icons.edit,
//                                 color: Colors.blueGrey,
//                               ),
//                               onPressed: () => _editPet(index), // 수정 기능 연결
//                             ),
//                             // 삭제 버튼
//                             IconButton(
//                               icon: const Icon(
//                                 Icons.delete,
//                                 color: Colors.redAccent,
//                               ),
//                               onPressed: () => _deletePet(index), // 삭제 기능 연결
//                             ),
//                           ],
//                         ),
//                       ),
//                     );
//                   },
//                 ),
//           ],
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () async {
//           // 펫 등록 페이지로 이동
//           final result = await Navigator.push(
//             context,
//             MaterialPageRoute(builder: (context) => const PetRegisterScreen()),
//           );
//           // 펫 등록 페이지에서 돌아왔을 때 (예: 등록 완료 후) 목록을 새로고침
//           if (result != null && result is Map<String, String>) {
//             setState(() {
//               _pets.add(result); // 새로 등록된 펫을 목록에 추가
//             });
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(content: Text('${result['name']} 펫이 등록되었습니다.')),
//             );
//             // TODO: 실제로는 서버에 펫 등록 API 호출 후 최신 목록을 다시 불러와야 함
//           } else if (result == false) {
//             // 사용자가 등록을 취소했거나 변경사항이 없을 경우
//             ScaffoldMessenger.of(
//               context,
//             ).showSnackBar(const SnackBar(content: Text('펫 등록이 취소되었습니다.')));
//           }
//         },
//         backgroundColor: Colors.blueAccent,
//         foregroundColor: Colors.white,
//         child: const Icon(Icons.add),
//       ),
//     );
//   }
// }

//============================================================================

// lib/user/user_dashboard.dart

import 'package:flutter/material.dart';
import 'package:connect/user/pet_register.dart';
import 'package:connect/models/pet_model.dart'; // Pet 모델 import

class PetManagementScreen extends StatefulWidget {
  const PetManagementScreen({super.key});

  @override
  State<PetManagementScreen> createState() => _PetManagementScreenState();
}

class _PetManagementScreenState extends State<PetManagementScreen> {
  // DB 스키마에 맞춘 Pet 객체 리스트 (예시 데이터)
  final List<Pet> _pets = [
    Pet(
      petId: 1,
      guardianIdx: 1,
      name: '멍멍이',
      species: '개',
      breed: '푸들',
      birthDate: DateTime(2022, 5, 10),
      weightKg: 5.2, // double 타입으로
      bloodType: 'DEA 1.1+',
      pregnant: false,
    ),
    Pet(
      petId: 2,
      guardianIdx: 1,
      name: '냥냥이',
      species: '고양이',
      breed: '코리안 숏헤어',
      birthDate: DateTime(2023, 8, 20),
      weightKg: 4.5, // double 타입으로
      bloodType: 'AB',
      pregnant: true,
    ),
  ];

  // 펫 등록 페이지로 이동하는 함수
  void _navigateAndRegisterPet() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PetRegisterScreen()),
    );

    if (result != null && result is Pet) {
      setState(() {
        _pets.add(result);
      });
      _showSnackBar('${result.name} 펫이 등록되었습니다.');
    }
  }

  // 펫 수정 기능
  void _editPet(int index) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PetRegisterScreen(petToEdit: _pets[index]),
      ),
    );

    if (result != null && result is Pet) {
      setState(() {
        _pets[index] = result;
      });
      _showSnackBar('${result.name} 펫 정보가 수정되었습니다.');
    }
  }

  // 펫 삭제 기능
  void _deletePet(int index) {
    final pet = _pets[index];
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('펫 삭제 확인'),
          content: Text("'${pet.name}' 펫의 정보를 정말 삭제하시겠습니까?"),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _pets.removeAt(index);
                });
                Navigator.of(context).pop();
                _showSnackBar('${pet.name} 펫이 삭제되었습니다.');
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // 사용자에게 피드백을 보여주는 SnackBar 함수
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '반려동물 관리',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child:
            _pets.isEmpty
                ? _buildEmptyState() // 펫이 없을 때 보여줄 위젯
                : _buildPetList(), // 펫이 있을 때 보여줄 리스트
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateAndRegisterPet,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  // 펫 목록이 비어있을 때 표시할 위젯
  Widget _buildEmptyState() {
    return Center(
      heightFactor: 2.5, // 화면 중앙에 좀 더 잘 보이도록 조정
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pets, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(
            '등록된 반려동물이 없습니다.',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 10),
          Text(
            '아래 + 버튼을 눌러 소중한 가족을 등록해주세요!',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 펫 목록을 표시할 위젯
  Widget _buildPetList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _pets.length,
      itemBuilder: (context, index) {
        final pet = _pets[index];
        return _buildPetCard(pet, index);
      },
    );
  }

  // 각 펫의 정보를 보여주는 카드 위젯
  Widget _buildPetCard(Pet pet, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.blueAccent.withOpacity(0.1),
              child: Icon(
                pet.species == '개'
                    ? Icons.pets
                    : Icons.cruelty_free, // 종에 따라 아이콘 변경
                color: Colors.blueAccent,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        pet.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 임신 중일 경우 뱃지 표시
                      if (pet.pregnant == true)
                        Chip(
                          label: const Text(
                            '임신중',
                            style: TextStyle(fontSize: 10, color: Colors.white),
                          ),
                          backgroundColor: Colors.pinkAccent,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${pet.species} / ${pet.breed ?? '정보 없음'} / ${pet.age}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  Text(
                    '몸무게: ${pet.weightKg}kg / 혈액형: ${pet.bloodType ?? '정보 없음'}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blueGrey),
              onPressed: () => _editPet(index),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () => _deletePet(index),
            ),
          ],
        ),
      ),
    );
  }
}
