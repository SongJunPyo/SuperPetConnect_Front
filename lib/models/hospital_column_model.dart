class HospitalColumn {
  final int columnIdx;
  final String title;
  final String content;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int hospitalIdx;
  final String hospitalName;

  HospitalColumn({
    required this.columnIdx,
    required this.title,
    required this.content,
    required this.isPublished,
    required this.createdAt,
    required this.updatedAt,
    required this.hospitalIdx,
    required this.hospitalName,
  });

  factory HospitalColumn.fromJson(Map<String, dynamic> json) {
    return HospitalColumn(
      columnIdx: json['column_idx'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      isPublished: json['is_published'] ?? false,
      createdAt: DateTime.parse(
        json['created_at'] ?? json['created_time'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? json['updated_time'] ?? DateTime.now().toIso8601String(),
      ),
      hospitalIdx: json['hospital_idx'] ?? 0,
      hospitalName: json['hospital_name'] ?? '',
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
    };
  }
}

class HospitalColumnCreateRequest {
  final String title;
  final String content;
  final bool isPublished;

  HospitalColumnCreateRequest({
    required this.title,
    required this.content,
    this.isPublished = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'is_published': isPublished,
    };
  }
}

class HospitalColumnUpdateRequest {
  final String? title;
  final String? content;

  HospitalColumnUpdateRequest({
    this.title,
    this.content,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (title != null) data['title'] = title;
    if (content != null) data['content'] = content;
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