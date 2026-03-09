@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/src/mcp/mcp_ws_client.dart';

/// Integration tests for API key rotation and multi-token support.
///
/// Tests that:
/// - Multiple `--auth-token` values are accepted concurrently
/// - `--auth-tokens-file` loads tokens from a file
/// - Modifying the tokens file hot-reloads without restart
/// - Removed tokens are immediately rejected
/// - New tokens are immediately accepted after file update
void main() {
  group('Multi-token auth', () {
    const port = 18648;
    const token1 = 'alpha-key-001';
    const token2 = 'beta-key-002';

    late Process serverProcess;
    late HttpClient httpClient;

    setUpAll(() async {
      serverProcess = await Process.start('dart', [
        'run',
        'titan_colossus:blueprint_mcp_server',
        '--transport',
        'auto',
        '--port',
        '$port',
        '--auth-token',
        token1,
        '--auth-token',
        token2,
      ], workingDirectory: Directory.current.path);

      httpClient = HttpClient();

      var ready = false;
      for (var i = 0; i < 30; i++) {
        try {
          final req = await httpClient.getUrl(
            Uri.parse('http://127.0.0.1:$port/health'),
          );
          final res = await req.close();
          if (res.statusCode == 200) {
            await res.drain<void>();
            ready = true;
            break;
          }
          await res.drain<void>();
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }

      if (!ready) {
        throw StateError('MCP multi-token server failed to start on $port');
      }
    });

    tearDownAll(() {
      serverProcess.kill();
      httpClient.close(force: true);
    });

    test('first token is accepted', () async {
      final req = await httpClient.postUrl(
        Uri.parse('http://127.0.0.1:$port/mcp'),
      );
      req.headers
        ..set('Content-Type', 'application/json')
        ..set('Authorization', 'Bearer $token1');
      req.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'initialize',
          'params': {
            'protocolVersion': '2025-03-26',
            'capabilities': <String, dynamic>{},
            'clientInfo': {'name': 'test', 'version': '1.0.0'},
          },
        }),
      );
      final res = await req.close();
      expect(res.statusCode, 200);
      await res.drain<void>();
    });

    test('second token is accepted', () async {
      final req = await httpClient.postUrl(
        Uri.parse('http://127.0.0.1:$port/mcp'),
      );
      req.headers
        ..set('Content-Type', 'application/json')
        ..set('Authorization', 'Bearer $token2');
      req.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'initialize',
          'params': {
            'protocolVersion': '2025-03-26',
            'capabilities': <String, dynamic>{},
            'clientInfo': {'name': 'test', 'version': '1.0.0'},
          },
        }),
      );
      final res = await req.close();
      expect(res.statusCode, 200);
      await res.drain<void>();
    });

    test('unknown token is rejected', () async {
      final req = await httpClient.postUrl(
        Uri.parse('http://127.0.0.1:$port/mcp'),
      );
      req.headers
        ..set('Content-Type', 'application/json')
        ..set('Authorization', 'Bearer wrong-token');
      req.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'initialize',
          'params': {
            'protocolVersion': '2025-03-26',
            'capabilities': <String, dynamic>{},
            'clientInfo': {'name': 'test', 'version': '1.0.0'},
          },
        }),
      );
      final res = await req.close();
      expect(res.statusCode, 401);
      await res.drain<void>();
    });

    test('WebSocket accepts either token via query param', () async {
      // Token 1 via query param
      var ws = await WebSocket.connect('ws://127.0.0.1:$port/ws?token=$token1');
      ws.add(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'initialize',
          'params': {
            'protocolVersion': '2025-03-26',
            'capabilities': <String, dynamic>{},
            'clientInfo': {'name': 'test', 'version': '1.0.0'},
          },
        }),
      );
      final msg1 = await ws.first;
      final data1 = jsonDecode(msg1 as String) as Map<String, dynamic>;
      expect(data1['result'], isNotNull);
      await ws.close();

      // Token 2 via query param
      ws = await WebSocket.connect('ws://127.0.0.1:$port/ws?token=$token2');
      ws.add(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 2,
          'method': 'initialize',
          'params': {
            'protocolVersion': '2025-03-26',
            'capabilities': <String, dynamic>{},
            'clientInfo': {'name': 'test', 'version': '1.0.0'},
          },
        }),
      );
      final msg2 = await ws.first;
      final data2 = jsonDecode(msg2 as String) as Map<String, dynamic>;
      expect(data2['result'], isNotNull);
      await ws.close();
    });

    test('McpWebSocketClient works with either token', () async {
      final client1 = McpWebSocketClient(
        Uri.parse('ws://127.0.0.1:$port/ws'),
        authToken: token1,
      );
      await client1.connect();
      final result1 = await client1.request(
        'initialize',
        params: {
          'protocolVersion': '2025-03-26',
          'capabilities': <String, dynamic>{},
          'clientInfo': {'name': 'test', 'version': '1.0.0'},
        },
      );
      expect(result1, isNotNull);
      await client1.close();

      final client2 = McpWebSocketClient(
        Uri.parse('ws://127.0.0.1:$port/ws'),
        authToken: token2,
      );
      await client2.connect();
      final result2 = await client2.request(
        'initialize',
        params: {
          'protocolVersion': '2025-03-26',
          'capabilities': <String, dynamic>{},
          'clientInfo': {'name': 'test', 'version': '1.0.0'},
        },
      );
      expect(result2, isNotNull);
      await client2.close();
    });
  });

  group('Token file hot-reload', () {
    const port = 18649;

    late Directory tempDir;
    late File tokensFile;
    late Process serverProcess;
    late HttpClient httpClient;

    setUpAll(() async {
      // Create a temporary directory with a tokens file
      tempDir = await Directory.systemTemp.createTemp('titan_auth_');
      tokensFile = File('${tempDir.path}/tokens.txt');

      // Write initial tokens
      tokensFile.writeAsStringSync('initial-token-aaa\ninitial-token-bbb\n');

      serverProcess = await Process.start('dart', [
        'run',
        'titan_colossus:blueprint_mcp_server',
        '--transport',
        'auto',
        '--port',
        '$port',
        '--auth-tokens-file',
        tokensFile.path,
      ], workingDirectory: Directory.current.path);

      httpClient = HttpClient();

      var ready = false;
      for (var i = 0; i < 30; i++) {
        try {
          final req = await httpClient.getUrl(
            Uri.parse('http://127.0.0.1:$port/health'),
          );
          final res = await req.close();
          if (res.statusCode == 200) {
            await res.drain<void>();
            ready = true;
            break;
          }
          await res.drain<void>();
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }

      if (!ready) {
        throw StateError('MCP token-file server failed to start on $port');
      }
    });

    tearDownAll(() {
      serverProcess.kill();
      httpClient.close(force: true);
      tempDir.deleteSync(recursive: true);
    });

    test('initial tokens from file are accepted', () async {
      final req = await httpClient.postUrl(
        Uri.parse('http://127.0.0.1:$port/mcp'),
      );
      req.headers
        ..set('Content-Type', 'application/json')
        ..set('Authorization', 'Bearer initial-token-aaa');
      req.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'initialize',
          'params': {
            'protocolVersion': '2025-03-26',
            'capabilities': <String, dynamic>{},
            'clientInfo': {'name': 'test', 'version': '1.0.0'},
          },
        }),
      );
      final res = await req.close();
      expect(res.statusCode, 200);
      await res.drain<void>();
    });

    test('tokens file supports comments and blank lines', () async {
      // Re-write file with comments and blanks
      tokensFile.writeAsStringSync(
        '# Primary key\n'
        'initial-token-aaa\n'
        '\n'
        '# Secondary key\n'
        'initial-token-bbb\n',
      );

      // Give the file watcher time to detect the change
      await Future<void>.delayed(const Duration(seconds: 2));

      // Both should still work
      for (final token in ['initial-token-aaa', 'initial-token-bbb']) {
        final req = await httpClient.postUrl(
          Uri.parse('http://127.0.0.1:$port/mcp'),
        );
        req.headers
          ..set('Content-Type', 'application/json')
          ..set('Authorization', 'Bearer $token');
        req.write(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'initialize',
            'params': {
              'protocolVersion': '2025-03-26',
              'capabilities': <String, dynamic>{},
              'clientInfo': {'name': 'test', 'version': '1.0.0'},
            },
          }),
        );
        final res = await req.close();
        expect(res.statusCode, 200, reason: 'Token $token should be accepted');
        await res.drain<void>();
      }
    });

    test('hot-reload: new token is accepted after file update', () async {
      // Add a new token to the file
      tokensFile.writeAsStringSync(
        'initial-token-aaa\n'
        'initial-token-bbb\n'
        'rotated-token-ccc\n',
      );

      // Give the file watcher time to detect the change
      await Future<void>.delayed(const Duration(seconds: 2));

      final req = await httpClient.postUrl(
        Uri.parse('http://127.0.0.1:$port/mcp'),
      );
      req.headers
        ..set('Content-Type', 'application/json')
        ..set('Authorization', 'Bearer rotated-token-ccc');
      req.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'initialize',
          'params': {
            'protocolVersion': '2025-03-26',
            'capabilities': <String, dynamic>{},
            'clientInfo': {'name': 'test', 'version': '1.0.0'},
          },
        }),
      );
      final res = await req.close();
      expect(res.statusCode, 200);
      await res.drain<void>();
    });

    test('hot-reload: removed token is rejected after file update', () async {
      // Remove initial-token-aaa, keep only rotated-token-ccc
      tokensFile.writeAsStringSync('rotated-token-ccc\n');

      // Give the file watcher time to detect the change
      await Future<void>.delayed(const Duration(seconds: 2));

      // Old token should no longer work
      final req = await httpClient.postUrl(
        Uri.parse('http://127.0.0.1:$port/mcp'),
      );
      req.headers
        ..set('Content-Type', 'application/json')
        ..set('Authorization', 'Bearer initial-token-aaa');
      req.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'initialize',
          'params': {
            'protocolVersion': '2025-03-26',
            'capabilities': <String, dynamic>{},
            'clientInfo': {'name': 'test', 'version': '1.0.0'},
          },
        }),
      );
      final res = await req.close();
      expect(res.statusCode, 401);
      await res.drain<void>();

      // New token should still work
      final req2 = await httpClient.postUrl(
        Uri.parse('http://127.0.0.1:$port/mcp'),
      );
      req2.headers
        ..set('Content-Type', 'application/json')
        ..set('Authorization', 'Bearer rotated-token-ccc');
      req2.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'initialize',
          'params': {
            'protocolVersion': '2025-03-26',
            'capabilities': <String, dynamic>{},
            'clientInfo': {'name': 'test', 'version': '1.0.0'},
          },
        }),
      );
      final res2 = await req2.close();
      expect(res2.statusCode, 200);
      await res2.drain<void>();
    });

    test('hot-reload: complete key rotation (all new tokens)', () async {
      // Replace all tokens with a completely new set
      tokensFile.writeAsStringSync(
        '# Rotated on 2025-01-01\n'
        'new-era-token-ddd\n'
        'new-era-token-eee\n',
      );

      await Future<void>.delayed(const Duration(seconds: 2));

      // Old token rejected
      final req1 = await httpClient.postUrl(
        Uri.parse('http://127.0.0.1:$port/mcp'),
      );
      req1.headers
        ..set('Content-Type', 'application/json')
        ..set('Authorization', 'Bearer rotated-token-ccc');
      req1.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'initialize',
          'params': {
            'protocolVersion': '2025-03-26',
            'capabilities': <String, dynamic>{},
            'clientInfo': {'name': 'test', 'version': '1.0.0'},
          },
        }),
      );
      final res1 = await req1.close();
      expect(res1.statusCode, 401);
      await res1.drain<void>();

      // New tokens accepted
      for (final token in ['new-era-token-ddd', 'new-era-token-eee']) {
        final req = await httpClient.postUrl(
          Uri.parse('http://127.0.0.1:$port/mcp'),
        );
        req.headers
          ..set('Content-Type', 'application/json')
          ..set('Authorization', 'Bearer $token');
        req.write(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'initialize',
            'params': {
              'protocolVersion': '2025-03-26',
              'capabilities': <String, dynamic>{},
              'clientInfo': {'name': 'test', 'version': '1.0.0'},
            },
          }),
        );
        final res = await req.close();
        expect(res.statusCode, 200, reason: 'Token $token should be accepted');
        await res.drain<void>();
      }
    });
  });
}
