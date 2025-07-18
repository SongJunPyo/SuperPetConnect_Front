// lib/user/pet_management.dart

import 'package:flutter/material.dart';
import 'package:connect/user/pet_register.dart';
import 'package:connect/models/pet_model.dart'; // Pet 모델 import
import 'package:connect/services/manage_pet_info.dart';

class PetManagementScreen extends StatefulWidget {
  const PetManagementScreen({super.key});

  @override
  State<PetManagementScreen> createState() => _PetManagementScreenState();
}

class _PetManagementScreenState extends State<PetManagementScreen> {
  // DB 스키마에 맞춘 Pet 객체 리스트 (예시 데이터)
  late Future<List<Pet>> _petsFuture;

  // --- 추가: 위젯이 처음 생성될 때 데이터를 불러오는 initState ---
  @override
  void initState() {
    super.initState();
    _refreshPets(); // 데이터를 불러오는 함수 호출
  }

  // --- 추가: 서버에서 펫 목록을 가져와 상태를 갱신하는 함수 ---
  void _refreshPets() {
    setState(() {
      _petsFuture = PetService.fetchPets();
    });
  }

  // 펫 등록 페이지로 이동하는 함수
  void _navigateAndRegisterPet() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PetRegisterScreen()),
    );

    if (result == true) {
      _refreshPets();
      _showSnackBar('새로운 펫이 등록되었습니다.');
    }
  }

  // 펫 수정 기능
  void _editPet(Pet pet) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PetRegisterScreen(petToEdit: pet),
      ),
    );
    if (result == true) {
      _refreshPets();
      _showSnackBar('${pet.name} 펫 정보가 수정되었습니다.');
    }
  }

  // 펫 삭제 기능
  void _deletePet(Pet pet) {
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
              // onPressed를 비동기(async)로 변경
              onPressed: () async {
                // petId가 null인 경우는 없어야 하지만, 안전을 위해 확인
                if (pet.petId == null) {
                  _showSnackBar('잘못된 펫 정보입니다.');
                  Navigator.of(context).pop();
                  return;
                }

                try {
                  // 1. PetService를 통해 서버에 삭제 요청
                  await PetService.deletePet(pet.petId!);

                  // 2. 다이얼로그 닫기
                  Navigator.of(context).pop();

                  // 3. 삭제 성공 메시지 표시
                  _showSnackBar('${pet.name} 펫이 삭제되었습니다.');

                  // 4. 목록 새로고침
                  _refreshPets();
                } catch (e) {
                  // 에러 처리
                  Navigator.of(context).pop();
                  _showSnackBar('삭제 실패: $e');
                }
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // 하단에 알림 보여주는 스낵바 함수
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
      body: FutureBuilder<List<Pet>>(
        future: _petsFuture, // 이 Future의 상태에 따라 UI가 결정됨
        builder: (context, snapshot) {
          // 1. 로딩 중일 때
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // 2. 에러가 발생했을 때
          if (snapshot.hasError) {
            return Center(child: Text('오류가 발생했습니다: ${snapshot.error}'));
          }
          // 3. 데이터가 없거나 비어있을 때
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          // 4. 데이터 로딩 성공 시
          final pets = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: _buildPetList(pets), // 가져온 데이터로 리스트를 그림
          );
        },
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
  Widget _buildPetList(List<Pet> pets) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: pets.length,
      itemBuilder: (context, index) {
        final pet = pets[index];
        return _buildPetCard(pet); // 인덱스 대신 pet 객체를 직접 전달
      },
    );
  }

  // 각 펫의 정보를 보여주는 카드 위젯
  Widget _buildPetCard(Pet pet) {
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
              onPressed: () => _editPet(pet),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () => _deletePet(pet),
            ),
          ],
        ),
      ),
    );
  }
}
