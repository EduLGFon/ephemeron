// Read-only Microsoft Graph client (calendars + To Do). Throws typed failures;
// never logs tokens, headers, or personal data.
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../domain/microsoft/microsoft_graph_models.dart';

class MicrosoftGraphException implements Exception {
  MicrosoftGraphException(this.status, this.message, {this.retryAfterSec});

  final int status;
  final String message;
  final int? retryAfterSec;

  bool get isUnauthorized => status == 401;
  bool get isForbidden => status == 403;
  bool get isNotFound => status == 404;
  bool get isGone => status == 410;
  bool get isRateLimited => status == 429;
  bool get isMalformed => status == 0;

  @override
  String toString() => 'MicrosoftGraphException($status, $message)';
}

abstract class MicrosoftGraphClient {
  Future<MsIdentity> getMe();
  Future<List<MsCalendar>> listCalendars();
  Future<List<MsEvent>> calendarView(
    DateTime startUtc,
    DateTime endUtc, {
    String? calendarId,
  });
  Future<List<MsTodoList>> listTodoLists();
  Future<List<MsTodoTask>> listTodoTasks(String listId);
}

/// Default wait between a transient failure and its single retry.
Future<void> _pauseForRetry(Duration delay) => Future<void>.delayed(delay);

class HttpMicrosoftGraphClient implements MicrosoftGraphClient {
  HttpMicrosoftGraphClient({
    required this._accessToken,
    http.Client? httpClient,
    Future<void> Function(Duration)? retryDelay,
  }) : _http = httpClient ?? http.Client(),
       _retryDelay = retryDelay ?? _pauseForRetry;

  final Future<String?> Function() _accessToken;
  final http.Client _http;
  final Future<void> Function(Duration) _retryDelay;

  static const int _maxPages = 50;

  /// One bounded retry per request for transient Graph failures. A retry that
  /// fails again propagates the typed exception so callers can classify it.
  static const int _maxRetries = 1;

  /// Retry-After is honored but capped: a foreground sync must not stall for
  /// minutes on a server-requested delay.
  static const Duration _maxRetryDelay = Duration(seconds: 10);

