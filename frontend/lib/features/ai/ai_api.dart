import '../../core/api/api_client.dart';

class AiApi {
  AiApi(this.client);
  final ApiClient client;

  Future<String> chat(
    String message,
    List<Map<String, String>> history, {
    required bool includeSummary,
  }) async {
    final json = await client.post(
      '/api/v1/ai/chat',
      expectStatus: 200,
      body: {
        'message': message,
        'history': history,
        'includeSummary': includeSummary,
      },
    );
    final reply = json['reply'];
    if (reply is! String || reply.trim().isEmpty) {
      throw const FormatException('Empty AI response');
    }
    return reply;
  }
}
