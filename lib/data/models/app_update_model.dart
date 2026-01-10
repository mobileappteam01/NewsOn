class AppUpdateModel {
  final String id;
  final String title;
  final String description;
  final String currentVersion;
  final String newVersion;
  final String submitText;
  final String ignoreText;
  final bool forceUpdate;
  final String updateTo;
  final bool isActive;
  final String? mediaUrl;

  AppUpdateModel({
    required this.id,
    required this.title,
    required this.description,
    required this.currentVersion,
    required this.newVersion,
    required this.submitText,
    required this.ignoreText,
    required this.forceUpdate,
    required this.updateTo,
    required this.isActive,
    this.mediaUrl,
  });

  factory AppUpdateModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return AppUpdateModel(
      id: data['_id'] as String,
      title: data['title'] as String,
      description: data['description'] as String,
      currentVersion: data['currentVersion'] as String,
      newVersion: data['newVersion'] as String,
      submitText: data['submitText'] as String,
      ignoreText: data['ignoreText'] as String,
      forceUpdate: data['forceUpdate'] as bool,
      updateTo: data['updateTo'] as String,
      isActive: data['isActive'] as bool,
      mediaUrl: data['media'] != null ? data['media']['url'] as String? : null,
    );
  }
}
