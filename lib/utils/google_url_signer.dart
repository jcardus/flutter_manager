import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Utility class for signing Google Maps API URLs with HMAC-SHA1
///
/// This is required when using Google Maps API with client IDs and signing secrets
/// to prevent unauthorized usage and ensure secure API calls.
class GoogleUrlSigner {
  static String signUrl(String url, String secret, {String? clientId}) {
    try {
      // Add client parameter if provided
      String urlWithClient = url;
      if (clientId != null && clientId.isNotEmpty) {
        final separator = url.contains('?') ? '&' : '?';
        urlWithClient = '$url${separator}client=$clientId';
      }

      final uriWithClient = Uri.parse(urlWithClient);

      // Extract path and query string (what needs to be signed)
      final urlPath = '${uriWithClient.path}?${uriWithClient.query}';

      // Generate signature
      final signature = _generateSignature(urlPath, secret);

      // Append signature to URL
      return '$urlWithClient&signature=$signature';
    } catch (e) {
      throw Exception('Failed to sign URL: $e');
    }
  }

  /// Generates HMAC-SHA1 signature for the given URL path
  ///
  /// [urlPath] - The path and query string to sign (e.g., '/maps/api/streetview?size=600x400&...')
  /// [secret] - The base64-encoded signing secret from Google
  ///
  /// Returns URL-safe base64-encoded signature
  static String _generateSignature(String urlPath, String secret) {
    // Decode the base64-encoded secret key
    final secretKey = base64.decode(secret);

    // Create HMAC-SHA1 with the secret key
    final hmac = Hmac(sha1, secretKey);

    // Convert URL path to bytes and compute signature
    final bytes = utf8.encode(urlPath);
    final digest = hmac.convert(bytes);

    // Convert to URL-safe base64
    return _base64UrlEncode(digest.bytes);
  }

  /// Converts bytes to URL-safe base64 encoding
  ///
  /// URL-safe base64 replaces + with -, / with _, and removes trailing =
  static String _base64UrlEncode(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
