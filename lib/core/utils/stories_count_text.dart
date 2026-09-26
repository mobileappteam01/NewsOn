/// Turns a localization template into a user-visible story count.
///
/// The UI must receive a number. Templates may arrive uninterpolated from
/// dynamic language files (`{count}`, `{{count}}`, `$count`, `%count%`).
abstract final class StoriesCountText {
  static String apply(String template, int count) {
    final n = count < 0 ? 0 : count;
    var text = template.trim();
    if (text.isEmpty || text == 'storiesCount') {
      text = '$n stories';
    }
    text = text
        .replaceAll('{{count}}', '$n')
        .replaceAll('{count}', '$n')
        .replaceAll('%count%', '$n')
        .replaceAll(r'$count', '$n');

    if (n == 1) {
      text = text.replaceFirst(' stories', ' story');
    }
    return text;
  }
}
