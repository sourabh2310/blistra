/// Friends: add by username, answer requests, and see who owes whom.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../../../core/widgets/glass.dart';
import '../finance_controller.dart';
import '../models.dart';
import '../widgets/finance_widgets.dart';

class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key, required this.onOpen});

  final ValueChanged<UserSummary> onOpen;

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  final _username = TextEditingController();
  bool _adding = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final username = _username.text.trim().replaceFirst(RegExp('^@'), '');
    if (username.isEmpty) {
      setState(() {
        _message = 'Enter your friend\'s username';
        _messageIsError = true;
      });
      return;
    }
    setState(() {
      _adding = true;
      _message = null;
    });
    try {
      final status = await context.read<FinanceController>().addFriend(username);
      _username.clear();
      setState(() {
        _message = status == 'ACCEPTED'
            ? 'You and @$username are now friends'
            : 'Request sent to @$username. You can split once they accept.';
        _messageIsError = false;
      });
    } catch (e) {
      setState(() {
        _message = friendlyError(e);
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final controller = context.watch<FinanceController>();
    final data = controller.friends;
    final withBalance = data.friends.where((f) => !f.settled).toList();
    final settled = data.friends.where((f) => f.settled).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 120),
      children: [
        PagePad(
          GlassCard(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('ADD A FRIEND', style: BlistraText.caption(colors.muted)),
                const SizedBox(height: 4),
                Text(
                  data.me == null
                      ? 'Ask them for their Blistra username.'
                      : 'Ask them for their Blistra username. Yours is @${data.me!.username}.',
                  style: TextStyle(color: colors.muted, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        decoration: BoxDecoration(
                          color: colors.inkAt(0.06),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: TextField(
                          key: const Key('friend-username'),
                          controller: _username,
                          autocorrect: false,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _add(),
                          style: TextStyle(fontSize: 14, color: colors.text),
                          decoration: InputDecoration(
                            prefixText: '@',
                            prefixStyle: TextStyle(fontSize: 14, color: colors.muted),
                            hintText: 'username',
                            isDense: true,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(72, 44)),
                      onPressed: _adding ? null : _add,
                      child: _adding
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: colors.onAccent),
                            )
                          : const Text('Add'),
                    ),
                  ],
                ),
                if (_message != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _message!,
                    style: TextStyle(
                      color: _messageIsError ? colors.danger : colors.accentText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (data.incoming.isNotEmpty) ...[
          const SizedBox(height: 24),
          const SectionHeader(title: 'Requests'),
          PagePad(
            GlassList(
              children: [
                for (final r in data.incoming)
                  GlassRow(
                    leading: UserAvatar(r.user),
                    title: r.user.displayName,
                    subtitle: '@${r.user.username} wants to split expenses',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Decline',
                          color: colors.muted,
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => _run(() => controller.dismissRequest(r)),
                        ),
                        IconButton.filled(
                          tooltip: 'Accept',
                          icon: const Icon(Icons.check_rounded),
                          onPressed: () => _run(() => controller.acceptRequest(r)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (withBalance.isNotEmpty) ...[
          const SizedBox(height: 24),
          const SectionHeader(title: 'Balances'),
          PagePad(
            GlassList(
              children: [for (final f in withBalance) _FriendTile(friend: f, onTap: () => widget.onOpen(f.user))],
            ),
          ),
        ],
        if (settled.isNotEmpty) ...[
          const SizedBox(height: 24),
          SectionHeader(title: withBalance.isEmpty ? 'Friends' : 'Settled up'),
          PagePad(
            GlassList(
              children: [for (final f in settled) _FriendTile(friend: f, onTap: () => widget.onOpen(f.user))],
            ),
          ),
        ],
        if (data.outgoing.isNotEmpty) ...[
          const SizedBox(height: 24),
          const SectionHeader(title: 'Waiting for them'),
          PagePad(
            GlassList(
              children: [
                for (final r in data.outgoing)
                  GlassRow(
                    leading: UserAvatar(r.user),
                    title: r.user.displayName,
                    subtitle: '@${r.user.username} · request sent',
                    trailing: Pill(
                      'Cancel',
                      color: colors.muted,
                      onTap: () => _run(() => controller.dismissRequest(r)),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (data.friends.isEmpty && data.incoming.isEmpty && data.outgoing.isEmpty)
          const PagePad(
            EmptyCard(
              message: 'Split bills with friends. Add friends by username, split any expense, '
                  'and Blistra keeps track of who owes whom.',
            ),
            top: 16,
          ),
      ],
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend, required this.onTap});

  final Friend friend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return GlassRow(
      onTap: onTap,
      leading: UserAvatar(friend.user),
      title: friend.user.displayName,
      subtitle: friend.isFriend ? '@${friend.user.username}' : '@${friend.user.username} · not a friend',
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 130),
        child: Text(
          balanceSentence(friend.balances),
          textAlign: TextAlign.end,
          maxLines: 2,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 11.5,
            color: balanceColor(friend.balances, colors),
          ),
        ),
      ),
    );
  }
}
