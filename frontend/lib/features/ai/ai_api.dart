import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import 'ai_draft.dart';

class AiApi {
  AiApi(this.client);
  final ApiClient client;

  static String referencePath(
    Map<String, dynamic> field,
    Map<String, dynamic> data,
  ) {
    var path = field['reference'] as String? ?? '';
    if (path == '/api/v1/finance/friends' && data['groupId'] != null) {
      return '/api/v1/finance/groups/${data['groupId']}';
    }
    if (path.contains('{medicineId}')) {
      if (data['medicineId'] == null) return '';
      path = path.replaceAll('{medicineId}', data['medicineId'].toString());
    }
    return path;
  }

  Future<AiEntryReply> assist(
    String message,
    List<Map<String, String>> history, {
    required bool includeSummary,
    String? draftId,
  }) async {
    final json = await client.post(
      '/api/v1/ai/entries/chat',
      expectStatus: 200,
      body: {
        'chat': {
          'message': message,
          'history': history,
          'includeSummary': includeSummary,
        },
        'draftId': ?draftId,
      },
    );
    return AiEntryReply(json);
  }

  Future<AiDraft> getDraft(String id) async =>
      AiDraft(await client.get('/api/v1/ai/entries/$id'));
  Future<AiDraft> edit(AiDraft draft, Map<String, dynamic> data) async =>
      AiDraft(
        await client.put(
          '/api/v1/ai/entries/${draft.id}',
          body: {'revision': draft.revision, 'data': data},
        ),
      );
  Future<AiDraft> approve(AiDraft draft) async => AiDraft(
    await client.post(
      '/api/v1/ai/entries/${draft.id}/approve',
      expectStatus: 200,
      body: {'revision': draft.revision, 'reviewed': true},
    ),
  );
  Future<void> cancel(AiDraft draft) async {
    await client.post(
      '/api/v1/ai/entries/${draft.id}/cancel',
      expectStatus: 200,
      body: {'revision': draft.revision},
    );
  }

  Future<List<Map<String, String>>> options(String path) async {
    // All paths come from the server's fixed catalog, never from model text.
    const allowed = {
      '/api/v1/medicines',
      '/api/v1/habits',
      '/api/v1/diet/meals',
      '/api/v1/planner/lists',
      '/api/v1/finance/accounts',
      '/api/v1/finance/categories',
      '/api/v1/finance/friends',
      '/api/v1/finance/groups',
    };
    final dynamicPath =
        RegExp(r'^/api/v1/medicines/[0-9a-fA-F-]{36}/schedules$')
            .hasMatch(path) ||
        RegExp(r'^/api/v1/finance/groups/[0-9a-fA-F-]{36}$').hasMatch(path);
    if (!allowed.contains(path) && !dynamicPath) return [];
    final result = <Map<String, String>>[];
    var page = 0;
    var more = true;
    while (more && page < 20) {
      Object raw;
      try {
        raw = await client.getList(
          path,
          query: {'page': '$page', 'size': '100'},
        );
      } on ApiException catch (e) {
        if (e.code != 'UNEXPECTED_RESPONSE') rethrow;
        raw = await client.get(path, query: {'page': '$page', 'size': '100'});
      }
      List items = [];
      more = false;
      if (raw is List) {
        items = raw;
      }
      if (raw is Map) {
        items =
            (raw['content'] ??
                    raw['items'] ??
                    raw['friends'] ??
                    raw['groups'] ??
                    raw['members'] ??
                    [])
                as List;
        if (raw['me'] is Map) items = [raw['me'], ...items];
        more =
            raw['last'] == false ||
            ((raw['totalPages'] as num? ?? 0) > page + 1);
      }
      for (final rawItem in items) {
        if (rawItem is! Map) continue;
        final item = rawItem['user'] is Map ? rawItem['user'] as Map : rawItem;
        final id = item['id']?.toString();
        var label =
            (item['name'] ??
                    item['title'] ??
                    item['displayName'] ??
                    item['username'])
                ?.toString();
        if (label == null && item['scheduleType'] != null) {
          label =
              '${item['scheduleType']} ${(item['times'] as List? ?? []).join(', ')}';
        }
        if (label != null && item['currency'] != null) {
          label = '$label (${item['currency']})';
        }
        if (id != null && label != null && !result.any((v) => v['id'] == id)) {
          result.add({'id': id, 'label': label});
        }
      }
      page++;
    }
    return result;
  }

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
