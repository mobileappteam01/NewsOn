class V2CategoryOption {
  const V2CategoryOption({
    required this.slug,
    required this.name,
    this.id,
    this.mediaUrl,
    this.mediaType,
    this.imageUrl,
  });

  final String slug;
  final String name;

  /// Mongo ObjectId when present — used only to map saved preferences → slugs.
  final String? id;

  /// Relative or absolute path from API `media.url`.
  final String? mediaUrl;

  /// MIME/kind from API `media.type` (e.g. `image`).
  final String? mediaType;

  /// Absolute URL for catalog cards (relative paths resolved via image base).
  final String? imageUrl;

  factory V2CategoryOption.fromJson(
    Map<String, dynamic> json, {
    String? imageBaseUrl,
  }) {
    final slug = categorySlugFromJson(json);
    final name = categoryDisplayNameFromJson(json, slug: slug);
    final id = categoryIdFromJson(json);
    final media = categoryMediaFromJson(json);
    final imageUrl = resolveCategoryImageUrl(
      mediaUrl: media?.url,
      imageBaseUrl: imageBaseUrl,
    );
    return V2CategoryOption(
      slug: slug ?? '',
      name: (name != null && name.isNotEmpty) ? name : (slug ?? ''),
      id: id,
      mediaUrl: media?.url,
      mediaType: media?.type,
      imageUrl: imageUrl,
    );
  }

  static List<V2CategoryOption> parseList(
    dynamic raw, {
    String? imageBaseUrl,
  }) {
    final list = _unwrapList(raw, const ['categories', 'items', 'results']);
    final out = <V2CategoryOption>[];
    final seenIds = <String>{};
    final seenSlugs = <String>{};
    for (final item in list) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      // Catalog contract: exclude inactive / soft-deleted rows at parse time.
      if (map['isDeleted'] == true) continue;
      if (map['isActive'] == false) continue;
      final option = V2CategoryOption.fromJson(
        map,
        imageBaseUrl: imageBaseUrl,
      );
      if (option.slug.isEmpty) continue;
      final idKey = (option.id ?? '').trim();
      if (idKey.isNotEmpty) {
        if (seenIds.contains(idKey)) continue;
        seenIds.add(idKey);
      } else if (seenSlugs.contains(option.slug)) {
        continue;
      }
      seenSlugs.add(option.slug);
      out.add(option);
    }
    return out;
  }
}

class V2RegionOption {
  const V2RegionOption({
    required this.slug,
    required this.name,
  });

  /// Canonical backend value (`name` from countries API). Used in queries/PATCH.
  final String slug;

  /// UI label (`label` from countries API when present, else name).
  final String name;

  factory V2RegionOption.fromJson(Map<String, dynamic> json) {
    // V2 countries contract: { name, label }. Prefer name as canonical value.
    final nameField = _pick(json, const ['name', 'country_name']);
    final label = _pick(json, const [
      'label',
      'title',
      'displayName',
      'display_name',
      'country_name',
    ]);
    // Do not prefer Mongo `id` — it is not a country slug.
    final slug = _pick(json, const ['slug', 'code']) ?? nameField ?? '';
    final display = label ?? nameField ?? slug;
    return V2RegionOption(
      slug: slug,
      name: display.isEmpty ? slug : display,
    );
  }

  static List<V2RegionOption> parseList(dynamic raw) {
    final list = _unwrapList(raw, const [
      'countries',
      'states',
      'cities',
      'districts',
      'regions',
      'items',
      'results',
    ]);
    final out = <V2RegionOption>[];
    final seen = <String>{};
    for (final item in list) {
      if (item is String) {
        final s = item.trim();
        if (s.isEmpty || seen.contains(s)) continue;
        seen.add(s);
        out.add(V2RegionOption(slug: s, name: s));
        continue;
      }
      if (item is! Map) continue;
      final option = V2RegionOption.fromJson(Map<String, dynamic>.from(item));
      if (option.slug.isEmpty || seen.contains(option.slug)) continue;
      seen.add(option.slug);
      out.add(option);
    }
    return out;
  }
}

