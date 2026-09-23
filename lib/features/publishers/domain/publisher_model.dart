import 'publisher_url_validator.dart';
import '../../news/domain/news_summary.dart';

/// Editorial publisher brand (not a technical Source/adapter).
///
/// Prefer backend publisher entity fields when present. Articles that only
/// carry sourceName/sourceIcon/sourceUrl still work via [PublisherModel.fromArticle].
class PublisherModel {
  const PublisherModel({
    required this.id,
    required this.name,
    this.slug,
    this.logoUrl,
    this.websiteUrl,
    this.description,
    this.languageCodes = const [],
    this.countryCodes = const [],
    this.attributionName,
    this.attributionUrl,
    this.isActive = true,
    this.sourceName,
    this.sourceId,
  });

  final String id;
  final String name;
  final String? slug;
  final String? logoUrl;
  final String? websiteUrl;
  final String? description;
  final List<String> languageCodes;
  final List<String> countryCodes;
  final String? attributionName;
  final String? attributionUrl;
  final bool isActive;

  /// Provenance keys used when filtering NewsOn articles (may equal [id]).
  final String? sourceName;
  final String? sourceId;

  String get displayName {
    for (final candidate in [
      name,
      attributionName,
      sourceName,
    ]) {
      final n = candidate?.trim() ?? '';
      if (n.isEmpty) continue;
      if (NewsArticleSummaryX.isIngestionProviderLabel(n)) continue;
      return n;
    }
    return 'Publisher';
  }

  /// API identity — prefer Mongo publisher id over slug for V2 routes.
  String get apiId {
    final trimmed = id.trim();
    if (trimmed.isNotEmpty) return trimmed;
    final s = slug?.trim();
    if (s != null && s.isNotEmpty) return s;
    return '';
  }

  String get routeId {
    final trimmed = id.trim();
    if (trimmed.isNotEmpty) return trimmed;
    final s = slug?.trim();
    if (s != null && s.isNotEmpty) return s;
    return '';
  }

  /// Trusted website for "Visit Publisher" — never raw user input from article body.
  String? get trustedWebsiteUrl {
    final candidates = [
      websiteUrl,
      attributionUrl,
    ];
    for (final raw in candidates) {
      final u = PublisherUrlValidator.normalize(raw);
      if (u != null) return u;
    }
    return null;
  }

  factory PublisherModel.fromJson(Map<String, dynamic> json) {
    final nested = json['publisher'];
    final map = nested is Map
        ? Map<String, dynamic>.from(nested)
        : Map<String, dynamic>.from(json);

    String? pickString(List<String> keys) {
      for (final k in keys) {
        final v = map[k];
        if (v == null) continue;
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
      return null;
    }

    List<String> pickStringList(List<String> keys) {
      for (final k in keys) {
        final v = map[k];
        if (v is List) {
          return v
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
        if (v is String && v.trim().isNotEmpty) {
          return v
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      }
      return const [];
    }

    final id = pickString([
          '_id',
          'id',
          'publisherId',
          'publisher_id',
          'slug',
          'source_id',
          'sourceId',
        ]) ??
        '';

    final name = pickString([
          'name',
          'publisherName',
          'publisher_name',
          'attributionName',
          'attribution_name',
          'source_name',
          'sourceName',
          'title',
        ]) ??
        'Publisher';

    final isActiveRaw = map['isActive'] ?? map['is_active'] ?? map['active'];
    final isDeleted = map['isDeleted'] == true || map['is_deleted'] == true;
    var isActive = true;
    if (isActiveRaw is bool) {
      isActive = isActiveRaw;
    } else if (isActiveRaw != null) {
      final s = isActiveRaw.toString().toLowerCase();
      if (s == 'false' || s == '0') isActive = false;
    }
    if (isDeleted) isActive = false;

    return PublisherModel(
      id: id.isNotEmpty ? id : name,
      name: name,
      slug: pickString(['slug', 'publisherSlug', 'publisher_slug']),
      logoUrl: pickString([
        'logoUrl',
        'logo_url',
        'logo',
        'icon',
        'source_icon',
        'sourceIcon',
        'imageUrl',
        'image_url',
      ]),
      websiteUrl: pickString([
        'websiteUrl',
        'website_url',
        'website',
        'url',
        'source_url',
        'sourceUrl',
      ]),
      description: pickString([
        'description',
        'about',
        'bio',
        'summary',
      ]),
      languageCodes: pickStringList([
        'languageCodes',
        'language_codes',
        'languages',
        'language',
      ]),
      countryCodes: pickStringList([
        'countryCodes',
        'country_codes',
        'countries',
        'country',
      ]),
      attributionName: pickString([
        'attributionName',
        'attribution_name',
      ]),
      attributionUrl: pickString([
        'attributionUrl',
        'attribution_url',
      ]),
      isActive: isActive,
      sourceName: pickString(['source_name', 'sourceName', 'name']),
      sourceId: pickString(['source_id', 'sourceId', 'sourceRefId', 'source_ref_id']),
    );
  }

  /// Synthesize a publisher identity from article provenance only.
  /// Does not invent description or licensing claims.
  factory PublisherModel.fromArticleProvenance({
    required String displayName,
    String? publisherId,
    String? sourceId,
    String? sourceName,
    String? sourceUrl,
    String? sourceIcon,
  }) {
    final name = displayName.trim().isNotEmpty ? displayName.trim() : 'Publisher';
    final id = (publisherId?.trim().isNotEmpty == true)
        ? publisherId!.trim()
        : (sourceId?.trim().isNotEmpty == true)
            ? sourceId!.trim()
            : name.toLowerCase().replaceAll(RegExp(r'\s+'), '-');

    return PublisherModel(
      id: id,
      name: name,
      logoUrl: sourceIcon,
      websiteUrl: sourceUrl,
      attributionName: sourceName ?? name,
      attributionUrl: sourceUrl,
      isActive: true,
      sourceName: sourceName ?? name,
      sourceId: sourceId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (slug != null) 'slug': slug,
        if (logoUrl != null) 'logoUrl': logoUrl,
        if (websiteUrl != null) 'websiteUrl': websiteUrl,
        if (description != null) 'description': description,
        'languageCodes': languageCodes,
        'countryCodes': countryCodes,
        if (attributionName != null) 'attributionName': attributionName,
        if (attributionUrl != null) 'attributionUrl': attributionUrl,
        'isActive': isActive,
        if (sourceName != null) 'sourceName': sourceName,
        if (sourceId != null) 'sourceId': sourceId,
      };
}
