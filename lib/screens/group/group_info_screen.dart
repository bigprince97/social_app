import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/conversation.dart';
import '../../services/chat_service.dart';
import '../../theme/app_style.dart';
import '../../widgets/premium_action_sheet.dart';
import '../../l10n/app_localizations.dart';
import 'group_files_screen.dart';

class GroupInfoScreen extends StatefulWidget {
  final Conversation conversation;
  final void Function(String announcement)? onAnnouncementUpdated;

  const GroupInfoScreen({
    super.key,
    required this.conversation,
    this.onAnnouncementUpdated,
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final _client = Supabase.instance.client;
  final _chatService = ChatService();
  late String? _announcement;
  bool _saving = false;
  late bool _isAdmin;
  late final String _myId;
  late List<ConversationMember> _members;

  @override
  void initState() {
    super.initState();
    _announcement = widget.conversation.announcement;
    _myId = _client.auth.currentUser?.id ?? '';
    _members = List.of(widget.conversation.members);
    _recomputeIsAdmin();
  }

  void _recomputeIsAdmin() {
    _isAdmin =
        _members.any((m) => m.userId == _myId && m.role == 'admin');
  }

  /// 成员变更后就地刷新名单，不退出页面
  Future<void> _reloadMembers() async {
    try {
      final convs = await _chatService.getConversations();
      final conv = convs.firstWhere((c) => c.id == widget.conversation.id);
      if (mounted) {
        setState(() {
          _members = List.of(conv.members);
          _recomputeIsAdmin();
        });
      }
    } catch (_) {}
  }

  // ─── Announcement ────────────────────────────────────────────────────────

  Future<void> _editAnnouncement() async {
    final ctrl = TextEditingController(text: _announcement);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).editGroupAnnouncement),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          autofocus: true,
          decoration:
              InputDecoration(hintText: AppLocalizations.of(context).announcementHint),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context).cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(AppLocalizations.of(context).save),
          ),
        ],
      ),
    );
    if (result == null) return;
    setState(() => _saving = true);
    try {
      await _client.from('conversations').update({
        'announcement': result.isEmpty ? null : result,
        'announcement_updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.conversation.id);
      setState(() => _announcement = result.isEmpty ? null : result);
      widget.onAnnouncementUpdated?.call(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).saveFailed(e.toString()))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── Member management ────────────────────────────────────────────────────

  Future<void> _removeMember(ConversationMember member) async {
    final confirm = await _confirmDialog(
      title: AppLocalizations.of(context).removeFromGroup,
      content: '确定要将 ${member.profile?.displayName ?? '该成员'} 移出群聊吗？',
      confirmLabel: '移出',
      destructive: true,
    );
    if (!confirm) return;
    try {
      await _client
          .from('conversation_members')
          .delete()
          .eq('id', member.id);
      await _reloadMembers();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).removedFromGroup)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).operationFailed(e.toString()))));
      }
    }
  }

  Future<void> _promoteToAdmin(ConversationMember member) async {
    final confirm = await _confirmDialog(
      title: AppLocalizations.of(context).promoteToAdmin,
      content:
          '确定要将 ${member.profile?.displayName ?? '该成员'} 设为管理员吗？',
      confirmLabel: AppLocalizations.of(context).confirm,
    );
    if (!confirm) return;
    try {
      await _chatService.promoteToAdmin(member.id);
      await _reloadMembers();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).promotedToAdmin)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).operationFailed(e.toString()))));
      }
    }
  }

  Future<void> _demoteToMember(ConversationMember member) async {
    final confirm = await _confirmDialog(
      title: AppLocalizations.of(context).demoteAdmin,
      content:
          '确定要撤销 ${member.profile?.displayName ?? '该成员'} 的管理员权限吗？',
      confirmLabel: AppLocalizations.of(context).confirm,
      destructive: true,
    );
    if (!confirm) return;
    try {
      await _chatService.demoteToMember(member.id);
      await _reloadMembers();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).demotedAdmin)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).operationFailed(e.toString()))));
      }
    }
  }

  Future<void> _leaveGroup() async {
    final me = widget.conversation.members
        .where((m) => m.userId == _myId)
        .firstOrNull;
    if (me == null) {
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }
    // shadow as non-nullable for the rest of the method
    final meMember = me;
    final confirm = await _confirmDialog(
      title: AppLocalizations.of(context).leaveGroup,
      content: AppLocalizations.of(context).confirmLeaveGroup,
      confirmLabel: AppLocalizations.of(context).confirmButton,
      destructive: true,
    );
    if (!confirm) return;
    try {
      await _client.from('conversation_members').delete().eq('id', meMember.id);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).leaveFailed(e.toString()))));
      }
    }
  }

  Future<void> _disbandGroup() async {
    final confirm = await _confirmDialog(
      title: AppLocalizations.of(context).disbandGroup,
      content: AppLocalizations.of(context).confirmDisbandGroup,
      confirmLabel: '解散',
      destructive: true,
    );
    if (!confirm) return;
    try {
      await _chatService.disbandGroup(widget.conversation.id);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).operationFailed(e.toString()))));
      }
    }
  }

  Future<bool> _confirmDialog({
    required String title,
    required String content,
    required String confirmLabel,
    bool destructive = false,
  }) {
    return showPremiumConfirm(
      context,
      title: title,
      message: content,
      confirmLabel: confirmLabel,
      destructive: destructive,
      icon: destructive ? Icons.warning_amber_rounded : Icons.help_outline_rounded,
    );
  }

  // ─── Member action menu ───────────────────────────────────────────────────

  void _showMemberActions(ConversationMember member) {
    final isMe = member.userId == _myId;
    if (isMe || !_isAdmin) return;
    final isAdmin = member.role == 'admin';
    showPremiumActionSheet(
      context,
      title: member.profile?.displayName ?? '成员',
      actions: [
        if (!isAdmin)
          PremiumAction(
            icon: Icons.admin_panel_settings_outlined,
            label: AppLocalizations.of(context).promoteToAdmin,
            color: const Color(0xFF0A84FF),
            onTap: () {
              Navigator.pop(context);
              _promoteToAdmin(member);
            },
          ),
        if (isAdmin)
          PremiumAction(
            icon: Icons.remove_moderator_outlined,
            label: AppLocalizations.of(context).demoteAdmin,
            color: const Color(0xFFFF9F0A),
            onTap: () {
              Navigator.pop(context);
              _demoteToMember(member);
            },
          ),
        PremiumAction(
          icon: Icons.remove_circle_outline,
          label: AppLocalizations.of(context).removeFromGroup,
          destructive: true,
          onTap: () {
            Navigator.pop(context);
            _removeMember(member);
          },
        ),
      ],
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final conv = widget.conversation;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).groupInfo),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
      body: ListView(
        children: [
          // 群名称 & 头像
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    (conv.name ?? AppLocalizations.of(context).group)[0],
                    style: TextStyle(
                        fontSize: 24,
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conv.name ?? AppLocalizations.of(context).group,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        AppLocalizations.of(context).memberCount(_members.length),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),

          // 群公告
          ListTile(
            leading: const Icon(Icons.campaign_outlined),
            title: Text(AppLocalizations.of(context).announcement),
            subtitle: _announcement?.isNotEmpty == true
                ? Text(_announcement!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis)
                : Text(
                    _isAdmin ? AppLocalizations.of(context).clickToSetAnnouncement : AppLocalizations.of(context).noAnnouncement,
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withAlpha(120))),
            trailing: _isAdmin ? const Icon(Icons.edit_outlined) : null,
            onTap: _isAdmin ? _editAnnouncement : null,
          ),
          const Divider(),

          // 群文件
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(AppLocalizations.of(context).groupFiles),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GroupFilesScreen(
                  conversationId: conv.id,
                  conversationName: conv.name ?? AppLocalizations.of(context).group,
                ),
              ),
            ),
          ),
          const Divider(),

          // 成员列表
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              AppLocalizations.of(context).members(_members.length),
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          ..._members.map((m) {
            final isMe = m.userId == _myId;
            return ListTile(
              onTap: () => _showMemberActions(m),
              leading: CircleAvatar(
                backgroundColor:
                    Theme.of(context).colorScheme.secondaryContainer,
                child: Text(
                  (m.profile?.displayName ?? '?')[0].toUpperCase(),
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSecondaryContainer),
                ),
              ),
              title: Text(
                m.profile?.displayName ?? m.userId,
                style: isMe
                    ? const TextStyle(fontWeight: FontWeight.bold)
                    : null,
              ),
              subtitle: isMe ? Text(AppLocalizations.of(context).you) : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (m.role == 'admin')
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        AppLocalizations.of(context).admin,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                        ),
                      ),
                    ),
                  if (_isAdmin && !isMe)
                    const Icon(Icons.more_vert,
                        size: 18, color: Colors.grey),
                ],
              ),
            );
          }),
          const Divider(),

          // 退出群聊
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: Text(AppLocalizations.of(context).leaveGroup,
                style: const TextStyle(color: Colors.red)),
            onTap: _leaveGroup,
          ),

          // 解散群聊（仅管理员）
          if (_isAdmin) ...[
            ListTile(
              leading:
                  const Icon(Icons.delete_forever, color: Colors.red),
              title: Text(AppLocalizations.of(context).disbandGroup,
                  style: const TextStyle(color: Colors.red)),
              onTap: _disbandGroup,
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
