/// 轻量内容过滤：发帖/评论前做基础敏感词检测。
/// 配合服务端举报 + 24h 人工审核，满足应用商店「过滤不良内容」要求。
class ContentFilter {
  // 基础违禁词库（可按需扩充）。命中即拦截。
  static const List<String> _banned = [
    // 色情低俗
    '色情', '裸聊', '约炮', '一夜情', 'av网站', '黄片', '成人电影',
    // 赌博诈骗
    '赌博', '博彩', '彩票投注', '六合彩', '刷单', '兼职刷单', '杀猪盘',
    // 毒品
    '冰毒', '大麻', '海洛因', '摇头丸', '吸毒',
    // 暴恐
    '恐怖袭击', '制造炸弹', '枪支弹药', '军火',
    // 辱骂（示例，少量）
    '傻逼', '操你妈', '草泥马', 'fuck you', 'cnm',
    // 违法交易
    '办证', '代开发票', '出售个人信息', '银行卡四件套',
  ];

  /// 返回命中的第一个违禁词；无命中返回 null。
  static String? firstHit(String text) {
    if (text.trim().isEmpty) return null;
    final lower = text.toLowerCase();
    for (final w in _banned) {
      if (lower.contains(w.toLowerCase())) return w;
    }
    return null;
  }

  /// 是否含违禁内容。
  static bool hasBanned(String text) => firstHit(text) != null;
}
