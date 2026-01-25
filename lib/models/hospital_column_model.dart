class HospitalColumn {
  final int columnIdx;
  final String title;
  final String content;
  final String? contentDelta; // Delta JSON 리치 텍스트
  final bool isPublished;
  final String? columnUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int hospitalIdx;
  final String hospitalName;
  final String? authorNickname; // 작성자 닉네임
  final int viewCount;
  final List<ColumnImage> images; // 칼럼 이미지 목록

  HospitalColumn({
    required this.columnIdx,
    required this.title,
    required this.content,
    this.contentDelta,
    required this.isPublished,
    required this.createdAt,
    required this.updatedAt,
    required this.hospitalIdx,
    required this.hospitalName,
    this.authorNickname,
    this.columnUrl,
    this.viewCount = 0,
    this.images = const [],
  });

  factory HospitalColumn.fromJson(Map<String, dynamic> json) {
    // 이미지 목록 파싱
    List<ColumnImage> imagesList = [];
    if (json['images'] != null && json['images'] is List) {
      imagesList = (json['images'] as List)
          .map((img) => ColumnImage.fromJson(img as Map<String, dynamic>))
          .toList();
    }

    return HospitalColumn(
      columnIdx: json['column_idx'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      contentDelta: json['content_delta'],
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
      images: imagesList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'column_idx': columnIdx,
      'title': title,
      'content': content,
      'content_delta': contentDelta,
      'is_published': isPublished,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'hospital_idx': hospitalIdx,
      'hospital_name': hospitalName,
      'author_nickname': authorNickname ?? '',
      'column_url': columnUrl,
      'view_count': viewCount,
      'images': images.map((img) => img.toJson()).toList(),
    };
  }
}

class HospitalColumnCreateRequest {
  final String title;
  final String content;
  final String? contentDelta; // Delta JSON 리치 텍스트
  final bool isPublished;
  final String? columnUrl;

  HospitalColumnCreateRequest({
    required this.title,
    required this.content,
    this.contentDelta,
    this.isPublished = true,
    this.columnUrl,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'title': title,
      'content': content,
      'is_published': isPublished,
    };
    if (contentDelta != null && contentDelta!.isNotEmpty) {
      data['content_delta'] = contentDelta;
    }
    if (columnUrl != null && columnUrl!.isNotEmpty) {
      data['column_url'] = columnUrl;
    }
    return data;
  }
}

class HospitalColumnUpdateRequest {
  final String? title;
  final String? content;
  final String? contentDelta; // Delta JSON 리치 텍스트
  final bool? isPublished;
  final String? columnUrl;

  HospitalColumnUpdateRequest({
    this.title,
    this.content,
    this.contentDelta,
    this.isPublished,
    this.columnUrl,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (title != null) data['title'] = title;
    if (content != null) data['content'] = content;
    if (contentDelta != null) data['content_delta'] = contentDelta;
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

/// 칼럼 이미지 모델
class ColumnImage {
  final int imageId;
  final int? columnIdx;
  final String imagePath;
  final String? thumbnailPath;
  final int imageOrder;
  final String? originalName;
  final int? fileSize;
  final DateTime? uploadedAt;

  ColumnImage({
    required this.imageId,
    this.columnIdx,
    required this.imagePath,
    this.thumbnailPath,
    this.imageOrder = 0,
    this.originalName,
    this.fileSize,
    this.uploadedAt,
  });

  factory ColumnImage.fromJson(Map<String, dynamic> json) {
    return ColumnImage(
      imageId: json['image_id'] ?? 0,
      columnIdx: json['column_idx'],
      imagePath: json['image_path'] ?? '',
      thumbnailPath: json['thumbnail_path'],
      imageOrder: json['image_order'] ?? 0,
      originalName: json['original_name'],
      fileSize: json['file_size'],
      uploadedAt: json['uploaded_at'] != null
          ? DateTime.parse(json['uploaded_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'image_id': imageId,
      'column_idx': columnIdx,
      'image_path': imagePath,
      'thumbnail_path': thumbnailPath,
      'image_order': imageOrder,
      'original_name': originalName,
      'file_size': fileSize,
      'uploaded_at': uploadedAt?.toIso8601String(),
    };
  }
}
