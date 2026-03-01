/// Trie-based route matcher for O(k) path resolution.
///
/// Supports:
/// - Static segments: `/home`, `/settings/profile`
/// - Dynamic segments (Runes): `/profile/:id`, `/post/:slug/comments`
/// - Wildcard: `/files/*` (catches remaining path)
/// - Priority: static > dynamic > wildcard
library;

/// Result of a route match.
class RouteMatch<T> {
  /// The matched value stored at this route node.
  final T value;

  /// Extracted path parameters (Runes).
  final Map<String, String> runes;

  /// The matched path pattern.
  final String pattern;

  /// Remaining unmatched path (for wildcard routes).
  final String? remaining;

  const RouteMatch({
    required this.value,
    required this.runes,
    required this.pattern,
    this.remaining,
  });
}

/// A node in the route trie.
class _TrieNode<T> {
  /// Value stored at this node (if this is a terminal node).
  T? value;

  /// The pattern that registered this node.
  String? pattern;

  /// Static children: segment → node.
  final Map<String, _TrieNode<T>> staticChildren = {};

  /// Dynamic parameter child (e.g., `:id`).
  _TrieNode<T>? paramChild;

  /// Parameter name for dynamic segments.
  String? paramName;

  /// Wildcard child (catches everything remaining).
  _TrieNode<T>? wildcardChild;
}

/// High-performance trie-based route matcher.
///
/// ```dart
/// final trie = RouteTrie<Widget Function()>();
/// trie.insert('/home', () => HomeScreen());
/// trie.insert('/profile/:id', () => ProfileScreen());
/// trie.insert('/files/*', () => FileScreen());
///
/// final match = trie.match('/profile/42');
/// // match.runes == {'id': '42'}
/// // match.value == ProfileScreen builder
/// ```
class RouteTrie<T> {
  final _TrieNode<T> _root = _TrieNode<T>();

  /// Number of registered routes.
  int _count = 0;

  /// Number of registered routes.
  int get length => _count;

  /// Insert a route pattern with its value.
  ///
  /// Patterns support:
  /// - `/static/path` — exact match
  /// - `/user/:id` — dynamic parameter (Rune)
  /// - `/files/*` — wildcard (matches remaining path)
  void insert(String pattern, T value) {
    final segments = _splitPath(pattern);
    var node = _root;

    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];

      if (segment == '*') {
        // Wildcard — must be last segment
        node.wildcardChild ??= _TrieNode<T>();
        node = node.wildcardChild!;
        break;
      } else if (segment.startsWith(':')) {
        // Dynamic parameter
        final paramName = segment.substring(1);
        if (node.paramChild == null) {
          node.paramChild = _TrieNode<T>();
          node.paramChild!.paramName = paramName;
        }
        node = node.paramChild!;
      } else {
        // Static segment
        node.staticChildren.putIfAbsent(segment, _TrieNode<T>.new);
        node = node.staticChildren[segment]!;
      }
    }

    node.value = value;
    node.pattern = pattern;
    _count++;
  }

  /// Match a URI path against registered routes.
  ///
  /// Returns null if no match found.
  /// Priority: static segments > dynamic parameters > wildcard.
  RouteMatch<T>? match(String path) {
    final segments = _splitPath(path);
    return _match(_root, segments, 0, {});
  }

  RouteMatch<T>? _match(
    _TrieNode<T> node,
    List<String> segments,
    int index,
    Map<String, String> runes,
  ) {
    // Base case: consumed all segments
    if (index == segments.length) {
      if (node.value != null) {
        return RouteMatch(
          value: node.value as T,
          runes: Map.unmodifiable(runes),
          pattern: node.pattern!,
        );
      }
      return null;
    }

    final segment = segments[index];

    // Priority 1: Static match
    if (node.staticChildren.containsKey(segment)) {
      final result = _match(
        node.staticChildren[segment]!,
        segments,
        index + 1,
        runes,
      );
      if (result != null) return result;
    }

    // Priority 2: Dynamic parameter match
    if (node.paramChild != null) {
      final paramRunes = Map<String, String>.from(runes);
      paramRunes[node.paramChild!.paramName!] = segment;
      final result = _match(
        node.paramChild!,
        segments,
        index + 1,
        paramRunes,
      );
      if (result != null) return result;
    }

    // Priority 3: Wildcard match
    if (node.wildcardChild != null && node.wildcardChild!.value != null) {
      final remaining = segments.sublist(index).join('/');
      return RouteMatch(
        value: node.wildcardChild!.value as T,
        runes: Map.unmodifiable(runes),
        pattern: node.wildcardChild!.pattern!,
        remaining: remaining,
      );
    }

    return null;
  }

  /// Split a path into segments, ignoring empty segments.
  static List<String> _splitPath(String path) {
    return path
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }
}
