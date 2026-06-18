import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_localizations.dart';
import '../models/post.dart';
import '../models/profile.dart';
import '../services/profile_service.dart';
import '../theme/app_style.dart';
import '../widgets/post_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _profileService = ProfileService();
  final _client = Supabase.instance.client;
  final _searchCtrl = TextEditingController();
  late final TabController _tabCtrl;

  List<Profile> _userResults = [];
  List<Post> _postResults = [];
  List<Map<String, dynamic>> _scriptureResults = [];
  bool _searching = false;
  bool _hasSearched = false;
  String _lastQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final trimmed = q.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _userResults = [];
        _postResults = [];
        _scriptureResults = [];
        _hasSearched = false;
        _lastQuery = '';
      });
      return;
    }
    if (trimmed == _lastQuery) return;
    _lastQuery = trimmed;
    setState(() => _searching = true);
    try {
      final results = await Future.wait([
        _profileService.searchUsers(trimmed),
        _searchPosts(trimmed),
        _searchScriptures(trimmed),
      ]);
      if (mounted && trimmed == _lastQuery) {
        setState(() {
          _userResults = results[0] as List<Profile>;
          _postResults = results[1] as List<Post>;
          _scriptureResults = results[2] as List<Map<String, dynamic>>;
          _hasSearched = true;
        });
      }
    } catch (_) {
      // 离线/网络错误：静默，展示空结果，不抛未捕获异常
      if (mounted && trimmed == _lastQuery) {
        setState(() => _hasSearched = true);
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<List<Post>> _searchPosts(String q) async {
    final data = await _client
        .from('posts')
        .select('*, profiles!posts_user_id_fkey(*)')
        .ilike('content', '%$q%')
        .order('created_at', ascending: false)
        .limit(20);
    return (data as List).map((e) => Post.fromJson(e)).toList();
  }

  Future<List<Map<String, dynamic>>> _searchScriptures(String q) async {
    final data = await _client
        .from('scriptures')
        .select('id, title, category, author, dynasty')
        .or('title.ilike.%$q%,author.ilike.%$q%,description.ilike.%$q%')
        .limit(20);
    return (data as List).cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context).searchHint,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 8),
          ),
          onChanged: (v) {
            setState(() {});
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 400), () => _search(v));
          },
          onSubmitted: _search,
        ),
        actions: [
          if (_searchCtrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchCtrl.clear();
                _search('');
              },
            ),
        ],
        bottom: _hasSearched || _searching
            ? TabBar(
                controller: _tabCtrl,
                tabs: [
                  Tab(text: '${AppLocalizations.of(context).users} (${_userResults.length})'),
                  Tab(text: '${AppLocalizations.of(context).posts2} (${_postResults.length})'),
                  Tab(text: '${AppLocalizations.of(context).scripture} (${_scriptureResults.length})'),
                ],
              )
            : null,
      ),
      body: _searching
          ? const Center(child: CircularProgressIndicator())
          : !_hasSearched
              ? _buildEmptyState()
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildUserResults(),
                    _buildPostResults(),
                    _buildScriptureResults(),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return PremiumEmptyState(
      icon: Icons.search_rounded,
      title: AppLocalizations.of(context).search,
      subtitle: AppLocalizations.of(context).searchEmptySubtitle,
    );
  }

  Widget _buildUserResults() {
    if (_userResults.isEmpty) {
      return PremiumEmptyState(
        icon: Icons.person_search_rounded,
        title: AppLocalizations.of(context).emptyUsers,
      );
    }
    return ListView.builder(
      itemCount: _userResults.length,
      itemBuilder: (context, i) => _UserTile(profile: _userResults[i]),
    );
  }

  Widget _buildPostResults() {
    if (_postResults.isEmpty) {
      return PremiumEmptyState(
        icon: Icons.dynamic_feed_rounded,
        title: AppLocalizations.of(context).emptyPosts,
      );
    }
    return ListView.builder(
      itemCount: _postResults.length,
      itemBuilder: (context, i) => PostCard(post: _postResults[i]),
    );
  }

  Widget _buildScriptureResults() {
    if (_scriptureResults.isEmpty) {
      return PremiumEmptyState(
        icon: Icons.menu_book_rounded,
        title: AppLocalizations.of(context).emptyScriptures,
      );
    }
    return ListView.builder(
      itemCount: _scriptureResults.length,
      itemBuilder: (context, i) {
        final s = _scriptureResults[i];
        final title = s['title'] as String? ?? '';
        final author = s['author'] as String?;
        final dynasty = s['dynasty'] as String?;
        final category = s['category'] as String? ?? '';
        return ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                title.isNotEmpty ? title[0] : '经',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text([
            author,
            dynasty,
            category,
          ].whereType<String>().join(' · ')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/scripture/detail/${s['id']}'),
        );
      },
    );
  }
}

class _UserTile extends StatelessWidget {
  final Profile profile;

  const _UserTile({required this.profile});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: profile.avatarUrl != null
            ? CachedNetworkImageProvider(profile.avatarUrl!)
            : null,
        child: profile.avatarUrl == null
            ? Text(profile.displayName[0].toUpperCase())
            : null,
      ),
      title: Text(profile.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      trailing: Text(
        AppLocalizations.of(context).followerCount(profile.followersCount),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: () => context.push('/profile/${profile.id}'),
    );
  }
}
