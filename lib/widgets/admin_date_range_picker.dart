import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../utils/app_theme.dart';
import '../utils/korean_holidays.dart';

/// 관리자용 날짜 범위 선택 다이얼로그.
/// Flutter `showDateRangePicker`가 leading icon / title 커스터마이즈를 막아서
/// `table_calendar` 기반으로 자체 구현 — 일요일/한국 공휴일 빨강 표시 포함.
Future<DateTimeRange?> showAdminDateRangePicker({
  required BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTimeRange? initialRange,
  String title = '작성일 기준 검색',
  String confirmText = '검색',
}) {
  return Navigator.of(context).push<DateTimeRange>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => _AdminDateRangePicker(
        firstDate: firstDate,
        lastDate: lastDate,
        initialRange: initialRange,
        title: title,
        confirmText: confirmText,
      ),
    ),
  );
}

class _AdminDateRangePicker extends StatefulWidget {
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTimeRange? initialRange;
  final String title;
  final String confirmText;

  const _AdminDateRangePicker({
    required this.firstDate,
    required this.lastDate,
    required this.title,
    required this.confirmText,
    this.initialRange,
  });

  @override
  State<_AdminDateRangePicker> createState() => _AdminDateRangePickerState();
}

class _AdminDateRangePickerState extends State<_AdminDateRangePicker> {
  late DateTime _focusedDay;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  @override
  void initState() {
    super.initState();
    _rangeStart = widget.initialRange?.start;
    _rangeEnd = widget.initialRange?.end;
    // initialRange가 없으면 lastDate(오늘)을 기준으로 — 가장 최근 달 표시.
    _focusedDay = _rangeStart ?? widget.lastDate;
  }

  void _onRangeSelected(DateTime? start, DateTime? end, DateTime focusedDay) {
    setState(() {
      _focusedDay = focusedDay;
      _rangeStart = start;
      _rangeEnd = end;
    });
  }

  void _onConfirm() {
    if (_rangeStart == null) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(
      DateTimeRange(
        start: _rangeStart!,
        end: _rangeEnd ?? _rangeStart!,
      ),
    );
  }

  String _formatRange() {
    if (_rangeStart == null) return '시작일 - 종료일';
    final fmt = DateFormat('yyyy.MM.dd', 'ko_KR');
    final start = fmt.format(_rangeStart!);
    if (_rangeEnd == null) return '$start - 종료일';
    final end = fmt.format(_rangeEnd!);
    return '$start - $end';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Text(
          widget.title,
          style: const TextStyle(
            fontSize: AppTheme.h3,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _rangeStart != null ? _onConfirm : null,
            child: Text(
              widget.confirmText,
              style: TextStyle(
                color: _rangeStart != null
                    ? AppTheme.primaryBlue
                    : AppTheme.textDisabled,
                fontSize: AppTheme.bodyLarge,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Text(
              _formatRange(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.h2,
                fontWeight: FontWeight.w700,
                color: _rangeStart != null
                    ? AppTheme.textPrimary
                    : AppTheme.textTertiary,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TableCalendar(
                firstDay: widget.firstDate,
                lastDay: widget.lastDate,
                focusedDay: _focusedDay,
                rangeStartDay: _rangeStart,
                rangeEndDay: _rangeEnd,
                rangeSelectionMode: RangeSelectionMode.toggledOn,
                onRangeSelected: _onRangeSelected,
                onPageChanged: (focusedDay) {
                  // setState 불필요 — focusedDay는 페이지 이동용 내부 상태.
                  _focusedDay = focusedDay;
                },
                holidayPredicate: KoreanHolidays.isHoliday,
                weekendDays: const [DateTime.sunday],
                locale: 'ko_KR',
                availableGestures: AvailableGestures.horizontalSwipe,
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: false,
                  leftChevronIcon:
                      Icon(Icons.chevron_left, color: AppTheme.textPrimary),
                  rightChevronIcon:
                      Icon(Icons.chevron_right, color: AppTheme.textPrimary),
                  titleTextStyle: TextStyle(
                    fontSize: AppTheme.bodyLarge,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekendStyle: TextStyle(
                    color: AppTheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                  weekdayStyle: TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  weekendTextStyle: const TextStyle(color: AppTheme.error),
                  holidayTextStyle: const TextStyle(color: AppTheme.error),
                  defaultTextStyle:
                      const TextStyle(color: AppTheme.textPrimary),
                  disabledTextStyle:
                      const TextStyle(color: AppTheme.textDisabled),
                  todayDecoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primaryBlue, width: 1.5),
                  ),
                  todayTextStyle: const TextStyle(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                  rangeStartDecoration: const BoxDecoration(
                    color: AppTheme.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  rangeEndDecoration: const BoxDecoration(
                    color: AppTheme.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  rangeStartTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  rangeEndTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  withinRangeDecoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                    shape: BoxShape.rectangle,
                  ),
                  withinRangeTextStyle:
                      const TextStyle(color: AppTheme.textPrimary),
                  rangeHighlightColor:
                      AppTheme.primaryBlue.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
