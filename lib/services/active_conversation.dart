/// 全局记录用户当前正打开的会话，用于抑制该会话的通知横幅。
/// 用栈以正确处理聊天页之上再叠开聊天页的情况。
class ActiveConversation {
  static final List<String> _stack = [];

  static String? get current => _stack.isEmpty ? null : _stack.last;

  static void enter(String conversationId) => _stack.add(conversationId);

  static void leave(String conversationId) {
    final index = _stack.lastIndexOf(conversationId);
    if (index != -1) _stack.removeAt(index);
  }
}
