// Thin hand-written Google REST client (Calendar + Tasks). No heavy
// googleapis dependency. Throws typed failures; never touches app data.
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';

part 'google_api_client/core.dart';
part 'google_api_client/calendar.dart';
part 'google_api_client/tasks.dart';

class GoogleApiException implements Exception {
  GoogleApiException(this.status, this.message, {this.retryAfterSec});

  final int status;
  final String message;
  final int? retryAfterSec;

  bool get isGone => status == 410;
  bool get isUnauthorized => status == 401;
  bool get isConflict => status == 412;

  Map<String, dynamic>? get _body {
    final trimmed = message.trim();
    if (!trimmed.startsWith('{')) return null;
    try {
      final decoded = jsonDecode(trimmed);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  String? _errorField(String field) {
    final error = _body?['error'];
    if (error is Map<String, dynamic>) {
      final value = error[field];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  /// First `error.errors[].reason` reported by Google, if any.
  String? get reason {
    final error = _body?['error'];
    if (error is Map<String, dynamic>) {
      final errors = error['errors'];
      if (errors is List) {
        for (final item in errors) {
          if (item is Map<String, dynamic>) {
            final value = item['reason'];
            if (value is String && value.isNotEmpty) return value;
          }
        }
      }
    }
    return null;
  }

  String? get _statusReason => _errorField('status');

  bool get _hasAuthReason {
    const reasons = {
      'autherror',
      'insufficientpermissions',
      'access_token_scope_insufficient',
      'unauthenticated',
    };
    final reason = this.reason?.toLowerCase();
    if (reason != null && reasons.contains(reason)) return true;
    final statusReason = _statusReason?.toLowerCase();
    return statusReason == 'unauthenticated' ||
        statusReason == 'access_token_scope_insufficient';
  }

  bool get _hasRateReason {
    const reasons = {
      'ratelimitexceeded',
      'userratelimitexceeded',
      'quotaexceeded',
      'resource_exhausted',
      'dailylimitexceeded',
      'calendarusagelimitsexceeded',
    };
    final reason = this.reason?.toLowerCase();
    if (reason != null && reasons.contains(reason)) return true;
    final statusReason = _statusReason?.toLowerCase();
    if (statusReason != null && reasons.contains(statusReason)) return true;
    final body = message.toLowerCase();
    return body.contains('ratelimit') ||
        body.contains('quotaexceeded') ||
        body.contains('quota_exceeded');
  }

  /// Expired/revoked token (401) or a 403 that explicitly reports an auth
  /// problem. Google reports per-resource denials (for example a shared
  /// freeBusyReader calendar) as 403 too; those must not trigger reconnect.
  bool get isAuthFailure {
    if (status == 401) return true;
    if (status != 403) return false;
    return _hasAuthReason;
  }

  /// 429, or 403 carrying a rate-limit/quota reason.
  bool get isRateLimited {
    if (status == 429) return true;
    if (status != 403) return false;
    return _hasRateReason;
  }

  /// A 403 that is neither auth nor rate limiting: the resource itself is
  /// inaccessible under this account (shared calendar, forbidden event).
  bool get isForbidden => status == 403 && !isAuthFailure && !isRateLimited;

  bool get isServerError => status >= 500 && status < 600;

  /// Compatibility alias: only auth failures require reconnecting.
  bool get isPermissionDenied => isAuthFailure;
}

class CalendarPage {
  CalendarPage({required this.items, this.nextSyncToken});
  final List<Map<String, dynamic>> items;
  final String? nextSyncToken;
}

class TasksPage {
  TasksPage({required this.items, this.nextUpdatedMin});
  final List<Map<String, dynamic>> items;
  final String? nextUpdatedMin;
}

abstract class GoogleApiClient {
  Future<List<Map<String, dynamic>>> calendarList();
  Future<CalendarPage> eventsList(
    String calendarId, {
    String? syncToken,
    String? timeMin,
    String? timeMax,
    bool singleEvents = false,
    bool showDeleted = true,
  });
  Future<Map<String, dynamic>> eventInsert(
    String calendarId,
    Map<String, dynamic> body,
  );
  Future<Map<String, dynamic>> eventPatch(
    String calendarId,
    String eventId,
    Map<String, dynamic> body, {
    String? etag,
  });
  Future<Map<String, dynamic>> eventMove(
    String sourceCalendarId,
    String eventId,
    String destinationCalendarId,
  );
  Future<void> eventDelete(String calendarId, String eventId);
  Future<List<Map<String, dynamic>>> taskLists();
  Future<Map<String, dynamic>> taskListCreate(String title);
  Future<Map<String, dynamic>> taskListPatch(String listId, String title);
  Future<void> taskListDelete(String listId);
  Future<TasksPage> tasksList(String taskListId, {String? updatedMin});
  Future<Map<String, dynamic>> taskInsert(
    String taskListId,
    Map<String, dynamic> body,
  );
  Future<Map<String, dynamic>> taskPatch(
    String taskListId,
    String taskId,
    Map<String, dynamic> body, {
    String? etag,
  });
  Future<Map<String, dynamic>> taskMove(
    String sourceTaskListId,
    String taskId,
    String destinationTaskListId,
  );
  Future<void> taskDelete(String taskListId, String taskId);
}

class HttpGoogleApiClient extends _GoogleApiBase
    with _GoogleApiCalendarOps, _GoogleApiTasksOps
    implements GoogleApiClient {
  HttpGoogleApiClient({required super.accessToken, super.httpClient});
}
