// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get deleteConversation => '删除对话';

  @override
  String get deleteConversationConfirm => '确定删除此对话吗？仅从你的列表移除，不影响对方。';

  @override
  String get conversationDeleted => '已删除对话';

  @override
  String get noOneSharingCamera => '还没有人开启摄像头';

  @override
  String unblockConfirm(Object name) {
    return '确定取消拉黑「$name」吗？取消后对方可以再次给你发消息。';
  }

  @override
  String userUnblocked(Object name) {
    return '已取消拉黑「$name」';
  }

  @override
  String get downloadForOffline => '下载离线';

  @override
  String get downloadedOffline => '已下载，可离线阅读';

  @override
  String get downloadComplete => '下载完成，可离线阅读';

  @override
  String downloadFailed(Object error) {
    return '下载失败：$error';
  }

  @override
  String get chatFiles => '聊天文件';

  @override
  String get addMembers => '添加成员';

  @override
  String get membersAdded => '已添加成员';

  @override
  String get searchUserHint => '搜索用户名或昵称';

  @override
  String loadFailed(Object error) {
    return '加载失败：$error';
  }

  @override
  String get contents => '目录';

  @override
  String get noChapterContent => '暂无章节内容';

  @override
  String get continueReading => '继续阅读';

  @override
  String get startReading => '开始阅读';

  @override
  String chaptersCountLabel(Object chaptersCount) {
    return '$chaptersCount 章';
  }

  @override
  String readPercent(Object percent) {
    return '已读 $percent%';
  }

  @override
  String get bookGenesis => '创世记';

  @override
  String get bookExodus => '出埃及记';

  @override
  String get bookLeviticus => '利未记';

  @override
  String get bookNumbers => '民数记';

  @override
  String get bookDeuteronomy => '申命记';

  @override
  String get bookJoshua => '约书亚记';

  @override
  String get bookJudges => '士师记';

  @override
  String get bookRuth => '路得记';

  @override
  String get book1Samuel => '撒母耳记上';

  @override
  String get book2Samuel => '撒母耳记下';

  @override
  String get book1Kings => '列王纪上';

  @override
  String get book2Kings => '列王纪下';

  @override
  String get book1Chronicles => '历代志上';

  @override
  String get book2Chronicles => '历代志下';

  @override
  String get bookEzra => '以斯拉记';

  @override
  String get bookNehemiah => '尼希米记';

  @override
  String get bookEsther => '以斯帖记';

  @override
  String get bookJob => '约伯记';

  @override
  String get bookPsalms => '诗篇';

  @override
  String get bookProverbs => '箴言';

  @override
  String get bookEcclesiastes => '传道书';

  @override
  String get bookSongOfSongs => '雅歌';

  @override
  String get bookIsaiah => '以赛亚书';

  @override
  String get bookJeremiah => '耶利米书';

  @override
  String get bookLamentations => '耶利米哀歌';

  @override
  String get bookEzekiel => '以西结书';

  @override
  String get bookDaniel => '但以理书';

  @override
  String get bookHosea => '何西阿书';

  @override
  String get bookJoel => '约珥书';

  @override
  String get bookAmos => '阿摩司书';

  @override
  String get bookObadiah => '俄巴底亚书';

  @override
  String get bookJonah => '约拿书';

  @override
  String get bookMicah => '弥迦书';

  @override
  String get bookNahum => '那鸿书';

  @override
  String get bookHabakkuk => '哈巴谷书';

  @override
  String get bookZephaniah => '西番雅书';

  @override
  String get bookHaggai => '哈该书';

  @override
  String get bookZechariah => '撒迦利亚书';

  @override
  String get bookMalachi => '玛拉基书';

  @override
  String get bookMatthew => '马太福音';

  @override
  String get bookMark => '马可福音';

  @override
  String get bookLuke => '路加福音';

  @override
  String get bookJohn => '约翰福音';

  @override
  String get bookActs => '使徒行传';

  @override
  String get bookRomans => '罗马书';

  @override
  String get book1Corinthians => '哥林多前书';

  @override
  String get book2Corinthians => '哥林多后书';

  @override
  String get bookGalatians => '加拉太书';

  @override
  String get bookEphesians => '以弗所书';

  @override
  String get bookPhilippians => '腓立比书';

  @override
  String get bookColossians => '歌罗西书';

  @override
  String get book1Thessalonians => '帖撒罗尼迦前书';

  @override
  String get book2Thessalonians => '帖撒罗尼迦后书';

  @override
  String get book1Timothy => '提摩太前书';

  @override
  String get book2Timothy => '提摩太后书';

  @override
  String get bookTitus => '提多书';

  @override
  String get bookPhilemon => '腓利门书';

  @override
  String get bookHebrews => '希伯来书';

  @override
  String get bookJames => '雅各书';

  @override
  String get book1Peter => '彼得前书';

  @override
  String get book2Peter => '彼得后书';

  @override
  String get book1John => '约翰一书';

  @override
  String get book2John => '约翰二书';

  @override
  String get book3John => '约翰三书';

  @override
  String get bookJude => '犹大书';

  @override
  String get bookRevelation => '启示录';

  @override
  String get books => '书卷';

  @override
  String get chapters => '章';

  @override
  String get oldTestament => '旧约';

  @override
  String get newTestament => '新约';

  @override
  String get selectBookFirst => '请先从书卷中选择一本书';

  @override
  String volumeCount(Object count) {
    return '$count卷';
  }

  @override
  String bookChapterDisplay(Object bookName, Object chapterNumber) {
    return '$bookName 第$chapterNumber章';
  }

  @override
  String get editGroupAnnouncement => '编辑群公告';

  @override
  String get announcementHint => '输入群公告内容...';

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String saveFailed(Object error) {
    return '保存失败：$error';
  }

  @override
  String get removeFromGroup => '移出群聊';

  @override
  String get removedFromGroup => '已移出群聊';

  @override
  String operationFailed(Object error) {
    return '操作失败：$error';
  }

  @override
  String get promoteToAdmin => '设为管理员';

  @override
  String get promotedToAdmin => '已设为管理员';

  @override
  String get demoteAdmin => '撤销管理员';

  @override
  String get demotedAdmin => '已撤销管理员权限';

  @override
  String get leaveGroup => '退出群聊';

  @override
  String get confirmLeaveGroup => '确定要退出此群聊吗？';

  @override
  String leaveFailed(Object error) {
    return '退出失败：$error';
  }

  @override
  String get disbandGroup => '解散群聊';

  @override
  String get confirmDisbandGroup => '解散后所有成员将被移出，聊天记录将被删除，此操作不可恢复。确定要解散吗？';

  @override
  String get groupInfo => '群聊信息';

  @override
  String get group => '群聊';

  @override
  String memberCount(Object count) {
    return '$count 名成员';
  }

  @override
  String get announcement => '群公告';

  @override
  String get clickToSetAnnouncement => '点击设置群公告';

  @override
  String get noAnnouncement => '暂无公告';

  @override
  String get groupFiles => '群文件';

  @override
  String members(Object count) {
    return '成员 ($count)';
  }

  @override
  String get you => '你';

  @override
  String get admin => '管理员';

  @override
  String get groupOwner => '群主';

  @override
  String createFailed(Object error) {
    return '新建失败：$error';
  }

  @override
  String get deleteFolder => '删除文件夹';

  @override
  String confirmDeleteFolder(Object folderName) {
    return '确定删除「$folderName」吗？文件夹内的文件会移回根目录，不会被删除。';
  }

  @override
  String get delete => '删除';

  @override
  String deleteFailed(Object error) {
    return '删除失败：$error';
  }

  @override
  String renameFailed(Object error) {
    return '重命名失败：$error';
  }

  @override
  String get createFolder => '新建文件夹';

  @override
  String get uploadFile => '上传文件';

  @override
  String get renameFolder => '重命名文件夹';

  @override
  String get folderName => '文件夹名称';

  @override
  String get confirm => '确定';

  @override
  String moveFileTo(Object fileName) {
    return '移动「$fileName」到';
  }

  @override
  String get rootDirectory => '根目录';

  @override
  String moveFailed(Object error) {
    return '移动失败：$error';
  }

  @override
  String get cannotOpenFile => '无法打开文件';

  @override
  String get files => '文件';

  @override
  String get noSharedFiles => '暂无共享文件';

  @override
  String get folderEmpty => '该文件夹为空';

  @override
  String get emptyFilesHint => '在聊天中发送文件后会显示在这里\n点右上角可新建文件夹';

  @override
  String get longPressToMoveFile => '长按文件可移动到这里';

  @override
  String get rename => '重命名';

  @override
  String fileCount(Object count) {
    return '$count 个文件';
  }

  @override
  String get moveToFolder => '移动到文件夹';

  @override
  String get unknownFile => '未知文件';

  @override
  String get copiedToClipboard => '已复制到剪贴板';

  @override
  String get selectConversation => '选择会话';

  @override
  String get privateChat => '私聊';

  @override
  String get sentToChat => '已发送到聊天';

  @override
  String noteTitle(Object chapterTitle) {
    return '笔记 · $chapterTitle';
  }

  @override
  String get noteHint => '写下你的感悟...';

  @override
  String get copyScripture => '复制经文';

  @override
  String get sendToChat => '发送到聊天';

  @override
  String selectedVerses(Object count) {
    return '已选 $count 节';
  }

  @override
  String get copy => '复制';

  @override
  String get quoteToChat => '引用到聊天';

  @override
  String get fontSizeSmall => '小字';

  @override
  String get fontSizeNormal => '标准';

  @override
  String get fontSizeLarge => '大字';

  @override
  String get fontSizeExtraLarge => '特大';

  @override
  String get previousChapter => '上章';

  @override
  String get note => '笔记';

  @override
  String get highlight => '划线';

  @override
  String get bookmark => '收藏';

  @override
  String get quote => '引用';

  @override
  String get nextChapter => '下章';

  @override
  String oldTestamentCount(Object count) {
    return '旧约 $count';
  }

  @override
  String crossReferenceTitle(Object chapterTitle, Object verse) {
    return '$chapterTitle 第$verse节 · 引用旧约';
  }

  @override
  String get chapterNotFound => '未找到对应章节';

  @override
  String get scripture => '经书';

  @override
  String get myBookmarks => '我的书签';

  @override
  String get savedPosts => '我的收藏';

  @override
  String get bookmarkTabScripture => '经书';

  @override
  String get bookmarkTabPosts => '帖子';

  @override
  String get noSavedPosts => '还没有收藏的帖子';

  @override
  String get myPosts => '我的发帖';

  @override
  String get lastReading => '上次阅读';

  @override
  String get allScriptures => '全部经书';

  @override
  String get continueLabel => '继续';

  @override
  String chapterCount(Object count) {
    return '$count 章';
  }

  @override
  String get noScriptureContent => '暂无经书内容';

  @override
  String get noBookmarks => '还没有书签';

  @override
  String get bookmarkHint => '阅读经文时点击书签图标即可收藏';

  @override
  String get deletedChapter => '已删除章节';

  @override
  String get blockUserTitle => '拉黑用户';

  @override
  String blockUserConfirm(Object displayName) {
    return '确定拉黑 $displayName 吗？';
  }

  @override
  String get block => '拉黑';

  @override
  String get userBlocked => '已拉黑该用户';

  @override
  String directMessageFailed(Object error) {
    return '发起私信失败：$error';
  }

  @override
  String get settings => '设置';

  @override
  String get editProfile => '编辑资料';

  @override
  String get languageSettings => '切换语言';

  @override
  String get logout => '退出登录';

  @override
  String get confirmLogout => '确定要退出登录吗？';

  @override
  String get confirmButton => '退出';

  @override
  String get userNotFound => '用户不存在';

  @override
  String get noPosts => '还没有发帖';

  @override
  String get posts => '帖子';

  @override
  String get followers => '粉丝';

  @override
  String get following => '关注';

  @override
  String get alreadyFollowing => '已关注';

  @override
  String get directMessage => '私信';

  @override
  String get displayNameRequired => '昵称不能为空';

  @override
  String get savingSucceeded => '保存成功';

  @override
  String get clickToChangeAvatar => '点击更换头像';

  @override
  String get displayName => '昵称';

  @override
  String get bio => '个人简介';

  @override
  String get region => '所在地区';

  @override
  String get notSet => '不设置';

  @override
  String get languagePreference => '语言偏好';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get regionBeijing => '北京';

  @override
  String get regionShanghai => '上海';

  @override
  String get regionGuangdong => '广东';

  @override
  String get regionZhejiang => '浙江';

  @override
  String get regionJiangsu => '江苏';

  @override
  String get regionSichuan => '四川';

  @override
  String get regionHongKong => '香港';

  @override
  String get regionTaiwan => '台湾';

  @override
  String get regionSingapore => '新加坡';

  @override
  String get regionMalaysia => '马来西亚';

  @override
  String get regionUSA => '美国';

  @override
  String get regionCanada => '加拿大';

  @override
  String get regionAustralia => '澳大利亚';

  @override
  String get regionUK => '英国';

  @override
  String get regionJapan => '日本';

  @override
  String get regionSouthKorea => '韩国';

  @override
  String get regionOther => '其他';

  @override
  String followersList(Object displayName) {
    return '$displayName的粉丝';
  }

  @override
  String followingList(Object displayName) {
    return '$displayName的关注';
  }

  @override
  String get noFollowers => '暂无粉丝';

  @override
  String get noFollowing => '还没有关注任何人';

  @override
  String followerCount(Object count) {
    return '$count 粉丝';
  }

  @override
  String joinLivestreamFailed(Object error) {
    return '加入直播失败：$error';
  }

  @override
  String sendFailed(Object error) {
    return '发送失败：$error';
  }

  @override
  String get blockedCannotSend => '对方已将你拉黑，消息无法送达';

  @override
  String get microphonePermissionRequired => '需要麦克风权限才能录音';

  @override
  String get attachmentTitle => '发送内容';

  @override
  String get attachmentPhoto => '图片';

  @override
  String get attachmentVideo => '视频';

  @override
  String get attachmentCamera => '拍摄';

  @override
  String blockUserConfirm2(Object name) {
    return '确定要拉黑 $name 吗？';
  }

  @override
  String userBlocked2(Object name) {
    return '已拉黑 $name';
  }

  @override
  String get online => '在线';

  @override
  String get voiceCall => '语音通话';

  @override
  String get videoCall => '视频通话';

  @override
  String get startLivestream => '开始直播';

  @override
  String get groupLivestreamOngoing => '群内正在直播';

  @override
  String get joinLivestream => '点击加入';

  @override
  String get sendFirstMessage => '发送第一条消息吧！';

  @override
  String get recording => '录音中';

  @override
  String get messages => '消息';

  @override
  String get searchConversations => '搜索聊天...';

  @override
  String get noMessages => '还没有消息';

  @override
  String get noSearchResults => '没有找到相关会话';

  @override
  String get createNewChat => '点击右上角发起新的聊天吧';

  @override
  String get noMessagePreview => '暂无消息';

  @override
  String get searchUsers => '搜索用户名或昵称';

  @override
  String get groupChatName => '群聊名称';

  @override
  String get searchMembers => '搜索添加成员';

  @override
  String createFailed2(Object error) {
    return '创建失败：$error';
  }

  @override
  String createGroupButton(Object count) {
    return '创建群聊（$count 人）';
  }

  @override
  String get recall => '撤回';

  @override
  String get recallTimeLimit => '消息仅2分钟内可撤回';

  @override
  String get messageDeleted => '消息已撤回';

  @override
  String audioPlayFailed(Object error) {
    return '播放失败：$error';
  }

  @override
  String scriptureQuote(Object scripture, Object chapter) {
    return '《$scripture》$chapter';
  }

  @override
  String get downloading => '正在下载…';

  @override
  String cannotOpen(Object message) {
    return '无法打开：$message';
  }

  @override
  String openFailed(Object error) {
    return '打开失败：$error';
  }

  @override
  String get today => '今天';

  @override
  String get yesterday => '昨天';

  @override
  String get square => '广场';

  @override
  String get latest => '最新';

  @override
  String get hot => '热门';

  @override
  String get topics => '话题';

  @override
  String get emptyFollowingSubtitle => '去广场发现有趣的人吧！';

  @override
  String get emptyPostsHint => '还没有帖子，来发第一条吧！';

  @override
  String newPostsNotification(Object count) {
    return '有 $count 条新帖子，点击刷新';
  }

  @override
  String get emptyTopicPosts => '该话题暂无帖子';

  @override
  String get searchTopicsHint => '搜索话题...';

  @override
  String get emptyTopics => '暂无话题';

  @override
  String get hotTopics => '热门话题';

  @override
  String get postTitle => '发帖';

  @override
  String get publish => '发布';

  @override
  String get shareThoughtsHint => '分享你的想法...';

  @override
  String get addTopicHint => '添加话题 #';

  @override
  String get postDetail => '帖子详情';

  @override
  String get comments => '评论';

  @override
  String get emptyComments => '暂无评论，来第一个评论吧！';

  @override
  String get writeCommentHint => '写评论...';

  @override
  String commentFailed(Object error) {
    return '评论失败：$error';
  }

  @override
  String get deletePost => '删除帖子';

  @override
  String get deletePostConfirm => '确定要删除这条帖子吗？此操作无法撤销。';

  @override
  String get deleteComment => '删除评论';

  @override
  String get deleteCommentConfirm => '确定要删除这条评论吗？此操作无法撤销。';

  @override
  String get unknownUser => '未知用户';

  @override
  String get searchHint => '搜索用户、动态、经书...';

  @override
  String get users => '用户';

  @override
  String get posts2 => '动态';

  @override
  String get search => '搜索';

  @override
  String get searchEmptySubtitle => '查找用户、动态或经书';

  @override
  String get emptyUsers => '没有找到相关用户';

  @override
  String get emptyPosts => '没有找到相关动态';

  @override
  String get emptyScriptures => '没有找到相关经书';

  @override
  String get notifications => '通知';

  @override
  String get markAllRead => '全部已读';

  @override
  String get emptyNotifications => '暂无通知';

  @override
  String get emptyNotificationsSubtitle => '有新的互动会在这里提醒你';

  @override
  String publishFailed(Object error) {
    return '发布失败：$error';
  }

  @override
  String connectionFailed(Object error) {
    return '连接失败：$error';
  }

  @override
  String get inCall => '通话中';

  @override
  String get ringing => '呼叫中...';

  @override
  String get callDeclined => '对方已拒绝';

  @override
  String get callEnded => '通话已结束';

  @override
  String get connecting => '连接中...';

  @override
  String get mute => '静音';

  @override
  String get unmute => '取消静音';

  @override
  String get cameraOff => '关摄像头';

  @override
  String get cameraOn => '开摄像头';

  @override
  String get earpiece => '听筒';

  @override
  String get speaker => '扬声器';

  @override
  String get waitingForHost => '等待主播开始直播...';

  @override
  String get micOn => '开麦';

  @override
  String get flipCamera => '翻转';

  @override
  String get endLivestream => '结束直播';

  @override
  String get incomingCall => '来电';

  @override
  String get livestreamInvite => '直播邀请';

  @override
  String callInvitation(Object typeLabel) {
    return '$typeLabel邀请…';
  }

  @override
  String get decline => '拒绝';

  @override
  String get accept => '接听';

  @override
  String get appName => 'Omega';

  @override
  String get appTagline => '经典传承，社区共建';

  @override
  String get welcomeBack => '欢迎回来';

  @override
  String get email => '邮箱';

  @override
  String get invalidEmailError => '请输入有效邮箱';

  @override
  String get password => '密码';

  @override
  String get passwordTooShortError => '密码至少6位';

  @override
  String get login => '登录';

  @override
  String get noAccountRegisterNow => '还没有账号？立即注册';

  @override
  String get networkError => '网络连接失败，请检查网络后重试';

  @override
  String get loginFailedGeneric => '邮箱或密码错误';

  @override
  String loginFailed(Object error) {
    return '登录失败：$error';
  }

  @override
  String get createAccount => '创建账号';

  @override
  String get nicknameRequiredError => '请输入昵称';

  @override
  String get register => '注册';

  @override
  String get hasAccountGoLogin => '已有账号？去登录';

  @override
  String registerFailed(Object error) {
    return '注册失败：$error';
  }

  @override
  String get tabProfile => '我的';

  @override
  String acceptCallFailed(Object error) {
    return '接听失败：$error';
  }

  @override
  String get imagePlaceholder => '[图片]';

  @override
  String get videoPlaceholder => '[视频]';

  @override
  String get filePlaceholder => '[文件]';

  @override
  String get audioPlaceholder => '[语音]';

  @override
  String get scripturePlaceholder => '[经文引用]';

  @override
  String notificationLiked(Object actor) {
    return '$actor 点赞了你的帖子';
  }

  @override
  String notificationCommented(Object actor) {
    return '$actor 评论了你的帖子';
  }

  @override
  String notificationFollowed(Object actor) {
    return '$actor 关注了你';
  }

  @override
  String get someone => '有人';

  @override
  String get newNotification => '你有一条新通知';

  @override
  String get action => '操作';

  @override
  String blockUserConfirm3(Object name) {
    return '确定拉黑 $name 吗？';
  }

  @override
  String get unblock => '解除拉黑';

  @override
  String get categoryDaoism => '道家';

  @override
  String get categoryBuddhism => '佛经';

  @override
  String get categoryChrisiandity => '基督教';

  @override
  String crossRefVerse(Object chapterTitle, Object verse) {
    return '$chapterTitle $verse节';
  }

  @override
  String crossRefVerseRange(
    Object chapterTitle,
    Object verseStart,
    Object verseEnd,
  ) {
    return '$chapterTitle $verseStart-$verseEnd节';
  }

  @override
  String get send => '发送';

  @override
  String get messageHint => '输入消息...';

  @override
  String get thisUser => '该用户';

  @override
  String callStartFailed(Object error) {
    return '发起通话失败：$error';
  }

  @override
  String livestreamStartFailed(Object error) {
    return '发起直播失败：$error';
  }

  @override
  String get regionCNBJ => '北京';

  @override
  String get regionCNSH => '上海';

  @override
  String get regionCNGD => '广东';

  @override
  String get regionCNZJ => '浙江';

  @override
  String get regionCNJS => '江苏';

  @override
  String get regionCNSC => '四川';

  @override
  String get regionHK => '香港';

  @override
  String get regionTW => '台湾';

  @override
  String get regionSG => '新加坡';

  @override
  String get regionMY => '马来西亚';

  @override
  String get regionUS => '美国';

  @override
  String get regionCA => '加拿大';

  @override
  String get regionAU => '澳大利亚';

  @override
  String get regionGB => '英国';

  @override
  String get regionJP => '日本';

  @override
  String get regionKR => '韩国';

  @override
  String get regionOTHER => '其他';

  @override
  String get recordingTooShort => '录音太短，未发送';

  @override
  String get onlineMembers => '在线成员';

  @override
  String get me => '我';

  @override
  String get hostLabel => '主播';

  @override
  String get deleteAccount => '注销账号';

  @override
  String get deleteAccountConfirm =>
      '确定要注销账号吗？此操作无法撤销。注销后，您的所有帖子、评论、消息和个人资料都将被永久删除。';

  @override
  String get deleteAccountSuccess => '账号注销成功。';

  @override
  String deleteAccountFailed(Object error) {
    return '注销失败：$error';
  }

  @override
  String get report => '举报';

  @override
  String get reportReason => '选择举报原因';

  @override
  String get reportReasonSpam => '垃圾广告或营销';

  @override
  String get reportReasonHarassment => '骚扰或仇恨言论';

  @override
  String get reportReasonObjectionable => '不良或不当内容';

  @override
  String get reportReasonViolence => '暴力或血腥内容';

  @override
  String get reportReasonOther => '其他问题';

  @override
  String get reportSuccess => '举报成功，我们将在 24 小时内进行审核处理。';

  @override
  String reportFailed(Object error) {
    return '举报失败，请稍后重试$error';
  }

  @override
  String get eulaMustAgree => '请先阅读并同意用户协议与隐私政策';

  @override
  String get agreeIntro => '我已阅读并同意';

  @override
  String get userAgreement => '《用户协议》';

  @override
  String get privacyPolicy => '《隐私政策》';

  @override
  String get and => '和';

  @override
  String get blockedUsers => '拉黑用户';

  @override
  String get noBlockedUsers => '还没有拉黑任何人';

  @override
  String get contentBlocked => '内容含违规词，请修改后再发';

  @override
  String get forgotPassword => '忘记密码？';

  @override
  String get resetPassword => '重置密码';

  @override
  String get resetEmailHint => '输入注册邮箱';

  @override
  String get sendCode => '发送验证码';

  @override
  String get resendCode => '重新发送';

  @override
  String get codeHint => '6位验证码';

  @override
  String get newPasswordHint => '设置新密码（至少6位）';

  @override
  String get resetCodeSent => '验证码已发送，请查收邮箱';

  @override
  String get resetSuccess => '密码已重置，请用新密码登录';

  @override
  String get resetFailed => '重置失败，请检查验证码或稍后重试';

  @override
  String get emailRequired => '请输入邮箱';

  @override
  String get codeRequired => '请输入验证码';

  @override
  String get verifyEmailTitle => '验证邮箱';

  @override
  String verifyEmailHint(Object email) {
    return '我们已向 $email 发送了一封验证码邮件，请输入邮件中的验证码完成注册。';
  }

  @override
  String get verifyEmailButton => '完成注册';

  @override
  String get verifyEmailSuccess => '邮箱验证成功，欢迎加入';

  @override
  String get verifyEmailFailed => '验证失败，请检查验证码或稍后重试';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get deleteConversation => '刪除對話';

  @override
  String get deleteConversationConfirm => '確定刪除此對話嗎？僅從你的列表移除，不影響對方。';

  @override
  String get conversationDeleted => '已刪除對話';

  @override
  String get noOneSharingCamera => '還沒有人開啟攝像頭';

  @override
  String unblockConfirm(Object name) {
    return '確定取消封鎖「$name」嗎？取消後對方可再次傳訊給你。';
  }

  @override
  String userUnblocked(Object name) {
    return '已取消封鎖「$name」';
  }

  @override
  String get downloadForOffline => '下載離線';

  @override
  String get downloadedOffline => '已下載，可離線閱讀';

  @override
  String get downloadComplete => '下載完成，可離線閱讀';

  @override
  String downloadFailed(Object error) {
    return '下載失敗：$error';
  }

  @override
  String get chatFiles => '聊天檔案';

  @override
  String get addMembers => '新增成員';

  @override
  String get membersAdded => '已新增成員';

  @override
  String get searchUserHint => '搜尋使用者名稱或暱稱';

  @override
  String loadFailed(Object error) {
    return '載入失敗：$error';
  }

  @override
  String get contents => '目錄';

  @override
  String get noChapterContent => '暫無章節內容';

  @override
  String get continueReading => '繼續閱讀';

  @override
  String get startReading => '開始閱讀';

  @override
  String chaptersCountLabel(Object chaptersCount) {
    return '$chaptersCount 章';
  }

  @override
  String readPercent(Object percent) {
    return '已讀 $percent%';
  }

  @override
  String get bookGenesis => '創世記';

  @override
  String get bookExodus => '出埃及記';

  @override
  String get bookLeviticus => '利未記';

  @override
  String get bookNumbers => '民數記';

  @override
  String get bookDeuteronomy => '申命記';

  @override
  String get bookJoshua => '約書亞記';

  @override
  String get bookJudges => '士師記';

  @override
  String get bookRuth => '路得記';

  @override
  String get book1Samuel => '撒母耳記上';

  @override
  String get book2Samuel => '撒母耳記下';

  @override
  String get book1Kings => '列王紀上';

  @override
  String get book2Kings => '列王紀下';

  @override
  String get book1Chronicles => '歷代志上';

  @override
  String get book2Chronicles => '歷代志下';

  @override
  String get bookEzra => '以斯拉記';

  @override
  String get bookNehemiah => '尼希米記';

  @override
  String get bookEsther => '以斯帖記';

  @override
  String get bookJob => '約伯記';

  @override
  String get bookPsalms => '詩篇';

  @override
  String get bookProverbs => '箴言';

  @override
  String get bookEcclesiastes => '傳道書';

  @override
  String get bookSongOfSongs => '雅歌';

  @override
  String get bookIsaiah => '以賽亞書';

  @override
  String get bookJeremiah => '耶利米書';

  @override
  String get bookLamentations => '耶利米哀歌';

  @override
  String get bookEzekiel => '以西結書';

  @override
  String get bookDaniel => '但以理書';

  @override
  String get bookHosea => '何西阿書';

  @override
  String get bookJoel => '約珥書';

  @override
  String get bookAmos => '阿摩司書';

  @override
  String get bookObadiah => '俄巴底亞書';

  @override
  String get bookJonah => '約拿書';

  @override
  String get bookMicah => '彌迦書';

  @override
  String get bookNahum => '那鴻書';

  @override
  String get bookHabakkuk => '哈巴谷書';

  @override
  String get bookZephaniah => '西番雅書';

  @override
  String get bookHaggai => '哈該書';

  @override
  String get bookZechariah => '撒迦利亞書';

  @override
  String get bookMalachi => '瑪拉基書';

  @override
  String get bookMatthew => '馬太福音';

  @override
  String get bookMark => '馬可福音';

  @override
  String get bookLuke => '路加福音';

  @override
  String get bookJohn => '約翰福音';

  @override
  String get bookActs => '使徒行傳';

  @override
  String get bookRomans => '羅馬書';

  @override
  String get book1Corinthians => '哥林多前書';

  @override
  String get book2Corinthians => '哥林多後書';

  @override
  String get bookGalatians => '加拉太書';

  @override
  String get bookEphesians => '以弗所書';

  @override
  String get bookPhilippians => '腓立比書';

  @override
  String get bookColossians => '歌羅西書';

  @override
  String get book1Thessalonians => '帖撒羅尼迦前書';

  @override
  String get book2Thessalonians => '帖撒羅尼迦後書';

  @override
  String get book1Timothy => '提摩太前書';

  @override
  String get book2Timothy => '提摩太後書';

  @override
  String get bookTitus => '提多書';

  @override
  String get bookPhilemon => '腓利門書';

  @override
  String get bookHebrews => '希伯來書';

  @override
  String get bookJames => '雅各書';

  @override
  String get book1Peter => '彼得前書';

  @override
  String get book2Peter => '彼得後書';

  @override
  String get book1John => '約翰一書';

  @override
  String get book2John => '約翰二書';

  @override
  String get book3John => '約翰三書';

  @override
  String get bookJude => '猶大書';

  @override
  String get bookRevelation => '啟示錄';

  @override
  String get books => '書卷';

  @override
  String get chapters => '章';

  @override
  String get oldTestament => '舊約';

  @override
  String get newTestament => '新約';

  @override
  String get selectBookFirst => '請先從書卷中選擇一本書';

  @override
  String volumeCount(Object count) {
    return '$count卷';
  }

  @override
  String bookChapterDisplay(Object bookName, Object chapterNumber) {
    return '$bookName 第$chapterNumber章';
  }

  @override
  String get editGroupAnnouncement => '編輯群公告';

  @override
  String get announcementHint => '輸入群公告內容...';

  @override
  String get cancel => '取消';

  @override
  String get save => '儲存';

  @override
  String saveFailed(Object error) {
    return '儲存失敗：$error';
  }

  @override
  String get removeFromGroup => '移出群組';

  @override
  String get removedFromGroup => '已移出群組';

  @override
  String operationFailed(Object error) {
    return '操作失敗：$error';
  }

  @override
  String get promoteToAdmin => '設為管理員';

  @override
  String get promotedToAdmin => '已設為管理員';

  @override
  String get demoteAdmin => '撤銷管理員';

  @override
  String get demotedAdmin => '已撤銷管理員權限';

  @override
  String get leaveGroup => '退出群組';

  @override
  String get confirmLeaveGroup => '確定要退出此群組嗎？';

  @override
  String leaveFailed(Object error) {
    return '退出失敗：$error';
  }

  @override
  String get disbandGroup => '解散群組';

  @override
  String get confirmDisbandGroup => '解散後所有成員將被移出，聊天記錄將被刪除，此操作無法復原。確定要解散嗎？';

  @override
  String get groupInfo => '群組資訊';

  @override
  String get group => '群組';

  @override
  String memberCount(Object count) {
    return '$count 名成員';
  }

  @override
  String get announcement => '群組公告';

  @override
  String get clickToSetAnnouncement => '點擊設定群組公告';

  @override
  String get noAnnouncement => '暫無公告';

  @override
  String get groupFiles => '群組檔案';

  @override
  String members(Object count) {
    return '成員 ($count)';
  }

  @override
  String get you => '你';

  @override
  String get admin => '管理員';

  @override
  String get groupOwner => '群主';

  @override
  String createFailed(Object error) {
    return '新增失敗：$error';
  }

  @override
  String get deleteFolder => '刪除資料夾';

  @override
  String confirmDeleteFolder(Object folderName) {
    return '確定刪除「$folderName」嗎？資料夾內的檔案會移回根目錄，不會被刪除。';
  }

  @override
  String get delete => '刪除';

  @override
  String deleteFailed(Object error) {
    return '刪除失敗：$error';
  }

  @override
  String renameFailed(Object error) {
    return '重新命名失敗：$error';
  }

  @override
  String get createFolder => '新增資料夾';

  @override
  String get uploadFile => '上傳檔案';

  @override
  String get renameFolder => '重新命名資料夾';

  @override
  String get folderName => '資料夾名稱';

  @override
  String get confirm => '確定';

  @override
  String moveFileTo(Object fileName) {
    return '移動「$fileName」到';
  }

  @override
  String get rootDirectory => '根目錄';

  @override
  String moveFailed(Object error) {
    return '移動失敗：$error';
  }

  @override
  String get cannotOpenFile => '無法開啟檔案';

  @override
  String get files => '檔案';

  @override
  String get noSharedFiles => '暫無共享檔案';

  @override
  String get folderEmpty => '此資料夾為空';

  @override
  String get emptyFilesHint => '在聊天中傳送檔案後會顯示在這裡\n點右上角可新增資料夾';

  @override
  String get longPressToMoveFile => '長按檔案可移動到這裡';

  @override
  String get rename => '重新命名';

  @override
  String fileCount(Object count) {
    return '$count 個檔案';
  }

  @override
  String get moveToFolder => '移動到資料夾';

  @override
  String get unknownFile => '未知檔案';

  @override
  String get copiedToClipboard => '已複製到剪貼簿';

  @override
  String get selectConversation => '選擇對話';

  @override
  String get privateChat => '私訊';

  @override
  String get sentToChat => '已傳送到聊天';

  @override
  String noteTitle(Object chapterTitle) {
    return '筆記 · $chapterTitle';
  }

  @override
  String get noteHint => '寫下你的感悟...';

  @override
  String get copyScripture => '複製經文';

  @override
  String get sendToChat => '傳送到聊天';

  @override
  String selectedVerses(Object count) {
    return '已選 $count 節';
  }

  @override
  String get copy => '複製';

  @override
  String get quoteToChat => '引用到聊天';

  @override
  String get fontSizeSmall => '小';

  @override
  String get fontSizeNormal => '標準';

  @override
  String get fontSizeLarge => '大';

  @override
  String get fontSizeExtraLarge => '特大';

  @override
  String get previousChapter => '上一章';

  @override
  String get note => '筆記';

  @override
  String get highlight => '劃線';

  @override
  String get bookmark => '收藏';

  @override
  String get quote => '引用';

  @override
  String get nextChapter => '下一章';

  @override
  String oldTestamentCount(Object count) {
    return '舊約 $count';
  }

  @override
  String crossReferenceTitle(Object chapterTitle, Object verse) {
    return '$chapterTitle 第$verse節 · 引用舊約';
  }

  @override
  String get chapterNotFound => '找不到對應章節';

  @override
  String get scripture => '經書';

  @override
  String get myBookmarks => '我的書籤';

  @override
  String get savedPosts => '我的收藏';

  @override
  String get bookmarkTabScripture => '經書';

  @override
  String get bookmarkTabPosts => '貼文';

  @override
  String get noSavedPosts => '還沒有收藏的貼文';

  @override
  String get myPosts => '我的發帖';

  @override
  String get lastReading => '上次閱讀';

  @override
  String get allScriptures => '全部經書';

  @override
  String get continueLabel => '繼續';

  @override
  String chapterCount(Object count) {
    return '$count 章';
  }

  @override
  String get noScriptureContent => '暫無經書內容';

  @override
  String get noBookmarks => '還沒有書籤';

  @override
  String get bookmarkHint => '閱讀經文時點選書籤圖示即可收藏';

  @override
  String get deletedChapter => '已刪除章節';

  @override
  String get blockUserTitle => '封鎖使用者';

  @override
  String blockUserConfirm(Object displayName) {
    return '確定要封鎖 $displayName 嗎？';
  }

  @override
  String get block => '封鎖';

  @override
  String get userBlocked => '已封鎖該使用者';

  @override
  String directMessageFailed(Object error) {
    return '發起私訊失敗：$error';
  }

  @override
  String get settings => '設定';

  @override
  String get editProfile => '編輯資料';

  @override
  String get languageSettings => '切換語言';

  @override
  String get logout => '登出';

  @override
  String get confirmLogout => '確定要登出嗎？';

  @override
  String get confirmButton => '登出';

  @override
  String get userNotFound => '使用者不存在';

  @override
  String get noPosts => '還沒有發文';

  @override
  String get posts => '貼文';

  @override
  String get followers => '粉絲';

  @override
  String get following => '關注';

  @override
  String get alreadyFollowing => '已關注';

  @override
  String get directMessage => '私訊';

  @override
  String get displayNameRequired => '暱稱不能為空';

  @override
  String get savingSucceeded => '儲存成功';

  @override
  String get clickToChangeAvatar => '點選更換大頭貼';

  @override
  String get displayName => '暱稱';

  @override
  String get bio => '個人簡介';

  @override
  String get region => '所在地區';

  @override
  String get notSet => '不設定';

  @override
  String get languagePreference => '語言偏好';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get regionBeijing => '北京';

  @override
  String get regionShanghai => '上海';

  @override
  String get regionGuangdong => '廣東';

  @override
  String get regionZhejiang => '浙江';

  @override
  String get regionJiangsu => '江蘇';

  @override
  String get regionSichuan => '四川';

  @override
  String get regionHongKong => '香港';

  @override
  String get regionTaiwan => '臺灣';

  @override
  String get regionSingapore => '新加坡';

  @override
  String get regionMalaysia => '馬來西亞';

  @override
  String get regionUSA => '美國';

  @override
  String get regionCanada => '加拿大';

  @override
  String get regionAustralia => '澳洲';

  @override
  String get regionUK => '英國';

  @override
  String get regionJapan => '日本';

  @override
  String get regionSouthKorea => '韓國';

  @override
  String get regionOther => '其他';

  @override
  String followersList(Object displayName) {
    return '$displayName的粉絲';
  }

  @override
  String followingList(Object displayName) {
    return '$displayName的關注';
  }

  @override
  String get noFollowers => '尚無粉絲';

  @override
  String get noFollowing => '還沒有關注任何人';

  @override
  String followerCount(Object count) {
    return '$count 粉絲';
  }

  @override
  String joinLivestreamFailed(Object error) {
    return '加入直播失敗：$error';
  }

  @override
  String sendFailed(Object error) {
    return '傳送失敗：$error';
  }

  @override
  String get blockedCannotSend => '對方已將你封鎖，訊息無法送達';

  @override
  String get microphonePermissionRequired => '需要麥克風權限才能錄音';

  @override
  String get attachmentTitle => '傳送內容';

  @override
  String get attachmentPhoto => '圖片';

  @override
  String get attachmentVideo => '影片';

  @override
  String get attachmentCamera => '拍攝';

  @override
  String blockUserConfirm2(Object name) {
    return '確定要封鎖 $name 嗎？';
  }

  @override
  String userBlocked2(Object name) {
    return '已封鎖 $name';
  }

  @override
  String get online => '線上';

  @override
  String get voiceCall => '語音通話';

  @override
  String get videoCall => '視訊通話';

  @override
  String get startLivestream => '開始直播';

  @override
  String get groupLivestreamOngoing => '群組正在直播';

  @override
  String get joinLivestream => '點擊加入';

  @override
  String get sendFirstMessage => '傳送第一則訊息吧！';

  @override
  String get recording => '錄音中';

  @override
  String get messages => '訊息';

  @override
  String get searchConversations => '搜尋聊天...';

  @override
  String get noMessages => '還沒有訊息';

  @override
  String get noSearchResults => '找不到相關對話';

  @override
  String get createNewChat => '點擊右上角發起新的聊天吧';

  @override
  String get noMessagePreview => '暫無訊息';

  @override
  String get searchUsers => '搜尋使用者名稱或暱稱';

  @override
  String get groupChatName => '群組名稱';

  @override
  String get searchMembers => '搜尋並新增成員';

  @override
  String createFailed2(Object error) {
    return '建立失敗：$error';
  }

  @override
  String createGroupButton(Object count) {
    return '建立群組（$count 人）';
  }

  @override
  String get recall => '收回';

  @override
  String get recallTimeLimit => '訊息僅可在 2 分鐘內收回';

  @override
  String get messageDeleted => '訊息已收回';

  @override
  String audioPlayFailed(Object error) {
    return '播放失敗：$error';
  }

  @override
  String scriptureQuote(Object scripture, Object chapter) {
    return '《$scripture》$chapter';
  }

  @override
  String get downloading => '下載中…';

  @override
  String cannotOpen(Object message) {
    return '無法開啟：$message';
  }

  @override
  String openFailed(Object error) {
    return '開啟失敗：$error';
  }

  @override
  String get today => '今天';

  @override
  String get yesterday => '昨天';

  @override
  String get square => '廣場';

  @override
  String get latest => '最新';

  @override
  String get hot => '熱門';

  @override
  String get topics => '話題';

  @override
  String get emptyFollowingSubtitle => '去廣場發現有趣的人吧！';

  @override
  String get emptyPostsHint => '還沒有貼文，來發第一則吧！';

  @override
  String newPostsNotification(Object count) {
    return '有 $count 則新貼文，點擊重新整理';
  }

  @override
  String get emptyTopicPosts => '此話題暫無貼文';

  @override
  String get searchTopicsHint => '搜尋話題...';

  @override
  String get emptyTopics => '暫無話題';

  @override
  String get hotTopics => '熱門話題';

  @override
  String get postTitle => '發文';

  @override
  String get publish => '發布';

  @override
  String get shareThoughtsHint => '分享你的想法...';

  @override
  String get addTopicHint => '新增話題 #';

  @override
  String get postDetail => '貼文詳情';

  @override
  String get comments => '留言';

  @override
  String get emptyComments => '暫無留言，來搶頭香吧！';

  @override
  String get writeCommentHint => '寫留言...';

  @override
  String commentFailed(Object error) {
    return '留言失敗：$error';
  }

  @override
  String get deletePost => '刪除貼文';

  @override
  String get deletePostConfirm => '確定要刪除這則貼文嗎？此操作無法復原。';

  @override
  String get deleteComment => '刪除留言';

  @override
  String get deleteCommentConfirm => '確定要刪除這條留言嗎？此操作無法復原。';

  @override
  String get unknownUser => '未知使用者';

  @override
  String get searchHint => '搜尋使用者、動態、經書...';

  @override
  String get users => '使用者';

  @override
  String get posts2 => '動態';

  @override
  String get search => '搜尋';

  @override
  String get searchEmptySubtitle => '尋找使用者、動態或經書';

  @override
  String get emptyUsers => '找不到相關使用者';

  @override
  String get emptyPosts => '找不到相關動態';

  @override
  String get emptyScriptures => '找不到相關經書';

  @override
  String get notifications => '通知';

  @override
  String get markAllRead => '全部標為已讀';

  @override
  String get emptyNotifications => '暫無通知';

  @override
  String get emptyNotificationsSubtitle => '有新的互動會在這裡提醒你';

  @override
  String publishFailed(Object error) {
    return '發布失敗：$error';
  }

  @override
  String connectionFailed(Object error) {
    return '連線失敗：$error';
  }

  @override
  String get inCall => '通話中';

  @override
  String get ringing => '撥號中...';

  @override
  String get callDeclined => '對方已拒絕';

  @override
  String get callEnded => '通話已結束';

  @override
  String get connecting => '連線中...';

  @override
  String get mute => '靜音';

  @override
  String get unmute => '取消靜音';

  @override
  String get cameraOff => '關閉鏡頭';

  @override
  String get cameraOn => '開啟鏡頭';

  @override
  String get earpiece => '聽筒';

  @override
  String get speaker => '擴音';

  @override
  String get waitingForHost => '等待主播開始直播…';

  @override
  String get micOn => '開麥';

  @override
  String get flipCamera => '翻轉';

  @override
  String get endLivestream => '結束直播';

  @override
  String get incomingCall => '來電';

  @override
  String get livestreamInvite => '直播邀請';

  @override
  String callInvitation(Object typeLabel) {
    return '$typeLabel邀請…';
  }

  @override
  String get decline => '拒絕';

  @override
  String get accept => '接聽';

  @override
  String get appName => 'Omega';

  @override
  String get appTagline => '經典傳承，社群共建';

  @override
  String get welcomeBack => '歡迎回來';

  @override
  String get email => '電子郵件';

  @override
  String get invalidEmailError => '請輸入有效的電子郵件';

  @override
  String get password => '密碼';

  @override
  String get passwordTooShortError => '密碼至少 6 位';

  @override
  String get login => '登入';

  @override
  String get noAccountRegisterNow => '還沒有帳號？立即註冊';

  @override
  String get networkError => '網路連線失敗，請檢查網路後重試';

  @override
  String get loginFailedGeneric => '信箱或密碼錯誤';

  @override
  String loginFailed(Object error) {
    return '登入失敗：$error';
  }

  @override
  String get createAccount => '建立帳號';

  @override
  String get nicknameRequiredError => '請輸入暱稱';

  @override
  String get register => '註冊';

  @override
  String get hasAccountGoLogin => '已有帳號？前往登入';

  @override
  String registerFailed(Object error) {
    return '註冊失敗：$error';
  }

  @override
  String get tabProfile => '我的';

  @override
  String acceptCallFailed(Object error) {
    return '接聽失敗：$error';
  }

  @override
  String get imagePlaceholder => '[圖片]';

  @override
  String get videoPlaceholder => '[影片]';

  @override
  String get filePlaceholder => '[檔案]';

  @override
  String get audioPlaceholder => '[語音]';

  @override
  String get scripturePlaceholder => '[經文引用]';

  @override
  String notificationLiked(Object actor) {
    return '$actor 對你的貼文按了讚';
  }

  @override
  String notificationCommented(Object actor) {
    return '$actor 留言了你的貼文';
  }

  @override
  String notificationFollowed(Object actor) {
    return '$actor 追蹤了你';
  }

  @override
  String get someone => '有人';

  @override
  String get newNotification => '你有一則新通知';

  @override
  String get action => '操作';

  @override
  String blockUserConfirm3(Object name) {
    return '確定要封鎖 $name 嗎？';
  }

  @override
  String get unblock => '解除封鎖';

  @override
  String get categoryDaoism => '道家';

  @override
  String get categoryBuddhism => '佛經';

  @override
  String get categoryChrisiandity => '基督教';

  @override
  String crossRefVerse(Object chapterTitle, Object verse) {
    return '$chapterTitle $verse節';
  }

  @override
  String crossRefVerseRange(
    Object chapterTitle,
    Object verseStart,
    Object verseEnd,
  ) {
    return '$chapterTitle $verseStart-$verseEnd節';
  }

  @override
  String get send => '傳送';

  @override
  String get messageHint => '輸入訊息...';

  @override
  String get thisUser => '該用戶';

  @override
  String callStartFailed(Object error) {
    return '發起通話失敗：$error';
  }

  @override
  String livestreamStartFailed(Object error) {
    return '發起直播失敗：$error';
  }

  @override
  String get regionCNBJ => '北京';

  @override
  String get regionCNSH => '上海';

  @override
  String get regionCNGD => '廣東';

  @override
  String get regionCNZJ => '浙江';

  @override
  String get regionCNJS => '江蘇';

  @override
  String get regionCNSC => '四川';

  @override
  String get regionHK => '香港';

  @override
  String get regionTW => '台灣';

  @override
  String get regionSG => '新加坡';

  @override
  String get regionMY => '馬來西亞';

  @override
  String get regionUS => '美國';

  @override
  String get regionCA => '加拿大';

  @override
  String get regionAU => '澳大利亞';

  @override
  String get regionGB => '英國';

  @override
  String get regionJP => '日本';

  @override
  String get regionKR => '韓國';

  @override
  String get regionOTHER => '其他';

  @override
  String get recordingTooShort => '錄音太短，未傳送';

  @override
  String get onlineMembers => '線上成員';

  @override
  String get me => '我';

  @override
  String get hostLabel => '主播';

  @override
  String get deleteAccount => '註銷帳號';

  @override
  String get deleteAccountConfirm =>
      '確定要註銷帳號嗎？此操作無法撤銷。註銷後，您的所有貼文、留言、訊息和個人資料都將被永久刪除。';

  @override
  String get deleteAccountSuccess => '帳號註銷成功。';

  @override
  String deleteAccountFailed(Object error) {
    return '註銷失敗：$error';
  }

  @override
  String get report => '檢舉';

  @override
  String get reportReason => '選擇檢舉原因';

  @override
  String get reportReasonSpam => '垃圾廣告或行銷';

  @override
  String get reportReasonHarassment => '骚扰或仇恨言論';

  @override
  String get reportReasonObjectionable => '不良或不當內容';

  @override
  String get reportReasonViolence => '暴力或血腥內容';

  @override
  String get reportReasonOther => '其他問題';

  @override
  String get reportSuccess => '檢舉成功，我們將在 24 小時內進行審核處理。';

  @override
  String reportFailed(Object error) {
    return '檢舉失敗，請稍後重試$error';
  }

  @override
  String get eulaMustAgree => '請先閱讀並同意用戶協議與隱私政策';

  @override
  String get agreeIntro => '我已閱讀並同意';

  @override
  String get userAgreement => '《用戶協議》';

  @override
  String get privacyPolicy => '《隱私政策》';

  @override
  String get and => '和';

  @override
  String get blockedUsers => '封鎖用戶';

  @override
  String get noBlockedUsers => '還沒有封鎖任何人';

  @override
  String get contentBlocked => '內容含違規詞，請修改後再發';

  @override
  String get forgotPassword => '忘記密碼？';

  @override
  String get resetPassword => '重設密碼';

  @override
  String get resetEmailHint => '輸入註冊郵箱';

  @override
  String get sendCode => '發送驗證碼';

  @override
  String get resendCode => '重新發送';

  @override
  String get codeHint => '6位驗證碼';

  @override
  String get newPasswordHint => '設定新密碼（至少6位）';

  @override
  String get resetCodeSent => '驗證碼已發送，請查收郵箱';

  @override
  String get resetSuccess => '密碼已重設，請用新密碼登入';

  @override
  String get resetFailed => '重設失敗，請檢查驗證碼或稍後重試';

  @override
  String get emailRequired => '請輸入郵箱';

  @override
  String get codeRequired => '請輸入驗證碼';

  @override
  String get verifyEmailTitle => '驗證信箱';

  @override
  String verifyEmailHint(Object email) {
    return '我們已向 $email 發送了一封驗證碼郵件，請輸入郵件中的驗證碼完成註冊。';
  }

  @override
  String get verifyEmailButton => '完成註冊';

  @override
  String get verifyEmailSuccess => '信箱驗證成功，歡迎加入';

  @override
  String get verifyEmailFailed => '驗證失敗，請檢查驗證碼或稍後重試';
}
