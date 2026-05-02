import 'package:flutter/material.dart';
import 'package:interval_time_picker/interval_time_picker.dart';

import '../models/donation_post_time_model.dart';
import '../utils/app_theme.dart';

/// 헌혈 일정(날짜 + 다중 시간) 추가용 바텀시트.
///
/// 병원 게시글 작성([HospitalPost])과 관리자 게시글 수정([AdminPostEdit]) 양쪽에서
/// 사용. `DraggableScrollableSheet` 안에 띄우며 외부 [scrollController]를 받아
/// 시트의 ListView가 시트와 함께 스크롤되게 함. 저장 버튼을 누르면 [onSave]에
/// [DonationDateWithTimes]를 넘기고 시트를 닫음.
///
/// [title]은 헤더 텍스트. 기본값은 `'헌혈 일정 추가'`이며, 호출부에서 다른 표현이
/// 필요하면 override.
class AddDateTimeBottomSheet extends StatefulWidget {
  final Function(DonationDateWithTimes) onSave;
  final ScrollController scrollController;
  final String title;

  const AddDateTimeBottomSheet({
    super.key,
    required this.onSave,
    required this.scrollController,
    this.title = '헌혈 일정 추가',
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
                  widget.title,
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
                      Icons.calendar_today_outlined,
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
