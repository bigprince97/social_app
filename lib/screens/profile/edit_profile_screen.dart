import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/premium_toast.dart';
import '../../services/local_cache.dart';
import '../../models/profile.dart';
import '../../services/event_bus.dart';
import '../../services/profile_service.dart';
import '../../services/storage_service.dart';
import '../../utils/auth_error.dart'
    show avatarInitial, isAuthExpiredError, requireUid, UserNotFoundException;
import '../../utils/content_filter.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _profileService = ProfileService();
  final _storageService = StorageService();
  final _displayNameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  Profile? _profile;
  bool _loading = true;
  // 加载失败标记 + 文案:异常时展示页内错误视图与重试按钮,避免永久转圈
  bool _loadError = false;
  String _loadErrorText = '';
  bool _saving = false;
  XFile? _newAvatarFile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _loadError = false;
    });
    try {
      // 会话失效时抛 SessionExpiredException,而非 currentUser! 空断言直接崩溃
      final userId = requireUid(Supabase.instance.client);
      final profile = await _profileService.getProfile(userId);
      if (mounted) {
        setState(() {
          _profile = profile;
          _displayNameCtrl.text = profile.displayName;
          _bioCtrl.text = profile.bio ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        final t = AppLocalizations.of(context);
        // 区分错误类型给出对应文案;网络错误 toast 静默,靠页内错误视图提示
        final message = isAuthExpiredError(e)
            ? t.sessionExpired
            : e is UserNotFoundException
            ? t.userNotFound
            : isNetworkError(e)
            ? t.networkError
            : t.loadFailed('$e');
        setState(() {
          _loadError = true;
          _loadErrorText = message;
        });
        showErrorIfNotNetwork(context, e, message);
      }
    } finally {
      // 无论成败都结束 loading,保证页面不会永久转圈
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (!mounted) return;
    if (picked != null) {
      setState(() => _newAvatarFile = picked);
    }
  }

  Future<void> _save() async {
    final displayName = _displayNameCtrl.text.trim();
    if (displayName.isEmpty) {
      showPremiumToast(
        context,
        AppLocalizations.of(context).displayNameRequired,
        kind: ToastKind.info,
      );
      return;
    }
    final bio = _bioCtrl.text.trim();
    if (ContentFilter.hasBanned('$displayName $bio')) {
      showPremiumToast(
        context,
        AppLocalizations.of(context).contentBlocked,
        kind: ToastKind.block,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      String? avatarUrl = _profile?.avatarUrl;
      if (_newAvatarFile != null) {
        avatarUrl = await _storageService.uploadAvatar(
          _newAvatarFile!,
          oldUrl: _profile?.avatarUrl,
        );
      }
      await _profileService.updateProfile(
        displayName: displayName,
        bio: bio,
        avatarUrl: avatarUrl,
      );
      if (mounted) {
        showPremiumToast(
          context,
          AppLocalizations.of(context).savingSucceeded,
          kind: ToastKind.success,
        );
        notifyProfileUpdated();
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        if (isAuthExpiredError(e)) {
          showPremiumToast(
            context,
            AppLocalizations.of(context).sessionExpired,
            kind: ToastKind.error,
          );
        } else {
          showErrorIfNotNetwork(
            context,
            e,
            AppLocalizations.of(context).saveFailed(e.toString()),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 点击空白处收回键盘(bio 多行输入没有 done 键,必须靠这个)
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).editProfile),
          actions: [
            TextButton(
              // 资料未加载成功前禁用保存,避免用空数据覆盖线上资料
              onPressed: (_saving || _profile == null) ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(AppLocalizations.of(context).save),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError
            ? Center(
                // 加载失败视图:提示 + 重试入口(AppBar 返回始终可用)
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _loadErrorText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: Color(0xFF777777),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _loadProfile,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 52,
                            backgroundImage: _newAvatarFile != null
                                ? (kIsWeb
                                      ? NetworkImage(_newAvatarFile!.path)
                                      : FileImage(
                                              // ignore: avoid_dynamic_calls
                                              File(_newAvatarFile!.path),
                                            )
                                            as ImageProvider)
                                : _profile?.avatarUrl != null
                                ? CachedNetworkImageProvider(
                                        _profile!.avatarUrl!,
                                      )
                                      as ImageProvider
                                : null,
                            child:
                                _newAvatarFile == null &&
                                    _profile?.avatarUrl == null
                                ? Text(
                                    avatarInitial(_profile?.displayName),
                                    style: const TextStyle(fontSize: 36),
                                  )
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context).clickToChangeAvatar,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _displayNameCtrl,
                      style: const TextStyle(
                        color: Color(0xFF1C1C1E),
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).displayName,
                        labelStyle: const TextStyle(color: Color(0xFF6E6E73)),
                        floatingLabelStyle: const TextStyle(
                          color: Color(0xFF9575CD),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF5F5F8),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF9575CD),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bioCtrl,
                      maxLines: 4,
                      maxLength: 150,
                      style: const TextStyle(
                        color: Color(0xFF1C1C1E),
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).bio,
                        labelStyle: const TextStyle(color: Color(0xFF6E6E73)),
                        floatingLabelStyle: const TextStyle(
                          color: Color(0xFF9575CD),
                        ),
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: const Color(0xFFF5F5F8),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF9575CD),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}
