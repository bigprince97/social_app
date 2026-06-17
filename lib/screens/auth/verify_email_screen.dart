import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../widgets/premium_toast.dart';
import '../../theme/app_style.dart';
import '../../utils/auth_error.dart';

/// 注册邮箱验证：注册后输入邮件里的验证码 → 完成注册进入 App。
class VerifyEmailScreen extends StatefulWidget {
  final String email;
  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _auth = AuthService();
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  int _cooldown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
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

  Future<void> _resend() async {
    final l = AppLocalizations.of(context);
    setState(() => _loading = true);
    try {
      await _auth.resendSignUpCode(widget.email);
      if (!mounted) return;
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

  Future<void> _verify() async {
    final l = AppLocalizations.of(context);
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      showPremiumToast(context, l.codeRequired, kind: ToastKind.info);
      return;
    }
    setState(() => _loading = true);
    try {
      await _auth.verifySignUpCode(email: widget.email, code: code);
      if (!mounted) return;
      showPremiumToast(context, l.verifyEmailSuccess, kind: ToastKind.success);
      context.go('/');
    } catch (e) {
      if (mounted) {
        showPremiumToast(context, isNetworkError(e) ? l.networkError : l.verifyEmailFailed,
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
      appBar: AppBar(title: Text(l.verifyEmailTitle)),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(
                l.verifyEmailHint(widget.email),
                style: const TextStyle(fontSize: 14, color: Color(0xFF6E6E73)),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l.codeHint,
                  prefixIcon: const Icon(Icons.pin_outlined),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: (_cooldown > 0 || _loading) ? null : _resend,
                  child: Text(_cooldown > 0
                      ? '${l.resendCode} (${_cooldown}s)'
                      : l.resendCode),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: _loading ? null : _verify,
                  style: FilledButton.styleFrom(backgroundColor: AppStyle.brand),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(l.verifyEmailButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
