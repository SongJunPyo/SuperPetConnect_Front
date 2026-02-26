import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:interval_time_picker/interval_time_picker.dart';
import 'dart:convert';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../utils/config.dart';
import '../utils/preferences_manager.dart';
import '../utils/app_theme.dart';
import '../utils/blood_type_constants.dart';
import '../models/donation_post_time_model.dart';
import '../models/donation_post_image_model.dart';
import '../widgets/rich_text_editor.dart';
import 'hospital_dashboard.dart';
import '../services/auth_http_client.dart';

class HospitalPost extends StatefulWidget {
  // PostCreationPage -> HospitalPost로 클래스명 변경
  const HospitalPost({super.key});

  @override
  State createState() => _HospitalPostState();
}

class _HospitalPostState extends State<HospitalPost> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _locationController =
      TextEditingController(); // 지역을 위한 컨트롤러 추가
  // 수혈환자 정보 컨트롤러 (긴급일 때만 사용)
  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _breedController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _diagnosisController = TextEditingController();
  // Legacy variables removed - now using selectedDonationDatesWithTimes
  List<DonationDateWithTimes> selectedDonationDatesWithTimes =
      []; // 헌혈 날짜+시간 목록
  DateTime selectedDate = DateTime.now();
  String selectedType = "정기"; // 초기값을 정기로 변경
  String selectedAnimalType = "dog"; // 동물 종류 (dog/cat)
  String selectedBlood = "전체"; // 기본값을 전체로 변경
  String additionalDescription = ""; // nullable 제거, 빈 문자열로 초기화
  List<DonationPostImage> _postImages = []; // 게시글 이미지 목록
  final GlobalKey<RichTextEditorState> _richEditorKey =
      GlobalKey<RichTextEditorState>(); // 리치 에디터 키
  String hospitalName = "병원"; // 병원 이름을 저장할 변수
  String hospitalNickname = "병원"; // 병원 닉네임을 저장할 변수
  List<Map<String, dynamic>> timeEntries = []; // 시간대 목록

  // Removed unused _getUserInfo method

  // 사용자 주소를 API에서 가져오기
  Future<String> _getUserAddress() async {
    try {
      // 올바른 API 엔드포인트 사용
      final response = await AuthHttpClient.get(
        Uri.parse('${Config.serverUrl}/api/auth/profile'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'] ?? '';
        final name = data['name'] ?? '';
        final nickname = data['nickname'] ?? name; // 닉네임이 없으면 이름 사용

        // 병원 이름과 닉네임을 함께 저장
        if (name.isNotEmpty) {
          setState(() {
            hospitalName = name;
            hospitalNickname = nickname;
          });
          _updateTitleText(); // 병원 정보가 업데이트되면 제목도 업데이트
        }

        return address;
      } else {}
    } catch (e) {
      // 토큰 로드 오류 무시
    }
    return '';
  }

  Future<void> _submitPost() async {
    if (selectedDonationDatesWithTimes.isEmpty) {
      // 시간대가 없으면 경고 메시지 표시
      _showAlertDialog('알림', '최소 하나 이상의 헌혈 날짜와 시간을 추가해주세요.');
      return;
    }

    if (_titleController.text.isEmpty) {
      _showAlertDialog('알림', '게시글 제목을 입력해주세요.');
      return;
    }

    if (_locationController.text.trim().isEmpty) {
      _showAlertDialog(
        '알림',
        '병원 위치가 설정되지 않았습니다.\n프로필 관리에서 주소를 먼저 설정해주세요.',
      );
      return;
    }

    try {
      // 병원 코드 가져오기
      final hospitalCode = await PreferencesManager.getHospitalCode();

      if (hospitalCode == null || hospitalCode.isEmpty) {
        _showAlertDialog('오류', '병원 코드가 없습니다. 병원 계정이 아니거나 승인되지 않았습니다.');
        return;
      }

      // 선택된 날짜와 시간 데이터 준비
      List<Map<String, dynamic>> dateTimeData = [];
      for (final dateWithTimes in selectedDonationDatesWithTimes) {
        final dateStr =
            "${dateWithTimes.donationDate.year}-${dateWithTimes.donationDate.month.toString().padLeft(2, '0')}-${dateWithTimes.donationDate.day.toString().padLeft(2, '0')}";

        for (final timeData in dateWithTimes.times) {
          dateTimeData.add({
            "date": dateStr,
            "time":
                "${timeData.donationTime.hour.toString().padLeft(2, '0')}:${timeData.donationTime.minute.toString().padLeft(2, '0')}",
          });
        }
      }

      // 리치 에디터에서 Delta JSON과 이미지 ID 목록 가져오기
      final editorState = _richEditorKey.currentState;
      final contentDelta = editorState?.contentDelta ?? "";
      final embeddedImageIds = editorState?.embeddedImageIds ?? <int>[];

      // 서버로 보낼 데이터를 Map 형태로 만듭니다.
      final Map<String, dynamic> postData = {
        "date":
            dateTimeData.isNotEmpty
                ? dateTimeData.first["date"]
                : "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}",
        "timeRanges": [], // 기존 호환성을 위해 유지
        "dateTimeSlots": dateTimeData, // 새로운 날짜+시간 데이터
        "types": selectedType == "긴급" ? 0 : 1,
        "title": _titleController.text,
        "descriptions": additionalDescription, // plain text (검색/미리보기용)
        "content_delta": contentDelta, // Delta JSON (리치 텍스트)
        "location": _locationController.text, // 지역 정보를 텍스트 필드에서 가져오기
        "animal_type": selectedAnimalType == "dog" ? 0 : 1, // 동물 종류 수정
        "hospital_code": hospitalCode, // 병원 코드 추가
        // 이미지 ID 목록 (Delta JSON에 포함된 이미지)
        if (embeddedImageIds.isNotEmpty) "image_ids": embeddedImageIds,
      };

      // '긴급' 타입일 때만 'emergency_blood_type' 필드를 추가합니다.
      if (selectedType == "긴급") {
        postData['emergency_blood_type'] =
            selectedBlood == "전체" ? null : selectedBlood;

        // 수혈환자 정보 추가 (모두 선택사항)
        if (_patientNameController.text.trim().isNotEmpty) {
          postData['patient_name'] = _patientNameController.text.trim();
        }
        if (_breedController.text.trim().isNotEmpty) {
          postData['breed'] = _breedController.text.trim();
        }
        if (_ageController.text.trim().isNotEmpty) {
          postData['age'] = int.tryParse(_ageController.text.trim());
        }
        if (_diagnosisController.text.trim().isNotEmpty) {
          postData['diagnosis'] = _diagnosisController.text.trim();
        }
      } else {
        postData['emergency_blood_type'] = null;
      }

      final url = Uri.parse('${Config.serverUrl}/api/hospital/post');

      final response = await AuthHttpClient.post(
        url,
        body: json.encode(postData),
      );

      if (response.statusCode == 201) {
        // 게시글이 성공적으로 생성된 경우
        // dateTimeSlots 필드로 서버에서 날짜+시간을 자동 생성하므로
        // 추가 API 호출 불필요

        _showAlertDialog('성공', '게시글이 성공적으로 등록되었습니다.', () {
          Navigator.of(context).pop(); // 다이얼로그 닫기
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HospitalDashboard()),
          );
        });
      } else {
        _showAlertDialog('등록 실패', '게시글 등록에 실패했습니다: ${response.body}');
      }
    } catch (e) {
      _showAlertDialog('오류 발생', '오류가 발생했습니다: $e');
    }
  }

  // 공통 Alert Dialog 함수
  void _showAlertDialog(
    String title,
    String content, [
    VoidCallback? onOkPressed,
  ]) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onOkPressed?.call(); // 확인 버튼 콜백 실행
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _updateTitleText(); // 초기 기본 제목을 설정하는 함수 호출
    _loadUserAddress(); // 사용자 주소 로드
  }

  // 사용자 주소를 로드하여 텍스트 필드에 설정
  Future<void> _loadUserAddress() async {
    final address = await _getUserAddress();
    if (address.isNotEmpty) {
      setState(() {
        _locationController.text = address;
      });
    } else {
      // API에서 주소를 가져올 수 없으면 빈 값으로 설정
      setState(() {
        _locationController.text = "";
      });

      // 주소를 가져올 수 없다는 메시지 표시
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAlertDialog(
          '알림',
          '병원 주소를 불러올 수 없습니다.\n프로필 관리에서 주소를 먼저 설정해주세요.',
        );
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose(); // 컨트롤러 메모리 해제
    _locationController.dispose(); // 지역 컨트롤러 메모리 해제
    super.dispose();
  }

  void _updateTitleText() {
    // 동물 종류 변환
    String animalTypeKorean = selectedAnimalType == "dog" ? "강아지" : "고양이";
    String title = '[$hospitalNickname] ';

    // 긴급이고 환자 이름이 있는 경우: [병원] 환자이름(강아지) 혈액형 긴급헌혈
    if (selectedType == "긴급" && _patientNameController.text.trim().isNotEmpty) {
      title += '${_patientNameController.text.trim()}($animalTypeKorean)';
      if (selectedBlood != "전체") {
        title += ' $selectedBlood';
      }
      title += ' 긴급헌혈';
    } else {
      // 기본 형식: [병원] 강아지 긴급헌혈 또는 [병원] 강아지 정기헌혈
      title += '$animalTypeKorean $selectedType 헌혈';
      // 긴급이고 혈액형이 전체가 아닌 경우 혈액형 추가
      if (selectedType == "긴급" && selectedBlood != "전체") {
        title += ' ($selectedBlood)';
      }
    }

    _titleController.text = title;
  }

  // 동물 종류에 따른 혈액형 목록 반환
  List<String> _getBloodTypeOptions() {
    // "dog" -> "강아지", "cat" -> "고양이"로 변환
    final String? species;
    if (selectedAnimalType == "dog") {
      species = "강아지";
    } else if (selectedAnimalType == "cat") {
      species = "고양이";
    } else {
      species = null;
    }

    // BloodTypeConstants에서 혈액형 목록 가져오기
    final bloodTypes = BloodTypeConstants.getBloodTypes(species: species);

    // '전체' 옵션을 맨 앞에 추가
    return ['전체', ...bloodTypes];
  }

  // 동물 종류 변경시 혈액형 유효성 검사
  void _validateBloodTypeOnAnimalChange() {
    final validBloodTypes = _getBloodTypeOptions();
    if (!validBloodTypes.contains(selectedBlood)) {
      selectedBlood = "전체"; // 유효하지 않으면 전체로 초기화
    }
  }

  // Modal Bottom Sheet for adding date/time
  void _showAddDateTimeBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder:
                (context, scrollController) => Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: AddDateTimeBottomSheet(
                    onSave: (dateWithTimes) {
                      setState(() {
                        // 같은 날짜가 이미 있는지 확인
                        final existingIndex = selectedDonationDatesWithTimes
                            .indexWhere(
                              (existing) =>
                                  existing.donationDate.year ==
                                      dateWithTimes.donationDate.year &&
                                  existing.donationDate.month ==
                                      dateWithTimes.donationDate.month &&
                                  existing.donationDate.day ==
                                      dateWithTimes.donationDate.day,
                            );

                        if (existingIndex != -1) {
                          // 같은 날짜가 있으면 시간만 추가
                          final existing =
                              selectedDonationDatesWithTimes[existingIndex];
                          final updatedTimes = List<DonationPostTime>.from(
                            existing.times,
                          );

                          // 중복되지 않는 시간만 추가
                          for (final newTime in dateWithTimes.times) {
                            final isDuplicate = updatedTimes.any(
                              (existingTime) =>
                                  existingTime.donationTime.hour ==
                                      newTime.donationTime.hour &&
                                  existingTime.donationTime.minute ==
                                      newTime.donationTime.minute,
                            );

                            if (!isDuplicate) {
                              updatedTimes.add(newTime);
                            }
                          }

                          // 시간순으로 정렬
                          updatedTimes.sort(
                            (a, b) => a.donationTime.compareTo(b.donationTime),
                          );

                          // 기존 항목 업데이트
                          selectedDonationDatesWithTimes[existingIndex] =
                              DonationDateWithTimes(
                                postDatesId: existing.postDatesId,
                                postIdx: existing.postIdx,
                                donationDate: existing.donationDate,
                                times: updatedTimes,
                              );
                        } else {
                          // 새로운 날짜면 추가
                          selectedDonationDatesWithTimes.add(dateWithTimes);
                        }

                        // 날짜순으로 정렬
                        selectedDonationDatesWithTimes.sort(
                          (a, b) => a.donationDate.compareTo(b.donationDate),
                        );
                      });
                    },
                    scrollController: scrollController,
                  ),
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 20.0,
            vertical: 16.0,
          ), // 좌우 여백 20, 상하 여백 16
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헌혈 날짜 및 시간 선택 섹션
              Text("헌혈 게시글 작성", style: AppTheme.h3Style),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radius16),
                  border: Border.all(
                    color: AppTheme.lightGray.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 헌혈 날짜+시간 추가 버튼
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _showAddDateTimeBottomSheet,
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          label: const Text('헌혈 일정 작성'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textSecondary,
                            side: BorderSide(
                              color: AppTheme.lightGray.withValues(alpha: 0.5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius12,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: AppTheme.spacing16,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: AppTheme.spacing16),

                      // 선택된 날짜+시간 목록 표시
                      if (selectedDonationDatesWithTimes.isNotEmpty) ...[
                        Text('선택된 헌혈 일정', style: AppTheme.h4Style),
                        const SizedBox(height: AppTheme.spacing8),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: selectedDonationDatesWithTimes.length,
                          itemBuilder: (context, index) {
                            final dateWithTimes =
                                selectedDonationDatesWithTimes[index];
                            return Container(
                              margin: const EdgeInsets.only(
                                bottom: AppTheme.spacing8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius12,
                                ),
                                border: Border.all(color: AppTheme.lightGray),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius12,
                                ),
                                child: ExpansionTile(
                                  title: Text(
                                    dateWithTimes.dateOnly,
                                    style: AppTheme.bodyLargeStyle.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${dateWithTimes.times.length}개의 시간대',
                                    style: AppTheme.bodySmallStyle.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  tilePadding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacing20,
                                    vertical: AppTheme.spacing8,
                                  ),
                                  childrenPadding: EdgeInsets.zero,
                                  shape: const Border(), // 테두리 제거
                                  collapsedShape:
                                      const Border(), // 닫혔을 때 테두리 제거
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'delete') {
                                        setState(() {
                                          selectedDonationDatesWithTimes
                                              .removeAt(index);
                                        });
                                      }
                                    },
                                    itemBuilder:
                                        (context) => [
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.delete,
                                                  size: 18,
                                                  color: Colors.red,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  '삭제',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                    child: Icon(
                                      Icons.more_vert,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  children:
                                      dateWithTimes.times.map((time) {
                                        return ListTile(
                                          leading: Icon(
                                            Icons.schedule,
                                            size: 20,
                                            color: AppTheme.primaryBlue,
                                          ),
                                          title: Text(
                                            time.formatted12Hour,
                                            style: AppTheme.bodyMediumStyle,
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: AppTheme.spacing20,
                                                vertical: AppTheme.spacing4,
                                              ),
                                        );
                                      }).toList(),
                                ),
                              ),
                            );
                          },
                        ),
                      ] else ...[
                        // 빈 상태 표시
                        Container(
                          padding: const EdgeInsets.all(AppTheme.spacing24),
                          decoration: BoxDecoration(
                            color: AppTheme.lightGray.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius12,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.date_range_outlined,
                                  size: 48,
                                  color: AppTheme.mediumGray,
                                ),
                                const SizedBox(height: AppTheme.spacing12),
                                Text(
                                  '헌혈 날짜와 시간을 추가해주세요',
                                  style: AppTheme.bodyMediumStyle.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32), // 섹션 간 간격
              // 정보 작성 파트
              Text("작성 정보", style: AppTheme.h3Style),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radius16),
                  border: Border.all(
                    color: AppTheme.lightGray.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing20),
                  child: Column(
                    children: [
                      // 지역 입력 (프로필 관리에서 설정한 주소, 수정 불가)
                      TextField(
                        controller: _locationController,
                        readOnly: true, // 수정 불가
                        enabled: false, // 비활성화 (회색으로 표시)
                        decoration: _buildInputDecoration(
                          context,
                          "병원 위치 (프로필 관리에서 수정 가능)",
                          Icons.location_on_outlined,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 동물 종류 선택
                      DropdownButtonFormField<String>(
                        initialValue: selectedAnimalType,
                        items: const [
                          DropdownMenuItem(value: "dog", child: Text("강아지")),
                          DropdownMenuItem(value: "cat", child: Text("고양이")),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedAnimalType = value ?? "dog";
                            _validateBloodTypeOnAnimalChange();
                            _updateTitleText(); // 동물 종류 변경시 제목 업데이트
                          });
                        },
                        decoration: _buildInputDecoration(
                          context,
                          "동물 종류",
                          selectedAnimalType == "dog"
                              ? FontAwesomeIcons.dog
                              : FontAwesomeIcons.cat,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 타입 선택
                      DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        items:
                            ["긴급", "정기"]
                                .map(
                                  (type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(type),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedType = value ?? "정기";
                            _updateTitleText(); // 타입 변경 시 제목 업데이트 함수 호출
                          });
                        },
                        decoration: _buildInputDecoration(
                          context,
                          "게시글 타입",
                          Icons.category_outlined,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 혈액형 선택 (긴급 헌혈일 때만 표시)
                      if (selectedType == "긴급") ...[
                        DropdownButtonFormField<String>(
                          initialValue: selectedBlood,
                          items:
                              _getBloodTypeOptions()
                                  .map(
                                    (type) => DropdownMenuItem(
                                      value: type,
                                      child: Text(type),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedBlood = value ?? "전체";
                              _updateTitleText(); // 혈액형 변경시 제목 업데이트
                            });
                          },
                          decoration: _buildInputDecoration(
                            context,
                            "필요 혈액형",
                            Icons.bloodtype_outlined,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 수혈환자 정보 섹션 (긴급일 때만 표시, 모두 선택사항)
                        Text(
                          "수혈환자 정보 (선택사항)",
                          style: AppTheme.bodyLargeStyle.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _patientNameController,
                          decoration: _buildInputDecoration(
                            context,
                            "환자 이름",
                            Icons.pets_outlined,
                          ),
                          onChanged: (_) => _updateTitleText(), // 이름 변경시 제목 업데이트
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _breedController,
                          decoration: _buildInputDecoration(
                            context,
                            "견종/묘종",
                            Icons.category_outlined,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _ageController,
                          decoration: _buildInputDecoration(
                            context,
                            "나이 (숫자만)",
                            Icons.cake_outlined,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _diagnosisController,
                          decoration: _buildInputDecoration(
                            context,
                            "병명/증상",
                            Icons.medical_information_outlined,
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 20),
                      ],

                      TextField(
                        controller: _titleController,
                        decoration: _buildInputDecoration(
                          context,
                          "게시글 제목",
                          Icons.title,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // 상세 설명 섹션 (리치 에디터)
              Text("상세 설명", style: AppTheme.h3Style),
              const SizedBox(height: 16),
              RichTextEditor(
                key: _richEditorKey,
                initialText: additionalDescription,
                initialImages: _postImages,
                maxImages: 5,
                onChanged: (text, images) {
                  setState(() {
                    additionalDescription = text;
                    _postImages = images;
                  });
                },
              ),

              // 이미지 안내
              Container(
                margin: const EdgeInsets.only(top: AppTheme.spacing16),
                padding: const EdgeInsets.all(AppTheme.spacing16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9E6),
                  border: Border.all(color: const Color(0xFFFFE4B5)),
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: const Color(0xFFB8860B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '이미지 안내',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFB8860B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• 최대 5장까지 업로드 가능합니다.\n'
                      '• 최대 파일 크기: 20MB (고화질 이미지 지원)\n'
                      '• 모든 이미지 형식 지원 (JPG로 자동 변환 저장)\n'
                      '• 이미지는 관리자 승인 후 7일 뒤 자동 삭제됩니다.',
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFF8B6914),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 등록 버튼
              Material(
                color: Colors.black,
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                child: InkWell(
                  onTap: _submitPost,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  child: Container(
                    height: AppTheme.buttonHeightLarge,
                    alignment: Alignment.center,
                    child: Text(
                      "헌혈 게시글 등록",
                      style: AppTheme.h4Style.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

  // InputDecoration 공통 스타일
  InputDecoration _buildInputDecoration(
    BuildContext context,
    String labelText,
    IconData icon,
  ) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(icon, color: Colors.grey[600]), // 아이콘 추가
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
    );
  }
}

class _TimeEntryDialog extends StatefulWidget {
  final Function(String timeRange, int teamNumber) onSave;

  const _TimeEntryDialog({required this.onSave}); // const 생성자 추가

  @override
  State createState() => _TimeEntryDialogState();
}

class _TimeEntryDialogState extends State<_TimeEntryDialog> {
  TimeOfDay startTimeOfDay = const TimeOfDay(hour: 9, minute: 0); // 기본 시작 시간
  TimeOfDay endTimeOfDay = const TimeOfDay(hour: 9, minute: 30); // 기본 종료 시간
  int teamNumber = 1;

  String get _formattedStartTime =>
      '${startTimeOfDay.hour.toString().padLeft(2, '0')}:${startTimeOfDay.minute.toString().padLeft(2, '0')}';
  String get _formattedEndTime =>
      '${endTimeOfDay.hour.toString().padLeft(2, '0')}:${endTimeOfDay.minute.toString().padLeft(2, '0')}';

  // 시간 비교 함수 (클래스 내부에 정의하여 재사용 가능하도록)
  bool _isTimeBefore(TimeOfDay time1, TimeOfDay time2) {
    int minutes1 = time1.hour * 60 + time1.minute;
    int minutes2 = time2.hour * 60 + time2.minute;
    return minutes1 < minutes2;
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showIntervalTimePicker(
      context: context,
      initialTime: isStartTime ? startTimeOfDay : endTimeOfDay,
      interval: 5, // 5분 단위로 설정
      builder: (context, child) {
        // 테마 적용
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary, // AppBar 색상과 일치
              onPrimary: Theme.of(context).colorScheme.onPrimary,
              onSurface: Colors.black87, // 텍스트 색상
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor:
                    Theme.of(context).colorScheme.primary, // 버튼 텍스트 색상
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          startTimeOfDay = picked;
          // 시작 시간 변경 시 종료 시간이 시작 시간보다 이전이면 조정
          if (_isTimeBefore(endTimeOfDay, startTimeOfDay)) {
            endTimeOfDay = TimeOfDay(
              hour: startTimeOfDay.hour,
              minute: startTimeOfDay.minute + 30,
            ); // 30분 후로 설정 예시
            if (endTimeOfDay.minute >= 60) {
              endTimeOfDay = TimeOfDay(
                hour: (endTimeOfDay.hour + 1) % 24,
                minute: endTimeOfDay.minute % 60,
              );
            }
          }
        } else {
          // 종료 시간이 시작 시간보다 이전인지 확인
          if (_isTimeBefore(picked, startTimeOfDay)) {
            _showAlertDialog('시간 오류', '종료 시간은 시작 시간보다 이후여야 합니다.');
          } else {
            endTimeOfDay = picked;
          }
        }
      });
    }
  }

  void _showAlertDialog(
    String title,
    String content, [
    VoidCallback? onOkPressed,
  ]) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onOkPressed?.call();
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text("시간대 추가", style: textTheme.titleLarge),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTimeSelectionTile(
            context,
            label: "시작 시간",
            time: _formattedStartTime,
            onTap: () => _selectTime(context, true),
          ),
          const Divider(height: 24),
          _buildTimeSelectionTile(
            context,
            label: "종료 시간",
            time: _formattedEndTime,
            onTap: () => _selectTime(context, false),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text("필요 팀 수:", style: textTheme.titleMedium),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: teamNumber,
                  items:
                      List.generate(10, (index) => index + 1)
                          .map(
                            (teamNum) => DropdownMenuItem<int>(
                              value: teamNum,
                              child: Text("$teamNum팀"),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        teamNumber = value;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
          child: const Text("취소"),
        ),
        ElevatedButton(
          onPressed: () {
            if (_isTimeBefore(endTimeOfDay, startTimeOfDay)) {
              _showAlertDialog('시간 오류', '종료 시간은 시작 시간보다 이후여야 합니다.');
              return;
            }
            widget.onSave(
              "$_formattedStartTime~$_formattedEndTime",
              teamNumber,
            );
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 2,
          ),
          child: const Text(
            "추가하기",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // 시간 선택 타일 공통 위젯
  Widget _buildTimeSelectionTile(
    BuildContext context, {
    required String label,
    required String time,
    required VoidCallback onTap,
  }) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$label: ', style: textTheme.titleMedium),
            Row(
              children: [
                Text(
                  time,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.access_time_outlined, color: Colors.grey[600]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EditEntryDialog extends StatefulWidget {
  final Map<String, dynamic> entry;
  final Function(Map<String, dynamic>) onSave;

  const _EditEntryDialog({
    required this.entry,
    required this.onSave,
  }); // const 생성자 추가

  @override
  State<_EditEntryDialog> createState() => _EditEntryDialogState();
}

class _EditEntryDialogState extends State<_EditEntryDialog> {
  late DateTime selectedDate;
  late TimeOfDay startTimeOfDay;
  late TimeOfDay endTimeOfDay;
  late int teamNumber;

  String get _formattedDate =>
      "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
  String get _formattedStartTime =>
      '${startTimeOfDay.hour.toString().padLeft(2, '0')}:${startTimeOfDay.minute.toString().padLeft(2, '0')}';
  String get _formattedEndTime =>
      '${endTimeOfDay.hour.toString().padLeft(2, '0')}:${endTimeOfDay.minute.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    // 날짜 처리 (기존 로직 그대로 유지)
    if (widget.entry['date'] != null) {
      try {
        selectedDate = DateTime.parse(widget.entry['date']);
      } catch (e) {
        selectedDate = DateTime.now();
      }
    } else {
      selectedDate = DateTime.now();
    }

    // 시간 문자열 파싱 (기존 로직 그대로 유지)
    final timeRange = widget.entry['timeRange'] ?? "00:00~00:30";
    final times = timeRange.split('~');

    startTimeOfDay = _parseTimeString(times[0]);
    endTimeOfDay = _parseTimeString(times[1]);

    teamNumber = widget.entry['teamNumber'] ?? 1;
  }

  TimeOfDay _parseTimeString(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  // 시간 비교 함수 (_TimeEntryDialogState와 동일하게 정의)
  bool _isTimeBefore(TimeOfDay time1, TimeOfDay time2) {
    int minutes1 = time1.hour * 60 + time1.minute;
    int minutes2 = time2.hour * 60 + time2.minute;
    return minutes1 < minutes2;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      helpText: '헌혈 날짜 선택',
      confirmText: '선택',
      cancelText: '취소',
      builder: (context, child) {
        // 테마 적용
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary, // AppBar 색상과 일치
              onPrimary: Theme.of(context).colorScheme.onPrimary,
              onSurface: Colors.black87, // 텍스트 색상
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor:
                    Theme.of(context).colorScheme.primary, // 버튼 텍스트 색상
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate != null) {
      setState(() {
        selectedDate = pickedDate;
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showIntervalTimePicker(
      // showTimePicker -> showIntervalTimePicker 변경
      context: context,
      initialTime: isStartTime ? startTimeOfDay : endTimeOfDay,
      interval: 5, // 5분 단위
      builder: (context, child) {
        // 테마 적용
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Theme.of(context).colorScheme.onPrimary,
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          startTimeOfDay = picked;
          // 시작 시간 변경 시 종료 시간이 시작 시간보다 이전이면 조정
          if (_isTimeBefore(endTimeOfDay, startTimeOfDay)) {
            endTimeOfDay = TimeOfDay(
              hour: startTimeOfDay.hour,
              minute: startTimeOfDay.minute + 30,
            ); // 30분 후로 설정 예시
            if (endTimeOfDay.minute >= 60) {
              endTimeOfDay = TimeOfDay(
                hour: (endTimeOfDay.hour + 1) % 24,
                minute: endTimeOfDay.minute % 60,
              );
            }
          }
        } else {
          // 종료 시간이 시작 시간보다 이전인지 확인
          if (_isTimeBefore(picked, startTimeOfDay)) {
            _showAlertDialog('시간 오류', '종료 시간은 시작 시간보다 이후여야 합니다.');
          } else {
            endTimeOfDay = picked;
          }
        }
      });
    }
  }

  void _showAlertDialog(
    String title,
    String content, [
    VoidCallback? onOkPressed,
  ]) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onOkPressed?.call();
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text("시간대 수정", style: textTheme.titleLarge),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 날짜 선택 버튼
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _selectDate(context),
              icon: Icon(Icons.calendar_today_outlined, size: 18),
              label: Text("날짜 선택: $_formattedDate"),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: BorderSide(
                  color: colorScheme.primary.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildTimeSelectionTile(
            context,
            label: "시작 시간",
            time: _formattedStartTime,
            onTap: () => _selectTime(context, true),
          ),
          const Divider(height: 24),
          _buildTimeSelectionTile(
            context,
            label: "종료 시간",
            time: _formattedEndTime,
            onTap: () => _selectTime(context, false),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text("필요 팀 수:", style: textTheme.titleMedium),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: teamNumber,
                  items:
                      List.generate(10, (index) => index + 1)
                          .map(
                            (teamNum) => DropdownMenuItem<int>(
                              value: teamNum,
                              child: Text("$teamNum팀"),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        teamNumber = value;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
          child: const Text("취소"),
        ),
        ElevatedButton(
          onPressed: () {
            if (_isTimeBefore(endTimeOfDay, startTimeOfDay)) {
              _showAlertDialog('시간 오류', '종료 시간은 시작 시간보다 이후여야 합니다.');
              return;
            }
            widget.onSave({
              "date": _formattedDate, // 수정된 날짜 반영
              "timeRange": "$_formattedStartTime~$_formattedEndTime",
              "teamNumber": teamNumber,
            });
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 2,
          ),
          child: const Text(
            "저장하기",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // 시간 선택 타일 공통 위젯 (_TimeEntryDialogState와 동일)
  Widget _buildTimeSelectionTile(
    BuildContext context, {
    required String label,
    required String time,
    required VoidCallback onTap,
  }) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$label: ', style: textTheme.titleMedium),
            Row(
              children: [
                Text(
                  time,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.access_time_outlined, color: Colors.grey[600]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Modal Bottom Sheet Widget for Date/Time Addition
class AddDateTimeBottomSheet extends StatefulWidget {
  final Function(DonationDateWithTimes) onSave;
  final ScrollController scrollController;

  const AddDateTimeBottomSheet({
    super.key,
    required this.onSave,
    required this.scrollController,
  });

  @override
  State<AddDateTimeBottomSheet> createState() => _AddDateTimeBottomSheetState();
}

class _AddDateTimeBottomSheetState extends State<AddDateTimeBottomSheet> {
  DateTime selectedDate = DateTime.now();
  List<TimeOfDay> selectedTimes = [];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '헌혈 일정 작성',
                  style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.w700),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                // Date Selection
                Text(
                  '날짜 선택',
                  style: AppTheme.bodyLargeStyle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.calendar_today,
                      color: Colors.black,
                    ),
                    title: Text(
                      '${selectedDate.year}년 ${selectedDate.month}월 ${selectedDate.day}일',
                      style: const TextStyle(color: Colors.black),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.black,
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() {
                          selectedDate = date;
                        });
                      }
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // Time Selection
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '시간 선택',
                      style: AppTheme.bodyLargeStyle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addTimeSlot,
                      icon: const Icon(
                        Icons.add,
                        color: Colors.black,
                        size: 20,
                      ),
                      label: const Text(
                        '시간 추가',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Selected Times List
                if (selectedTimes.isNotEmpty) ...[
                  ...selectedTimes.asMap().entries.map((entry) {
                    int index = entry.key;
                    TimeOfDay time = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.access_time,
                          color: Colors.black,
                        ),
                        title: Text(
                          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.black),
                        ),
                        trailing: IconButton(
                          onPressed: () {
                            setState(() {
                              selectedTimes.removeAt(index);
                            });
                          },
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    );
                  }),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        '시간을 추가해주세요',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 30),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedTimes.isNotEmpty ? _saveDateTime : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('일정 저장'),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addTimeSlot() async {
    final time = await showIntervalTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0), // 오전 9시로 초기 설정
      interval: 5, // 5분 단위로 설정
    );

    if (time != null) {
      setState(() {
        if (!selectedTimes.any(
          (t) => t.hour == time.hour && t.minute == time.minute,
        )) {
          selectedTimes.add(time);
          selectedTimes.sort(
            (a, b) =>
                a.hour.compareTo(b.hour) != 0
                    ? a.hour.compareTo(b.hour)
                    : a.minute.compareTo(b.minute),
          );
        }
      });
    }
  }

  void _saveDateTime() {
    final dateWithTimes = DonationDateWithTimes(
      postDatesId: 0, // 임시값, 서버에서 생성됨
      postIdx: 0, // 임시값, 서버에서 생성됨
      donationDate: selectedDate,
      times:
          selectedTimes
              .map<DonationPostTime>(
                (time) => DonationPostTime(
                  postTimesId: null, // nullable이므로 null로 설정
                  postDatesIdx: 0, // 임시값
                  donationTime: DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    time.hour,
                    time.minute,
                  ),
                ),
              )
              .toList(),
    );

    widget.onSave(dateWithTimes);
    Navigator.pop(context);
  }
}
