import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/message.dart';
import '../../services/chat_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_style.dart';
import '../../widgets/premium_action_sheet.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/premium_toast.dart';

class _Folder {
  final String id;
  final String name;
  final DateTime createdAt;
  _Folder({required this.id, required this.name, required this.createdAt});
  factory _Folder.fromJson(Map<String, dynamic> j) => _Folder(
    id: j['id'] as String,
    name: j['name'] as String,
    createdAt: DateTime.parse(j['created_at'] as String),
  );
}

class GroupFilesScreen extends StatefulWidget {
  final String conversationId;
  final String conversationName;

  const GroupFilesScreen({
    super.key,
    required this.conversationId,
    required this.conversationName,
  });

  @override
  State<GroupFilesScreen> createState() => _GroupFilesScreenState();
}

class _GroupFilesScreenState extends State<GroupFilesScreen> {
  final _client = Supabase.instance.client;
  final _chatService = ChatService();
  final _storageService = StorageService();
  List<Message> _files = [];
  List<_Folder> _folders = [];
  // message_id -> folder_id
  Map<String, String> _assignments = {};
  bool _loading = true;
  bool _uploading = false;

  // 当前所在文件夹（null = 根目录）
  String? _currentFolderId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final fileData = await _client
          .from('messages')
          .select('*, profiles(*)')
          .eq('conversation_id', widget.conversationId)
          .eq('message_type', 'file')
          .eq('is_deleted', false)
          .order('created_at', ascending: false)
          .limit(200);
      final folderData = await _client
          .from('group_folders')
          .select()
          .eq('conversation_id', widget.conversationId)
          .order('created_at', ascending: false);
      final assignData = await _client
          .from('group_file_folders')
          .select('message_id, folder_id')
          .eq('conversation_id', widget.conversationId);

