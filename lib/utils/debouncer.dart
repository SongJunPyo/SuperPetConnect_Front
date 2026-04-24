// 디바운스 유틸리티
//
// 검색 입력, 페이지네이션 쿼리, 설정 저장 등 "키 입력마다 작업을 실행하지 않고
// 마지막 이벤트 후 일정 시간이 지나면 한 번만 실행"하는 패턴을 통합.
//
// 기존 프로젝트에서 반복되던 패턴:
//   Timer? _debounce;
//   void onChanged(String v) {
//     _debounce?.cancel();
//     _debounce = Timer(const Duration(milliseconds: 400), () { ... });
//   }
//   @override void dispose() { _debounce?.cancel(); super.dispose(); }

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 일정 지연 후 단 한 번의 액션을 실행하는 디바운서.
///
/// 사용 예 (검색 입력):
/// ```dart
/// final _searchDebouncer = Debouncer(delay: Duration(milliseconds: 400));
///
/// void _onSearchChanged(String value) {
///   _searchDebouncer(() {
///     setState(() => _query = value);
///     _fetchResults();
///   });
/// }
///
/// @override
/// void dispose() {
///   _searchDebouncer.dispose();
///   super.dispose();
/// }
/// ```
class Debouncer {
  /// 기본 400ms — 프로젝트 내 검색 UX에 맞게 튜닝된 값.
  /// 더 짧게 (200ms) 쓰려면 생성자에서 지정.
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 400)});

  /// 예약된 이전 호출을 취소하고 새 호출을 예약.
  /// `delay` 이내 다시 호출하면 타이머가 리셋됨.
  void call(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// 예약된 호출이 있으면 실행하지 않고 취소.
  /// (검색 clear 버튼 등 즉시 반영이 필요한 상호작용에서 사용)
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// 예약된 호출이 대기 중인지 여부.
  bool get isActive => _timer?.isActive ?? false;

  /// State.dispose()에서 반드시 호출하여 leak 방지.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
