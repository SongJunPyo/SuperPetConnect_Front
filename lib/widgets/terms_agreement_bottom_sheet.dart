import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/donation_consent_model.dart';
import '../services/donation_survey_service.dart';
import '../utils/app_theme.dart';

/// 헌혈 신청 직전에 띄우는 안내사항 정독 동의 바텀시트.
///
/// 백엔드 `GET /api/donation-consent/items`에서 받은 `guidance_html` 마크다운을 렌더하고
/// 단일 정독 체크박스를 노출. 신청 시점에는 DB 저장 X (단순 진입 게이트).
/// 설문 시점 5개 동의는 별도 화면(`donation_survey_form_page.dart`)에서 처리.
///
/// 동의 체크 후 "확인"을 누르면 시트를 먼저 닫고, 다음 프레임에 [onConfirm]을
/// 호출. 이렇게 두 단계로 분리하는 이유는 [onConfirm]에서 또 다른 다이얼로그를
/// 띄울 때 현재 시트의 build 컨텍스트와 충돌하지 않게 하기 위함.
class TermsAgreementBottomSheet extends StatefulWidget {
  final VoidCallback onConfirm;

  const TermsAgreementBottomSheet({super.key, required this.onConfirm});

  @override
  State<TermsAgreementBottomSheet> createState() =>
      _TermsAgreementBottomSheetState();
}

class _TermsAgreementBottomSheetState extends State<TermsAgreementBottomSheet> {
  bool isAgreed = false;
  DonationConsentItems? _consentItems;
  String? _loadError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConsent();
  }

  Future<void> _loadConsent() async {
    try {
      final items = await DonationSurveyService.getConsentItems();
      if (!mounted) return;
      setState(() {
        _consentItems = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // 핸들 바
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.red, size: 24),
                const SizedBox(width: 8),
                Text(
                  '헌혈 사전 안내사항',
                  style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // 안내문 본문 (백엔드 guidance_html 마크다운)
          Expanded(child: _buildBody()),

          // 동의 체크박스 및 버튼
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: isAgreed,
                      onChanged: _consentItems == null
                          ? null
                          : (value) {
                              setState(() {
                                isAgreed = value ?? false;
                              });
                            },
                      activeColor: AppTheme.success,
                    ),
                    Expanded(
                      child: Text(
                        '위 안내문을 정독했습니다',
                        style: AppTheme.bodyMediumStyle.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                        child: Text(
                          '취소',
                          style: AppTheme.bodyLargeStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isAgreed
                            ? () {
                                Navigator.pop(context);
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  widget.onConfirm();
                                });
                              }
                            : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.success,
                          side: BorderSide(
                            color: isAgreed
                                ? AppTheme.success
                                : Colors.grey.shade300,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          '확인',
                          style: AppTheme.bodyLargeStyle.copyWith(
                            color: isAgreed
                                ? AppTheme.success
                                : Colors.grey.shade400,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              '안내문을 불러오지 못했습니다',
              style: AppTheme.bodyLargeStyle
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              _loadError!,
              style: AppTheme.bodySmallStyle
                  .copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _loadError = null;
                });
                _loadConsent();
              },
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }
    return Markdown(
      data: _consentItems!.guidanceHtml,
      padding: const EdgeInsets.all(20),
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: AppTheme.bodyMediumStyle.copyWith(height: 1.6),
        h1: AppTheme.h2Style.copyWith(fontWeight: FontWeight.bold),
        h2: AppTheme.h3Style.copyWith(fontWeight: FontWeight.bold),
        h3: AppTheme.h4Style.copyWith(fontWeight: FontWeight.bold),
        listBullet: AppTheme.bodyMediumStyle.copyWith(height: 1.6),
      ),
    );
  }
}
