import 'dart:typed_data';

/// 헌혈 게시글 이미지 모델
///
/// 서버 테이블: donation_post_images
/// 용도: 헌혈 게시글에 첨부되는 이미지 정보 관리
class DonationPostImage {
  final int imageId;
  final int? postIdx; // NULL = 임시 이미지 (게시글 생성 전)
  final String imagePath;
  final String? thumbnailPath;
  final int imageOrder;
  final String? caption;
  final String? originalName;
  final int? fileSize;
  final DateTime? uploadedAt;
  final bool isDeleted;

  // 로컬 상태 관리용 (서버 데이터 아님)
  final bool isUploading;
  final double uploadProgress;
  final String? localPath; // 업로드 전 로컬 파일 경로 (모바일용)
  final Uint8List? localBytes; // 업로드 전 이미지 바이트 (웹 지원용)

  DonationPostImage({
    required this.imageId,
    this.postIdx,
    required this.imagePath,
    this.thumbnailPath,
    this.imageOrder = 0,
    this.caption,
    this.originalName,
    this.fileSize,
    this.uploadedAt,
    this.isDeleted = false,
    this.isUploading = false,
    this.uploadProgress = 0.0,
    this.localPath,
    this.localBytes,
  });

  /// JSON에서 모델 생성
  factory DonationPostImage.fromJson(Map<String, dynamic> json) {
    return DonationPostImage(
      imageId: _parseInt(json['image_id'] ?? json['imageId']),
      postIdx: json['post_idx'] != null || json['postIdx'] != null
          ? _parseInt(json['post_idx'] ?? json['postIdx'])
          : null,
      imagePath: json['image_path'] ?? json['imagePath'] ?? '',
      thumbnailPath: json['thumbnail_path'] ?? json['thumbnailPath'],
      imageOrder: _parseInt(json['image_order'] ?? json['imageOrder'] ?? 0),
      caption: json['caption'],
      originalName: json['original_name'] ?? json['originalName'],
      fileSize: json['file_size'] != null || json['fileSize'] != null
          ? _parseInt(json['file_size'] ?? json['fileSize'])
          : null,
      uploadedAt: json['uploaded_at'] != null
          ? DateTime.tryParse(json['uploaded_at'])
          : json['uploadedAt'] != null
              ? DateTime.tryParse(json['uploadedAt'])
              : null,
      isDeleted: json['is_deleted'] == 1 || json['isDeleted'] == true,
    );
  }

  /// 모델을 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'image_id': imageId,
      'post_idx': postIdx,
      'image_path': imagePath,
      'thumbnail_path': thumbnailPath,
      'image_order': imageOrder,
      'caption': caption,
      'original_name': originalName,
      'file_size': fileSize,
    };
  }

  /// 로컬 임시 이미지 생성 (업로드 전)
  factory DonationPostImage.temporary({
    String? localPath,
    Uint8List? localBytes,
    required String originalName,
    int? fileSize,
  }) {
    return DonationPostImage(
      imageId: -DateTime.now().millisecondsSinceEpoch, // 임시 음수 ID
      imagePath: localPath ?? '',
      originalName: originalName,
      fileSize: fileSize,
      localPath: localPath,
      localBytes: localBytes,
      isUploading: true,
      uploadProgress: 0.0,
    );
  }

  /// 업로드 진행률 업데이트
  DonationPostImage copyWithProgress(double progress) {
    return DonationPostImage(
      imageId: imageId,
      postIdx: postIdx,
      imagePath: imagePath,
      thumbnailPath: thumbnailPath,
      imageOrder: imageOrder,
      caption: caption,
      originalName: originalName,
      fileSize: fileSize,
      uploadedAt: uploadedAt,
      isDeleted: isDeleted,
      isUploading: progress < 1.0,
      uploadProgress: progress,
      localPath: localPath,
      localBytes: localBytes,
    );
  }

  /// 업로드 완료 후 서버 응답으로 업데이트
  DonationPostImage copyWithServerResponse(Map<String, dynamic> response) {
    return DonationPostImage(
      imageId: _parseInt(response['image_id'] ?? response['imageId']),
      postIdx: postIdx,
      imagePath: response['image_path'] ?? response['imagePath'] ?? imagePath,
      thumbnailPath: response['thumbnail_path'] ?? response['thumbnailPath'],
      imageOrder: imageOrder,
      caption: caption,
      originalName: response['original_name'] ?? response['originalName'] ?? originalName,
      fileSize: response['file_size'] != null
          ? _parseInt(response['file_size'])
          : fileSize,
      uploadedAt: DateTime.now(),
      isDeleted: false,
      isUploading: false,
      uploadProgress: 1.0,
      localPath: null,
    );
  }

  /// 순서 변경
  DonationPostImage copyWithOrder(int newOrder) {
    return DonationPostImage(
      imageId: imageId,
      postIdx: postIdx,
      imagePath: imagePath,
      thumbnailPath: thumbnailPath,
      imageOrder: newOrder,
      caption: caption,
      originalName: originalName,
      fileSize: fileSize,
      uploadedAt: uploadedAt,
      isDeleted: isDeleted,
      isUploading: isUploading,
      uploadProgress: uploadProgress,
      localPath: localPath,
      localBytes: localBytes,
    );
  }

  /// 캡션 변경
  DonationPostImage copyWithCaption(String? newCaption) {
    return DonationPostImage(
      imageId: imageId,
      postIdx: postIdx,
      imagePath: imagePath,
      thumbnailPath: thumbnailPath,
      imageOrder: imageOrder,
      caption: newCaption,
      originalName: originalName,
      fileSize: fileSize,
      uploadedAt: uploadedAt,
      isDeleted: isDeleted,
      isUploading: isUploading,
      uploadProgress: uploadProgress,
      localPath: localPath,
      localBytes: localBytes,
    );
  }

  /// 임시 이미지인지 확인 (아직 서버에 연결되지 않음)
  bool get isTemporary => imageId < 0;

  /// 표시할 이미지 경로 (로컬 또는 서버)
  String get displayPath => localPath ?? imagePath;

  /// 파일 크기 포맷팅 (KB/MB)
  String get fileSizeFormatted {
    if (fileSize == null) return '';
    if (fileSize! < 1024) return '${fileSize}B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)}KB';
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// int 파싱 헬퍼
  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

/// 이미지 순서 변경 요청 모델
class ImageOrderUpdate {
  final int imageId;
  final int imageOrder;

  ImageOrderUpdate({
    required this.imageId,
    required this.imageOrder,
  });

  Map<String, dynamic> toJson() {
    return {
      'image_id': imageId,
      'image_order': imageOrder,
    };
  }
}
