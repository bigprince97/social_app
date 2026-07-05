import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../utils/auth_error.dart' show avatarInitial;
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
import '../../models/profile.dart';
import '../../services/profile_service.dart';

enum FollowListType { followers, following }

class FollowListScreen extends StatefulWidget {
  final String userId;
  final String displayName;
  final FollowListType type;

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.displayName,
    required this.type,
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  final _service = ProfileService();
  List<Profile> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = widget.type == FollowListType.followers
          ? await _service.getFollowers(widget.userId)
          : await _service.getFollowing(widget.userId);
      if (mounted) setState(() => _list = result);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == FollowListType.followers
        ? AppLocalizations.of(context).followersList(widget.displayName)
        : AppLocalizations.of(context).followingList(widget.displayName);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _list.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.7,
                        child: Center(
                          child: Text(
                            widget.type == FollowListType.followers
                                ? AppLocalizations.of(context).noFollowers
                                : AppLocalizations.of(context).noFollowing,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withAlpha(120),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _list.length,
                    itemBuilder: (context, i) {
                        final p = _list[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: p.avatarUrl != null
                                ? CachedNetworkImageProvider(p.avatarUrl!)
                                : null,
                            child: p.avatarUrl == null
                                ? Text(avatarInitial(p.displayName))
                                : null,
                          ),
                          title: Text(p.displayName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text('@${p.username}'),
                          trailing: Text(
                            AppLocalizations.of(context).followerCount(p.followersCount),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          onTap: () => context.push('/profile/${p.id}'),
                        );
                      },
                    ),
            ),
    );
  }
}
