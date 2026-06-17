import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../widgets/premium_toast.dart';
import '../../theme/app_style.dart';
import '../../utils/auth_error.dart';

/// 忘记密码：输入邮箱 → 收验证码 → 输验证码+新密码 → 重置。
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _auth = AuthService();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _pwdCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _sendCode() async {
    final l = AppLocalizations.of(context);
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      showPremiumToast(context, l.emailRequired, kind: ToastKind.info);
      return;
    }
    setState(() => _loading = true);
    try {
      await _auth.sendPasswordResetCode(email);
      if (!mounted) return;
      setState(() => _codeSent = true);
      _startCooldown();
      showPremiumToast(context, l.resetCodeSent, kind: ToastKind.success);
    } catch (e) {
      if (mounted) {
        showPremiumToast(context, isNetworkError(e) ? l.networkError : l.resetFailed,
            kind: ToastKind.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reset() async {
    final l = AppLocalizations.of(context);
    final code = _codeCtrl.text.trim();
    final pwd = _pwdCtrl.text;
    if (code.isEmpty) {
      showPremiumToast(context, l.codeRequired, kind: ToastKind.info);
      return;
    }
    if (pwd.length < 6) {
      showPremiumToast(context, l.passwordTooShortError, kind: ToastKind.info);
      return;
    }
    setState(() => _loading = true);
    try {
      await _auth.verifyResetAndUpdatePassword(
        email: _emailCtrl.text.trim(),
        code: code,
        newPassword: pwd,
      );
      if (!mounted) return;
      showPremiumToast(context, l.resetSuccess, kind: ToastKind.success);
      context.go('/login');
    } catch (e) {
      if (mounted) {
        showPremiumToast(context, isNetworkError(e) ? l.networkError : l.resetFailed,
            kind: ToastKind.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.resetPassword)),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                enabled: !_codeSent,
                decoration: InputDecoration(
                  labelText: l.resetEmailHint,
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              if (!_codeSent)
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: _loading ? null : _sendCode,
                    style: FilledButton.styleFrom(
                        backgroundColor: AppStyle.brand),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(l.sendCode),
                  ),
                )
              else ...[
                TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l.codeHint,
                    prefixIcon: const Icon(Icons.pin_outlined),
                    border: const OutlineInputBorder(),
                    suffixText: _cooldown > 0 ? '${_cooldown}s' : null,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _pwdCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l.newPasswordHint,
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: (_cooldown > 0 || _loading) ? null : _sendCode,
                    child: Text(_cooldown > 0
                        ? '${l.resendCode} (${_cooldown}s)'
                        : l.resendCode),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: _loading ? null : _reset,
                    style: FilledButton.styleFrom(
                        backgroundColor: AppStyle.brand),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(l.resetPassword),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
