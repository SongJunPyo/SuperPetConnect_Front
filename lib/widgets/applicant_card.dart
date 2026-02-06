// lib/widgets/applicant_card.dart
// 신청자 카드 공통 위젯

import 'package:flutter/material.dart';
import '../models/applicant_model.dart';
import '../models/donation_history_model.dart';
import '../services/donation_history_service.dart';
import '../utils/app_theme.dart';

/// 신청자 카드 위젯
class ApplicantCard extends StatelessWidget {
  final ApplicantInfo applicant;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final bool showActionButtons;

  const ApplicantCard({
    super.key,
    required this.applicant,
    this.onApprove,
    this.onReject,
    this.showActionButtons = true,
  });

  /// 상태별 색상
  Color _getStatusColor(int status) {
    switch (status) {
      case 0:
        return Colors.orange;
      case 1:
        return Colors.green;
      case 2:
        return Colors.red;
      case 3:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(applicant.status);

    return GestureDetector(
      onTap: () => _showApplicantDetail(context),
      behavior: HitTestBehavior.opaque,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
        elevation: 1,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 이름 및 상태 태그
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      applicant.name,
                      style: AppTheme.bodyLargeStyle.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(38),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      applicant.statusText,
                      style: AppTheme.bodySmallStyle.copyWith(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 상세 정보
              _buildDetailRow(Icons.phone_outlined, '연락처', applicant.contact),
              _buildDetailRow(Icons.pets_outlined, '반려동물', applicant.dogInfo),
              _buildDetailRow(
                Icons.calendar_today_outlined,
                '직전 헌혈일',
                applicant.formattedLastDonationDate,
              ),

              // 승인/거절 버튼 (대기 상태일 때만)
              if (showActionButtons && applicant.isPending) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: OutlinedButton(
                          onPressed: onReject,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('거절', style: TextStyle(color: Colors.red)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: onApprove,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('승인'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: AppTheme.bodyMediumStyle.copyWith(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyMediumStyle.copyWith(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 신청자 상세 정보 바텀시트
  void _showApplicantDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ApplicantDetailSheet(applicant: applicant),
    );
  }
}

/// 신청자 상세 정보 바텀시트
class _ApplicantDetailSheet extends StatefulWidget {
  final ApplicantInfo applicant;

  const _ApplicantDetailSheet({required this.applicant});

  @override
  State<_ApplicantDetailSheet> createState() => _ApplicantDetailSheetState();
}

class _ApplicantDetailSheetState extends State<_ApplicantDetailSheet> {
  bool _isLoadingHistory = false;
  String? _historyError;
  DonationHistoryResponse? _historyResponse;

  @override
  void initState() {
    super.initState();
    _loadDonationHistory();
  }

  Future<void> _loadDonationHistory() async {
    if (widget.applicant.petIdx == null) {
      setState(() {
        _historyError = '헌혈 이력 조회를 위한 정보가 없습니다.';
      });
      return;
    }

    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });

    try {
      final response = await DonationHistoryService.getHistory(
        petIdx: widget.applicant.petIdx!,
        limit: 50,
      );
      if (mounted) {
        setState(() {
          _historyResponse = response;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _historyError = e.toString();
          _isLoadingHistory = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // 핸들 바
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // 헤더
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.applicant.name,
                          style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.applicant.dogInfo,
                          style: AppTheme.bodyMediumStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            const Divider(height: 24),

            // 내용
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // 기본 정보
                  _buildInfoSection(),

                  const SizedBox(height: 24),

                  // 헌혈 이력 섹션
                  _buildDonationHistorySection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '신청자 정보',
          style: AppTheme.bodyLargeStyle.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        _buildInfoRow('연락처', widget.applicant.contact),
        _buildInfoRow('반려동물', widget.applicant.dogInfo),
        _buildInfoRow('직전 헌혈일', widget.applicant.formattedLastDonationDate),
        _buildInfoRow('상태', widget.applicant.statusText),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTheme.bodyMediumStyle.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyMediumStyle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '헌혈 이력',
          style: AppTheme.bodyLargeStyle.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),

        // 로딩 상태
        if (_isLoadingHistory)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        // 에러 상태 (pet_idx 없음 포함)
        else if (_historyError != null)
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
                    widget.applicant.petIdx == null
                        ? '헌혈 이력 조회 기능 준비 중입니다.'
                        : '이력을 불러오지 못했습니다.',
                    style: AppTheme.bodyMediumStyle.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          )
        // 데이터 있음
        else if (_historyResponse != null) ...[
          // 통계 요약
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('총 헌혈 횟수', '${_historyResponse!.totalCount}회'),
                Container(width: 1, height: 30, color: Colors.grey.shade300),
                _buildStatItem('총 헌혈량', _historyResponse!.totalBloodVolumeText),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 이력 목록
          if (_historyResponse!.histories.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  '헌혈 이력이 없습니다.',
                  style: AppTheme.bodyMediumStyle.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            )
          else
            ...(_historyResponse!.histories.map((history) => _buildHistoryItem(history))),
        ],
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
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

  Widget _buildHistoryItem(DonationHistory history) {
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: history.isSystemRecord ? Colors.blue.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  history.isSystemRecord ? '자동' : '수동',
                  style: AppTheme.bodySmallStyle.copyWith(
                    color: history.isSystemRecord ? Colors.blue.shade600 : Colors.green.shade600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.local_hospital, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(
                history.hospitalName ?? '정보 없음',
                style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.textSecondary),
              ),
              Text(' • ', style: TextStyle(color: AppTheme.textSecondary)),
              Icon(Icons.water_drop, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(
                history.bloodVolumeMl != null ? '${history.bloodVolumeMl}ml' : '정보 없음',
                style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
          if (history.notes != null && history.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              history.notes!,
              style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}
