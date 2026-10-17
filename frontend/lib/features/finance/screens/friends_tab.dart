/// Friends: add by username, answer requests, and see who owes whom.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add a friend', style: TextStyle(fontWeight: FontWeight.w700, color: colors.text)),
              const SizedBox(height: 4),
              Text(
                data.me == null
                    ? 'Ask them for their Blistra username.'
                    : 'Ask them for their Blistra username. Yours is @${data.me!.username}.',
                style: TextStyle(color: colors.muted, fontSize: 12.5),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('friend-username'),
                      controller: _username,
                      autocorrect: false,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _add(),
                      decoration: const InputDecoration(prefixText: '@', hintText: 'username', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(72, 48)),
                    onPressed: _adding ? null : _add,
                    child: _adding
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Add'),
                  ),
                ],
              ),
              if (_message != null) ...[
                const SizedBox(height: 8),
                Text(_message!,
                    style: TextStyle(color: _messageIsError ? oweColor : owedColor, fontSize: 12.5)),
              ],
            ],
          ),
        ),
        if (data.incoming.isNotEmpty) ...[
          const SectionLabel('Requests'),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final r in data.incoming)
                  ListTile(
                    leading: UserAvatar(r.user),
                    title: Text(r.user.displayName),
                    subtitle: Text('@${r.user.username} wants to split expenses'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Decline',
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
          const SectionLabel('Balances'),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [for (final f in withBalance) _FriendTile(friend: f, onTap: () => widget.onOpen(f.user))]),
          ),
        ],
        if (settled.isNotEmpty) ...[
          SectionLabel(withBalance.isEmpty ? 'Friends' : 'Settled up'),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [for (final f in settled) _FriendTile(friend: f, onTap: () => widget.onOpen(f.user))]),
          ),
        ],
        if (data.outgoing.isNotEmpty) ...[
          const SectionLabel('Waiting for them'),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final r in data.outgoing)
                  ListTile(
                    leading: UserAvatar(r.user),
                    title: Text(r.user.displayName),
                    subtitle: Text('@${r.user.username} · request sent'),
                    trailing: TextButton(
                      onPressed: () => _run(() => controller.dismissRequest(r)),
                      child: const Text('Cancel'),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (data.friends.isEmpty && data.incoming.isEmpty && data.outgoing.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 36),
            child: Column(
              children: [
                Icon(Icons.groups_rounded, size: 46, color: colors.muted),
                const SizedBox(height: 10),
                Text('Split bills with friends',
                    style: TextStyle(fontWeight: FontWeight.w600, color: colors.text)),
                const SizedBox(height: 4),
                Text(
                  'Add friends by username, split any expense, and Blistra keeps track of who owes whom.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.muted),
                ),
              ],
            ),
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
    return ListTile(
      onTap: onTap,
      leading: UserAvatar(friend.user),
      title: Text(friend.user.displayName, style: TextStyle(fontWeight: FontWeight.w600, color: colors.text)),
      subtitle: Text(friend.isFriend ? '@${friend.user.username}' : '@${friend.user.username} · not a friend'),
      trailing: SizedBox(
        width: 130,
        child: Text(
          balanceSentence(friend.balances),
          textAlign: TextAlign.end,
          maxLines: 2,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
            color: balanceColor(friend.balances, colors),
          ),
        ),
      ),
    );
  }
}
