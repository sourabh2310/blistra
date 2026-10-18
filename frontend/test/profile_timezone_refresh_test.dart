import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/features/profile/profile_controller.dart';

void main() {
  test('successful zone changes refresh reminders immediately; failed saves do not', () async {
    var refreshes = 0;
    var failed = false;
    final profile = ProfileController(
      ApiClient(
        baseUrl: 'http://test',
        httpClient: MockClient((request) async {
          if (failed) return http.Response('{"message":"Save failed"}', 500);
          return http.Response(jsonEncode(jsonDecode(request.body)), 200);
        }),
      ),
      onTimezoneChanged: () async {
        refreshes++;
      },
    );
    expect(await profile.save({'timezone': 'Asia/Kolkata'}), isTrue);
    expect(refreshes, 1);
    expect(await profile.save({'timezone': 'Asia/Kolkata'}), isTrue);
    expect(refreshes, 1);
    expect(await profile.save({'timezone': 'America/New_York'}), isTrue);
    expect(refreshes, 2);
    failed = true;
    expect(await profile.save({'timezone': 'UTC'}), isFalse);
    expect(refreshes, 2);
    expect(profile.profile?.timezone, 'America/New_York');
    profile.dispose();
  });
}
