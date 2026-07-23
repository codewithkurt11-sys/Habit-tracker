import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/app_state.dart';
import '../../services/auth_service.dart';
import '../../services/friends_repository.dart';
import '../../core/theme/app_spacing.dart';
import 'friend_profile_screen.dart';

/// Friends hub: shows your account status (sign-in / username), your friends
/// list, incoming requests, and a search field to find new friends by username.
class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final auth = state.authService;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SizedBox(height: AppSpacing.lg),

        // ---------- Account section ----------
        _AccountCard(state: state, auth: auth),
        const SizedBox(height: AppSpacing.xl),

        // ---------- Incoming requests ----------
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: state.friendsRepo.incomingRequestsStream(),
          builder: (context, snapshot) {
            final requests = snapshot.data ?? [];
            if (requests.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Friend Requests (${requests.length})',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Card(
                  child: Column(
                    children: requests.map((req) {
                      final fromUid = req['fromUid'] as String? ?? '';
                      return FutureBuilder(
                        future: _fetchProfile(state.friendsRepo, fromUid),
                        builder: (context, snap) {
                          final profile = snap.data;
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                  profile?.displayName.isNotEmpty == true
                                      ? profile!.displayName[0].toUpperCase()
                                      : '?'),
                            ),
                            title: Text(profile?.username ??
                                profile?.displayName ??
                                'Unknown'),
                            subtitle: Text(profile?.displayName ?? ''),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check,
                                      color: Colors.green),
                                  onPressed: () =>
                                      state.friendsRepo.acceptRequest(fromUid),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.red),
                                  onPressed: () =>
                                      state.friendsRepo.declineRequest(fromUid),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            );
          },
        ),

        // ---------- Friends list ----------
        Text('Your Friends', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        StreamBuilder<List<FriendProfile>>(
          stream: state.friendsRepo.friendsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Card(
                  child: ListTile(title: Text('Loading friends...')));
            }
            final friends = snapshot.data ?? [];
            if (friends.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      Icon(Icons.people_outline,
                          size: 40,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.3)),
                      const SizedBox(height: AppSpacing.sm),
                      Text('No friends yet', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text('Search for a friend by username below.',
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              );
            }
            return Card(
              child: Column(
                children: friends.map((f) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          f.photoUrl != null && f.photoUrl!.isNotEmpty
                              ? NetworkImage(f.photoUrl!)
                              : null,
                      child: f.photoUrl == null || f.photoUrl!.isEmpty
                          ? Text(f.displayName.isNotEmpty
                              ? f.displayName[0].toUpperCase()
                              : '?')
                          : null,
                    ),
                    title: Text(f.username ?? f.displayName),
                    subtitle: Text(f.displayName),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FriendProfileScreen(friend: f),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),

        // ---------- Search by username ----------
        const _SearchByUsernameSection(),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Future<FriendProfile> _fetchProfile(
      FriendsRepository repo, String uid) async {
    // Simple in-memory cache could be added; for now fetch directly.
    try {
      final users = await repo.searchByUsername('');
      return users.firstWhere((p) => p.uid == uid,
          orElse: () => FriendProfile(uid: uid, displayName: 'User'));
    } catch (_) {
      return FriendProfile(uid: uid, displayName: 'User');
    }
  }
}

class _AccountCard extends StatelessWidget {
  final AppState state;
  final AuthService auth;
  const _AccountCard({required this.state, required this.auth});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Text('Cloud Sync', style: theme.textTheme.titleMedium),
                const Spacer(),
                if (auth.isSignedIn)
                  StreamBuilder(
                    stream: Stream.periodic(const Duration(seconds: 0)),
                    builder: (_, __) => Chip(
                      label: Text(
                          state.syncService.isOnline ? 'Online' : 'Offline',
                          style: const TextStyle(fontSize: 11)),
                      avatar: Icon(
                        state.syncService.isOnline
                            ? Icons.wifi
                            : Icons.wifi_off,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (!auth.isSignedIn) ...[
              Text(
                'Sign in with Google to sync your habits, goals, tasks, and schedule to the cloud, '
                'and see friends\' activity.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _signIn(context),
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in with Google'),
                ),
              ),
            ] else ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundImage: auth.photoUrl != null
                      ? NetworkImage(auth.photoUrl!)
                      : null,
                  child: auth.photoUrl == null
                      ? Text(auth.displayName?.isNotEmpty == true
                          ? auth.displayName![0].toUpperCase()
                          : '?')
                      : null,
                ),
                title: Text(auth.displayName ?? 'User'),
                subtitle: Text(auth.username != null
                    ? '@${auth.username}'
                    : 'No username claimed yet'),
                trailing: TextButton(
                  onPressed: () => auth.signOut(),
                  child: const Text('Sign out'),
                ),
              ),
              if (auth.username == null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showClaimUsernameDialog(context),
                    icon: const Icon(Icons.alternate_email),
                    label: const Text('Claim a username'),
                  ),
                )
              else
                Text(
                  'Your data syncs automatically when online. Sign out keeps all local data.',
                  style: theme.textTheme.bodySmall,
                ),
            ],
            if (auth.lastError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(auth.lastError!,
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _signIn(BuildContext context) async {
    final result = await auth.signInWithGoogle();
    if (result == AuthResult.success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed in successfully!')),
      );
    } else if (result == AuthResult.error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(auth.lastError ?? 'Sign-in failed.')),
        );
      }
    }
  }

  void _showClaimUsernameDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Claim a username'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('3-20 chars: lowercase letters, numbers, underscore.',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                prefixText: '@',
                hintText: 'your_name',
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              final ok = await auth.claimUsername(name);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'Username claimed!'
                        : (auth.lastError ?? 'Failed')),
                  ),
                );
              }
            },
            child: const Text('Claim'),
          ),
        ],
      ),
    );
  }
}

class _SearchByUsernameSection extends StatefulWidget {
  const _SearchByUsernameSection();

  @override
  State<_SearchByUsernameSection> createState() =>
      _SearchByUsernameSectionState();
}

class _SearchByUsernameSectionState extends State<_SearchByUsernameSection> {
  final _controller = TextEditingController();
  List<FriendProfile> _results = [];
  bool _searching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(AppState state) async {
    final q = _controller.text.trim();
    if (q.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    final results = await state.friendsRepo.searchByUsername(q);
    if (mounted) {
      setState(() {
        _results = results;
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final auth = state.authService;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Find a Friend', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (!auth.isSignedIn)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Sign in to search for friends by username.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          )
        else ...[
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Search by @username...',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: _searching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ))
                  : IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () => _search(state),
                    ),
            ),
            onSubmitted: (_) => _search(state),
            textCapitalization: TextCapitalization.none,
            autocorrect: false,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_results.isNotEmpty)
            Card(
              child: Column(
                children: _results.map((f) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          f.photoUrl != null && f.photoUrl!.isNotEmpty
                              ? NetworkImage(f.photoUrl!)
                              : null,
                      child: f.photoUrl == null || f.photoUrl!.isEmpty
                          ? Text(f.displayName.isNotEmpty
                              ? f.displayName[0].toUpperCase()
                              : '?')
                          : null,
                    ),
                    title: Text(
                        f.username != null ? '@${f.username}' : f.displayName),
                    subtitle: Text(f.displayName),
                    trailing: IconButton(
                      icon: const Icon(Icons.person_add_outlined),
                      onPressed: () {
                        state.friendsRepo.sendRequest(f.uid);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Friend request sent to @${f.username}')),
                        );
                      },
                    ),
                  );
                }).toList(),
              ),
            )
          else if (!_searching && _controller.text.isNotEmpty)
            Text('No results.', style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}
