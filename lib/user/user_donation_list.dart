import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../services/dashboard_service.dart';
import 'package:intl/intl.dart';
import '../widgets/marquee_text.dart';
import '../utils/number_format_util.dart';

class UserDonationListScreen extends StatefulWidget {
  const UserDonationListScreen({super.key});

  @override
  State<UserDonationListScreen> createState() => _UserDonationListScreenState();
}

class _UserDonationListScreenState extends State<UserDonationListScreen> {
  List<DonationPost> donations = [];
  bool isLoading = true;
  String? errorMessage;

  // 필터링 옵션
  String selectedAnimalType = '전체'; // 전체, DOG, CAT
  String selectedBloodType = '전체'; // 전체, A, B, AB, O
  bool showUrgentOnly = false;
  String searchQuery = '';
  TextEditingController searchController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;

  final List<String> animalTypes = ['전체', 'DOG', 'CAT'];
  final List<String> bloodTypes = ['전체', 'A', 'B', 'AB', 'O'];

  @override
  void initState() {
    super.initState();
    _loadDonations();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDonations() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // API에서 데이터 로드 (개별 API 사용)
      final allDonations = await DashboardService.getPublicPosts(limit: 100);

      // 필터링 적용
      List<DonationPost> filteredDonations =
          allDonations.where((donation) {
            // 검색어 필터
            if (searchQuery.isNotEmpty) {
              final titleMatch = donation.title.toLowerCase().contains(
                searchQuery.toLowerCase(),
              );
              final hospitalMatch = donation.hospitalName
                  .toLowerCase()
                  .contains(searchQuery.toLowerCase());
              if (!titleMatch && !hospitalMatch) {
                return false;
              }
            }

            // 동물 타입 필터
            if (selectedAnimalType != '전체' &&
                donation.animalType != selectedAnimalType) {
              return false;
            }

            // 혈액형 필터
            if (selectedBloodType != '전체' &&
                donation.bloodType != selectedBloodType) {
              return false;
            }

            // 긴급 필터
            if (showUrgentOnly && !donation.isUrgent) {
              return false;
            }

            // 날짜 범위 필터
            if (startDate != null && endDate != null) {
              final createdAt = donation.createdAt;
              if (createdAt.isBefore(startDate!) ||
                  createdAt.isAfter(endDate!.add(const Duration(days: 1)))) {
                return false;
              }
            }

            return true;
          }).toList();

      // 정렬: 긴급 우선, 그 다음 최신순
      filteredDonations.sort((a, b) {
        if (a.isUrgent && !b.isUrgent) return -1;
        if (!a.isUrgent && b.isUrgent) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      setState(() {
        donations = filteredDonations;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      searchQuery = query;
    });
    _loadDonations();
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange:
          startDate != null && endDate != null
              ? DateTimeRange(start: startDate!, end: endDate!)
              : null,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: AppTheme.primaryBlue,
            colorScheme: ColorScheme.light(primary: AppTheme.primaryBlue),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
      _loadDonations();
    }
  }

  void _clearDateRange() {
    setState(() {
      startDate = null;
      endDate = null;
    });
    _loadDonations();
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('필터 설정'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '동물 타입',
                    style: AppTheme.bodyLargeStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children:
                        animalTypes.map((type) {
                          return FilterChip(
                            label: Text(
                              type == 'DOG'
                                  ? '강아지'
                                  : type == 'CAT'
                                  ? '고양이'
                                  : type,
                            ),
                            selected: selectedAnimalType == type,
                            onSelected: (selected) {
                              setDialogState(() {
                                selectedAnimalType = type;
                              });
                            },
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '혈액형',
                    style: AppTheme.bodyLargeStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children:
                        bloodTypes.map((type) {
                          return FilterChip(
                            label: Text(type),
                            selected: selectedBloodType == type,
                            onSelected: (selected) {
                              setDialogState(() {
                                selectedBloodType = type;
                              });
                            },
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('긴급 모집만 보기'),
                    value: showUrgentOnly,
                    onChanged: (value) {
                      setDialogState(() {
                        showUrgentOnly = value ?? false;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _loadDonations();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('적용'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '헌혈 모집',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: '날짜 범위 선택',
          ),
          if (startDate != null || endDate != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearDateRange,
              tooltip: '날짜 범위 초기화',
            ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: '필터',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDonations,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Column(
        children: [
          // 검색창 및 필터 표시
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: '제목, 병원명으로 검색...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppTheme.primaryBlue,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryBlue,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    suffixIcon:
                        searchQuery.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                            : null,
                  ),
                ),
                // 날짜 범위 표시
                if (startDate != null && endDate != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.date_range,
                          size: 16,
                          color: AppTheme.primaryBlue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${DateFormat('yyyy.MM.dd').format(startDate!)} - ${DateFormat('yyyy.MM.dd').format(endDate!)}',
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: AppTheme.primaryBlue,
                            size: 18,
                          ),
                          onPressed: _clearDateRange,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadDonations,
              color: AppTheme.primaryBlue,
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryBlue),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.error),
            const SizedBox(height: 16),
            Text('오류가 발생했습니다', style: AppTheme.h4Style),
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              style: AppTheme.bodyMediumStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadDonations,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (donations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bloodtype_outlined,
              size: 64,
              color: AppTheme.mediumGray,
            ),
            const SizedBox(height: 16),
            Text('조건에 맞는 헌혈 모집이 없습니다', style: AppTheme.h4Style),
            const SizedBox(height: 8),
            Text('필터를 조정해보세요', style: AppTheme.bodyMediumStyle),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(color: Colors.white),
      child: Column(
        children: [
          // 목록
          Expanded(
            child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: donations.length,
                separatorBuilder:
                    (context, index) => Container(
                      height: 1,
                      color: AppTheme.lightGray.withOpacity(0.2),
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                itemBuilder: (context, index) {
                  final donation = donations[index];

                  return InkWell(
                    onTap: () {
                      // TODO: 헌혈 모집글 상세 페이지로 이동
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '헌혈 모집글 ${donation.postId} 상세 페이지 (준비 중)',
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 15,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 왼쪽: 순서 (카드 중앙 높이)
                          Container(
                            width: 28,
                            child: Text(
                              '${index + 1}',
                              style: AppTheme.bodySmallStyle.copyWith(
                                color: AppTheme.textTertiary,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 중앙: 메인 콘텐츠
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 첫 번째 줄: 뱃지 + 제목
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            donation.isUrgent
                                                ? AppTheme.error
                                                : AppTheme.success,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        donation.isUrgent ? '긴급' : '정기',
                                        style: AppTheme.bodySmallStyle.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: MarqueeText(
                                        text: donation.title,
                                        style: AppTheme.bodyMediumStyle
                                            .copyWith(
                                              color:
                                                  donation.isUrgent
                                                      ? AppTheme.error
                                                      : AppTheme.textPrimary,
                                              fontWeight:
                                                  donation.isUrgent
                                                      ? FontWeight.w600
                                                      : FontWeight.w500,
                                              fontSize: 14,
                                            ),
                                        animationDuration: const Duration(milliseconds: 4000),
                                        pauseDuration: const Duration(milliseconds: 1000),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // 두 번째 줄: 병원 주소
                                Row(
                                  children: [
                                    // 병원 주소 (전체 표시)
                                    Expanded(
                                      child: Text(
                                        donation.location.isNotEmpty
                                            ? donation.location
                                            : '주소 정보 없음',
                                        style: AppTheme.bodySmallStyle.copyWith(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // 오른쪽: 날짜들 + 2줄 높이의 조회수 박스
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 날짜 컴럼 (등록/헌혈 날짜 세로 배치)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '등록: ${DateFormat('yy.MM.dd').format(donation.createdAt)}',
                                    style: AppTheme.bodySmallStyle.copyWith(
                                      color: AppTheme.textTertiary,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '헌혈: ${donation.donationDate != null ? DateFormat('yy.MM.dd').format(donation.donationDate!) : '미정'}',
                                    style: AppTheme.bodySmallStyle.copyWith(
                                      color: AppTheme.textTertiary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              // 2줄 높이의 조회수 박스
                              Container(
                                height: 36, // 높이 늘림
                                width: 40, // 너비 늘림
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.mediumGray.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppTheme.lightGray.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.visibility_outlined,
                                      size: 10,
                                      color: AppTheme.textTertiary,
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      NumberFormatUtil.formatViewCount(donation.viewCount),
                                      style: AppTheme.bodySmallStyle.copyWith(
                                        color: AppTheme.textTertiary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
    );
  }
}
