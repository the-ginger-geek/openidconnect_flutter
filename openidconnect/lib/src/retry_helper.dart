part of openidconnect;

/// Makes HTTP requests with automatic retry capability for transient failures
///
/// Parameters:
/// - [fn]: The HTTP request function to execute
/// - [delayFactor]: Base delay duration between retries
/// - [randomizationFactor]: Random factor applied to delay to avoid synchronized retries
/// - [maxDelay]: Maximum delay between retries
/// - [maxAttempts]: Maximum number of retry attempts
/// - [retryIf]: Optional predicate to determine if an exception should trigger retry
/// - [onRetry]: Optional callback executed before each retry
///
/// Returns a decoded JSON response as Map<String, dynamic> or null for empty responses
Future<Map<String, dynamic>?> httpRetry<T extends http.Response>(
    FutureOr<T> Function() fn, {
      Duration delayFactor = const Duration(milliseconds: 200),
      double randomizationFactor = 0.25,
      Duration maxDelay = const Duration(seconds: 30),
      int maxAttempts = 8,
      FutureOr<bool> Function(Exception)? retryIf,
      FutureOr<void> Function(Exception)? onRetry,
    }) async {
  final options = RetryOptions(
    delayFactor: delayFactor,
    randomizationFactor: randomizationFactor,
    maxDelay: maxDelay,
    maxAttempts: maxAttempts,
  );

  int attempt = 0;

  while (attempt < maxAttempts) {
    attempt++;

    try {
      final response = await fn();

      // Handle service unavailable status codes
      if (_isServiceUnavailable(response.statusCode)) {
        if (attempt >= maxAttempts) {
          throw HttpException("The server could not be reached. Please try again later.");
        }
        await Future<void>.delayed(options.delay(attempt));
        continue;
      }

      // Process the response body and convert to JSON
      final processedBody = _processResponseBody(response.body);
      final jsonResponse = jsonDecode(processedBody) as Map<String, dynamic>?;

      // Handle non-success status codes
      if (!_isSuccessStatusCode(response.statusCode)) {
        _handleErrorResponse(jsonResponse!);
      }

      // Return null for empty responses, otherwise return the JSON
      return response.body.isEmpty ? null : jsonResponse;

    } catch (e) {
      // Handle exceptions that match retry criteria
      if (e is Exception && retryIf != null && await retryIf(e)) {
        if (onRetry != null) {
          await onRetry(e);
        }

        if (attempt < maxAttempts) {
          await Future<void>.delayed(options.delay(attempt));
          continue;
        }
      }
      rethrow;
    }
  }

  throw HttpException("Maximum retry attempts reached");
}

/// Determines if a status code indicates service unavailability
bool _isServiceUnavailable(int statusCode) {
  return statusCode == 502 || statusCode == 503 || statusCode == 504;
}

/// Determines if a status code indicates a successful response
bool _isSuccessStatusCode(int statusCode) {
  return statusCode >= 200 && statusCode < 300;
}

/// Processes the response body to ensure it's valid JSON
///
/// - Returns empty JSON object for empty or HTML responses
/// - Returns original body if it's already JSON
/// - Wraps plain text in an error JSON object
String _processResponseBody(String originalBody) {
  if (originalBody.isEmpty || originalBody.startsWith("<html")) {
    return "{}";
  }

  if (originalBody.startsWith("{")) {
    return originalBody;
  }

  // Handle plain text as an error
  return """{"error": "${originalBody.replaceAll("\"", "'")}"}""";
}

/// Handles error responses by throwing an appropriate exception
///
/// Extracts error information from the JSON response and formats
/// it according to ERROR_MESSAGE_FORMAT
void _handleErrorResponse(Map<String, dynamic> jsonResponse) {
  if (jsonResponse["error"] != null) {
    var errorMessage = jsonResponse["error"].toString();

    if (jsonResponse["error_description"] != null) {
      errorMessage += ": ${jsonResponse["error_description"]}";
    }

    throw HttpResponseException(
        ERROR_MESSAGE_FORMAT.replaceAll("%2", errorMessage)
    );
  } else {
    throw HttpResponseException(
        ERROR_MESSAGE_FORMAT.replaceAll("%2", "unknown_error")
    );
  }
}