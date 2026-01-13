class HospitalColumn {
  final int columnIdx;
  final String title;
  final String content;
  final bool isPublished;
  final String? columnUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int hospitalIdx;
  final String hospitalName;
  final String? authorNickname; // 작성자 닉네임
  final int viewCount;

  HospitalColumn({
    required this.columnIdx,
    required this.title,
    required this.content,
    required this.isPublished,
    required this.createdAt,
    required this.updatedAt,
    required this.hospitalIdx,
    required this.hospitalName,
    this.authorNickname,
    this.columnUrl,
    this.viewCount = 0,
  });

  factory HospitalColumn.fromJson(Map<String, dynamic> json) {
    return HospitalColumn(
      columnIdx: json['column_idx'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      isPublished: json['columns_active'] ?? false,
      createdAt: DateTime.parse(
        json['created_at'] ?? json['created_time'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? json['updated_time'] ?? DateTime.now().toIso8601String(),
      ),
      hospitalIdx: json['hospital_idx'] ?? 0,
      hospitalName: json['hospital_name'] ?? '',
      authorNickname: (json['hospital_nickname'] != null && json['hospital_nickname'].toString() != 'null' && json['hospital_nickname'].toString().isNotEmpty) 
          ? json['hospital_nickname'] 
          : '닉네임 없음',
      columnUrl: (json['column_url'] != null && json['column_url'].toString().isNotEmpty)
          ? json['column_url']
          : null,
      viewCount: json['view_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'column_idx': columnIdx,
      'title': title,
      'content': content,
      'is_published': isPublished,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'hospital_idx': hospitalIdx,
      'hospital_name': hospitalName,
      'author_nickname': authorNickname ?? '',
      'column_url': columnUrl,
      'view_count': viewCount,
    };
  }
}

class HospitalColumnCreateRequest {
  final String title;
  final String content;
  final bool isPublished;
  final String? columnUrl;

  HospitalColumnCreateRequest({
    required this.title,
    required this.content,
    this.isPublished = true,
    this.columnUrl,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'title': title,
      'content': content,
      'is_published': isPublished,
    };
    if (columnUrl != null && columnUrl!.isNotEmpty) {
      data['column_url'] = columnUrl;
    }
    return data;
  }
}

class HospitalColumnUpdateRequest {
  final String? title;
  final String? content;
  final bool? isPublished;
  final String? columnUrl;

  HospitalColumnUpdateRequest({
    this.title,
    this.content,
    this.isPublished,
    this.columnUrl,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (title != null) data['title'] = title;
    if (content != null) data['content'] = content;
    if (isPublished != null) data['is_published'] = isPublished;
    if (columnUrl != null) data['column_url'] = columnUrl;
    return data;
  }
}

class HospitalColumnListResponse {
  final List<HospitalColumn> columns;
  final int totalCount;
  final int page;
  final int pageSize;

  HospitalColumnListResponse({
    required this.columns,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  factory HospitalColumnListResponse.fromJson(Map<String, dynamic> json) {
    final columnsList = (json['columns'] as List? ?? [])
        .map((column) => HospitalColumn.fromJson(column as Map<String, dynamic>))
        .toList();
    
    return HospitalColumnListResponse(
      columns: columnsList,
      totalCount: json['total_count'] ?? columnsList.length,
      page: json['page'] ?? 1,
      pageSize: json['page_size'] ?? columnsList.length,
    );
  }
}
