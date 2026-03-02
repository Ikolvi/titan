import 'package:flutter_test/flutter_test.dart';
import 'package:titan_atlas/titan_atlas.dart';

void main() {
  group('Cartograph', () {
    setUp(() {
      Cartograph.reset();
    });

    tearDown(() {
      Cartograph.reset();
    });

    group('Named Routes', () {
      test('register a named route', () {
        Cartograph.name('home', '/');
        expect(Cartograph.hasName('home'), isTrue);
        expect(Cartograph.pathFor('home'), '/');
      });

      test('register multiple named routes', () {
        Cartograph.nameAll({
          'home': '/',
          'profile': '/users/:id',
          'settings': '/settings',
        });

        expect(Cartograph.hasName('home'), isTrue);
        expect(Cartograph.hasName('profile'), isTrue);
        expect(Cartograph.hasName('settings'), isTrue);
        expect(
          Cartograph.routeNames,
          containsAll(['home', 'profile', 'settings']),
        );
      });

      test('pathFor returns null for unregistered name', () {
        expect(Cartograph.pathFor('unknown'), isNull);
      });

      test('hasName returns false for unregistered name', () {
        expect(Cartograph.hasName('unknown'), isFalse);
      });
    });

    group('URL Building', () {
      test('build simple URL', () {
        Cartograph.name('settings', '/settings');
        final url = Cartograph.build('settings');
        expect(url, '/settings');
      });

      test('build URL with runes', () {
        Cartograph.name('profile', '/users/:id');
        final url = Cartograph.build('profile', runes: {'id': '42'});
        expect(url, '/users/42');
      });

      test('build URL with multiple runes', () {
        Cartograph.name('post', '/users/:userId/posts/:postId');
        final url = Cartograph.build(
          'post',
          runes: {'userId': '42', 'postId': '7'},
        );
        expect(url, '/users/42/posts/7');
      });

      test('build URL with query parameters', () {
        Cartograph.name('search', '/search');
        final url = Cartograph.build(
          'search',
          query: {'q': 'flutter', 'page': '2'},
        );
        expect(url, contains('/search?'));
        expect(url, contains('q=flutter'));
        expect(url, contains('page=2'));
      });

      test('build URL with runes and query', () {
        Cartograph.name('profile', '/users/:id');
        final url = Cartograph.build(
          'profile',
          runes: {'id': '42'},
          query: {'tab': 'posts'},
        );
        expect(url, '/users/42?tab=posts');
      });

      test('build throws for unregistered route', () {
        expect(() => Cartograph.build('unknown'), throwsA(isA<StateError>()));
      });

      test('build throws for missing rune', () {
        Cartograph.name('profile', '/users/:id');
        expect(
          () => Cartograph.build('profile'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('buildFromTemplate works without registration', () {
        final url = Cartograph.buildFromTemplate(
          '/users/:id',
          runes: {'id': '42'},
        );
        expect(url, '/users/42');
      });
    });

    group('Deep Link Parsing', () {
      test('parse matches named route', () {
        Cartograph.name('profile', '/users/:id');

        final match = Cartograph.parse(Uri.parse('/users/42'));
        expect(match, isNotNull);
        expect(match!.path, '/users/:id');
        expect(match.runes, {'id': '42'});
      });

      test('parse captures query parameters', () {
        Cartograph.name('profile', '/users/:id');

        final match = Cartograph.parse(Uri.parse('/users/42?tab=posts'));
        expect(match, isNotNull);
        expect(match!.runes, {'id': '42'});
        expect(match.query, {'tab': 'posts'});
      });

      test('parse returns null for no match', () {
        Cartograph.name('home', '/');

        final match = Cartograph.parse(Uri.parse('/unknown/path'));
        expect(match, isNull);
      });

      test('parse matches deep link patterns', () {
        Cartograph.link('/items/:category/:id');

        final match = Cartograph.parse(Uri.parse('/items/books/123'));
        expect(match, isNotNull);
        expect(match!.path, '/items/:category/:id');
        expect(match.runes, {'category': 'books', 'id': '123'});
      });

      test('parse matches exact paths', () {
        Cartograph.name('about', '/about');

        final match = Cartograph.parse(Uri.parse('/about'));
        expect(match, isNotNull);
        expect(match!.path, '/about');
        expect(match.runes, isEmpty);
      });

      test('parse does not match wrong segment count', () {
        Cartograph.name('profile', '/users/:id');

        final match = Cartograph.parse(Uri.parse('/users/42/posts'));
        expect(match, isNull);
      });
    });

    group('Deep Link Handling', () {
      test('handleDeepLink invokes registered handler', () {
        String? capturedId;
        Cartograph.link('/users/:id', (match) {
          capturedId = match.runes['id'];
        });

        final handled = Cartograph.handleDeepLink(Uri.parse('/users/42'));
        expect(handled, isTrue);
        expect(capturedId, '42');
      });

      test('handleDeepLink returns false for no match', () {
        final handled = Cartograph.handleDeepLink(Uri.parse('/unknown'));
        expect(handled, isFalse);
      });

      test('handleDeepLink returns false for pattern without handler', () {
        Cartograph.link('/users/:id'); // No handler

        final handled = Cartograph.handleDeepLink(Uri.parse('/users/42'));
        expect(handled, isFalse);
      });
    });

    group('Reset', () {
      test('reset clears all routes and links', () {
        Cartograph.name('test', '/test');
        Cartograph.link('/deep/:id');

        Cartograph.reset();

        expect(Cartograph.hasName('test'), isFalse);
        expect(Cartograph.routeNames, isEmpty);
        expect(Cartograph.parse(Uri.parse('/deep/1')), isNull);
      });
    });

    group('CartographMatch', () {
      test('toString contains useful info', () {
        final match = CartographMatch(
          path: '/users/:id',
          runes: {'id': '42'},
          query: {'tab': 'posts'},
        );

        final str = match.toString();
        expect(str, contains('/users/:id'));
        expect(str, contains('runes'));
      });
    });
  });
}
