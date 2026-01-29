/// Model for App Update information from API
class AppUpdateModel {
  final String id;
  final AppUpdateMedia? media;
  final String title;
  final String description;
  final String currentVersion;
  final String newVersion;
  final String submitText;
  final String ignoreText;
  final bool forceUpdate;
  final String updateTo;
  final bool isActive;
  final String? androidLink;
  final String? iosLink;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AppUpdateModel({
    required this.id,
    this.media,
    required this.title,
    required this.description,
    required this.currentVersion,
    required this.newVersion,
    required this.submitText,
    required this.ignoreText,
    required this.forceUpdate,
    required this.updateTo,
    required this.isActive,
    this.androidLink,
    this.iosLink,
    this.createdAt,
    this.updatedAt,
  });

  factory AppUpdateModel.fromJson(Map<String, dynamic> json) {
    return AppUpdateModel(
      id: json['_id'] as String? ?? '',
      media: json['media'] != null 
          ? AppUpdateMedia.fromJson(json['media'] as Map<String, dynamic>)
          : null,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      currentVersion: json['currentVersion'] as String? ?? '0.0.0',
      newVersion: json['newVersion'] as String? ?? '0.0.0',
      submitText: json['submitText'] as String? ?? 'Update Now',
      ignoreText: json['ignoreText'] as String? ?? 'Later',
      forceUpdate: json['forceUpdate'] as bool? ?? false,
      updateTo: json['updateTo'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? false,
      androidLink: json['andriodLink'] as String?, // Note: API has typo "andriod"
      iosLink: json['iosLink'] as String?,
      createdAt: json['createdAt'] != null 
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'media': media?.toJson(),
      'title': title,
      'description': description,
      'currentVersion': currentVersion,
      'newVersion': newVersion,
      'submitText': submitText,
      'ignoreText': ignoreText,
      'forceUpdate': forceUpdate,
      'updateTo': updateTo,
      'isActive': isActive,
      'andriodLink': androidLink,
      'iosLink': iosLink,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Check if an update is available by comparing versions
  bool isUpdateAvailable(String currentAppVersion) {
    if (!isActive) return false;
    return _compareVersions(currentAppVersion, newVersion) < 0;
  }

  /// Compare two version strings
  /// Returns: -1 if v1 < v2, 0 if v1 == v2, 1 if v1 > v2
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // Pad shorter version with zeros
    while (parts1.length < parts2.length) {
      parts1.add(0);
    }
    while (parts2.length < parts1.length) {
      parts2.add(0);
    }

    for (int i = 0; i < parts1.length; i++) {
      if (parts1[i] < parts2[i]) return -1;
      if (parts1[i] > parts2[i]) return 1;
    }
    return 0;
  }

  @override
  String toString() {
    return 'AppUpdateModel(title: $title, currentVersion: $currentVersion, newVersion: $newVersion, forceUpdate: $forceUpdate, isActive: $isActive)';
  }
}

/// Model for media in app update
class AppUpdateMedia {
  final String url;
  final String type;
  final String filename;
  final int size;
  final String mimetype;
  final String id;

  AppUpdateMedia({
    required this.url,
    required this.type,
    required this.filename,
    required this.size,
    required this.mimetype,
    required this.id,
  });

  factory AppUpdateMedia.fromJson(Map<String, dynamic> json) {
    return AppUpdateMedia(
      url: json['url'] as String? ?? '',
      type: json['type'] as String? ?? '',
      filename: json['filename'] as String? ?? '',
      size: json['size'] as int? ?? 0,
      mimetype: json['mimetype'] as String? ?? '',
      id: json['_id'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'type': type,
      'filename': filename,
      'size': size,
      'mimetype': mimetype,
      '_id': id,
    };
  }
}
