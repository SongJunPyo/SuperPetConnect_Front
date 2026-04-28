import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// 리스트 화면 공용 상태 위젯 (로딩/에러/빈 화면).
///
/// 12개 이상의 리스트 화면에서 동일한 구조로 반복되던
/// `CircularProgressIndicator` / 에러 + 다시 시도 / 빈 아이콘 + 메시지
/// 패턴을 단일 위젯으로 통합.
///
/// 사용 예:
/// ```dart
/// if (isLoading) return const StateView.loading();
/// if (errorMessage != null) {
///   return StateView.error(message: errorMessage!, onRetry: _load);
/// }
/// if (items.isEmpty) {
///   return const StateView.empty(
///     icon: Icons.announcement_outlined,
///     message: '공지사항이 없습니다',
///   );
/// }
/// ```
class StateView extends StatelessWidget {
  final _StateViewKind _kind;
  final IconData? _icon;
  final String? _message;
  final String? _subtitle;
  final VoidCallback? _onRetry;
  final String _retryLabel;

  const StateView.loading({super.key})
      : _kind = _StateViewKind.loading,
        _icon = null,
        _message = null,
        _subtitle = null,
        _onRetry = null,
        _retryLabel = '';

  const StateView.error({
    super.key,
    required String message,
    required VoidCallback onRetry,
    String retryLabel = '다시 시도',
  })  : _kind = _StateViewKind.error,
        _icon = null,
        _message = message,
        _subtitle = null,
        _onRetry = onRetry,
        _retryLabel = retryLabel;

  const StateView.empty({
    super.key,
    required IconData icon,
    required String message,
    String? subtitle,
  })  : _kind = _StateViewKind.empty,
        _icon = icon,
        _message = message,
        _subtitle = subtitle,
        _onRetry = null,
        _retryLabel = '';

  /// `StateView`를 부모 `RefreshIndicator`에서 pull-to-refresh가 동작하도록
  /// 스크롤 가능한 ListView로 감싼다. 화면 60% 높이를 확보해 가운데 정렬.
  ///
  /// 비어있는 화면에서도 아래로 당겨 새로고침이 가능해야 하는 경우에 사용.
  static Widget scrollable(BuildContext context, Widget child) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: child,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_kind) {
      case _StateViewKind.loading:
        return const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryBlue),
        );
      case _StateViewKind.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
              const SizedBox(height: 16),
              Text('오류가 발생했습니다', style: AppTheme.h4Style),
              const SizedBox(height: 8),
              Text(
                _message!,
                style: AppTheme.bodyMediumStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(_retryLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      case _StateViewKind.empty:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_icon, size: 64, color: AppTheme.mediumGray),
              const SizedBox(height: 16),
              Text(_message!, style: AppTheme.h4Style),
              if (_subtitle != null) ...[
                const SizedBox(height: 8),
                Text(_subtitle, style: AppTheme.bodyMediumStyle),
              ],
            ],
          ),
        );
    }
  }
}

enum _StateViewKind { loading, error, empty }
