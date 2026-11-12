import 'dart:convert';

import 'package:ephemeron/data/remote/google_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('calendarList follows nextPageToken', () async {
    final client = MockClient((req) async {
      final page = req.url.queryParameters['pageToken'];
      if (page == null) {
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'c1', 'summary': 'Cal 1'},
            ],
            'nextPageToken': 'p2',
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'items': [
            {'id': 'c2', 'summary': 'Cal 2'},
          ],
        }),
        200,
      );
    });
    final api = HttpGoogleApiClient(
      accessToken: () async => 'tok',
      httpClient: client,
    );
    final items = await api.calendarList();
    expect(items.map((e) => e['id']), ['c1', 'c2']);
  });
}
