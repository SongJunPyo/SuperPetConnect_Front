import 'package:flutter/material.dart';
import '../models/region_model.dart';
import '../utils/app_theme.dart';

class RegionSelectionSheet extends StatefulWidget {
  final Function(Region, Region, Region?) onRegionSelected;

  const RegionSelectionSheet({
    super.key,
    required this.onRegionSelected,
  });

  @override
  State<RegionSelectionSheet> createState() => _RegionSelectionSheetState();
}

class _RegionSelectionSheetState extends State<RegionSelectionSheet> {
  Region? selectedLargeRegion; // 큰 단위 (시/도)
  Region? selectedMediumRegion; // 중간 단위 (시/군/구)
  Region? selectedSmallRegion; // 작은 단위 (동/면/읍)

  List<Region> get largeRegions => RegionData.regions;
  List<Region> get mediumRegions => selectedLargeRegion?.children ?? [];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
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
                    Text(
                      '지역 선택',
                      style: AppTheme.h3Style,
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 컨텐츠
              Expanded(
                child: Row(
                  children: [
                    // 큰 단위 (시/도)
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
                              controller: scrollController,
                              itemCount: largeRegions.length,
                              itemBuilder: (context, index) {
                                final region = largeRegions[index];
                                final isSelected = selectedLargeRegion == region;
                                
                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      selectedLargeRegion = region;
                                      selectedMediumRegion = null;
                                      selectedSmallRegion = null;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    color: isSelected
                                        ? AppTheme.primaryBlue.withOpacity(0.1)
                                        : Colors.transparent,
                                    child: Row(
                                      children: [
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
                                        if (region.children != null && region.children!.isNotEmpty)
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            size: 12,
                                            color: isSelected
                                                ? AppTheme.primaryBlue
                                                : AppTheme.textTertiary,
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
                    const VerticalDivider(width: 1),
                    // 중간 단위 (시/군/구)
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              '시/군/구',
                              style: AppTheme.bodyLargeStyle.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: mediumRegions.isEmpty
                                ? const Center(
                                    child: Text(
                                      '시/도를 먼저\n선택해주세요',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppTheme.textTertiary,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: mediumRegions.length,
                                    itemBuilder: (context, index) {
                                      final region = mediumRegions[index];
                                      final isSelected = selectedMediumRegion == region;
                                      
                                      return InkWell(
                                        onTap: () {
                                          setState(() {
                                            selectedMediumRegion = region;
                                            selectedSmallRegion = null;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          color: isSelected
                                              ? AppTheme.primaryBlue.withOpacity(0.1)
                                              : Colors.transparent,
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
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    // 작은 단위 (동/면/읍) - 현재는 구현하지 않음
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              '동/면/읍',
                              style: AppTheme.bodyLargeStyle.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Center(
                              child: Text(
                                '시/군/구까지만\n선택 가능합니다',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // 선택된 지역 표시
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.veryLightGray,
                  border: const Border(
                    top: BorderSide(color: AppTheme.lightGray),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '선택된 지역',
                      style: AppTheme.bodyLargeStyle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getSelectedRegionText(),
                      style: AppTheme.bodyMediumStyle.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: selectedLargeRegion != null && selectedMediumRegion != null
                            ? () {
                                widget.onRegionSelected(
                                  selectedLargeRegion!,
                                  selectedMediumRegion!,
                                  selectedSmallRegion,
                                );
                                Navigator.pop(context);
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radius12),
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
    if (selectedLargeRegion == null) {
      return '지역을 선택해주세요';
    }
    
    if (selectedMediumRegion == null) {
      return selectedLargeRegion!.name;
    }
    
    return '${selectedLargeRegion!.name} ${selectedMediumRegion!.name}';
  }
}