/// Query value for `category=`. Explicit slug fields win.
/// Mongo ids are never used as the slug (they live on [V2CategoryOption.id]).
String? categorySlugFromJson(Map<String, dynamic> json) {
  final explicit = _pick(json, const [
    'slug',
    'categorySlug',
    'category_slug',
  ]);
  if (explicit != null && !isMongoObjectId(explicit)) {
    final normalized = normalizeCategorySlug(explicit);
    if (isCategorySlugToken(normalized)) return normalized;
  }

  final provider = _pick(json, const [
    'providerCategory',
    'provider_category',
  ]);
  if (provider != null) {
    final normalized = normalizeCategorySlug(provider);
    if (isCategorySlugToken(normalized)) return normalized;
  }

  final name = _pick(json, const ['name']);
  if (name != null && !isMongoObjectId(name)) {
    final normalized = normalizeCategorySlug(name);
    if (isCategorySlugToken(normalized)) return normalized;
  }
  return null;
}

String? categoryIdFromJson(Map<String, dynamic> json) {
  for (final key in const ['_id', 'id', 'categoryId', 'category_id']) {
    final value = json[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (isMongoObjectId(text)) return text;
  }
  return null;
}

/// Parsed `media` object from V2 `/api/v2/categories`.
class V2CategoryMedia {
  const V2CategoryMedia({required this.url, this.type});

  final String url;
  final String? type;
}

/// Reads category image path from V2 payloads (`media.url` / `media.type`).
V2CategoryMedia? categoryMediaFromJson(Map<String, dynamic> json) {
  final media = json['media'];
  if (media is Map) {
    final map = Map<String, dynamic>.from(media);
    final url = _pick(map, const ['url', 'path', 'src']);
    if (url != null) {
      final type = _pick(map, const ['type', 'mimeType', 'mimetype']);
      return V2CategoryMedia(url: url, type: type ?? 'image');
    }
  }
  final flat = _pick(json, const [
    'imageUrl',
    'image_url',
    'image',
    'thumbnail',
    'thumbnailUrl',
  ]);
  if (flat == null) return null;
  return V2CategoryMedia(url: flat, type: 'image');
}

/// Convenience: media.url only (null-safe).
String? categoryMediaUrlFromJson(Map<String, dynamic> json) =>
    categoryMediaFromJson(json)?.url;

/// Resolves relative media paths against the shared image base URL.
/// Absolute http(s) URLs are returned unchanged.
/// Null/empty media → null. Relative without a base → null (safe UI fallback).
String? resolveCategoryImageUrl({
  required String? mediaUrl,
  String? imageBaseUrl,
}) {
  final path = mediaUrl?.trim() ?? '';
  if (path.isEmpty) return null;
  final lower = path.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return path;
  }
  final base = imageBaseUrl?.trim() ?? '';
  if (base.isEmpty) return null;
  final normalizedBase =
      base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
  return '$normalizedBase/$normalizedPath';
}

/// Lowercase hyphenated slug matching backend `categoryLookupKeys`.
String normalizeCategorySlug(String token) {
  final name = token
      .trim()
      .toLowerCase()
      .replaceAll('-', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return name.replaceAll(' ', '-');
}

String? categoryDisplayNameFromJson(
  Map<String, dynamic> json, {
  String? slug,
}) {
  final display = _pick(json, const [
    'categoryName',
    'displayName',
    'display_name',
    'title',
    'label',
  ]);
  if (display != null) return display;
  final name = _pick(json, const ['name']);
  if (name != null && name != slug) return name;
  return slug;
}

/// Presentation-only: first character uppercase, rest unchanged.
/// Does not mutate slugs or backend category names.
String capitalizeCategoryLabel(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return text;
  if (text.length == 1) return text.toUpperCase();
  return '${text[0].toUpperCase()}${text.substring(1)}';
}

bool isMongoObjectId(String value) =>
    RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(value.trim());

/// Lowercase backend slug, not a localized label.
bool isCategorySlugToken(String value) =>
    RegExp(r'^[a-z0-9]+(?:[-_][a-z0-9]+)*$').hasMatch(value.trim());

String? _pick(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

List<dynamic> _unwrapList(dynamic raw, List<String> nestedKeys) {
  if (raw is List) return raw;
  if (raw is! Map) return const [];
  final map = Map<String, dynamic>.from(raw);
  final data = map['data'];
  if (data is List) return data;
  if (data is Map) {
    final nested = Map<String, dynamic>.from(data);
    for (final key in nestedKeys) {
      final value = nested[key];
      if (value is List) return value;
    }
  }
  for (final key in nestedKeys) {
    final value = map[key];
    if (value is List) return value;
  }
  return const [];
}
