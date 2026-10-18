import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/features/ai/ai_api.dart';
import 'package:frontend/features/ai/ai_screen.dart';
import 'package:frontend/features/ai/ai_entry_editor.dart';

Map<String, dynamic> taskDraft({
  int revision = 1,
  String state = 'PENDING',
  String? title = 'Exercise',
}) => {
  'id': '00000000-0000-0000-0000-000000000001',
  'action': 'task',
  'label': 'Task',
  'module': 'Planner',
  'data': {'title': ?title},
  'errors': {if (title == null) 'title': 'Title is required.'},
  'fields': [
    {
      'name': 'title',
      'label': 'Title',
      'type': 'text',
      'required': true,
      'choices': [],
      'fields': [],
      'reference': '',
      'help': '',
    },
  ],
  'effect': 'Adds one task in Planner.',
  'revision': revision,
  'state': state,
  'expiresAt': DateTime.now()
      .toUtc()
      .add(const Duration(minutes: 30))
      .toIso8601String(),
  'timezone': 'Asia/Kolkata',
  if (state == 'APPLIED') 'result': {'id': 'saved-task', 'title': title},
};

Future<void> largeScreen(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> send(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), 'Add Exercise');
  await tester.tap(find.byTooltip('Send message'));
  await tester.pumpAndSettle();
}

