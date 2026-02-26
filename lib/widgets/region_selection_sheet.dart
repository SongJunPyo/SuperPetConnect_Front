import 'package:flutter/material.dart';
import '../models/region_model.dart';
import '../utils/app_theme.dart';

class RegionSelectionSheet extends StatefulWidget {
  final List<Region> initialSelectedRegions;
  final Function(List<Region>) onRegionSelected;

  const RegionSelectionSheet({
    super.key,
    required this.onRegionSelected,
    this.initialSelectedRegions = const [],
  });

  @override
  State<RegionSelectionSheet> createState() => _RegionSelectionSheetState();
}

class _RegionSelectionSheetState extends State<RegionSelectionSheet> {
  List<Region> selectedRegions = [];

  @override
  void initState() {
    super.initState();
    selectedRegions = List.from(widget.initialSelectedRegions);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 핸들바
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.lightGray,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 헤더
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('선호 지역 선택', style: AppTheme.h3Style),
                        const SizedBox(height: 4),
                        Text(
                          '다중 선택 가능 (최대 5개)',
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (selectedRegions.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                selectedRegions.clear();
                              });
                            },
                            child: Text(
                              '전체 해제',
                              style: AppTheme.bodySmallStyle.copyWith(
                                color: AppTheme.error,
                              ),
                            ),
                          ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // 선택된 지역 칩
              if (selectedRegions.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children:
                        selectedRegions.map((region) {
                          return Chip(
                            label: Text(
                              region.name,
                              style: AppTheme.bodySmallStyle.copyWith(
                                fontSize: 12,
                              ),
                            ),
                            backgroundColor: AppTheme.primaryBlue.withValues(
                              alpha: 0.1,
                            ),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setState(() {
                                selectedRegions.remove(region);
                              });
                            },
                          );
                        }).toList(),
                  ),
                ),

              // 지역 목록
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: RegionData.regions.length + 1,
                  itemBuilder: (context, index) {
                    // "전체 지역" 옵션
                    if (index == 0) {
                      final isSelected = selectedRegions.isEmpty;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            selectedRegions.clear();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? AppTheme.primaryBlue.withValues(
                                      alpha: 0.1,
                                    )
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                size: 20,
                                color:
                                    isSelected
                                        ? AppTheme.primaryBlue
                                        : AppTheme.textTertiary,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '전체 지역',
                                style: AppTheme.bodyMediumStyle.copyWith(
                                  color:
                                      isSelected
                                          ? AppTheme.primaryBlue
                                          : AppTheme.textPrimary,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final region = RegionData.regions[index - 1];
                    final isSelected = selectedRegions.contains(region);

                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            selectedRegions.remove(region);
                          } else {
                            if (selectedRegions.length >= 5) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '최대 5개 지역까지만 선택할 수 있습니다.',
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              return;
                            }
                            selectedRegions.add(region);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              isSelected
                                  ? Border.all(
                                    color: AppTheme.primaryBlue,
                                    width: 1,
                                  )
                                  : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              size: 20,
                              color:
                                  isSelected
                                      ? AppTheme.primaryBlue
                                      : AppTheme.textTertiary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              region.name,
                              style: AppTheme.bodyMediumStyle.copyWith(
                                color:
                                    isSelected
                                        ? AppTheme.primaryBlue
                                        : AppTheme.textPrimary,
                                fontWeight:
                                    isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // 하단 버튼
              Container(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onRegionSelected(selectedRegions);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                      ),
                    ),
                    child: Text(
                      selectedRegions.isEmpty
                          ? '전체 지역으로 선택'
                          : '${selectedRegions.length}개 지역 선택 완료',
                      style: AppTheme.bodyLargeStyle.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
