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
