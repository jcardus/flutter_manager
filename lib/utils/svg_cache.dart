import 'dart:developer' as dev;
import 'package:http/http.dart' as http;

/// Fetches SVGs and inlines CSS <style> classes into element attributes,
/// working around flutter_svg's lack of <style> support.
class SvgCache {
  static final _cache = <String, String>{};

  /// Returns cached SVG synchronously, or null if not yet fetched.
  static String? getSync(String url) => _cache[url];

  /// Returns the SVG string with CSS classes inlined, or null on failure.
  static Future<String?> get(String url) async {
    if (_cache.containsKey(url)) {
      dev.log('SvgCache HIT: $url');
      return _cache[url];
    }

    try {
      dev.log('SvgCache FETCH: $url');
      final response = await http.get(Uri.parse(url));
      dev.log('SvgCache ${response.statusCode}: $url');
      if (response.statusCode != 200) return null;

      final svg = _inlineStyles(response.body);
      _cache[url] = svg;
      return svg;
    } catch (e) {
      dev.log('SvgCache ERROR: $url — $e');
      return null;
    }
  }

  static String _inlineStyles(String svg) {
    // Extract <style>...</style> content
    final styleMatch = RegExp(
      r'<style[^>]*>(.*?)</style>',
      dotAll: true,
    ).firstMatch(svg);
    if (styleMatch == null) return svg;

    final styleContent = styleMatch.group(1)!;

    // Parse CSS rules: .cls-1{fill:#fff;opacity:0.3;}
    final rules = <String, Map<String, String>>{};
    final rulePattern = RegExp(r'\.([\w-]+)\s*\{([^}]*)\}');
    for (final m in rulePattern.allMatches(styleContent)) {
      final className = m.group(1)!;
      final props = <String, String>{};
      for (final decl in m.group(2)!.split(';')) {
        final parts = decl.split(':');
        if (parts.length == 2) {
          props[parts[0].trim()] = parts[1].trim();
        }
      }
      rules[className] = props;
    }

    // Remove the <defs><style>...</style></defs> or just <style>...</style>
    var result = svg.replaceAll(
      RegExp(r'<defs>\s*<style[^>]*>.*?</style>\s*</defs>', dotAll: true),
      '',
    );
    result = result.replaceAll(
      RegExp(r'<style[^>]*>.*?</style>', dotAll: true),
      '',
    );

    // Replace class="cls-X" with inline SVG attributes
    result = result.replaceAllMapped(
      RegExp(r'class="([\w-]+)"'),
      (match) {
        final className = match.group(1)!;
        final props = rules[className];
        if (props == null) return match.group(0)!;

        final attrs = props.entries.map((e) => '${e.key}="${e.value}"');
        return attrs.join(' ');
      },
    );

    return result;
  }
}
