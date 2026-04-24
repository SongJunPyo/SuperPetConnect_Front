import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/config.dart';
import '../utils/api_endpoints.dart';
import '../utils/app_theme.dart';

/// 이용약관 페이지
///
/// 서버에서 이용약관 내용을 조회하여 표시합니다.
/// 인증 불필요 (공개 API)
class TermsOfServicePage extends StatefulWidget {
  const TermsOfServicePage({super.key});

  @override
  State<TermsOfServicePage> createState() => _TermsOfServicePageState();
}

class _TermsOfServicePageState extends State<TermsOfServicePage> {
  String? _title;
  String? _content;
  String? _updatedAt;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTerms();
  }

  Future<void> _loadTerms() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.serverUrl}${ApiEndpoints.termsOfService}'),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _title = data['title'] ?? '이용약관';
          _content = data['content'] ?? '';
          _updatedAt = data['updatedAt'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = '이용약관을 불러올 수 없습니다.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '네트워크 오류가 발생했습니다.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _title ?? '이용약관',
          style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.mediumGray),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: AppTheme.bodyMediumStyle.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadTerms();
              },
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    return SizedBox.expand(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_updatedAt != null) ...[
                  Text(
                    '최종 수정일: ${_formatDate(_updatedAt!)}',
                    style: AppTheme.bodySmallStyle.copyWith(
                      color: AppTheme.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Text(
                  _content ?? '',
                  style: AppTheme.bodyMediumStyle.copyWith(
                    height: 1.8,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}
