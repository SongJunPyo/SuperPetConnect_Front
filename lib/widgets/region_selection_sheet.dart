import 'package:flutter/material.dart';
import '../models/region_model.dart';
import '../utils/app_theme.dart';

class RegionSelectionSheet extends StatefulWidget {
  final List<Region> initialSelectedLargeRegions;
  final Map<Region, List<Region>> initialSelectedMediumRegions;
  final Function(List<Region>, Map<Region, List<Region>>) onRegionSelected;

  const RegionSelectionSheet({
    super.key,
    required this.onRegionSelected,
    this.initialSelectedLargeRegions = const [],
    this.initialSelectedMediumRegions = const {},
  });

  @override
  State<RegionSelectionSheet> createState() => _RegionSelectionSheetState();
}

class _RegionSelectionSheetState extends State<RegionSelectionSheet> {
  List<Region> selectedLargeRegions = []; // 선택된 시/도 목록
  Map<Region, List<Region>> selectedMediumRegions = {}; // 시/도별 선택된 시/군/구 목록
  Region? currentViewingRegion; // 현재 보고 있는 시/도 (오른쪽 패널용)

  List<Region> get largeRegions => RegionData.regions;
  List<Region> get mediumRegions => currentViewingRegion?.children ?? [];

  @override
  void initState() {
    super.initState();
    selectedLargeRegions = List.from(widget.initialSelectedLargeRegions);
    selectedMediumRegions = Map.from(widget.initialSelectedMediumRegions);
    // 첫 번째 선택된 지역을 현재 보고 있는 지역으로 설정
    if (selectedLargeRegions.isNotEmpty) {
      currentViewingRegion = selectedLargeRegions.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
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
                        Text('지역 선택', style: AppTheme.h3Style),
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
                        if (selectedLargeRegions.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                selectedLargeRegions.clear();
                                selectedMediumRegions.clear();
                                currentViewingRegion = null;
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
              
              // 현재 선택된 지역 표시
              if (selectedLargeRegions.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '선택된 지역:',
                        style: AppTheme.bodySmallStyle.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: selectedLargeRegions.map((region) {
                          final mediums = selectedMediumRegions[region] ?? [];
                          final displayText = mediums.isEmpty 
                              ? '${region.name} 전체'
                              : '${region.name} ${mediums.length}곳';
                          
                          return Chip(
                            label: Text(
                              displayText,
                              style: AppTheme.bodySmallStyle.copyWith(
                                fontSize: 12,
                              ),
                            ),
                            backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setState(() {
                                selectedLargeRegions.remove(region);
                                selectedMediumRegions.remove(region);
                                if (currentViewingRegion == region) {
                                  currentViewingRegion = selectedLargeRegions.isNotEmpty 
                                      ? selectedLargeRegions.first 
                                      : null;
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              
              // 컨텐츠
              Expanded(
                child: Row(
                  children: [
                    // 큰 단위 (시/도) - 왼쪽
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              '시/도',
                              style: AppTheme.bodyLargeStyle.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: largeRegions.length + 1, // "전체" 옵션을 위해 +1
                              itemBuilder: (context, index) {
                                // 첫 번째 아이템은 "전체" 옵션
                                if (index == 0) {
                                  final isSelected = selectedLargeRegions.isEmpty;
                                  
                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        selectedLargeRegions.clear();
                                        selectedMediumRegions.clear();
                                        currentViewingRegion = null;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected 
                                            ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '전체',
                                        style: AppTheme.bodyMediumStyle.copyWith(
                                          color: isSelected 
                                              ? AppTheme.primaryBlue 
                                              : AppTheme.textPrimary,
                                          fontWeight: isSelected 
                                              ? FontWeight.w600 
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                
                                // 나머지는 기존 지역 데이터
                                final region = largeRegions[index - 1];
                                final isSelected = selectedLargeRegions.contains(region);
                                final isViewing = currentViewingRegion == region;

                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (selectedLargeRegions.length >= 5 && !isSelected) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('최대 5개 지역까지만 선택할 수 있습니다.'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                        return;
                                      }
                                      
                                      if (isSelected) {
                                        // 이미 선택된 지역이면 해제
                                        selectedLargeRegions.remove(region);
                                        selectedMediumRegions.remove(region);
                                        if (currentViewingRegion == region) {
                                          currentViewingRegion = selectedLargeRegions.isNotEmpty 
                                              ? selectedLargeRegions.first 
                                              : null;
                                        }
                                      } else {
                                        // 새로운 지역 선택
                                        selectedLargeRegions.add(region);
                                        selectedMediumRegions[region] = [];
                                      }
                                      
                                      // 오른쪽 패널에 표시할 지역 설정
                                      currentViewingRegion = region;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isViewing
                                          ? AppTheme.lightGray.withValues(alpha: 0.3)
                                          : isSelected
                                              ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                                              : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: isSelected
                                          ? Border.all(color: AppTheme.primaryBlue, width: 1)
                                          : null,
                                    ),
                                    child: Row(
                                      children: [
                                        if (isSelected)
                                          Container(
                                            margin: const EdgeInsets.only(right: 8),
                                            child: Icon(
                                              Icons.check_circle,
                                              size: 16,
                                              color: AppTheme.primaryBlue,
                                            ),
                                          ),
                                        Expanded(
                                          child: Text(
                                            region.name,
                                            style: AppTheme.bodyMediumStyle.copyWith(
                                              color: isSelected 
                                                  ? AppTheme.primaryBlue 
                                                  : AppTheme.textPrimary,
                                              fontWeight: isSelected 
                                                  ? FontWeight.w600 
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right,
                                          size: 16,
                                          color: AppTheme.textTertiary,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    Container(width: 1, color: AppTheme.lightGray),
                    
                    // 중간 단위 (시/군/구) - 오른쪽
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              currentViewingRegion?.name ?? '시/군/구',
                              style: AppTheme.bodyLargeStyle.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (currentViewingRegion == null)
                            Expanded(
                              child: Center(
                                child: Text(
                                  '시/도를 먼저 선택해주세요',
                                  style: AppTheme.bodyMediumStyle.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            )
                          else
                            Expanded(
                              child: ListView.builder(
                                itemCount: mediumRegions.length + 1, // "전체" 옵션을 위해 +1
                                itemBuilder: (context, index) {
                                  // 첫 번째 아이템은 "전체" 옵션
                                  if (index == 0) {
                                    final selectedMediums = selectedMediumRegions[currentViewingRegion!] ?? [];
                                    final isAllSelected = selectedMediums.isEmpty && selectedLargeRegions.contains(currentViewingRegion!);
                                    
                                    return InkWell(
                                      onTap: () {
                                        setState(() {
                                          if (selectedLargeRegions.contains(currentViewingRegion!)) {
                                            selectedMediumRegions[currentViewingRegion!] = [];
                                          }
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isAllSelected
                                              ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            if (isAllSelected)
                                              Container(
                                                margin: const EdgeInsets.only(right: 8),
                                                child: Icon(
                                                  Icons.check_circle,
                                                  size: 16,
                                                  color: AppTheme.primaryBlue,
                                                ),
                                              ),
                                            Text(
                                              '전체',
                                              style: AppTheme.bodyMediumStyle.copyWith(
                                                color: isAllSelected 
                                                    ? AppTheme.primaryBlue 
                                                    : AppTheme.textPrimary,
                                                fontWeight: isAllSelected 
                                                    ? FontWeight.w600 
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                  
                                  final mediumRegion = mediumRegions[index - 1];
                                  final selectedMediums = selectedMediumRegions[currentViewingRegion!] ?? [];
                                  final isSelected = selectedMediums.contains(mediumRegion);
                                  
                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        if (selectedLargeRegions.contains(currentViewingRegion!)) {
                                          final currentMediums = selectedMediumRegions[currentViewingRegion!] ?? [];
                                          if (isSelected) {
                                            currentMediums.remove(mediumRegion);
                                          } else {
                                            currentMediums.add(mediumRegion);
                                          }
                                          selectedMediumRegions[currentViewingRegion!] = currentMediums;
                                        }
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          if (isSelected)
                                            Container(
                                              margin: const EdgeInsets.only(right: 8),
                                              child: Icon(
                                                Icons.check_circle,
                                                size: 16,
                                                color: AppTheme.primaryBlue,
                                              ),
                                            ),
                                          Expanded(
                                            child: Text(
                                              mediumRegion.name,
                                              style: AppTheme.bodyMediumStyle.copyWith(
                                                color: isSelected 
                                                    ? AppTheme.primaryBlue 
                                                    : AppTheme.textPrimary,
                                                fontWeight: isSelected 
                                                    ? FontWeight.w600 
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // 하단 버튼
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      _getSelectedRegionText(),
                      style: AppTheme.bodyMediumStyle.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          widget.onRegionSelected(selectedLargeRegions, selectedMediumRegions);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius12,
                            ),
                          ),
                        ),
                        child: Text(
                          '지역 선택 완료',
                          style: AppTheme.bodyLargeStyle.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getSelectedRegionText() {
    if (selectedLargeRegions.isEmpty) {
      return '전체 지역';
    }
    
    if (selectedLargeRegions.length == 1) {
      final region = selectedLargeRegions.first;
      final mediums = selectedMediumRegions[region] ?? [];
      
      if (mediums.isEmpty) {
        return '${region.name} 전체';
      } else if (mediums.length == 1) {
        return '${region.name} ${mediums.first.name}';
      } else {
        return '${region.name} ${mediums.first.name} 외 ${mediums.length - 1}곳';
      }
    } else {
      return selectedLargeRegions.map((r) => r.name).join(', ');
    }
  }
}