Future<void> review(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(CheckboxListTile));
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'A stale approval refreshes the template and requires another field review',
    (tester) async {
      await largeScreen(tester);
      final client = ApiClient(
        baseUrl: 'http://localhost',
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode(taskDraft(revision: 2, title: 'Walk')),
              200,
            );
          }
          if (request.url.path.endsWith('/approve')) {
            if ((jsonDecode(request.body) as Map)['revision'] == 1) {
              return http.Response(
                '{"code":"INVALID_STATE","message":"This draft changed. Review its latest version."}',
                409,
              );
            }
            return http.Response(
              jsonEncode(
                taskDraft(revision: 2, title: 'Walk', state: 'APPLIED'),
              ),
              200,
            );
          }
          return http.Response(
            jsonEncode({'reply': 'Review your task.', 'draft': taskDraft()}),
            200,
          );
        }),
      );
      await tester.pumpWidget(MaterialApp(home: AiScreen(api: AiApi(client))));
      await send(tester);
      await review(tester);
      await tester.tap(find.text('Approve and add'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refresh draft'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        false,
      );
      expect(find.text('Title: Walk'), findsOneWidget);
      await review(tester);
      await tester.tap(find.text('Approve and add'));
      await tester.pumpAndSettle();
      expect(find.text('Saved: Task'), findsOneWidget);
    },
  );
  testWidgets(
    'Nothing saves before explicit review and approval; receipt refreshes app',
    (tester) async {
      await largeScreen(tester);
      final approvals = <Map<String, dynamic>>[];
      var refreshed = 0;
      final client = ApiClient(
        baseUrl: 'http://localhost',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/approve')) {
            approvals.add(jsonDecode(request.body) as Map<String, dynamic>);
            return http.Response(jsonEncode(taskDraft(state: 'APPLIED')), 200);
          }
          return http.Response(
            jsonEncode({'reply': 'Review your task.', 'draft': taskDraft()}),
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AiScreen(
            api: AiApi(client),
            onEntrySaved: () async {
              refreshed++;
            },
          ),
        ),
      );
      await send(tester);
      expect(approvals, isEmpty);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Approve and add'),
            )
            .onPressed,
        isNull,
      );
      await review(tester);
      await tester.tap(find.text('Approve and add'));
      await tester.pumpAndSettle();
      expect(approvals, [
        {'revision': 1, 'reviewed': true},
      ]);
      expect(refreshed, 1);
      expect(find.text('Saved: Task'), findsOneWidget);
      expect(find.text('Approve and add'), findsNothing);
    },
  );

  testWidgets(
    'Missing fields block approval; edit validates then requires a fresh review',
    (tester) async {
      await largeScreen(tester);
      var approvals = 0;
      Map<String, dynamic>? edited;
      final client = ApiClient(
        baseUrl: 'http://localhost',
        httpClient: MockClient((request) async {
          if (request.method == 'PUT') {
            edited = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode(taskDraft(revision: 2, title: 'Walk')),
              200,
            );
          }
          if (request.url.path.endsWith('/approve')) {
            approvals++;
            expect((jsonDecode(request.body) as Map)['revision'], 2);
            return http.Response(
              jsonEncode(
                taskDraft(revision: 2, title: 'Walk', state: 'APPLIED'),
              ),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'reply': 'Please supply the title.',
              'draft': taskDraft(title: null),
            }),
            200,
          );
        }),
      );
      await tester.pumpWidget(MaterialApp(home: AiScreen(api: AiApi(client))));
      await send(tester);
      await review(tester);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Approve and add'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Walk');
      await tester.tap(find.text('Validate and review'));
      await tester.pumpAndSettle();
      expect(edited, {
        'revision': 1,
        'data': {'title': 'Walk'},
      });
      expect(approvals, 0);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        false,
      );
      await review(tester);
      await tester.tap(find.text('Approve and add'));
      await tester.pumpAndSettle();
      expect(approvals, 1);
    },
  );

  testWidgets('Uncertain approval can retry only the same draft revision', (
    tester,
  ) async {
    await largeScreen(tester);
    final ids = <String>[];
    final client = ApiClient(
      baseUrl: 'http://localhost',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/approve')) {
          ids.add(
            '${request.url.path}:${(jsonDecode(request.body) as Map)['revision']}',
          );
          if (ids.length == 1) {
            return http.Response(
              '{"code":"TEMPORARY","message":"Unavailable"}',
              503,
            );
          }
          return http.Response(jsonEncode(taskDraft(state: 'APPLIED')), 200);
        }
        return http.Response(
          jsonEncode({'reply': 'Review your task.', 'draft': taskDraft()}),
          200,
        );
      }),
    );
    await tester.pumpWidget(MaterialApp(home: AiScreen(api: AiApi(client))));
    await send(tester);
    await review(tester);
    await tester.tap(find.text('Approve and add'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Could not confirm whether this was saved'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.delete_outline),
          )
          .onPressed,
      isNull,
    );
    await tester.ensureVisible(find.text('Approve and add'));
    await tester.tap(find.text('Approve and add'));
    await tester.pumpAndSettle();
    expect(ids.length, 2);
    expect(ids[0], ids[1]);
    expect(find.text('Saved: Task'), findsOneWidget);
  });

  testWidgets('Cancelling a draft does not call approval', (tester) async {
    await largeScreen(tester);
    var cancelled = false;
    final client = ApiClient(
      baseUrl: 'http://localhost',
      httpClient: MockClient((request) async {
        expect(request.url.path.endsWith('/approve'), false);
        if (request.url.path.endsWith('/cancel')) {
          cancelled = true;
          return http.Response('{"state":"CANCELLED"}', 200);
        }
        return http.Response(
          jsonEncode({'reply': 'Review your task.', 'draft': taskDraft()}),
          200,
        );
      }),
    );
    await tester.pumpWidget(MaterialApp(home: AiScreen(api: AiApi(client))));
    await send(tester);
    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(cancelled, true);
    expect(find.text('Draft cancelled. Nothing was added.'), findsOneWidget);
    expect(find.text('Approve and add'), findsNothing);
  });

  testWidgets('Clearing an optional field clears its displayed value', (
    tester,
  ) async {
    Object? value = 'Keep note';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EntryField(
            api: AiApi(ApiClient(baseUrl: 'http://localhost')),
            field: const {
              'name': 'notes',
              'label': 'Notes',
              'type': 'text',
              'required': false,
            },
            value: value,
            onChanged: (v) => value = v,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Leave unset'));
    await tester.pumpAndSettle();
    expect(value, isNull);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      isEmpty,
    );
  });
}
