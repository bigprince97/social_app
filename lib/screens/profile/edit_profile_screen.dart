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
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final profile = await _profileService.getProfile(userId);
    if (mounted) {
      setState(() {
        _profile = profile;
        _displayNameCtrl.text = profile.displayName;
        _bioCtrl.text = profile.bio ?? '';
        _loading = false;
      });
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
    if (picked != null) {
      setState(() => _newAvatarFile = picked);
    }
  }

  Future<void> _save() async {
    final displayName = _displayNameCtrl.text.trim();
    if (displayName.isEmpty) {
      showPremiumToast(context, AppLocalizations.of(context).displayNameRequired, kind: ToastKind.info);
      return;
    }
    setState(() => _saving = true);
    try {
      String? avatarUrl = _profile?.avatarUrl;
      if (_newAvatarFile != null) {
        avatarUrl = await _storageService.uploadAvatar(_newAvatarFile!);
      }
      await _profileService.updateProfile(
        displayName: displayName,
        bio: _bioCtrl.text.trim(),
        avatarUrl: avatarUrl,
      );
      if (mounted) {
        showPremiumToast(context, AppLocalizations.of(context).savingSucceeded, kind: ToastKind.success);
        notifyProfileUpdated();
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showErrorIfNotNetwork(context, e, AppLocalizations.of(context).saveFailed(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).editProfile),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
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
          : SingleChildScrollView(
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
                                      File(_newAvatarFile!.path)) as ImageProvider)
                              : _profile?.avatarUrl != null
                                  ? CachedNetworkImageProvider(
                                          _profile!.avatarUrl!)
                                      as ImageProvider
                                  : null,
                          child: _newAvatarFile == null &&
                                  _profile?.avatarUrl == null
                              ? Text(
                                  _profile?.displayName[0].toUpperCase() ?? '?',
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
                            child: const Icon(Icons.camera_alt,
                                color: Colors.white, size: 18),
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
                        color: Color(0xFF1C1C1E), fontSize: 16),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).displayName,
                      labelStyle: const TextStyle(color: Color(0xFF6E6E73)),
                      floatingLabelStyle:
                          const TextStyle(color: Color(0xFF9575CD)),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F8),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
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
                            color: Color(0xFF9575CD), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bioCtrl,
                    maxLines: 4,
                    maxLength: 150,
                    style: const TextStyle(
                        color: Color(0xFF1C1C1E), fontSize: 16),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).bio,
                      labelStyle: const TextStyle(color: Color(0xFF6E6E73)),
                      floatingLabelStyle:
                          const TextStyle(color: Color(0xFF9575CD)),
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: const Color(0xFFF5F5F8),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
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
                            color: Color(0xFF9575CD), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
