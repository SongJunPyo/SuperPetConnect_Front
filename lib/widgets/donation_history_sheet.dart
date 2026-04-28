import 'package:flutter/material.dart';

import '../models/donation_history_model.dart';
import '../services/donation_history_service.dart';
import '../utils/app_theme.dart';

/// 반려동물 헌혈 이력 통계 카드 + 탭 시 상세 시트 오픈.
///
/// `petIdx`가 null이면 안내 박스만 표시. 그 외에는 [DonationHistoryService]로
/// 비동기 fetch 후 총 횟수/총량 카드를 보여주고, 이력이 있으면 카드 탭 시
/// 상세 시트가 열림.
class DonationHistorySection extends StatelessWidget {
  final int? petIdx;

  const DonationHistorySection({super.key, required this.petIdx});

  @override
  Widget build(BuildContext context) {
    if (petIdx == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '헌혈 이력',
            style: AppTheme.bodyLargeStyle.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey.shade600),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '헌혈 이력 조회 기능 준비 중입니다.',
                    style: AppTheme.bodyMediumStyle.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '헌혈 이력',
          style: AppTheme.bodyLargeStyle.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        FutureBuilder<DonationHistoryResponse?>(
          future: DonationHistoryService.getHistory(petIdx: petIdx!, limit: 50),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snapshot.hasError) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '이력을 불러오지 못했습니다.',
                        style: AppTheme.bodyMediumStyle.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            final historyResponse = snapshot.data;
            if (historyResponse == null) {
              return const SizedBox.shrink();
            }

            return GestureDetector(
              onTap: historyResponse.histories.isNotEmpty
                  ? () => showDonationHistoryDetailSheet(context, historyResponse)
                  : null,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _HistoryStatItem(
                            label: '총 헌혈 횟수',
                            value: '${historyResponse.totalCount}회',
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: Colors.grey.shade300,
                          ),
                          _HistoryStatItem(
                            label: '총 헌혈량',
                            value: historyResponse.totalBloodVolumeText,
                          ),
                        ],
                      ),
                    ),
                    if (historyResponse.histories.isNotEmpty)
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppTheme.textTertiary,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// 헌혈 이력 상세 시트. 통계 + 이력 목록.
void showDonationHistoryDetailSheet(
  BuildContext context,
  DonationHistoryResponse historyResponse,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '헌혈 이력',
                style: AppTheme.h4Style.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _HistoryStatItem(
                  label: '총 헌혈 횟수',
                  value: '${historyResponse.totalCount}회',
                ),
                Container(width: 1, height: 30, color: Colors.grey.shade300),
                _HistoryStatItem(
                  label: '총 헌혈량',
                  value: historyResponse.totalBloodVolumeText,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: historyResponse.histories.length,
              itemBuilder: (context, index) =>
                  _HistoryItemCard(history: historyResponse.histories[index]),
            ),
          ),
        ],
      ),
    ),
  );
}

class _HistoryStatItem extends StatelessWidget {
  final String label;
  final String value;

  const _HistoryStatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTheme.h4Style.copyWith(
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTheme.bodySmallStyle.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _HistoryItemCard extends StatelessWidget {
  final DonationHistory history;

  const _HistoryItemCard({required this.history});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                history.dateText,
                style: AppTheme.bodyMediumStyle.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: history.isSystemRecord
                      ? AppTheme.lightBlue
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  history.isSystemRecord ? '자동' : '수동',
                  style: AppTheme.bodySmallStyle.copyWith(
                    color: history.isSystemRecord
                        ? AppTheme.primaryBlue
                        : Colors.green.shade600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.local_hospital,
                size: 14,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                history.displayHospitalName ?? '정보 없음',
                style: AppTheme.bodySmallStyle.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(' • ', style: TextStyle(color: AppTheme.textSecondary)),
              Icon(Icons.water_drop, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(
                history.bloodVolumeMl != null
                    ? '${history.bloodVolumeMl}ml'
                    : '정보 없음',
                style: AppTheme.bodySmallStyle.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          if (history.notes != null && history.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              history.notes!,
              style: AppTheme.bodySmallStyle.copyWith(
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
