import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_state.dart';
import 'ai_api.dart';
import 'ai_draft.dart';
import 'ai_draft_card.dart';
import 'ai_entry_editor.dart';

class AiScreen extends StatefulWidget {
  const AiScreen({
    super.key,
    required this.api,
    this.authState,
    this.onEntrySaved,
    this.onUploadDocument,
    this.onViewEntry,
  });
  final AiApi api;
  final AuthState? authState;
  final Future<void> Function()? onEntrySaved;
  final VoidCallback? onUploadDocument;
  final ValueChanged<String>? onViewEntry;

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, String>> _turns = [];
  bool _busy = false;
  bool _share = false;
  String? _error;
  bool _sessionEnded = false;
  String? _owner;
  AiDraft? _draft;
  bool _uploadDocument = false;
  bool _approvalUncertain = false;

  @override
  void initState() {
    super.initState();
    _owner = widget.authState?.account?.id ?? widget.authState?.userEmail;
    widget.authState?.addListener(_checkSession);
  }

  void _checkSession() {
    final auth = widget.authState!;
    if (_sessionEnded) return;
    if (!auth.isAuthenticated ||
        (auth.account?.id ?? auth.userEmail) != _owner) {
      _sessionEnded = true;
      _turns.clear();
      _draft = null;
      _input.clear();
      if (mounted) setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  void dispose() {
    widget.authState?.removeListener(_checkSession);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  });

  Future<void> _send() async {
    final text = _input.text.trim();
    if (_busy || _sessionEnded || text.isEmpty || text.length > 2000) return;
    if (_approvalUncertain) {
      setState(
        () => _error = 'Retry approval of the current draft to confirm its save status before starting another entry.',
      );
      return;
    }
    final history = _turns
        .skip(_turns.length > 10 ? _turns.length - 10 : 0)
        .map((turn) => Map<String, String>.of(turn))
        .toList();
    setState(() {
      _busy = true;
      _error = null;
      _turns.add({'role': 'user', 'content': text});
      _input.clear();
    });
    _scrollDown();
    try {
      final reply = await widget.api.assist(
        text,
        history,
        includeSummary: _share,
        draftId: _draft?.pending == true ? _draft!.id : null,
      );
      if (!mounted || _sessionEnded) return;
      setState(() {
        _turns.add({'role': 'assistant', 'content': reply.reply});
        _draft = reply.draft;
        _uploadDocument = reply.uploadDocument;
      });
    } catch (e) {
      if (!mounted || _sessionEnded) return;
      setState(() {
        _turns.removeLast();
        _input.text = text;
        _error = e is ApiException && e.statusCode != 0
            ? e.message
            : 'Could not reach Blistra AI. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _scrollDown();
      }
    }
  }

  Future<void> _approve() async {
    final draft = _draft;
    if (_busy || _sessionEnded || draft == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await widget.api.approve(draft);
      if (!mounted || _sessionEnded) return;
      setState(() {
        _draft = saved;
        _approvalUncertain = false;
      });
      try {
        await widget.onEntrySaved?.call();
      } catch (_) {
        /* Saved receipt remains authoritative. */
      }
    } catch (e) {
      if (!mounted || _sessionEnded) return;
      setState(() {
        _approvalUncertain =
            e is! ApiException || e.statusCode == 0 || e.statusCode >= 500;
        _error = _approvalUncertain
            ? 'Could not confirm whether this was saved. Retry approval of this same draft; it will not create a duplicate.'
            : (e as ApiException).message;
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _scrollDown();
      }
    }
  }

  Future<void> _edit() async {
    final draft = _draft;
    if (_busy || _sessionEnded || draft == null) return;
    if (_approvalUncertain) {
      setState(
        () => _error = 'Retry the existing approval first to confirm whether the entry was saved.',
      );
      return;
    }
    final edited = await Navigator.of(context).push<AiDraft>(
      MaterialPageRoute(
        builder: (_) => AiEntryEditor(api: widget.api, draft: draft),
      ),
    );
    if (mounted && !_sessionEnded && edited != null) {
      setState(() {
        _draft = edited;
        _error = null;
      });
      _scrollDown();
    }
  }

  Future<void> _cancel() async {
    final draft = _draft;
    if (_busy || _sessionEnded || draft == null) return;
    if (_approvalUncertain) {
      setState(
        () => _error =
            'Retry the existing approval first to confirm save status.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.cancel(draft);
      if (mounted && !_sessionEnded) {
        setState(() {
          _draft = null;
          _turns.add({
            'role': 'assistant',
            'content': 'Draft cancelled. Nothing was added.',
          });
        });
      }
    } catch (e) {
      if (mounted && !_sessionEnded) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Could not cancel this draft. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshDraft() async {
    final current = _draft;
    if (_busy || _sessionEnded || current == null) return;
    setState(() => _busy = true);
    try {
      final latest = await widget.api.getDraft(current.id);
      if (!mounted || _sessionEnded) return;
      setState(() {
        _draft = latest;
        // A pending read cannot disprove an approval still committing on the server.
        if (latest.state != 'PENDING') _approvalUncertain = false;
        _error = _approvalUncertain
            ? 'Retry approval of this same draft to confirm its save status.'
            : null;
      });
      if (latest.state == 'APPLIED') {
        try {
          await widget.onEntrySaved?.call();
        } catch (_) {
          /* Receipt is already saved. */
        }
      }
    } catch (e) {
      if (mounted && !_sessionEnded) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Could not refresh this draft. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Blistra AI'),
      actions: [
        IconButton(
          tooltip: 'Clear chat',
          icon: const Icon(Icons.delete_outline),
          onPressed: _busy || _approvalUncertain
              ? null
              : () => setState(() {
                  _turns.clear();
                  _error = null;
                  _input.clear();
                  _share = false;
                  _draft = null;
                  _uploadDocument = false;
                }),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              if (MediaQuery.viewInsetsOf(context).bottom == 0)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'AI replies can be inaccurate. Messages go to the configured AI provider. '
                    'Entry details are sent for drafting and stored temporarily for review. Nothing is added until you approve.',
                  ),
                ),
              if (MediaQuery.viewInsetsOf(context).bottom == 0)
                SwitchListTile(
                  title: const Text('Share my daily summary'),
                  subtitle: const Text(
                    'Today’s task, event, habit, dose and meal counts + water total. '
                    'No record details. Changing this clears chat context.',
                  ),
                  value: _share,
                  onChanged: _busy || _approvalUncertain
                      ? null
                      : (value) => setState(() {
                          _share = value;
                          _turns.clear();
                          _error = null;
                          _draft = null;
                          _uploadDocument = false;
                        }),
                ),
              Expanded(
                child:
                    _turns.isEmpty &&
                        !_busy &&
                        _draft == null &&
                        !_uploadDocument
                    ? ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          const Icon(Icons.auto_awesome, size: 42),
                          const SizedBox(height: 16),
                          const Text(
                            'How can I help you with Blistra?',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          for (final prompt in [
                            'What can I do in Blistra?',
                            'Help me plan my day',
                            'Help me build a habit',
                          ])
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: OutlinedButton(
                                onPressed: () {
                                  _input.text = prompt;
                                  _send();
                                },
                                child: Text(prompt),
                              ),
                            ),
                        ],
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        itemCount:
                            _turns.length +
                            (_draft != null ? 1 : 0) +
                            (_uploadDocument ? 1 : 0) +
                            (_busy ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_draft != null && index == _turns.length) {
                            return AiDraftCard(
                              key: ValueKey(_draft!.id),
                              api: widget.api,
                              draft: _draft!,
                              busy: _busy,
                              onApprove: _approve,
                              onEdit: _edit,
                              onCancel: _cancel,
                              onView: widget.onViewEntry == null
                                  ? null
                                  : () => widget.onViewEntry!(_draft!.module),
                            );
                          }
                          if (_uploadDocument &&
                              index ==
                                  _turns.length + (_draft != null ? 1 : 0)) {
                            return FilledButton.icon(
                              onPressed: _busy ? null : widget.onUploadDocument,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Select and review document'),
                            );
                          }
                          if (index >= _turns.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Blistra AI is thinking…',
                                semanticsLabel: 'Waiting for AI response',
                              ),
                            );
                          }
                          final turn = _turns[index];
                          final user = turn['role'] == 'user';
                          return Align(
                            alignment: user
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Card(
                              color: user
                                  ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user ? 'You' : 'Blistra AI',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    SelectableText(turn['content']!),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      if (_draft != null)
                        TextButton(
                          onPressed: _busy ? null : _refreshDraft,
                          child: const Text('Refresh draft'),
                        ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        enabled: !_busy,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                          hintText: 'Ask about Blistra…',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Send message',
                      onPressed: _busy ? null : _send,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
