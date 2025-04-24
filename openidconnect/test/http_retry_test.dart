import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'package:openidconnect/openidconnect.dart';

// Assuming these are defined elsewhere in your codebase
const String ERROR_MESSAGE_FORMAT = "Error: %2";

class HttpResponseException implements Exception {
  final String message;
  HttpResponseException(this.message);
  @override
  String toString() => message;
}

// Mock HTTP Response
class MockResponse extends Mock implements http.Response {
  @override
  final String body;
  @override
  final int statusCode;

  MockResponse(this.statusCode, this.body);
}

void main() {
  // Use a smaller delay factor for faster tests
  final testDelayFactor = Duration(milliseconds: 10);

  group('httpRetry tests', () {
    test('Successfully handles a 200 response on first try', () async {
      int callCount = 0;

      final result = await httpRetry(
            () {
          callCount++;
          return Future.value(MockResponse(200, '{"success": true, "data": "test"}'));
        },
        delayFactor: testDelayFactor,
      );

      expect(callCount, 1);
      expect(result, isA<Map<String, dynamic>>());
      expect(result?['success'], true);
      expect(result?['data'], 'test');
    });

    test('Handles empty response bodies', () async {
      final result = await httpRetry(
            () => Future.value(MockResponse(204, '')),
        delayFactor: testDelayFactor,
      );

      expect(result, null);
    });

    test('Retries on 503 status code and succeeds eventually', () async {
      int callCount = 0;

      final result = await httpRetry(
            () {
          callCount++;
          if (callCount < 3) {
            return Future.value(MockResponse(503, ''));
          }
          return Future.value(MockResponse(200, '{"success": true}'));
        },
        delayFactor: testDelayFactor,
      );

      expect(callCount, 3);
      expect(result?['success'], true);
    });

    test('Throws exception after max attempts for 503', () async {
      int callCount = 0;

      expect(() async => await httpRetry(
            () {
          callCount++;
          return Future.value(MockResponse(503, ''));
        },
        maxAttempts: 3,
        delayFactor: testDelayFactor,
      ), throwsA(isA<HttpException>()));

      // Wait for all retries to complete
      await Future.delayed(Duration(milliseconds: 100));
      expect(callCount, 3);
    });

    test('Retries on exceptions based on retryIf predicate', () async {
      int callCount = 0;
      int retryCallbackCount = 0;

      final result = await httpRetry(
            () {
          callCount++;
          if (callCount < 3) {
            throw TimeoutException('Test timeout');
          }
          return Future.value(MockResponse(200, '{"success": true}'));
        },
        delayFactor: testDelayFactor,
        retryIf: (e) => e is TimeoutException,
        onRetry: (e) {
          retryCallbackCount++;
        },
      );

      expect(callCount, 3);
      expect(retryCallbackCount, 2);
      expect(result?['success'], true);
    });

    test('Does not retry on exceptions not matching retryIf predicate', () async {
      int callCount = 0;

      expect(() async => await httpRetry(
            () {
          callCount++;
          throw FormatException('Test format exception');
        },
        delayFactor: testDelayFactor,
        retryIf: (e) => e is TimeoutException,
      ), throwsA(isA<FormatException>()));

      expect(callCount, 1);
    });

    test('Handles error responses with error description', () async {
      await expectLater(
              () => httpRetry(
                () => Future.value(MockResponse(400, '{"error": "invalid_request", "error_description": "Missing parameter"}')),
            delayFactor: testDelayFactor,
          ),
          throwsA(
              predicate((e) => e.toString() == "Request Failed: [error: request_failed, description: invalid_request: Missing parameter]")
          )
      );
    });

    test('Handles non-JSON, non-HTML responses', () async {
      await expectLater(
              () => httpRetry(
                () => Future.value(MockResponse(400, 'Plain text error')),
            delayFactor: testDelayFactor,
          ),
          throwsA(
              predicate((e) => e.toString() == "Request Failed: [error: request_failed, description: Plain text error]")
          )
      );
    });

    test('Respects the global maxAttempts parameter', () async {
      int callCount = 0;
      final stopwatch = Stopwatch()..start();

      try {
        await httpRetry(
              () {
            callCount++;
            return Future.value(MockResponse(503, ''));
          },
          maxAttempts: 4,
          delayFactor: testDelayFactor,
        );
      } catch (e) {
        // Expected exception
      }

      stopwatch.stop();

      expect(callCount, 4);
      // Verify we didn't take too long (check that we're not doing nested retries)
      // Allow some buffer for test execution time
      expect(stopwatch.elapsedMilliseconds < 200, true);
    });
  });
}