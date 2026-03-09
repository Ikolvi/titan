import 'dart:async';
import 'dart:io';

import '../courier.dart';
import '../dispatch.dart';
import '../missive.dart';

/// **CookieCourier** — Automatic cookie management for [Envoy].
///
/// Stores cookies from responses and attaches them to subsequent requests,
/// respecting domain, path, and expiry rules. Uses a simple in-memory
/// cookie jar by default.
///
/// ```dart
/// final envoy = Envoy(baseUrl: 'https://api.example.com');
///
/// envoy.addCourier(CookieCourier());
///
/// // Login — server sets session cookie
/// await envoy.post('/auth/login', data: credentials);
///
/// // Subsequent requests automatically include the session cookie
/// await envoy.get('/profile'); // Cookie: session=abc123
/// ```
class CookieCourier extends Courier {
  /// Creates a new [CookieCourier].
  ///
  /// - [persistCookies]: Whether cookies persist across sessions
  ///   (default: true). When false, all cookies are treated as session
  ///   cookies and cleared when the courier is disposed.
  CookieCourier({this.persistCookies = true});

  /// Whether to persist cookies with explicit expiry dates.
  final bool persistCookies;

  final Map<String, Map<String, _CookieEntry>> _jar = {};

  @override
  Future<Dispatch> intercept(Missive missive, CourierChain chain) async {
    // Attach stored cookies to the request
    final uri = missive.resolvedUri;
    final cookieHeader = _getCookiesForUri(uri);

    Missive requestMissive = missive;
    if (cookieHeader.isNotEmpty) {
      final updatedHeaders = Map<String, String>.from(missive.headers);
      final existing = updatedHeaders['cookie'];
      if (existing != null && existing.isNotEmpty) {
        updatedHeaders['cookie'] = '$existing; $cookieHeader';
      } else {
        updatedHeaders['cookie'] = cookieHeader;
      }
      requestMissive = missive.copyWith(headers: updatedHeaders);
    }

    final dispatch = await chain.proceed(requestMissive);

    // Extract and store cookies from response
    _storeCookies(uri, dispatch.headers);

    return dispatch;
  }

  /// Returns all cookies currently stored for [uri].
  String _getCookiesForUri(Uri uri) {
    _evictExpired();

    final host = uri.host;
    final path = uri.path.isEmpty ? '/' : uri.path;
    final buffer = StringBuffer();

    for (final entry in _jar.entries) {
      final domain = entry.key;
      if (!_domainMatches(host, domain)) continue;

      for (final cookie in entry.value.values) {
        if (!path.startsWith(cookie.path)) continue;

        if (cookie.secure && uri.scheme != 'https') continue;

        if (buffer.isNotEmpty) buffer.write('; ');
        buffer.write('${cookie.name}=${cookie.value}');
      }
    }

    return buffer.toString();
  }

  /// Stores cookies from response headers.
  void _storeCookies(Uri uri, Map<String, String> headers) {
    final setCookie = headers['set-cookie'];
    if (setCookie == null) return;

    // set-cookie headers may be joined with comma —
    // but cookies themselves can contain commas in dates.
    // We parse conservatively: split on ', ' only if followed by a cookie name.
    final cookies = _parseSetCookieHeader(setCookie);

    for (final cookieStr in cookies) {
      final cookie = _parseCookie(cookieStr, uri);
      if (cookie == null) continue;

      if (!persistCookies && cookie.expires != null) {
        // Treat as session cookie: keep but ignore expiry
        cookie.expires = null;
      }

      _jar.putIfAbsent(cookie.domain, () => {});
      _jar[cookie.domain]![cookie.name] = cookie;
    }
  }

  List<String> _parseSetCookieHeader(String header) {
    // Simple split: individual set-cookie values were already joined by ', '
    // in the response header map. We need to split them back.
    // A cookie starts with "name=value" so we look for ", name=" patterns.
    final result = <String>[];
    final regExp = RegExp(r',\s*(?=[a-zA-Z_][a-zA-Z0-9_]*=)');
    result.addAll(header.split(regExp));
    return result;
  }

  _CookieEntry? _parseCookie(String cookieStr, Uri uri) {
    final parts = cookieStr.split(';').map((p) => p.trim()).toList();
    if (parts.isEmpty) return null;

    final nameValue = parts[0].split('=');
    if (nameValue.length < 2) return null;

    final name = nameValue[0].trim();
    final value = nameValue.sublist(1).join('=').trim();

    if (name.isEmpty) return null;

    var domain = uri.host;
    var path = '/';
    DateTime? expires;
    var secure = false;
    var httpOnly = false;

    for (var i = 1; i < parts.length; i++) {
      final attr = parts[i];
      final eqIndex = attr.indexOf('=');
      final attrName = (eqIndex > 0 ? attr.substring(0, eqIndex) : attr)
          .trim()
          .toLowerCase();
      final attrValue = eqIndex > 0 ? attr.substring(eqIndex + 1).trim() : '';

      switch (attrName) {
        case 'domain':
          domain = attrValue.startsWith('.')
              ? attrValue.substring(1)
              : attrValue;
        case 'path':
          path = attrValue.isEmpty ? '/' : attrValue;
        case 'expires':
          expires = HttpDate.parse(attrValue);
        case 'max-age':
          final seconds = int.tryParse(attrValue);
          if (seconds != null) {
            expires = DateTime.now().add(Duration(seconds: seconds));
          }
        case 'secure':
          secure = true;
        case 'httponly':
          httpOnly = true;
      }
    }

    return _CookieEntry(
      name: name,
      value: value,
      domain: domain,
      path: path,
      expires: expires,
      secure: secure,
      httpOnly: httpOnly,
    );
  }

  bool _domainMatches(String host, String domain) {
    return host == domain || host.endsWith('.$domain');
  }

  void _evictExpired() {
    final now = DateTime.now();
    for (final domainCookies in _jar.values) {
      domainCookies.removeWhere(
        (_, cookie) => cookie.expires != null && cookie.expires!.isBefore(now),
      );
    }
    _jar.removeWhere((_, cookies) => cookies.isEmpty);
  }

  /// Clears all stored cookies.
  void clear() => _jar.clear();

  /// Number of cookies currently stored.
  int get cookieCount =>
      _jar.values.fold(0, (sum, cookies) => sum + cookies.length);
}

class _CookieEntry {
  _CookieEntry({
    required this.name,
    required this.value,
    required this.domain,
    required this.path,
    this.expires,
    this.secure = false,
    this.httpOnly = false,
  });

  final String name;
  final String value;
  final String domain;
  final String path;
  DateTime? expires;
  final bool secure;
  final bool httpOnly;
}
