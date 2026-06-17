import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
import '../settings/legal_screen.dart';
import '../../widgets/premium_toast.dart';
import '../../services/auth_service.dart';
import '../../theme/app_style.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;
  bool _obscure = true;
  bool _agreed = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      showPremiumToast(context, AppLocalizations.of(context).eulaMustAgree,
          kind: ToastKind.info);
      return;
    }
    setState(() => _loading = true);
    try {
      final email = _emailCtrl.text.trim();
      await _authService.signUp(
        name: _nameCtrl.text.trim(),
        email: email,
        password: _passwordCtrl.text,
      );
      // 注册成功 → 进入邮箱验证码页面（开启 Confirm email 后此时尚无会话）
      if (mounted) context.push('/verify-email', extra: email);
    } catch (e) {
      if (mounted) {
        showPremiumToast(context, AppLocalizations.of(context).registerFailed(''), kind: ToastKind.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── 顶部品牌区（与登录页一致）──────────────────────────
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                  32, MediaQuery.of(context).padding.top + 48, 32, 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, Color.lerp(primary, Colors.deepPurple, 0.5)!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.menu_book_rounded,
                        size: 36, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(context).appName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            // ── 表单区 ────────────────────────────────────────────
            Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Text(AppLocalizations.of(context).createAccount,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).displayName,
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? AppLocalizations.of(context).nicknameRequiredError : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).email,
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  validator: (v) =>
                      v == null || !v.contains('@') ? AppLocalizations.of(context).invalidEmailError : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _register(),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).password,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.length < 6 ? AppLocalizations.of(context).passwordTooShortError : null,
                ),
                const SizedBox(height: 16),
                // 同意条款勾选 + 协议链接（上架审核要求）
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _agreed,
                        onChanged: (v) => setState(() => _agreed = v ?? false),
                        activeColor: const Color(0xFF9575CD),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text.rich(
                          TextSpan(
                            style: const TextStyle(
                                fontSize: 12.5, color: Color(0xFF6E6E73)),
                            children: [
                              TextSpan(
                                  text: AppLocalizations.of(context).agreeIntro),
                              TextSpan(
                                text:
                                    AppLocalizations.of(context).userAgreement,
                                style: const TextStyle(
                                    color: Color(0xFF9575CD),
                                    fontWeight: FontWeight.w600),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => const LegalScreen(
                                              doc: LegalDoc.eula))),
                              ),
                              TextSpan(
                                  text: AppLocalizations.of(context).and),
                              TextSpan(
                                text:
                                    AppLocalizations.of(context).privacyPolicy,
                                style: const TextStyle(
                                    color: Color(0xFF9575CD),
                                    fontWeight: FontWeight.w600),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => const LegalScreen(
                                              doc: LegalDoc.privacy))),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                PremiumButton(
                  label: AppLocalizations.of(context).register,
                  icon: Icons.person_add_alt_rounded,
                  expand: true,
                  loading: _loading,
                  onTap: _loading ? null : _register,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(AppLocalizations.of(context).hasAccountGoLogin),
                ),
              ],
            ),
          ),
        ),
          ],
        ),
      ),
    );
  }
}
