import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  String? get currentUserId => _client.auth.currentUser?.id;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    // 自动生成唯一 username：邮箱前缀 + 4位随机数
    final prefix = email.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    final suffix = DateTime.now().millisecondsSinceEpoch % 10000;
    final username = '${prefix}_$suffix';

    await _client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username, 'display_name': name},
    );
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// 忘记密码 - 第一步：发送重置验证码到邮箱。
  /// (需 Supabase「Reset Password」邮件模板含 {{ .Token }} + SMTP 已配置)
  Future<void> sendPasswordResetCode(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  /// 忘记密码 - 第二步：校验验证码并设置新密码。
  Future<void> verifyResetAndUpdatePassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    // 用 recovery OTP 校验，成功后会建立临时会话
    await _client.auth.verifyOTP(
      email: email.trim(),
      token: code.trim(),
      type: OtpType.recovery,
    );
    // 更新密码
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  Future<void> deleteAccount() async {
    await _client.rpc('delete_current_user');
    await signOut();
  }
}
