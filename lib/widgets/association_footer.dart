import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'terms_of_service_page.dart';

/// 한국헌혈견협회 담당자 정보를 표시하는 footer 위젯
class AssociationFooter extends StatelessWidget {
  const AssociationFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.backgroundColor,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radius4),
                child: Image.asset(
                  'lib/images/한국헌혈견협회 로고.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Flexible(
                child: Text(
                  '헌혈견협회 담당자 카카오톡 @kboosung',
                  style: TextStyle(
                    fontSize: AppTheme.bodyMedium,
                    color: AppTheme.textPrimary,
                    height: 1.4,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            '한국헌혈견협회 | 대표자 : 강부성',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '사업자등록번호 : 134-82-82524',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TermsOfServicePage(),
                ),
              );
            },
            child: Text(
              '이용약관',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                decoration: TextDecoration.underline,
                decorationColor: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
