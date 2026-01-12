/// Model representing a supported language fetched from Firebase
class LanguageModel {
  final String code;
  final String name;
  final String nativeName;
  final bool isDefault;
  final bool isActive;
  final String? flagEmoji;

  LanguageModel({
    required this.code,
    required this.name,
    required this.nativeName,
    this.isDefault = false,
    this.isActive = true,
    this.flagEmoji,
  });

  factory LanguageModel.fromJson(Map<String, dynamic> json) {
    return LanguageModel(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      nativeName: json['nativeName'] as String? ?? json['name'] as String? ?? '',
      isDefault: json['isDefault'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      flagEmoji: json['flagEmoji'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'nativeName': nativeName,
      'isDefault': isDefault,
      'isActive': isActive,
      'flagEmoji': flagEmoji,
    };
  }

  @override
  String toString() => 'LanguageModel(code: $code, name: $name, nativeName: $nativeName, isActive: $isActive)';
}
