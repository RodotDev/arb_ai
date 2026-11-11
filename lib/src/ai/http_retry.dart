import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Longest server-requested wait that is still worth retrying.
const _maxRetryDelay = Duration(seconds: 120);

/// Posts [body] to [url], retrying rate limits (429) and the transient
/// [retryableStatuses] with exponential backoff.
///
/// [retryDelay] lets a provider read the wait time requested by the server
/// (e.g. a `retry-after` header); when it returns null, backoff is used.
/// [fatalHint] may add a human-friendly tip to non-retryable failures.
///
/// Returns the successful (200) response, or throws an [HttpException].
Future<http.Response> postWithRetry({
  required http.Client client,
  required Uri url,
  required Map<String, String> headers,
  required String body,
  required Future<void> Function(Duration) delay,
  Set<int> retryableStatuses = const {500, 502, 503},
  Duration? Function(http.Response response)? retryDelay,
  String? Function(int status)? fatalHint,
  int maxRetries = 5,
}) async {
  var attempt = 0;

  while (true) {
    final http.Response response;
    try {
      response = await client.post(url, headers: headers, body: body);
    } catch (e) {
      throw HttpException('Network or connection error occurred: $e', uri: url);
    }

    final status = response.statusCode;
    if (status == 200) return response;

    final details = prettyPrintJson(response.body);

    if (status != 429 && !retryableStatuses.contains(status)) {
      final hint = fatalHint?.call(status);
      throw HttpException(
        'Failed with status $status (fatal error):\n$details'
        '${hint != null ? '\n$hint' : ''}',
        uri: url,
      );
    }

    final requested = _tryParse(retryDelay, response);
    if (requested != null && requested > _maxRetryDelay) {
      throw HttpException(
        'Quota exhausted. Safe retry limit (${_maxRetryDelay.inSeconds}s) '
        'exceeded: ${requested.inSeconds}s. Aborting.\n$details',
        uri: url,
      );
    }

    attempt++;
    if (attempt >= maxRetries) {
      final label = status == 429 ? '429 (Too Many Requests)' : '$status';
      throw HttpException(
        'Failed after $maxRetries retries with status $label. '
        'Last body:\n$details',
        uri: url,
      );
    }

    await delay(requested ?? Duration(seconds: 1 << attempt));
  }
}

/// Pretty prints [body] when it is JSON, otherwise returns it unchanged.
String prettyPrintJson(String body) {
  try {
    return const JsonEncoder.withIndent('  ').convert(jsonDecode(body));
  } catch (_) {
    return body;
  }
}

Duration? _tryParse(
  Duration? Function(http.Response)? parser,
  http.Response response,
) {
  try {
    return parser?.call(response);
  } catch (_) {
    return null;
  }
}
