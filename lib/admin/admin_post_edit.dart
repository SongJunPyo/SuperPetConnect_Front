// lib/admin/admin_post_edit.dart
// 관리자 게시글 수정 페이지

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:interval_time_picker/interval_time_picker.dart';
import 'dart:convert';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../utils/config.dart';
import '../utils/app_theme.dart';
import '../utils/blood_type_constants.dart';
import '../models/donation_post_time_model.dart';
import '../models/donation_post_image_model.dart';
import '../widgets/rich_text_editor.dart';
import '../services/auth_http_client.dart';

class AdminPostEdit extends StatefulWidget {
  final Map<String, dynamic> post;

  const AdminPostEdit({super.key, required this.post});

  @override
  State<AdminPostEdit> createState() => _AdminPostEditState();
}

class _AdminPostEditState extends State<AdminPostEdit> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _breedController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _diagnosisController = TextEditingController();

  List<DonationDateWithTimes> selectedDonationDatesWithTimes = [];
  String selectedType = "정기";
  String selectedAnimalType = "dog";
  String selectedBlood = "전체";
  String additionalDescription = "";
  List<DonationPostImage> _postImages = [];
  final GlobalKey<RichTextEditorState> _richEditorKey =
      GlobalKey<RichTextEditorState>();

  String? _initialContentDelta; // 기존 리치텍스트 Delta JSON
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadPostData();
  }

  /// 기존 게시글 데이터를 폼에 로드
  void _loadPostData() {
    final post = widget.post;

    // 제목
    _titleController.text = post['title'] ?? '';

    // 위치
    _locationController.text = post['location'] ?? '';

    // 동물 종류 (0=dog, 1=cat)
    final animalTypeRaw = post['animalType'] ?? post['animal_type'];
    if (animalTypeRaw == 1 || animalTypeRaw == '1') {
      selectedAnimalType = 'cat';
    } else {
      selectedAnimalType = 'dog';
    }

    // 게시글 타입 (0=긴급, 1=정기)
    final typesRaw = post['types'];
    if (typesRaw == 0 || typesRaw == '0') {
      selectedType = '긴급';
    } else {
      selectedType = '정기';
    }

    // 혈액형
    final bloodType = post['bloodType'] ?? post['blood_type'] ?? post['emergency_blood_type'];
    if (bloodType != null && bloodType.toString().isNotEmpty) {
      selectedBlood = bloodType.toString();
    } else {
      selectedBlood = '전체';
    }

    // 환자 정보 (긴급 헌혈)
    _patientNameController.text = post['patientName']?.toString() ?? post['patient_name']?.toString() ?? '';
    _breedController.text = post['breed']?.toString() ?? '';
    final age = post['age'];
    _ageController.text = age != null ? age.toString() : '';
    _diagnosisController.text = post['diagnosis']?.toString() ?? '';

    // 설명 (plain text)
    additionalDescription = post['description']?.toString() ?? '';

    // Delta JSON (리치 텍스트)
    _initialContentDelta = (post['contentDelta'] ?? post['content_delta'])?.toString();

    // 시간대 데이터 변환
    _loadAvailableDates();
  }

  /// availableDates Map을 DonationDateWithTimes 목록으로 변환
  void _loadAvailableDates() {
    final availableDates = widget.post['availableDates'];
    if (availableDates == null || availableDates is! Map) return;

    final List<DonationDateWithTimes> datesList = [];

    availableDates.forEach((dateStr, timesData) {
      if (timesData is! List) return;

      final DateTime date;
      try {
        date = DateTime.parse(dateStr.toString());
      } catch (e) {
        return;
      }

      final List<DonationPostTime> times = [];
      for (final timeEntry in timesData) {
        if (timeEntry is! Map) continue;

        final timeStr = timeEntry['time']?.toString();
        final datetimeStr = timeEntry['datetime']?.toString();

        DateTime? donationTime;
        if (datetimeStr != null) {
          try {
            donationTime = DateTime.parse(datetimeStr);
          } catch (_) {}
        }
        if (donationTime == null && timeStr != null) {
          final parts = timeStr.split(':');
          if (parts.length >= 2) {
            donationTime = DateTime(
              date.year, date.month, date.day,
              int.tryParse(parts[0]) ?? 0,
              int.tryParse(parts[1]) ?? 0,
            );
          }
        }

        if (donationTime != null) {
          times.add(DonationPostTime(
            postTimesId: timeEntry['post_times_idx'],
            postDatesIdx: 0,
            donationTime: donationTime,
            status: timeEntry['status'] ?? 0,
          ));
        }
      }

      if (times.isNotEmpty) {
        times.sort((a, b) => a.donationTime.compareTo(b.donationTime));
        datesList.add(DonationDateWithTimes(
          postDatesId: 0,
          postIdx: widget.post['id'] ?? 0,
          donationDate: date,
          times: times,
        ));
      }
    });

    datesList.sort((a, b) => a.donationDate.compareTo(b.donationDate));
    setState(() {
      selectedDonationDatesWithTimes = datesList;
    });
  }

  /// 동물 종류에 따른 혈액형 목록 반환
  List<String> _getBloodTypeOptions() {
    final String? species;
    if (selectedAnimalType == "dog") {
      species = "강아지";
    } else if (selectedAnimalType == "cat") {
      species = "고양이";
    } else {
      species = null;
    }
    final bloodTypes = BloodTypeConstants.getBloodTypes(species: species);
    return ['전체', ...bloodTypes];
  }

  /// 동물 종류 변경시 혈액형 유효성 검사
  void _validateBloodTypeOnAnimalChange() {
    final validBloodTypes = _getBloodTypeOptions();
    if (!validBloodTypes.contains(selectedBlood)) {
      selectedBlood = "전체";
    }
  }

  /// 게시글 수정 제출
  Future<void> _submitEdit() async {
    if (_isSubmitting) return;

    if (selectedDonationDatesWithTimes.isEmpty) {
      _showAlertDialog('알림', '최소 하나 이상의 헌혈 날짜와 시간을 추가해주세요.');
      return;
    }

    if (_titleController.text.isEmpty) {
      _showAlertDialog('알림', '게시글 제목을 입력해주세요.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final postIdx = widget.post['id'];
      if (postIdx == null) {
        _showAlertDialog('오류', '게시글 ID를 찾을 수 없습니다.');
        return;
      }

      // 날짜+시간 데이터 준비
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

      final Map<String, dynamic> postData = {
        "title": _titleController.text,
        "descriptions": additionalDescription,
        "content_delta": contentDelta,
        "animal_type": selectedAnimalType == "dog" ? 0 : 1,
        "types": selectedType == "긴급" ? 0 : 1,
        "dateTimeSlots": dateTimeData,
      };

      // 긴급 타입일 때 추가 필드
      if (selectedType == "긴급") {
        postData['emergency_blood_type'] =
            selectedBlood == "전체" ? null : selectedBlood;

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

      // 이미지 ID 목록
      if (embeddedImageIds.isNotEmpty) {
        postData["image_ids"] = embeddedImageIds;
      }

      final url = Uri.parse('${Config.serverUrl}/api/admin/posts/$postIdx');

      final response = await AuthHttpClient.put(
        url,
        body: json.encode(postData),
      );

      if (response.statusCode == 200) {
        _showAlertDialog('성공', '게시글이 성공적으로 수정되었습니다.', () {
          Navigator.of(context).pop(); // 다이얼로그 닫기
          Navigator.of(context).pop(true); // 수정 페이지 닫기, 결과 반환
        });
      } else {
        _showAlertDialog('수정 실패', '게시글 수정에 실패했습니다: ${response.body}');
      }
    } catch (e) {
      _showAlertDialog('오류 발생', '오류가 발생했습니다: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showAlertDialog(String title, String content, [VoidCallback? onOkPressed]) {
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

  /// 날짜+시간 추가 바텀시트
  void _showAddDateTimeBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: _AddDateTimeBottomSheet(
            onSave: (dateWithTimes) {
              setState(() {
                final existingIndex = selectedDonationDatesWithTimes.indexWhere(
                  (existing) =>
                      existing.donationDate.year == dateWithTimes.donationDate.year &&
                      existing.donationDate.month == dateWithTimes.donationDate.month &&
                      existing.donationDate.day == dateWithTimes.donationDate.day,
                );

                if (existingIndex != -1) {
                  final existing = selectedDonationDatesWithTimes[existingIndex];
                  final updatedTimes = List<DonationPostTime>.from(existing.times);

                  for (final newTime in dateWithTimes.times) {
                    final isDuplicate = updatedTimes.any(
                      (existingTime) =>
                          existingTime.donationTime.hour == newTime.donationTime.hour &&
                          existingTime.donationTime.minute == newTime.donationTime.minute,
                    );
                    if (!isDuplicate) {
                      updatedTimes.add(newTime);
                    }
                  }

                  updatedTimes.sort((a, b) => a.donationTime.compareTo(b.donationTime));

                  selectedDonationDatesWithTimes[existingIndex] = DonationDateWithTimes(
                    postDatesId: existing.postDatesId,
                    postIdx: existing.postIdx,
                    donationDate: existing.donationDate,
                    times: updatedTimes,
                  );
                } else {
                  selectedDonationDatesWithTimes.add(dateWithTimes);
                }

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

  InputDecoration _buildInputDecoration(
    BuildContext context,
    String labelText,
    IconData icon,
  ) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(icon, color: Colors.grey[600]),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      labelStyle: TextStyle(color: Colors.grey[700]),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _patientNameController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _diagnosisController.dispose();
    super.dispose();
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
        title: const Text('게시글 수정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헌혈 일정 섹션
              Text("헌혈 일정", style: AppTheme.h3Style),
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
                      // 헌혈 일정 추가 버튼
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _showAddDateTimeBottomSheet,
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          label: const Text('헌혈 일정 추가'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textSecondary,
                            side: BorderSide(
                              color: AppTheme.lightGray.withValues(alpha: 0.5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radius12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
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
                            final dateWithTimes = selectedDonationDatesWithTimes[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(AppTheme.radius12),
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
                                borderRadius: BorderRadius.circular(AppTheme.radius12),
                                child: ExpansionTile(
                                  title: Text(
                                    dateWithTimes.dateOnly,
                                    style: AppTheme.bodyLargeStyle.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    '${dateWithTimes.times.length}개의 시간대',
                                    style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.textSecondary),
                                  ),
                                  tilePadding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacing20,
                                    vertical: AppTheme.spacing8,
                                  ),
                                  childrenPadding: EdgeInsets.zero,
                                  shape: const Border(),
                                  collapsedShape: const Border(),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'delete') {
                                        setState(() {
                                          selectedDonationDatesWithTimes.removeAt(index);
                                        });
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, size: 18, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('삭제', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                    child: Icon(Icons.more_vert, color: AppTheme.textSecondary),
                                  ),
                                  children: dateWithTimes.times.map((time) {
                                    return ListTile(
                                      leading: Icon(Icons.schedule, size: 20, color: AppTheme.primaryBlue),
                                      title: Text(time.formatted12Hour, style: AppTheme.bodyMediumStyle),
                                      contentPadding: const EdgeInsets.symmetric(
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
                        Container(
                          padding: const EdgeInsets.all(AppTheme.spacing24),
                          decoration: BoxDecoration(
                            color: AppTheme.lightGray.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(AppTheme.radius12),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.date_range_outlined, size: 48, color: AppTheme.mediumGray),
                                const SizedBox(height: AppTheme.spacing12),
                                Text(
                                  '헌혈 날짜와 시간을 추가해주세요',
                                  style: AppTheme.bodyMediumStyle.copyWith(color: AppTheme.textSecondary),
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

              const SizedBox(height: 32),

              // 작성 정보 섹션
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
                      // 병원 위치 (서버에서 Account 주소를 사용하므로 수정 불가)
                      TextField(
                        controller: _locationController,
                        readOnly: true,
                        enabled: false,
                        decoration: _buildInputDecoration(
                          context,
                          "병원 위치 (병원 프로필에서 수정 가능)",
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
                        items: ["긴급", "정기"]
                            .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedType = value ?? "정기";
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
                          items: _getBloodTypeOptions()
                              .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedBlood = value ?? "전체";
                            });
                          },
                          decoration: _buildInputDecoration(
                            context,
                            "필요 혈액형",
                            Icons.bloodtype_outlined,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 수혈환자 정보 (선택사항)
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
                          decoration: _buildInputDecoration(context, "환자 이름", Icons.pets_outlined),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _breedController,
                          decoration: _buildInputDecoration(context, "견종/묘종", Icons.category_outlined),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _ageController,
                          decoration: _buildInputDecoration(context, "나이 (숫자만)", Icons.cake_outlined),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _diagnosisController,
                          decoration: _buildInputDecoration(context, "병명/증상", Icons.medical_information_outlined),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 20),
                      ],

                      // 게시글 제목
                      TextField(
                        controller: _titleController,
                        decoration: _buildInputDecoration(context, "게시글 제목", Icons.title),
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
                initialContentDelta: _initialContentDelta,
                initialImages: _postImages,
                maxImages: 5,
                onChanged: (text, images) {
                  setState(() {
                    additionalDescription = text;
                    _postImages = images;
                  });
                },
              ),

              const SizedBox(height: 32),

              // 수정 완료 버튼
              Material(
                color: _isSubmitting ? Colors.grey : Colors.black,
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                child: InkWell(
                  onTap: _isSubmitting ? null : _submitEdit,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  child: Container(
                    height: AppTheme.buttonHeightLarge,
                    alignment: Alignment.center,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            "수정 완료",
                            style: AppTheme.h4Style.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// 날짜+시간 추가 바텀시트 (hospital_post.dart의 AddDateTimeBottomSheet 기반)
class _AddDateTimeBottomSheet extends StatefulWidget {
  final Function(DonationDateWithTimes) onSave;
  final ScrollController scrollController;

  const _AddDateTimeBottomSheet({
    required this.onSave,
    required this.scrollController,
  });

  @override
  State<_AddDateTimeBottomSheet> createState() => _AddDateTimeBottomSheetState();
}

class _AddDateTimeBottomSheetState extends State<_AddDateTimeBottomSheet> {
  DateTime selectedDate = DateTime.now();
  List<TimeOfDay> selectedTimes = [];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                  '헌혈 일정 추가',
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
                // 날짜 선택
                Text(
                  '날짜 선택',
                  style: AppTheme.bodyLargeStyle.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today, color: Colors.black),
                    title: Text(
                      '${selectedDate.year}년 ${selectedDate.month}월 ${selectedDate.day}일',
                      style: const TextStyle(color: Colors.black),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() => selectedDate = date);
                      }
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // 시간 선택
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '시간 선택',
                      style: AppTheme.bodyLargeStyle.copyWith(fontWeight: FontWeight.w600),
                    ),
                    TextButton.icon(
                      onPressed: _addTimeSlot,
                      icon: const Icon(Icons.add, color: Colors.black, size: 20),
                      label: const Text('시간 추가', style: TextStyle(color: Colors.black)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

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
                        leading: const Icon(Icons.access_time, color: Colors.black),
                        title: Text(
                          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.black),
                        ),
                        trailing: IconButton(
                          onPressed: () {
                            setState(() => selectedTimes.removeAt(index));
                          },
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
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
                      child: Text('시간을 추가해주세요', style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                ],

                const SizedBox(height: 30),

                // 저장 버튼
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
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      interval: 5,
    );

    if (time != null) {
      setState(() {
        if (!selectedTimes.any((t) => t.hour == time.hour && t.minute == time.minute)) {
          selectedTimes.add(time);
          selectedTimes.sort(
            (a, b) => a.hour.compareTo(b.hour) != 0
                ? a.hour.compareTo(b.hour)
                : a.minute.compareTo(b.minute),
          );
        }
      });
    }
  }

  void _saveDateTime() {
    final dateWithTimes = DonationDateWithTimes(
      postDatesId: 0,
      postIdx: 0,
      donationDate: selectedDate,
      times: selectedTimes
          .map<DonationPostTime>(
            (time) => DonationPostTime(
              postTimesId: null,
              postDatesIdx: 0,
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
