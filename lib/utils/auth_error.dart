/// 把后端/网络异常转成对用户友好的提示，绝不暴露原始堆栈。
bool isNetworkError(Object e) {
  final s = e.toString();
  return s.contains('SocketException') ||
      s.contains('Failed host lookup') ||
      s.contains('AuthRetryableFetchException') ||
      s.contains('ClientException') ||
      s.contains('Connection closed') ||
      s.contains('Connection refused') ||
      s.contains('timed out') ||
      s.contains('TimeoutException');
}

/// 会话已失效（本地判断到 currentUser 为 null）。抛出它而非裸 `!` 触发的
/// "Null check operator" 崩溃，便于 UI 友好提示重新登录。
class SessionExpiredException implements Exception {
  const SessionExpiredException();
  @override
  String toString() => 'SessionExpiredException: 登录状态已失效';
}

/// 写操作前取当前用户 id；为空则抛 [SessionExpiredException]（会话过期）。
String requireUid(dynamic client) {
  final id = client.auth.currentUser?.id as String?;
  if (id == null) throw const SessionExpiredException();
  return id;
}

/// 会话失效 / 未授权：令牌过期或 RLS 拒绝（多因登录态丢失）。
/// 命中时应提示用户重新登录，而不是显示原始 StorageException/RLS 文案。
bool isAuthExpiredError(Object e) {
  final s = e.toString();
  return e is SessionExpiredException ||
      s.contains('SessionExpiredException') ||
      s.contains('row-level security') ||
      s.contains('row level security') ||
      s.contains('statusCode: 403') ||
      s.contains('JWT expired') ||
      s.contains('Unauthorized') ||
      s.contains('"code":"401"') ||
      s.contains('statusCode: 401');
}