      if (!mounted) return;
      setState(() {
        _files = (fileData as List).map((e) => Message.fromJson(e)).toList();
        _folders = (folderData as List)
            .map((e) => _Folder.fromJson(e))
            .toList();
        _assignments = {
          for (final a in assignData as List)
            a['message_id'] as String: a['folder_id'] as String,
        };
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── 文件夹增删 ──────────────────────────────────────────────

  Future<void> _createFolder() async {
    final name = await _promptName();
    if (!mounted) return;
    if (name == null || name.trim().isEmpty) return;
    try {
      await _client.from('group_folders').insert({
        'conversation_id': widget.conversationId,
        'name': name.trim(),
        'created_by': _client.auth.currentUser?.id,
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack(AppLocalizations.of(context).createFailed(e.toString()));
    }
  }

  Future<void> _deleteFolder(_Folder f) async {
    final ok = await showPremiumConfirm(
      context,
      icon: Icons.folder_delete_outlined,
      title: AppLocalizations.of(context).deleteFolder,
      message: AppLocalizations.of(context).confirmDeleteFolder(f.name),
      confirmLabel: AppLocalizations.of(context).delete,
      destructive: true,
    );
    if (!mounted) return;
    if (!ok) return;
    try {
      await _client.from('group_folders').delete().eq('id', f.id);
      if (_currentFolderId == f.id) _currentFolderId = null;
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack(AppLocalizations.of(context).deleteFailed(e.toString()));
    }
  }

  Future<void> _renameFolder(_Folder f) async {
    final name = await _promptName(initial: f.name);
    if (!mounted) return;
    if (name == null || name.trim().isEmpty) return;
    try {
      await _client
          .from('group_folders')
          .update({'name': name.trim()})
          .eq('id', f.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack(AppLocalizations.of(context).renameFailed(e.toString()));
    }
  }

  Future<String?> _promptName({String? initial}) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          initial == null
              ? AppLocalizations.of(context).createFolder
              : AppLocalizations.of(context).renameFolder,
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context).folderName,
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(AppLocalizations.of(context).confirm),
          ),
        ],
      ),
    );
  }

  // ── 文件归属 ────────────────────────────────────────────────

  Future<void> _moveFile(Message msg) async {
    final currentFolder = _assignments[msg.id];
    showPremiumActionSheet(
      context,
      title: AppLocalizations.of(
        context,
      ).moveFileTo(msg.fileName ?? AppLocalizations.of(context).files),
      actions: [
        PremiumAction(
          icon: Icons.home_outlined,
          label: AppLocalizations.of(context).rootDirectory,
          color: AppStyle.blue,
          onTap: () {
            Navigator.pop(context);
            _assignFile(msg.id, null);
          },
        ),
        for (final f in _folders)
          PremiumAction(
            icon: currentFolder == f.id ? Icons.folder : Icons.folder_outlined,
            label: f.name,
            color: AppStyle.orange,
            onTap: () {
              Navigator.pop(context);
              _assignFile(msg.id, f.id);
            },
          ),
      ],
    );
  }

  Future<void> _assignFile(String messageId, String? folderId) async {
    try {
      if (folderId == null) {
        await _client
            .from('group_file_folders')
            .delete()
            .eq('message_id', messageId);
      } else {
        await _client.from('group_file_folders').upsert({
          'message_id': messageId,
          'folder_id': folderId,
          'conversation_id': widget.conversationId,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack(AppLocalizations.of(context).moveFailed(e.toString()));
    }
  }

  // 直接在群文件页上传文件：选文件→上传→发为文件消息→（若在文件夹内）归入当前文件夹
  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (!mounted) return;
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;
    setState(() => _uploading = true);
    try {
      final up = await _storageService.uploadChatFile(
        Uint8List.fromList(bytes),
        f.name,
      );
      final ext = f.name.contains('.') ? f.name.split('.').last : '';
      final msg = await _chatService.sendFileMessage(
        conversationId: widget.conversationId,
        fileUrl: up.url,
        fileName: f.name,
        fileSize: up.size,
        mimeType: ext.isEmpty ? null : 'application/$ext',
        filesOnly: true, // 仅进群文件，不在聊天中显示
      );
      // 当前在某文件夹内 → 新文件归入该文件夹
      if (_currentFolderId != null && _currentFolderId != _kChatFolderId) {
        await _client.from('group_file_folders').upsert({
          'message_id': msg.id,
          'folder_id': _currentFolderId,
          'conversation_id': widget.conversationId,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
      await _load();
    } catch (e) {
      if (mounted) _snack(AppLocalizations.of(context).sendFailed(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _openFile(Message msg) async {
    if (msg.mediaUrl == null) return;
    final uri = Uri.parse(msg.mediaUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      _snack(AppLocalizations.of(context).cannotOpenFile);
    }
  }

  void _snack(String msg) {
    if (mounted) {
      showPremiumToast(context, msg, kind: ToastKind.info);
    }
  }

  // ── helpers ─────────────────────────────────────────────────

  String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  IconData _iconForMime(String? mime, String? name) {
    final m = mime ?? '';
    final n = name ?? '';
    if (m.contains('pdf') || n.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (m.contains('word') || n.endsWith('.doc') || n.endsWith('.docx')) {
      return Icons.description;
    }
    if (m.contains('sheet') || n.endsWith('.xls') || n.endsWith('.xlsx')) {
      return Icons.table_chart;
    }
    if (m.contains('presentation') ||
        n.endsWith('.ppt') ||
        n.endsWith('.pptx')) {
      return Icons.slideshow;
    }
    if (m.contains('image')) return Icons.image;
    if (m.contains('audio')) return Icons.audio_file;
    if (m.contains('video')) return Icons.video_file;
    if (m.contains('zip') || m.contains('rar')) return Icons.folder_zip;
    if (m.contains('text') || n.endsWith('.txt')) return Icons.article;
    return Icons.insert_drive_file;
  }

  Color _colorForMime(String? mime, String? name) {
    final m = mime ?? '';
    final n = name ?? '';
    if (m.contains('pdf') || n.endsWith('.pdf')) return Colors.red.shade400;
    if (m.contains('word') || n.endsWith('.doc') || n.endsWith('.docx')) {
      return Colors.blue.shade400;
    }
    if (m.contains('sheet') || n.endsWith('.xls') || n.endsWith('.xlsx')) {
      return Colors.green.shade500;
    }
    if (m.contains('presentation') ||
        n.endsWith('.ppt') ||
        n.endsWith('.pptx')) {
      return Colors.orange.shade400;
    }
    if (m.contains('image')) return Colors.purple.shade400;
    if (m.contains('audio')) return Colors.teal.shade400;
    if (m.contains('video')) return Colors.indigo.shade400;
    return AppStyle.brand;
  }

  // 虚拟「聊天文件」文件夹 id（非真实 group_folders 记录）
  static const _kChatFolderId = '__chat__';

  bool _isFilesOnly(Message f) => f.payload?['files_only'] == true;

  /// 文件的有效归属文件夹：
  /// 有手动归属→该文件夹；否则聊天发来的文件→「聊天文件」；上传的→根目录
  String? _effectiveFolder(Message f) {
    final assigned = _assignments[f.id];
    if (assigned != null) return assigned;
    return _isFilesOnly(f) ? null : _kChatFolderId;
  }

  // ── build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // 当前目录下的文件
    final visibleFiles = _files
        .where((f) => _effectiveFolder(f) == _currentFolderId)
        .toList();
    // 「聊天文件」虚拟文件夹内的文件数
    final chatFileCount = _files
        .where((f) => _effectiveFolder(f) == _kChatFolderId)
        .length;
    final inChatFolder = _currentFolderId == _kChatFolderId;
    final currentFolder = (_currentFolderId == null || inChatFolder)
        ? null
        : _folders.where((f) => f.id == _currentFolderId).firstOrNull;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _uploadFile,
        backgroundColor: AppStyle.brand,
        icon: _uploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.upload_file, color: Colors.white),
        label: Text(
          AppLocalizations.of(context).uploadFile,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      appBar: AppBar(
        leading: _currentFolderId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _currentFolderId = null),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              inChatFolder
                  ? AppLocalizations.of(context).chatFiles
                  : currentFolder?.name ??
                        AppLocalizations.of(context).groupFiles,
            ),
            Text(
              currentFolder == null
                  ? widget.conversationName
                  : widget.conversationName,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          if (_currentFolderId == null)
            IconButton(
              icon: const Icon(Icons.create_new_folder_outlined),
              tooltip: AppLocalizations.of(context).createFolder,
              onPressed: _createFolder,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // 文件夹（仅根目录显示）：聊天文件虚拟夹 + 真实文件夹
                  if (_currentFolderId == null &&
                      (_folders.isNotEmpty || chatFileCount > 0))
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            if (chatFileCount > 0)
                              _VirtualChatFolderChip(
                                name: AppLocalizations.of(context).chatFiles,
                                count: chatFileCount,
                                onTap: () => setState(
                                  () => _currentFolderId = _kChatFolderId,
                                ),
                              ),
                            for (final f in _folders)
                              _FolderChip(
                                folder: f,
                                count: _assignments.values
                                    .where((v) => v == f.id)
                                    .length,
                                onTap: () =>
                                    setState(() => _currentFolderId = f.id),
                                onLongPress: () => _folderMenu(f),
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (_currentFolderId == null &&
                      (_folders.isNotEmpty || chatFileCount > 0))
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          AppLocalizations.of(context).files,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  // 文件列表
                  if (visibleFiles.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: PremiumEmptyState(
                        icon: Icons.folder_open_rounded,
                        title: _currentFolderId == null
                            ? AppLocalizations.of(context).noSharedFiles
                            : AppLocalizations.of(context).folderEmpty,
                        subtitle: _currentFolderId == null
                            ? AppLocalizations.of(context).emptyFilesHint
                            : AppLocalizations.of(context).longPressToMoveFile,
                        color: AppStyle.orange,
                      ),
                    )
                  else
                    SliverList.separated(
                      itemCount: visibleFiles.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 72),
                      itemBuilder: (context, i) => _fileTile(visibleFiles[i]),
                    ),
                ],
              ),
            ),
    );
  }

  void _folderMenu(_Folder f) {
    showPremiumActionSheet(
      context,
      title: f.name,
      actions: [
        PremiumAction(
          icon: Icons.drive_file_rename_outline,
          label: AppLocalizations.of(context).rename,
          color: AppStyle.blue,
          onTap: () {
            Navigator.pop(context);
            _renameFolder(f);
          },
        ),
        PremiumAction(
          icon: Icons.delete_outline_rounded,
          label: AppLocalizations.of(context).deleteFolder,
          destructive: true,
          onTap: () {
            Navigator.pop(context);
            _deleteFolder(f);
          },
        ),
      ],
    );
  }

  Widget _fileTile(Message msg) {
    final name =
        msg.fileName ?? msg.content ?? AppLocalizations.of(context).unknownFile;
    final size = _formatSize(msg.fileSize);
    final sender = msg.sender;
    final date = DateFormat('yyyy/MM/dd HH:mm').format(msg.createdAt.toLocal());
    final icon = _iconForMime(msg.fileMime, name);
    final color = _colorForMime(msg.fileMime, name);

    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        '${sender != null ? '${sender.displayName} · ' : ''}$size${size.isNotEmpty ? ' · ' : ''}$date',
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.onSurface.withAlpha(120),
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.drive_file_move_outline, size: 20),
        tooltip: AppLocalizations.of(context).moveToFolder,
        onPressed: () => _moveFile(msg),
      ),
      onTap: () => _openFile(msg),
      onLongPress: () => _moveFile(msg),
    );
  }
}

/// 「聊天文件」虚拟文件夹卡片（聊天中发送的文件默认归此处，不可删除/重命名）
class _VirtualChatFolderChip extends StatelessWidget {
  final String name;
  final int count;
  final VoidCallback onTap;
  const _VirtualChatFolderChip({
    required this.name,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = (MediaQuery.of(context).size.width - 24 - 10) / 2;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withAlpha(12)
                : Colors.black.withAlpha(8),
            width: 0.6,
          ),
          boxShadow: AppStyle.softShadow(isDark, blur: 12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: AppStyle.tintTile(AppStyle.brand, isDark),
              child: const Icon(
                Icons.forum_rounded,
                color: AppStyle.brand,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppLocalizations.of(context).fileCount(count),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderChip extends StatelessWidget {
  final _Folder folder;
  final int count;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _FolderChip({
    required this.folder,
    required this.count,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = (MediaQuery.of(context).size.width - 24 - 10) / 2;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withAlpha(12)
                : Colors.black.withAlpha(8),
            width: 0.6,
          ),
          boxShadow: AppStyle.softShadow(isDark, blur: 12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: AppStyle.tintTile(AppStyle.orange, isDark),
              child: const Icon(
                Icons.folder_rounded,
                color: AppStyle.orange,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppLocalizations.of(context).fileCount(count),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