  Future<Map<String, String>> _headers({bool preferUtc = false}) async {
    final token = await _accessToken();
    if (token == null) {
      throw MicrosoftGraphException(401, 'no token');
    }
    final headers = <String, String>{
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    if (preferUtc) {
      headers['Prefer'] = 'outlook.timezone="UTC"';
    }
    return headers;
  }

  Never _throw(http.Response r) {
    throw MicrosoftGraphException(
      r.statusCode,
      _safeMessage(r.body),
      retryAfterSec: _retryAfterSec(r),
    );
  }

  int? _retryAfterSec(http.Response r) {
    for (final e in r.headers.entries) {
      if (e.key.toLowerCase() == 'retry-after') {
        return int.tryParse(e.value);
      }
    }
    return null;
  }

  bool _isTransientStatus(int status) =>
      status == 429 || (status >= 500 && status <= 599);

  Duration _retryDelayFor(http.Response r) {
    final retryAfter = _retryAfterSec(r);
    if (retryAfter != null && retryAfter > 0) {
      final delay = Duration(seconds: retryAfter);
      return delay > _maxRetryDelay ? _maxRetryDelay : delay;
    }
    // 429 without Retry-After: brief pause. 5xx: retry immediately.
    return r.statusCode == 429 ? const Duration(seconds: 1) : Duration.zero;
  }

  /// GETs [url] with at most one retry for 429/5xx, honoring Retry-After.
  /// Other non-2xx responses throw immediately. All Graph calls here are GETs,
  /// so a retry cannot duplicate a mutation.
  Future<http.Response> _get(Uri url, Map<String, String> headers) async {
    var attempt = 0;
    while (true) {
      final r = await _http.get(url, headers: headers);
      if (r.statusCode >= 200 && r.statusCode < 300) return r;
      if (attempt >= _maxRetries || !_isTransientStatus(r.statusCode)) {
        _throw(r);
      }
      await _retryDelay(_retryDelayFor(r));
      attempt++;
    }
  }

  String _safeMessage(String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map<String, dynamic>) {
        final e = j['error'];
        if (e is Map<String, dynamic>) {
          final m = e['message'];
          if (m is String && m.isNotEmpty) return m;
        }
        final m = j['message'];
        if (m is String && m.isNotEmpty) return m;
      }
    } catch (_) {}
    return 'graph ${body.isNotEmpty ? 'error' : 'empty'}';
  }

  Map<String, dynamic> _decode(http.Response r) {
    try {
      final j = jsonDecode(r.body);
      if (j is! Map<String, dynamic>) {
        throw MicrosoftGraphException(0, 'malformed json');
      }
      return j;
    } on FormatException {
      throw MicrosoftGraphException(0, 'malformed json');
    } on MicrosoftGraphException {
      rethrow;
    } catch (_) {
      throw MicrosoftGraphException(0, 'malformed json');
    }
  }

  List<T> _pageItems<T>(
    Map<String, dynamic> body,
    T Function(Map<String, dynamic>) fromMap,
  ) {
    final value = body['value'];
    if (value is! List) return const [];
    return value.whereType<Map<String, dynamic>>().map(fromMap).toList();
  }

  Future<List<T>> _paginate<T>(
    Uri initial,
    Map<String, String> headers,
    T Function(Map<String, dynamic>) fromMap,
  ) async {
    final all = <T>[];
    Uri? next = initial;
    var pages = 0;
    while (next != null && pages < _maxPages) {
      final r = await _get(next, headers);
      final body = _decode(r);
      all.addAll(_pageItems(body, fromMap));
      final link = body['@odata.nextLink'];
      next = link is String && link.isNotEmpty ? Uri.parse(link) : null;
      pages++;
    }
    if (next != null) {
      // A capped listing is incomplete. Never return it as if it were complete:
      // callers reconcile remote deletions only after a full successful fetch.
      throw MicrosoftGraphException(0, 'pagination limit reached');
    }
    return all;
  }

  @override
  Future<MsIdentity> getMe() async {
    final headers = await _headers();
    final r = await _get(
      Uri.parse('${AppConfig.microsoftGraphBase}/me').replace(
        queryParameters: const {
          r'$select': 'id,displayName,mail,userPrincipalName',
        },
      ),
      headers,
    );
    final body = _decode(r);
    return MsIdentity.fromMap(body);
  }

  @override
  Future<List<MsCalendar>> listCalendars() async {
    final headers = await _headers();
    final initial = Uri.parse('${AppConfig.microsoftGraphBase}/me/calendars')
        .replace(
          queryParameters: const {
            r'$select': 'id,name,color,hexColor,isDefaultCalendar,isSharedWithMe,canEdit,owner',
          },
        );
    return _paginate(initial, headers, MsCalendar.fromMap);
  }

  @override
  Future<List<MsEvent>> calendarView(
    DateTime startUtc,
    DateTime endUtc, {
    String? calendarId,
  }) async {
    final headers = await _headers(preferUtc: true);
    final path = calendarId == null || calendarId.isEmpty
        ? '/me/calendarView'
        : '/me/calendars/${Uri.encodeComponent(calendarId)}/calendarView';
    final initial = Uri.parse('${AppConfig.microsoftGraphBase}$path').replace(
      queryParameters: {
        r'$select': 'id,subject,bodyPreview,start,end,isAllDay,location,showAs,isCancelled,seriesMasterId,type,recurrence,onlineMeetingUrl,attendees,organizer,lastModifiedDateTime',
        'startDateTime': startUtc.toUtc().toIso8601String(),
        'endDateTime': endUtc.toUtc().toIso8601String(),
      },
    );
    return _paginate(initial, headers, MsEvent.fromMap);
  }

  @override
  Future<List<MsTodoList>> listTodoLists() async {
    final headers = await _headers();
    // SECURITY/PRIVACY: no $select here. The To Do API rejects $select for
    // these endpoints (HTTP 400 invalidRequest); the default payload is used
    // and mapped by fixed fields, so no extra data is logged or stored.
    final initial = Uri.parse('${AppConfig.microsoftGraphBase}/me/todo/lists');
    return _paginate(initial, headers, MsTodoList.fromMap);
  }

  @override
  Future<List<MsTodoTask>> listTodoTasks(String listId) async {
    final headers = await _headers();
    // No $select: see listTodoLists.
    final initial = Uri.parse(
      '${AppConfig.microsoftGraphBase}/me/todo/lists/${Uri.encodeComponent(listId)}/tasks',
    );
    return _paginate(initial, headers, MsTodoTask.fromMap);
  }
}
