import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/profile.dart';
import '../../services/profile_service.dart';
import '../../theme/app_style.dart';
import '../../l10n/app_localizations.dart';

/// 选人页：搜索用户、多选，返回选中的 user id 列表。
/// excludeIds 中的用户（已在群里）不显示。
class AddMembersScreen extends StatefulWidget {
  final Set<String> excludeIds;
  const AddMembersScreen({super.key, required this.excludeIds});

  @override
  State<AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<AddMembersScreen> {
  final _profileService = ProfileService();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<Profile> _results = [];
  final Map<String, Profile> _selected = {};
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await _profileService.searchUsers(q.trim());
      if (!mounted) return;
      setState(() {
        _results =
            res.where((p) => !widget.excludeIds.contains(p.id)).toList();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggle(Profile p) {
    setState(() {
      if (_selected.containsKey(p.id)) {
        _selected.remove(p.id);
      } else {
        _selected[p.id] = p;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.addMembers),
        actions: [
          TextButton(
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.pop(context, _selected.keys.toList()),
            child: Text(
              _selected.isEmpty ? t.confirm : '${t.confirm}(${_selected.length})',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: _onQueryChanged,
              decoration: InputDecoration(
                hintText: t.searchUserHint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
            ),
          ),
          // 已选 chips
          if (_selected.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: _selected.values
                    .map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Chip(
                          label: Text(p.displayName),
                          onDeleted: () => _toggle(p),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final p = _results[i];
                      final checked = _selected.containsKey(p.id);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppStyle.brand.withAlpha(40),
                          child: Text(
                            p.displayName.isNotEmpty
                                ? p.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(color: AppStyle.brand),
                          ),
                        ),
                        title: Text(p.displayName),
                        trailing: Checkbox(
                          value: checked,
                          onChanged: (_) => _toggle(p),
                        ),
                        onTap: () => _toggle(p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
