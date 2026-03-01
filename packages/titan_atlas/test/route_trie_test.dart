import 'package:flutter_test/flutter_test.dart';
import 'package:titan_atlas/src/core/route_trie.dart';

void main() {
  group('RouteTrie', () {
    late RouteTrie<String> trie;

    setUp(() {
      trie = RouteTrie<String>();
    });

    test('matches static routes', () {
      trie.insert('/home', 'home');
      trie.insert('/about', 'about');
      trie.insert('/settings/profile', 'settings-profile');

      expect(trie.match('/home')?.value, 'home');
      expect(trie.match('/about')?.value, 'about');
      expect(trie.match('/settings/profile')?.value, 'settings-profile');
    });

    test('returns null for unregistered routes', () {
      trie.insert('/home', 'home');
      expect(trie.match('/unknown'), isNull);
      expect(trie.match('/home/extra'), isNull);
    });

    test('matches dynamic parameters (Runes)', () {
      trie.insert('/user/:id', 'user');
      trie.insert('/post/:slug/comments', 'post-comments');

      final userMatch = trie.match('/user/42');
      expect(userMatch?.value, 'user');
      expect(userMatch?.runes, {'id': '42'});

      final postMatch = trie.match('/post/hello-world/comments');
      expect(postMatch?.value, 'post-comments');
      expect(postMatch?.runes, {'slug': 'hello-world'});
    });

    test('matches multiple dynamic parameters', () {
      trie.insert('/org/:orgId/team/:teamId', 'team');

      final match = trie.match('/org/acme/team/dev');
      expect(match?.value, 'team');
      expect(match?.runes, {'orgId': 'acme', 'teamId': 'dev'});
    });

    test('matches wildcard routes', () {
      trie.insert('/files/*', 'files');

      final match = trie.match('/files/docs/readme.md');
      expect(match?.value, 'files');
      expect(match?.remaining, 'docs/readme.md');
    });

    test('prioritizes static over dynamic', () {
      trie.insert('/user/me', 'user-me');
      trie.insert('/user/:id', 'user-dynamic');

      expect(trie.match('/user/me')?.value, 'user-me');
      expect(trie.match('/user/42')?.value, 'user-dynamic');
    });

    test('prioritizes dynamic over wildcard', () {
      trie.insert('/api/:version', 'api-version');
      trie.insert('/api/*', 'api-wildcard');

      expect(trie.match('/api/v2')?.value, 'api-version');
      expect(trie.match('/api/v2/users')?.value, 'api-wildcard');
    });

    test('handles root path', () {
      trie.insert('/', 'root');
      expect(trie.match('/')?.value, 'root');
    });

    test('handles trailing slashes', () {
      trie.insert('/home', 'home');
      expect(trie.match('/home/')?.value, 'home');
    });

    test('reports correct length', () {
      expect(trie.length, 0);
      trie.insert('/a', 'a');
      trie.insert('/b', 'b');
      expect(trie.length, 2);
    });

    test('returns correct pattern in match', () {
      trie.insert('/user/:id', 'user');
      final match = trie.match('/user/42');
      expect(match?.pattern, '/user/:id');
    });
  });
}
