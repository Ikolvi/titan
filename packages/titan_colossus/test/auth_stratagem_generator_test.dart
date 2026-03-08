import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  const generator = AuthStratagemGenerator();

  // -----------------------------------------------------------------------
  // isLoginButton
  // -----------------------------------------------------------------------

  group('AuthStratagemGenerator.isLoginButton', () {
    test('recognizes "Sign In"', () {
      expect(generator.isLoginButton('Sign In'), isTrue);
    });

    test('recognizes "Log In"', () {
      expect(generator.isLoginButton('Log In'), isTrue);
    });

    test('recognizes "Login"', () {
      expect(generator.isLoginButton('Login'), isTrue);
    });

    test('recognizes "Enter"', () {
      expect(generator.isLoginButton('Enter'), isTrue);
    });

    test('recognizes "Submit"', () {
      expect(generator.isLoginButton('Submit'), isTrue);
    });

    test('recognizes "Continue"', () {
      expect(generator.isLoginButton('Continue'), isTrue);
    });

    test('recognizes "Get Started"', () {
      expect(generator.isLoginButton('Get Started'), isTrue);
    });

    test('is case-insensitive', () {
      expect(generator.isLoginButton('SIGN IN'), isTrue);
      expect(generator.isLoginButton('log in'), isTrue);
      expect(generator.isLoginButton('LOGIN'), isTrue);
      expect(generator.isLoginButton('sUbMiT'), isTrue);
    });

    test('matches partial labels', () {
      expect(generator.isLoginButton('Enter the Questboard'), isTrue);
      expect(generator.isLoginButton('Continue to Dashboard'), isTrue);
      expect(generator.isLoginButton('Get Started Now'), isTrue);
    });

    test('rejects non-login labels', () {
      expect(generator.isLoginButton('Cancel'), isFalse);
      expect(generator.isLoginButton('Back'), isFalse);
      expect(generator.isLoginButton('Settings'), isFalse);
      expect(generator.isLoginButton('View Profile'), isFalse);
      expect(generator.isLoginButton('Delete Account'), isFalse);
    });

    test('rejects labels where indicator is embedded in a word', () {
      expect(generator.isLoginButton('Enterprise'), isFalse);
      expect(generator.isLoginButton('Entrepreneurship'), isFalse);
      expect(generator.isLoginButton('Reenter'), isFalse);
      expect(generator.isLoginButton('Discontinue'), isFalse);
      expect(generator.isLoginButton('Subcontinent'), isFalse);
    });

    test('accepts labels where indicator is at word boundary', () {
      expect(generator.isLoginButton('Enter'), isTrue);
      expect(generator.isLoginButton('Enter the App'), isTrue);
      expect(generator.isLoginButton('Please Continue'), isTrue);
      expect(generator.isLoginButton('Submit Form'), isTrue);
      expect(generator.isLoginButton('Log In Here'), isTrue);
    });
  });

  // -----------------------------------------------------------------------
  // loginButtonIndicators
  // -----------------------------------------------------------------------

  group('AuthStratagemGenerator.loginButtonIndicators', () {
    test('contains expected indicators', () {
      expect(
        AuthStratagemGenerator.loginButtonIndicators,
        containsAll([
          'sign in',
          'log in',
          'login',
          'enter',
          'submit',
          'continue',
          'get started',
        ]),
      );
    });

    test('has 7 indicators', () {
      expect(AuthStratagemGenerator.loginButtonIndicators, hasLength(7));
    });
  });

  // -----------------------------------------------------------------------
  // generate — empty / no auth screen
  // -----------------------------------------------------------------------

  group('AuthStratagemGenerator.generate — no auth screen', () {
    test('returns noAuthScreen for empty glyphs', () {
      final result = generator.generate([]);

      expect(result.isAuthScreen, isFalse);
      expect(result.textFields, isEmpty);
      expect(result.loginButtons, isEmpty);
      expect(result.authStratagem, isNull);
    });

    test('returns noAuthScreen when no interactive elements', () {
      final result = generator.generate([
        {'wt': 'Text', 'l': 'Hello', 'x': 0, 'y': 0, 'w': 100, 'h': 20},
        {'wt': 'Container', 'l': 'Box', 'x': 0, 'y': 50, 'w': 100, 'h': 100},
      ]);

      expect(result.isAuthScreen, isFalse);
      expect(result.authStratagem, isNull);
    });

    test('returns noAuthScreen for interactive non-auth elements', () {
      final result = generator.generate([
        // Interactive button but not a login button
        {
          'wt': 'ElevatedButton',
          'l': 'View Profile',
          'ia': true,
          'it': 'tap',
          'x': 0,
          'y': 0,
          'w': 100,
          'h': 40,
        },
        // Interactive but not text input
        {
          'wt': 'GestureDetector',
          'l': 'Settings',
          'ia': true,
          'it': 'tap',
          'x': 0,
          'y': 50,
          'w': 100,
          'h': 40,
        },
      ]);

      expect(result.isAuthScreen, isFalse);
    });
  });

  // -----------------------------------------------------------------------
  // generate — text field detection
  // -----------------------------------------------------------------------

  group('AuthStratagemGenerator.generate — text fields', () {
    test('detects textInput interaction type', () {
      final result = generator.generate([
        {
          'wt': 'TextField',
          'l': 'Hero Name',
          'ia': true,
          'it': 'textInput',
          'x': 20,
          'y': 100,
          'w': 300,
          'h': 48,
        },
      ]);

      expect(result.isAuthScreen, isTrue);
      expect(result.textFields, hasLength(1));
      expect(result.textFields[0]['l'], 'Hero Name');
    });

    test('detects TextField widget type even without textInput', () {
      final result = generator.generate([
        {
          'wt': 'TextField',
          'l': 'Username',
          'ia': true,
          'x': 20,
          'y': 100,
          'w': 300,
          'h': 48,
        },
      ]);

      expect(result.isAuthScreen, isTrue);
      expect(result.textFields, hasLength(1));
      expect(result.textFields[0]['l'], 'Username');
    });

    test('detects TextFormField widget type', () {
      final result = generator.generate([
        {
          'wt': 'TextFormField',
          'l': 'Email',
          'ia': true,
          'x': 20,
          'y': 100,
          'w': 300,
          'h': 48,
        },
      ]);

      expect(result.isAuthScreen, isTrue);
      expect(result.textFields, hasLength(1));
      expect(result.textFields[0]['l'], 'Email');
    });

    test('ignores non-interactive text fields', () {
      final result = generator.generate([
        {
          'wt': 'TextField',
          'l': 'Disabled Field',
          'ia': false, // Not interactive
          'it': 'textInput',
          'x': 20,
          'y': 100,
          'w': 300,
          'h': 48,
        },
      ]);

      expect(result.isAuthScreen, isFalse);
      expect(result.textFields, isEmpty);
    });

    test('ignores text fields with empty labels', () {
      final result = generator.generate([
        {
          'wt': 'TextField',
          'l': '', // Empty label
          'ia': true,
          'it': 'textInput',
          'x': 20,
          'y': 100,
          'w': 300,
          'h': 48,
        },
      ]);

      expect(result.isAuthScreen, isFalse);
      expect(result.textFields, isEmpty);
    });

    test('deduplicates text fields by label', () {
      final result = generator.generate([
        {
          'wt': 'TextField',
          'l': 'Hero Name',
          'ia': true,
          'it': 'textInput',
          'x': 20,
          'y': 100,
          'w': 300,
          'h': 48,
        },
        {
          'wt': 'TextFormField',
          'l': 'Hero Name', // Duplicate label
          'ia': true,
          'it': 'textInput',
          'x': 20,
          'y': 200,
          'w': 300,
          'h': 48,
        },
      ]);

      expect(result.textFields, hasLength(1));
    });

    test('detects multiple distinct text fields', () {
      final result = generator.generate([
        {
          'wt': 'TextField',
          'l': 'Username',
          'ia': true,
          'it': 'textInput',
          'x': 20,
          'y': 100,
          'w': 300,
          'h': 48,
        },
        {
          'wt': 'TextField',
          'l': 'Password',
          'ia': true,
          'it': 'textInput',
          'x': 20,
          'y': 200,
          'w': 300,
          'h': 48,
        },
      ]);

      expect(result.textFields, hasLength(2));
      expect(result.textFields[0]['l'], 'Username');
      expect(result.textFields[1]['l'], 'Password');
    });
  });

  // -----------------------------------------------------------------------
  // generate — login button detection
  // -----------------------------------------------------------------------

  group('AuthStratagemGenerator.generate — login buttons', () {
    test('detects button by tap interaction type', () {
      final result = generator.generate([
        {
          'wt': 'ElevatedButton',
          'l': 'Sign In',
          'ia': true,
          'it': 'tap',
          'x': 50,
          'y': 300,
          'w': 200,
          'h': 48,
        },
      ]);

      expect(result.isAuthScreen, isTrue);
      expect(result.loginButtons, hasLength(1));
      expect(result.loginButtons[0]['l'], 'Sign In');
    });

    test('detects button by semantic role', () {
      final result = generator.generate([
        {
          'wt': 'GestureDetector',
          'l': 'Login',
          'ia': true,
          'sr': 'button',
          'x': 50,
          'y': 300,
          'w': 200,
          'h': 48,
        },
      ]);

      expect(result.isAuthScreen, isTrue);
      expect(result.loginButtons, hasLength(1));
    });

    test('detects button with "Enter" in label', () {
      final result = generator.generate([
        {
          'wt': 'ElevatedButton',
          'l': 'Enter the Questboard',
          'ia': true,
          'it': 'tap',
          'x': 50,
          'y': 300,
          'w': 200,
          'h': 48,
        },
      ]);

      expect(result.loginButtons, hasLength(1));
      expect(result.loginButtons[0]['l'], 'Enter the Questboard');
    });

    test('ignores non-interactive buttons', () {
      final result = generator.generate([
        {
          'wt': 'ElevatedButton',
          'l': 'Sign In',
          'ia': false, // Not interactive
          'it': 'tap',
          'x': 50,
          'y': 300,
          'w': 200,
          'h': 48,
        },
      ]);

      expect(result.isAuthScreen, isFalse);
      expect(result.loginButtons, isEmpty);
    });

    test('ignores buttons without login-related labels', () {
      final result = generator.generate([
        {
          'wt': 'ElevatedButton',
          'l': 'About Us',
          'ia': true,
          'it': 'tap',
          'x': 50,
          'y': 300,
          'w': 200,
          'h': 48,
        },
      ]);

      expect(result.isAuthScreen, isFalse);
      expect(result.loginButtons, isEmpty);
    });

    test('deduplicates login buttons by label', () {
      final result = generator.generate([
        {
          'wt': 'ElevatedButton',
          'l': 'Sign In',
          'ia': true,
          'it': 'tap',
          'x': 50,
          'y': 300,
          'w': 200,
          'h': 48,
        },
        {
          'wt': 'GestureDetector',
          'l': 'Sign In', // Duplicate label
          'ia': true,
          'it': 'tap',
          'x': 50,
          'y': 350,
          'w': 200,
          'h': 48,
        },
      ]);

      expect(result.loginButtons, hasLength(1));
    });
  });

  // -----------------------------------------------------------------------
  // generate — complete authStratagem output
  // -----------------------------------------------------------------------

  group('AuthStratagemGenerator.generate — stratagem output', () {
    test('generates valid authStratagem with text field + button', () {
      final result = generator.generate([
        {
          'wt': 'TextField',
          'l': 'Hero Name',
          'ia': true,
          'it': 'textInput',
          'x': 20,
          'y': 100,
          'w': 300,
          'h': 48,
        },
        {
          'wt': 'ElevatedButton',
          'l': 'Enter the Questboard',
          'ia': true,
          'it': 'tap',
          'x': 50,
          'y': 300,
          'w': 200,
          'h': 48,
        },
      ]);

      expect(result.isAuthScreen, isTrue);
      expect(result.authStratagem, isNotNull);

      final stratagem = result.authStratagem!;
      expect(stratagem['name'], '_auth');
      expect(
        stratagem['description'],
        'Auto-login — generated from live screen',
      );
      expect(stratagem['startRoute'], '');

      final steps = stratagem['steps'] as List<Map<String, dynamic>>;
      expect(steps, hasLength(2));

      // First step: enterText
      expect(steps[0]['id'], 1);
      expect(steps[0]['action'], 'enterText');
      expect(steps[0]['target'], {'label': 'Hero Name'});
      expect(steps[0]['value'], '<fill_in_value>');

      // Second step: tap
      expect(steps[1]['id'], 2);
      expect(steps[1]['action'], 'tap');
      expect(steps[1]['target'], {'label': 'Enter the Questboard'});
    });

    test('uses custom defaultValue for text fields', () {
      final result = generator.generate([
        {
          'wt': 'TextField',
          'l': 'Hero Name',
          'ia': true,
          'it': 'textInput',
          'x': 20,
          'y': 100,
          'w': 300,
          'h': 48,
        },
        {
          'wt': 'ElevatedButton',
          'l': 'Enter the Questboard',
          'ia': true,
          'it': 'tap',
          'x': 50,
          'y': 300,
          'w': 200,
          'h': 48,
        },
      ], defaultValue: 'Kael');

      final steps =
          result.authStratagem!['steps'] as List<Map<String, dynamic>>;
      expect(steps[0]['value'], 'Kael');
    });

    test('orders text fields before buttons', () {
      // Put button first in the glyph list
      final result = generator.generate([
        {
          'wt': 'ElevatedButton',
          'l': 'Submit',
          'ia': true,
          'it': 'tap',
          'x': 50,
          'y': 300,
          'w': 200,
          'h': 48,
        },
        {
          'wt': 'TextField',
          'l': 'Email',
          'ia': true,
          'it': 'textInput',
          'x': 20,
          'y': 100,
          'w': 300,
          'h': 48,
        },
      ]);

      final steps =
          result.authStratagem!['steps'] as List<Map<String, dynamic>>;
      // Text field step first, button step second
      expect(steps[0]['action'], 'enterText');
      expect(steps[0]['target'], {'label': 'Email'});
      expect(steps[1]['action'], 'tap');
      expect(steps[1]['target'], {'label': 'Submit'});
    });

    test('step IDs are sequential', () {
      final result = generator.generate([
        {
          'wt': 'TextField',
          'l': 'Username',
          'ia': true,
          'it': 'textInput',
          'x': 20,
          'y': 100,
          'w': 300,
          'h': 48,
        },
        {
          'wt': 'TextField',
          'l': 'Password',
          'ia': true,
          'it': 'textInput',
          'x': 20,
          'y': 200,
          'w': 300,
          'h': 48,
        },
        {
          'wt': 'ElevatedButton',
          'l': 'Sign In',
          'ia': true,
          'it': 'tap',
          'x': 50,
          'y': 300,
          'w': 200,
          'h': 48,
        },
      ]);

      final steps =
          result.authStratagem!['steps'] as List<Map<String, dynamic>>;
      expect(steps, hasLength(3));
      expect(steps[0]['id'], 1);
      expect(steps[1]['id'], 2);
      expect(steps[2]['id'], 3);
    });

    test('generates auth-only from text field without buttons', () {
      final result = generator.generate([
        {
          'wt': 'TextField',
          'l': 'API Key',
          'ia': true,
          'it': 'textInput',
          'x': 20,
          'y': 100,
          'w': 300,
          'h': 48,
        },
      ]);

      expect(result.isAuthScreen, isTrue);
      expect(result.textFields, hasLength(1));
      expect(result.loginButtons, isEmpty);

      final steps =
          result.authStratagem!['steps'] as List<Map<String, dynamic>>;
      expect(steps, hasLength(1));
      expect(steps[0]['action'], 'enterText');
    });

    test('generates auth-only from login button without text fields', () {
      final result = generator.generate([
        {
          'wt': 'ElevatedButton',
          'l': 'Continue',
          'ia': true,
          'it': 'tap',
          'x': 50,
          'y': 300,
          'w': 200,
          'h': 48,
        },
      ]);

      expect(result.isAuthScreen, isTrue);
      expect(result.textFields, isEmpty);
      expect(result.loginButtons, hasLength(1));

      final steps =
          result.authStratagem!['steps'] as List<Map<String, dynamic>>;
      expect(steps, hasLength(1));
      expect(steps[0]['action'], 'tap');
    });
  });

  // -----------------------------------------------------------------------
  // generate — realistic login screens
  // -----------------------------------------------------------------------

  group('AuthStratagemGenerator.generate — realistic screens', () {
    test('Questboard login screen', () {
      final result = generator.generate([
        // Non-interactive text (title)
        {
          'wt': 'Text',
          'l': 'Welcome to the Questboard',
          'x': 50,
          'y': 50,
          'w': 300,
          'h': 30,
        },
        // Hero name text field
        {
          'wt': 'TextField',
          'l': 'Hero Name',
          'ia': true,
          'it': 'textInput',
          'x': 50,
          'y': 150,
          'w': 300,
          'h': 48,
        },
        // Enter button
        {
          'wt': 'ElevatedButton',
          'l': 'Enter the Questboard',
          'ia': true,
          'it': 'tap',
          'sr': 'button',
          'x': 100,
          'y': 250,
          'w': 200,
          'h': 48,
        },
      ], defaultValue: 'Kael');

      expect(result.isAuthScreen, isTrue);
      expect(result.textFields, hasLength(1));
      expect(result.loginButtons, hasLength(1));

      final stratagem = result.authStratagem!;
      final steps = stratagem['steps'] as List<Map<String, dynamic>>;
      expect(steps[0]['action'], 'enterText');
      expect(steps[0]['value'], 'Kael');
      expect(steps[0]['target'], {'label': 'Hero Name'});
      expect(steps[1]['action'], 'tap');
      expect(steps[1]['target'], {'label': 'Enter the Questboard'});
    });

    test('email + password login form', () {
      final result = generator.generate([
        {
          'wt': 'TextFormField',
          'l': 'Email',
          'ia': true,
          'it': 'textInput',
          'x': 50,
          'y': 100,
          'w': 300,
          'h': 48,
        },
        {
          'wt': 'TextFormField',
          'l': 'Password',
          'ia': true,
          'it': 'textInput',
          'x': 50,
          'y': 200,
          'w': 300,
          'h': 48,
        },
        {
          'wt': 'ElevatedButton',
          'l': 'Sign In',
          'ia': true,
          'it': 'tap',
          'x': 100,
          'y': 300,
          'w': 200,
          'h': 48,
        },
        // "Forgot password?" link — should be ignored
        {
          'wt': 'InkWell',
          'l': 'Forgot Password?',
          'ia': true,
          'it': 'tap',
          'x': 120,
          'y': 360,
          'w': 160,
          'h': 20,
        },
      ], defaultValue: 'test@example.com');

      expect(result.textFields, hasLength(2));
      expect(result.loginButtons, hasLength(1));
      expect(result.loginButtons[0]['l'], 'Sign In');

      final steps =
          result.authStratagem!['steps'] as List<Map<String, dynamic>>;
      expect(steps, hasLength(3));
      expect(steps[0]['target'], {'label': 'Email'});
      expect(steps[1]['target'], {'label': 'Password'});
      expect(steps[2]['target'], {'label': 'Sign In'});
    });

    test('mixed interactive and non-interactive elements', () {
      final result = generator.generate([
        // App bar title
        {'wt': 'Text', 'l': 'Login', 'x': 100, 'y': 10, 'w': 100, 'h': 24},
        // Back button (not a login button)
        {
          'wt': 'IconButton',
          'l': 'Back',
          'ia': true,
          'it': 'tap',
          'x': 10,
          'y': 10,
          'w': 48,
          'h': 48,
        },
        // Username field
        {
          'wt': 'TextField',
          'l': 'Username',
          'ia': true,
          'it': 'textInput',
          'x': 30,
          'y': 100,
          'w': 300,
          'h': 48,
        },
        // Login button
        {
          'wt': 'FilledButton',
          'l': 'Log In',
          'ia': true,
          'it': 'tap',
          'sr': 'button',
          'x': 100,
          'y': 200,
          'w': 200,
          'h': 48,
        },
        // Help text
        {
          'wt': 'Text',
          'l': 'Need help? Contact support',
          'x': 50,
          'y': 300,
          'w': 250,
          'h': 20,
        },
      ]);

      expect(result.textFields, hasLength(1));
      expect(result.textFields[0]['l'], 'Username');
      expect(result.loginButtons, hasLength(1));
      expect(result.loginButtons[0]['l'], 'Log In');
    });
  });

  // -----------------------------------------------------------------------
  // AuthStratagemResult
  // -----------------------------------------------------------------------

  group('AuthStratagemResult', () {
    test('noAuthScreen has expected defaults', () {
      final result = AuthStratagemResult.noAuthScreen();

      expect(result.isAuthScreen, isFalse);
      expect(result.textFields, isEmpty);
      expect(result.loginButtons, isEmpty);
      expect(result.authStratagem, isNull);
    });

    test('constructor sets isAuthScreen to true', () {
      final result = AuthStratagemResult(
        textFields: [
          {'l': 'Name', 'wt': 'TextField'},
        ],
        loginButtons: [],
        authStratagem: {'name': '_auth', 'steps': []},
      );

      expect(result.isAuthScreen, isTrue);
    });
  });

  // -----------------------------------------------------------------------
  // generate — edge cases
  // -----------------------------------------------------------------------

  group('AuthStratagemGenerator.generate — edge cases', () {
    test('handles glyphs with missing optional fields', () {
      final result = generator.generate([
        {
          'wt': 'TextField',
          'l': 'Name',
          'ia': true,
          // No 'it' key
        },
      ]);

      // TextField widget type triggers detection even without 'it'
      expect(result.isAuthScreen, isTrue);
      expect(result.textFields, hasLength(1));
    });

    test('handles glyphs with null label field', () {
      final result = generator.generate([
        {
          'wt': 'TextField',
          // No 'l' key — label defaults to ''
          'ia': true,
          'it': 'textInput',
        },
      ]);

      // Empty label means it won't be detected
      expect(result.isAuthScreen, isFalse);
    });

    test('handles glyph without ia field (defaults to non-interactive)', () {
      final result = generator.generate([
        {
          'wt': 'TextField',
          'l': 'Name',
          // No 'ia' key — defaults to false
          'it': 'textInput',
        },
      ]);

      expect(result.isAuthScreen, isFalse);
    });

    test('defaultValue defaults to <fill_in_value>', () {
      final result = generator.generate([
        {'wt': 'TextField', 'l': 'Name', 'ia': true, 'it': 'textInput'},
      ]);

      final steps =
          result.authStratagem!['steps'] as List<Map<String, dynamic>>;
      expect(steps[0]['value'], '<fill_in_value>');
    });

    test('description fields are populated', () {
      final result = generator.generate([
        {'wt': 'TextField', 'l': 'Hero Name', 'ia': true, 'it': 'textInput'},
        {'wt': 'ElevatedButton', 'l': 'Submit', 'ia': true, 'it': 'tap'},
      ]);

      final steps =
          result.authStratagem!['steps'] as List<Map<String, dynamic>>;
      expect(steps[0]['description'], 'Enter value in "Hero Name" field');
      expect(steps[1]['description'], 'Tap "Submit" button');
    });
  });
}
