import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/auth_error.dart' show avatarInitial;
import '../l10n/app_localizations.dart';
import '../models/profile.dart';
import '../services/friend_service.dart';
import '../services/local_cache.dart';
import '../services/profile_service.dart';
import '../theme/app_style.dart';
import '../widgets/premium_toast.dart';

/// 搜索用户 → 添加好友。
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _profileService = ProfileService();
  final _friendService = FriendService();
  final _searchCtrl = TextEditingController();

  List<Profile> _userResults = [];
  final Map<String, Friendship?> _relations = {};
  bool _searching = false;
  bool _hasSearched = false;
  String _lastQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final trimmed = q.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _userResults = [];
        _hasSearched = false;
        _lastQuery = '';
      });
      return;
    }
    if (trimmed == _lastQuery) return;
    _lastQuery = trimmed;
    setState(() => _searching = true);
    try {
      final results = await _profileService.searchUsers(trimmed);
      if (mounted && trimmed == _lastQuery) {
        setState(() {
          _userResults = results;
          _hasSearched = true;
        });
        _loadRelations(results);
      }
    } catch (_) {
      if (mounted && trimmed == _lastQuery) {
        setState(() => _hasSearched = true);
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _loadRelations(List<Profile> profiles) async {
    for (final p in profiles) {
      if (_relations.containsKey(p.id)) continue;
      try {
        final f = await _friendService.getFriendshipWith(p.id);
        if (mounted) setState(() => _relations[p.id] = f);
      } catch (_) {}
    }
  }

  Future<void> _sendRequest(Profile p) async {
    final t = AppLocalizations.of(context);
    try {
      await _friendService.sendRequest(p.id);
      _relations.remove(p.id);
      final f = await _friendService.getFriendshipWith(p.id);
      if (mounted) {
        setState(() => _relations[p.id] = f);
        showPremiumToast(context, t.friendRequestSentToast,
            kind: ToastKind.success);
      }
    } catch (e) {
      if (mounted) {
        if (e is BlockedUserInteractionException) {
          showPremiumToast(context, t.blockedInteraction,
              kind: ToastKind.block);
          return;
        }
        showErrorIfNotNetwork(context, e, t.operationFailed(e.toString()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: t.searchUsersHint,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          textInputAction: TextInputAction.search,
          onChanged: (v) => setState(() {}),
          onSubmitted: _search,
        ),
        actions: [
          if (_searchCtrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => _search(_searchCtrl.text),
            ),
          if (_searchCtrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchCtrl.clear();
                _search('');
              },
            ),
        ],
      ),
      body: _searching
          ? const Center(child: CircularProgressIndicator())
          : !_hasSearched
              ? PremiumEmptyState(
                  icon: Icons.person_search_rounded,
                  title: t.addFriend,
                  subtitle: t.searchUsersHint,
                )
              : _userResults.isEmpty
                  ? PremiumEmptyState(
                      icon: Icons.person_search_rounded,
                      title: t.emptyUsers,
                    )
                  : ListView.builder(
                      itemCount: _userResults.length,
                      itemBuilder: (context, i) => _UserTile(
                        profile: _userResults[i],
                        friendship: _relations[_userResults[i].id],
                        onAdd: () => _sendRequest(_userResults[i]),
                        onChanged: () async {
                          _relations.remove(_userResults[i].id);
                          _loadRelations([_userResults[i]]);
                        },
                      ),
                    ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final Profile profile;
  final Friendship? friendship;
  final VoidCallback onAdd;
  final VoidCallback onChanged;

  const _UserTile({
    required this.profile,
    required this.friendship,
    required this.onAdd,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final myId = Supabase.instance.client.auth.currentUser?.id ?? '';
    Widget trailing;
    final f = friendship;
    if (f == null) {
      trailing = TextButton.icon(
        onPressed: onAdd,
        style: TextButton.styleFrom(
          backgroundColor: AppStyle.brand,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        icon: const Icon(Icons.person_add_alt_1, size: 16),
        label: Text(t.addFriend),
      );
    } else if (f.status == 'accepted') {
      trailing = Text(
        t.alreadyFriends,
        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
      );
    } else {
      // pending：我发出的显示"已发送申请"，对方发来的显示"待你处理"
      trailing = Text(
        f.requesterId == myId ? t.friendRequestSent : t.friendRequestPending,
        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
      );
    }
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: profile.avatarUrl != null
            ? CachedNetworkImageProvider(profile.avatarUrl!)
            : null,
        child: profile.avatarUrl == null
            ? Text(avatarInitial(profile.displayName))
            : null,
      ),
      title: Text(
        profile.displayName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text('@${profile.username}'),
      trailing: trailing,
      onTap: () async {
        await context.push('/profile/${profile.id}');
        onChanged();
      },
    );
  }
}
