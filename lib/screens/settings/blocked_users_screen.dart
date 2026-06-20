import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../utils/auth_error.dart' show avatarInitial;
import '../../l10n/app_localizations.dart';
import '../../models/profile.dart';
import '../../services/block_service.dart';
import '../../services/local_cache.dart';
import '../../widgets/premium_toast.dart';

/// 已拉黑用户管理页：查看并解除拉黑。
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final _blockService = BlockService();
  List<Profile> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final users = await _blockService.getBlockedProfiles();
      if (mounted) setState(() => _users = users);
    } catch (e) {
      if (mounted) showErrorIfNotNetwork(context, e, '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unblock(Profile p) async {
    setState(() => _users.removeWhere((u) => u.id == p.id));
    try {
      await _blockService.unblockUser(p.id);
      if (mounted) {
        showPremiumToast(context, AppLocalizations.of(context).userUnblocked(p.displayName),
            kind: ToastKind.success);
      }
    } catch (e) {
      if (mounted) {
        showErrorIfNotNetwork(context, e, '$e');
        _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.blockedUsers)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? Center(
                  child: Text(l.noBlockedUsers,
                      style: const TextStyle(color: Color(0xFF8E8E93))))
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (context, i) {
                    final p = _users[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFE6E0F0),
                        backgroundImage: p.avatarUrl != null
                            ? CachedNetworkImageProvider(p.avatarUrl!)
                            : null,
                        child: p.avatarUrl == null
                            ? Text(p.displayName.isNotEmpty
                                ? avatarInitial(p.displayName)
                                : '?')
                            : null,
                      ),
                      title: Text(p.displayName),
                      trailing: OutlinedButton(
                        onPressed: () => _unblock(p),
                        child: Text(l.unblock),
                      ),
                    );
                  },
                ),
    );
  }
}
