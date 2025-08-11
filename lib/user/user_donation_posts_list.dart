import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../services/dashboard_service.dart';
import '../widgets/marquee_text.dart';
import '../utils/number_format_util.dart';
import 'package:intl/intl.dart';

class UserDonationPostsListScreen extends StatefulWidget {
  const UserDonationPostsListScreen({super.key});

  @override
  State<UserDonationPostsListScreen> createState() => _UserDonationPostsListScreenState();
}

class _UserDonationPostsListScreenState extends State<UserDonationPostsListScreen>
    with SingleTickerProviderStateMixin {
  List<DonationPost> allPosts = [];
  List<DonationPost> filteredPosts = [];
  bool isLoading = true;
  String errorMessage = '';
  String searchQuery = '';
  TextEditingController searchController = TextEditingController();
  
  // 탭 컨트롤러
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadDonationPosts();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging || _tabController.index != _currentTabIndex) {
      setState(() {
        _currentTabIndex = _tabController.index;
        _filterPosts();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDonationPosts() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      // 모든 헌혈 모집글을 가져옵니다 (limit을 크게 설정)
      final posts = await DashboardService.getPublicPosts(limit: 100);
      
      setState(() {
        allPosts = posts;
        _filterPosts();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = '헌혈 모집글을 불러오는데 실패했습니다: $e';
        isLoading = false;
      });
    }
  }

  void _filterPosts() {
    List<DonationPost> filtered = allPosts;

    // 탭에 따른 필터링
    if (_currentTabIndex == 0) {
      // 긴급 탭: 긴급 게시글만 표시 (types == 0)
      filtered = filtered.where((post) => post.types == 0).toList();
    } else {
      // 정기 탭: 정기 게시글만 표시 (types == 1)
      filtered = filtered.where((post) => post.types == 1).toList();
    }

    // 검색어 필터링
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((post) {
        return post.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
            post.hospitalName.toLowerCase().contains(searchQuery.toLowerCase()) ||
            post.location.toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();
    }

    // 긴급 게시글을 상단에, 그 다음 최신 순으로 정렬
    filtered.sort((a, b) {
      // 긴급도 우선 정렬
      if (a.isUrgent && !b.isUrgent) return -1;
      if (!a.isUrgent && b.isUrgent) return 1;
      // 같은 긴급도면 최신 순
      return b.createdAt.compareTo(a.createdAt);
    });

    setState(() {
      filteredPosts = filtered;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      searchQuery = query;
    });
    _filterPosts();
  }

  Future<void> _showPostDetail(DonationPost post) async {
    // 상세 정보 조회
    final detailPost = await DashboardService.getDonationPostDetail(post.postIdx);
    
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        final displayPost = detailPost ?? post;
        
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
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
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Row(
                      children: [
                        // 긴급/정기 뱃지
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: displayPost.isUrgent 
                                ? Colors.red.withOpacity(0.15)
                                : Colors.blue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            displayPost.typeText,
                            style: AppTheme.bodySmallStyle.copyWith(
                              color: displayPost.isUrgent ? Colors.red : Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            displayPost.title,
                            style: AppTheme.h3Style.copyWith(
                              color: displayPost.isUrgent ? Colors.red : AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  
                  const Divider(height: 1),
                  
                  // 메타 정보
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.business, size: 16, color: AppTheme.textSecondary),
                            const SizedBox(width: 8),
                            Text(
                              displayPost.hospitalName,
                              style: AppTheme.bodyMediumStyle.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              DateFormat('yyyy년 MM월 dd일').format(displayPost.createdAt),
                              style: AppTheme.bodySmallStyle.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: AppTheme.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                displayPost.location,
                                style: AppTheme.bodyMediumStyle,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // 헌혈 정보
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 혈액형 정보
                          if (displayPost.emergencyBloodType != null && displayPost.emergencyBloodType!.isNotEmpty) ...[
                            Text('필요 혈액형', style: AppTheme.h4Style),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: displayPost.isUrgent ? Colors.red.shade50 : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: displayPost.isUrgent ? Colors.red.shade200 : Colors.blue.shade200,
                                ),
                              ),
                              child: Text(
                                displayPost.displayBloodType,
                                style: AppTheme.h3Style.copyWith(
                                  color: displayPost.isUrgent ? Colors.red : Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          
                          // 헌혈 날짜 정보
                          Text('헌혈 예정일', style: AppTheme.h4Style),
                          const SizedBox(height: 12),
                          if (displayPost.donationDates != null && displayPost.donationDates!.isNotEmpty) ...[
                            ...displayPost.donationDates!.map((dateInfo) => Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Text(
                                dateInfo.formattedDate,
                                style: AppTheme.bodyLargeStyle.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )).toList(),
                          ] else if (displayPost.donationDate != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Text(
                                DateFormat('yyyy년 MM월 dd일 EEEE', 'ko').format(displayPost.donationDate!),
                                style: AppTheme.bodyLargeStyle.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ] else ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Text(
                                '헌혈 날짜가 아직 확정되지 않았습니다',
                                style: AppTheme.bodyMediumStyle.copyWith(
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 24),
                          
                          // 신청 안내
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: AppTheme.primaryBlue,
                                  size: 32,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '헌혈 신청은 병원에 직접 연락하여\n진행해주세요',
                                  style: AppTheme.bodyMediumStyle.copyWith(
                                    color: AppTheme.primaryBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
        title: Text(
          "헌혈 모집 게시글",
          style: AppTheme.h2Style.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined, color: Colors.black87),
            tooltip: '새로고침',
            onPressed: _loadDonationPosts,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 검색창
          Container(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: '게시글 제목, 병원명, 위치로 검색...',
                prefixIcon: const Icon(Icons.search, color: Colors.black),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                suffixIcon: searchQuery.isNotEmpty
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
          ),

          // 탭 바
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Text('긴급'),
                  ),
                ),
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Text('정기'),
                  ),
                ),
              ],
              indicatorColor: Colors.black,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              indicatorWeight: 3.0,
              indicatorPadding: const EdgeInsets.symmetric(horizontal: 8.0),
            ),
          ),

          // 콘텐츠
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('헌혈 모집글을 불러오고 있습니다...'),
          ],
        ),
      );
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                '오류가 발생했습니다',
                style: AppTheme.h3Style.copyWith(color: Colors.red[500]),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage,
                style: AppTheme.bodyMediumStyle.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadDonationPosts,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    if (filteredPosts.isEmpty) {
      String emptyMessage = _currentTabIndex == 0 
          ? '긴급 헌혈 모집글이 없습니다.' 
          : '정기 헌혈 모집글이 없습니다.';

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pets_outlined, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                style: AppTheme.h4Style.copyWith(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: filteredPosts.length + 1, // 헤더 포함
      itemBuilder: (context, index) {
        // 첫 번째 아이템은 헤더
        if (index == 0) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade400, width: 2),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    '구분',
                    style: AppTheme.bodyMediumStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '제목',
                    style: AppTheme.bodyMediumStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    '병원',
                    style: AppTheme.bodyMediumStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    '등록일',
                    style: AppTheme.bodyMediumStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        }

        // 나머지는 게시글 아이템
        final post = filteredPosts[index - 1];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: _buildPostListItem(post),
        );
      },
    );
  }

  Widget _buildPostListItem(DonationPost post) {
    return InkWell(
      onTap: () => _showPostDetail(post),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14.0),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 구분 (긴급/정기 뱃지)
            Container(
              width: 50,
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                decoration: BoxDecoration(
                  color: post.isUrgent
                      ? Colors.red.withOpacity(0.15)
                      : Colors.blue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Text(
                  post.typeText,
                  style: AppTheme.bodySmallStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: post.isUrgent ? Colors.red : Colors.blue,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            
            // 제목
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                alignment: Alignment.centerLeft,
                child: MarqueeText(
                  text: post.title,
                  style: AppTheme.bodyMediumStyle.copyWith(
                    fontWeight: FontWeight.w500,
                    color: post.isUrgent ? Colors.red.shade700 : AppTheme.textPrimary,
                  ),
                  animationDuration: const Duration(milliseconds: 5000),
                  pauseDuration: const Duration(milliseconds: 2000),
                ),
              ),
            ),
            
            // 병원명
            Container(
              width: 60,
              alignment: Alignment.center,
              child: Text(
                post.hospitalName.length > 4 
                    ? '${post.hospitalName.substring(0, 4)}..'
                    : post.hospitalName,
                style: AppTheme.bodySmallStyle.copyWith(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            // 등록날짜
            Container(
              width: 70,
              alignment: Alignment.center,
              child: Text(
                DateFormat('MM.dd').format(post.createdAt),
                style: AppTheme.bodySmallStyle.copyWith(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}