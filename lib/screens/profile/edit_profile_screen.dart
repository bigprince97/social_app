import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/bible_books.dart';
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
  String? _selectedRegion;
  String _selectedLanguage = 'zh';

  static const _regions = [
    ('CN-BJ', '北京'), ('CN-SH', '上海'), ('CN-GD', '广东'),
    ('CN-ZJ', '浙江'), ('CN-JS', '江苏'), ('CN-SC', '四川'),
    ('HK', '香港'), ('TW', '台湾'), ('SG', '新加坡'),
    ('MY', '马来西亚'), ('US', '美国'), ('CA', '加拿大'),
    ('AU', '澳大利亚'), ('GB', '英国'), ('JP', '日本'),
    ('KR', '韩国'), ('OTHER', '其他'),
  ];

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
    final raw = await Supabase.instance.client
        .from('profiles')
        .select('region, language')
        .eq('id', userId)
        .single();
    if (mounted) {
      setState(() {
        _profile = profile;
        _displayNameCtrl.text = profile.displayName;
        _bioCtrl.text = profile.bio ?? '';
        _selectedRegion = raw['region'] as String?;
        _selectedLanguage = (raw['language'] as String?) ?? 'zh';
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).displayNameRequired)));
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
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('profiles').update({
        'region': _selectedRegion,
        'language': _selectedLanguage,
      }).eq('id', userId);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).savingSucceeded)));
        notifyProfileUpdated();
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).saveFailed(e.toString()))));
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
                    child:
                        CircularProgressIndicator(strokeWidth: 2),
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
                                  : FileImage(// dart:io File — non-web only
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
                                  _profile?.displayName[0].toUpperCase() ??
                                      '?',
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
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).displayName,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bioCtrl,
                    maxLines: 4,
                    maxLength: 150,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).bio,
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).region,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedRegion,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      items: [
                        DropdownMenuItem(value: null, child: Text(AppLocalizations.of(context).notSet)),
                        ..._regions.map((r) => DropdownMenuItem(
                              value: r.$1,
                              child: Text(localizedRegion(
                                  AppLocalizations.of(context), r.$1)),
                            )),
                      ],
                      onChanged: (v) => setState(() => _selectedRegion = v),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).languagePreference,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedLanguage,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      items: [
                        DropdownMenuItem(value: 'zh', child: Text(AppLocalizations.of(context).languageChinese)),
                        DropdownMenuItem(value: 'en', child: Text(AppLocalizations.of(context).languageEnglish)),
                      ],
                      onChanged: (v) => setState(() => _selectedLanguage = v ?? 'zh'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
