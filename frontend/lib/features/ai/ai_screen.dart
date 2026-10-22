import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/blistra_ui.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/page_header.dart';
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

  void _clearChat() => setState(() {
    _turns.clear();
    _error = null;
    _input.clear();
    _share = false;
    _draft = null;
    _uploadDocument = false;
  });

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final canPop = Navigator.of(context).canPop();
    final empty =
        _turns.isEmpty && !_busy && _draft == null && !_uploadDocument;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Compact header so the chat still fits with the keyboard open.
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    kPageGutter,
                    8,
                    kPageGutter,
                    6,
                  ),
                  child: Row(
                    children: [
                      if (canPop) ...[
                        GlassIconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: 'Back',
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: 'Blistra '),
                              TextSpan(
                                text: 'AI',
                                style: TextStyle(color: colors.accentText),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          style: BlistraText.serif(24, colors.text),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Clear chat',
                        style: IconButton.styleFrom(
                          fixedSize: const Size(38, 38),
                          minimumSize: const Size(38, 38),
                          backgroundColor: colors.glassFill,
                          side: BorderSide(color: colors.glassBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: Icon(
                          Icons.delete_outline,
                          size: 19,
                          color: colors.text,
                        ),
                        onPressed: _busy || _approvalUncertain
                            ? null
                            : _clearChat,
                      ),
                    ],
                  ),
                ),
                if (!keyboardOpen)
                  PagePad(
                    top: 6,
                    GlassCard(
                      radius: 20,
                      padding: const EdgeInsets.fromLTRB(15, 12, 6, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 9),
                            child: Text(
                              'AI replies can be inaccurate. Messages go to the configured AI provider. '
                              'Entry details are sent for drafting and stored temporarily for review. Nothing is added until you approve.',
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.45,
                                color: colors.muted,
                              ),
                            ),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              'Share my daily summary',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: colors.text,
                              ),
                            ),
                            subtitle: Text(
                              'Today’s task, event, habit, dose and meal counts + water total. '
                              'No record details. Changing this clears chat context.',
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.muted,
                              ),
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
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: empty
                      ? ListView(
                          padding: const EdgeInsets.fromLTRB(
                            kPageGutter,
                            24,
                            kPageGutter,
                            16,
                          ),
                          children: [
                            Center(
                              child: IconWell(
                                Icons.auto_awesome_rounded,
                                size: 56,
                                color: colors.accentText,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'How can I help you with Blistra?',
                              textAlign: TextAlign.center,
                              style: BlistraText.serif(19, colors.text),
                            ),
                            const SizedBox(height: 18),
                            GlassList(
                              children: [
                                for (final prompt in [
                                  'What can I do in Blistra?',
                                  'Help me plan my day',
                                  'Help me build a habit',
                                ])
                                  GlassRow(
                                    leading: IconWell(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 32,
                                    ),
                                    title: prompt,
                                    trailing: Icon(
                                      Icons.north_east_rounded,
                                      size: 16,
                                      color: colors.muted,
                                    ),
                                    onTap: () {
                                      _input.text = prompt;
                                      _send();
                                    },
                                  ),
                              ],
                            ),
                          ],
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(
                            kPageGutter,
                            14,
                            kPageGutter,
                            12,
                          ),
                          itemCount:
                              _turns.length +
                              (_draft != null ? 1 : 0) +
                              (_uploadDocument ? 1 : 0) +
                              (_busy ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_draft != null && index == _turns.length) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: AiDraftCard(
                                  key: ValueKey(_draft!.id),
                                  api: widget.api,
                                  draft: _draft!,
                                  busy: _busy,
                                  onApprove: _approve,
                                  onEdit: _edit,
                                  onCancel: _cancel,
                                  onView: widget.onViewEntry == null
                                      ? null
                                      : () =>
                                            widget.onViewEntry!(_draft!.module),
                                ),
                              );
                            }
                            if (_uploadDocument &&
                                index ==
                                    _turns.length + (_draft != null ? 1 : 0)) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: FilledButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : widget.onUploadDocument,
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text(
                                    'Select and review document',
                                  ),
                                ),
                              );
                            }
                            if (index >= _turns.length) {
                              return const _Bubble(
                                user: false,
                                child: _Thinking(),
                              );
                            }
                            final turn = _turns[index];
                            final user = turn['role'] == 'user';
                            return _Bubble(
                              user: user,
                              child: SelectableText(
                                turn['content']!,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.45,
                                  color: colors.text,
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (_error != null)
                  PagePad(
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                      decoration: BoxDecoration(
                        color: colors.danger.withValues(
                          alpha: colors.isDark ? .16 : .1,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: colors.danger,
                                fontWeight: FontWeight.w500,
                              ),
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
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    kPageGutter,
                    4,
                    kPageGutter,
                    10,
                  ),
                  child: GlassCard(
                    radius: 26,
                    padding: const EdgeInsets.fromLTRB(16, 4, 5, 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: TextField(
                              controller: _input,
                              enabled: !_busy,
                              minLines: 1,
                              maxLines: 4,
                              maxLength: 2000,
                              style: TextStyle(
                                fontSize: 14,
                                color: colors.text,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Ask about Blistra…',
                                hintStyle: TextStyle(color: colors.muted),
                                filled: false,
                                isDense: true,
                                counterText: '',
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                              ),
                              onSubmitted: (_) => _send(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: 'Send message',
                          style: IconButton.styleFrom(
                            fixedSize: const Size(40, 40),
                            minimumSize: const Size(40, 40),
                            backgroundColor: colors.accentText,
                            disabledBackgroundColor: colors.accentText
                                .withValues(alpha: .4),
                            shape: const CircleBorder(),
                          ),
                          onPressed: _busy ? null : _send,
                          icon: Icon(
                            Icons.arrow_upward_rounded,
                            size: 20,
                            color: colors.onAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One chat message: accent-tinted on the right for the user, frosted glass
/// on the left for Blistra AI.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.user, required this.child});

  final bool user;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(user ? 20 : 6),
      bottomRight: Radius.circular(user ? 6 : 20),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: user ? Alignment.centerRight : Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: 0.86,
          alignment: user ? Alignment.centerRight : Alignment.centerLeft,
          child: Align(
            alignment: user ? Alignment.centerRight : Alignment.centerLeft,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                color: user ? colors.accentSoft : null,
                gradient: user
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [colors.glassFill, colors.glassFillEnd],
                      ),
                border: Border.all(
                  color: user
                      ? colors.accentText.withValues(alpha: .3)
                      : colors.glassBorder,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!user) ...[
                      Text(
                        'BLISTRA AI',
                        style: BlistraText.eyebrow(colors.accentText),
                      ),
                      const SizedBox(height: 4),
                    ],
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Text(
      'Blistra AI is thinking…',
      semanticsLabel: 'Waiting for AI response',
      style: TextStyle(fontSize: 13, color: colors.muted),
    );
  }
}
