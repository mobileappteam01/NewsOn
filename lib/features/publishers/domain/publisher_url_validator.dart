/// Validates trusted publisher website URLs for "Visit Publisher".
abstract final class PublisherUrlValidator {
  static bool isTrustedHttpUrl(String? raw) {
    final t = raw?.trim();
    if (t == null || t.isEmpty) return false;
    final lower = t.toLowerCase();
    if (lower.startsWith('javascript:') ||
        lower.startsWith('data:') ||
        lower.startsWith('file:')) {
      return false;
    }
    final withScheme = (t.startsWith('http://') || t.startsWith('https://'))
        ? t
        : (t.contains('.') && !t.contains(' ') ? 'https://$t' : null);
    if (withScheme == null) return false;
    final uri = Uri.tryParse(withScheme);
    if (uri == null) return false;
    if (!(uri.isScheme('http') || uri.isScheme('https'))) return false;
    if (uri.host.isEmpty) return false;
    return true;
  }

  static String? normalize(String? raw) {
    if (!isTrustedHttpUrl(raw)) return null;
    final t = raw!.trim();
    if (t.startsWith('http://') || t.startsWith('https://')) return t;
    return 'https://$t';
  }
}
