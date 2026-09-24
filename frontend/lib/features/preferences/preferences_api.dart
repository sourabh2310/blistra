/// Backend client for per-user Home/navigation preferences.
///
/// Server owns validation + ownership (JWT identity); unknown identifiers are
/// rejected with 400 and never stored.
library;

import '../../core/api/api_client.dart';

class AppPreferencesPayload {
  AppPreferencesPayload({
    required this.bottomNav,
    required this.homeWidgets,
  });

  final List<String> bottomNav;
  final List<String> homeWidgets;

  factory AppPreferencesPayload.fromJson(Map<String, dynamic> json) {
    List<String> list(dynamic raw) => [
          for (final item in (raw as List? ?? const [])) item.toString(),
        ];
    return AppPreferencesPayload(
      bottomNav: list(json['bottomNav']),
      homeWidgets: list(json['homeWidgets']),
    );
  }

  Map<String, dynamic> toJson() => {
        'bottomNav': bottomNav,
        'homeWidgets': homeWidgets,
      };
}

class PreferencesApi {
  PreferencesApi(this._client);

  final ApiClient _client;

  Future<AppPreferencesPayload> getPreferences() async {
    final json = await _client.get('/api/v1/preferences');
    return AppPreferencesPayload.fromJson(json);
  }

  Future<AppPreferencesPayload> updatePreferences({
    required List<String> bottomNav,
    required List<String> homeWidgets,
  }) async {
    final json = await _client.put('/api/v1/preferences', body: {
      'bottomNav': bottomNav,
      'homeWidgets': homeWidgets,
    });
    return AppPreferencesPayload.fromJson(json);
  }
}
