// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get deleteConversation => '会話を削除';

  @override
  String get deleteConversationConfirm => 'この会話を削除しますか？あなたのリストからのみ削除されます。';

  @override
  String get conversationDeleted => '会話を削除しました';

  @override
  String get noOneSharingCamera => 'まだ誰もカメラをオンにしていません';

  @override
  String unblockConfirm(Object name) {
    return '$nameのブロックを解除しますか？相手は再びメッセージを送れます。';
  }

  @override
  String userUnblocked(Object name) {
    return '$nameのブロックを解除しました';
  }

  @override
  String get downloadForOffline => 'オフライン用にダウンロード';

  @override
  String get downloadedOffline => 'ダウンロード済み（オフライン閲覧可）';

  @override
  String get downloadComplete => 'ダウンロード完了、オフラインで閲覧可能';

  @override
  String downloadFailed(Object error) {
    return 'ダウンロード失敗：$error';
  }

  @override
  String get chatFiles => 'チャットファイル';

  @override
  String get addMembers => 'メンバーを追加';

  @override
  String get membersAdded => 'メンバーを追加しました';

  @override
  String get searchUserHint => 'ユーザー名または名前で検索';

  @override
  String loadFailed(Object error) {
    return '読み込みに失敗しました：$error';
  }

  @override
  String get contents => '目次';

  @override
  String get noChapterContent => '章の内容がありません';

  @override
  String get continueReading => '続きを読む';

  @override
  String get startReading => '読み始める';

  @override
  String chaptersCountLabel(Object chaptersCount) {
    return '$chaptersCount 章';
  }

  @override
  String readPercent(Object percent) {
    return '$percent% 読了';
  }

  @override
  String get bookGenesis => '創世記';

  @override
  String get bookExodus => '出エジプト記';

  @override
  String get bookLeviticus => 'レビ記';

  @override
  String get bookNumbers => '民数記';

  @override
  String get bookDeuteronomy => '申命記';

  @override
  String get bookJoshua => 'ヨシュア記';

  @override
  String get bookJudges => '士師記';

  @override
  String get bookRuth => 'ルツ記';

  @override
  String get book1Samuel => 'サムエル記上';

  @override
  String get book2Samuel => 'サムエル記下';

  @override
  String get book1Kings => '列王記上';

  @override
  String get book2Kings => '列王記下';

  @override
  String get book1Chronicles => '歴代誌上';

  @override
  String get book2Chronicles => '歴代誌下';

  @override
  String get bookEzra => 'エズラ記';

  @override
  String get bookNehemiah => 'ネヘミヤ記';

  @override
  String get bookEsther => 'エステル記';

  @override
  String get bookJob => 'ヨブ記';

  @override
  String get bookPsalms => '詩篇';

  @override
  String get bookProverbs => '箴言';

  @override
  String get bookEcclesiastes => '伝道者の書';

  @override
  String get bookSongOfSongs => '雅歌';

  @override
  String get bookIsaiah => 'イザヤ書';

  @override
  String get bookJeremiah => 'エレミヤ書';

  @override
  String get bookLamentations => '哀歌';

  @override
  String get bookEzekiel => 'エゼキエル書';

  @override
  String get bookDaniel => 'ダニエル書';

  @override
  String get bookHosea => 'ホセア書';

  @override
  String get bookJoel => 'ヨエル書';

  @override
  String get bookAmos => 'アモス書';

  @override
  String get bookObadiah => 'オバデヤ書';

  @override
  String get bookJonah => 'ヨナ書';

  @override
  String get bookMicah => 'ミカ書';

  @override
  String get bookNahum => 'ナホム書';

  @override
  String get bookHabakkuk => 'ハバクク書';

  @override
  String get bookZephaniah => 'ゼパニヤ書';

  @override
  String get bookHaggai => 'ハガイ書';

  @override
  String get bookZechariah => 'ゼカリヤ書';

  @override
  String get bookMalachi => 'マラキ書';

  @override
  String get bookMatthew => 'マタイによる福音書';

  @override
  String get bookMark => 'マルコによる福音書';

  @override
  String get bookLuke => 'ルカによる福音書';

  @override
  String get bookJohn => 'ヨハネによる福音書';

  @override
  String get bookActs => '使徒の働き';

  @override
  String get bookRomans => 'ローマ人への手紙';

  @override
  String get book1Corinthians => 'コリント人への手紙第一';

  @override
  String get book2Corinthians => 'コリント人への手紙第二';

  @override
  String get bookGalatians => 'ガラテヤ人への手紙';

  @override
  String get bookEphesians => 'エペソ人への手紙';

  @override
  String get bookPhilippians => 'ピリピ人への手紙';

  @override
  String get bookColossians => 'コロサイ人への手紙';

  @override
  String get book1Thessalonians => 'テサロニケ人への手紙第一';

  @override
  String get book2Thessalonians => 'テサロニケ人への手紙第二';

  @override
  String get book1Timothy => 'テモテへの手紙第一';

  @override
  String get book2Timothy => 'テモテへの手紙第二';

  @override
  String get bookTitus => 'テトスへの手紙';

  @override
  String get bookPhilemon => 'ピレモンへの手紙';

  @override
  String get bookHebrews => 'ヘブル人への手紙';

  @override
  String get bookJames => 'ヤコブの手紙';

  @override
  String get book1Peter => 'ペテロの手紙第一';

  @override
  String get book2Peter => 'ペテロの手紙第二';

  @override
  String get book1John => 'ヨハネの手紙第一';

  @override
  String get book2John => 'ヨハネの手紙第二';

  @override
  String get book3John => 'ヨハネの手紙第三';

  @override
  String get bookJude => 'ユダの手紙';

  @override
  String get bookRevelation => 'ヨハネの黙示録';

  @override
  String get books => '書巻';

  @override
  String get chapters => '章';

  @override
  String get oldTestament => '旧約聖書';

  @override
  String get newTestament => '新約聖書';

  @override
  String get selectBookFirst => '先に書巻を選んでください';

  @override
  String volumeCount(Object count) {
    return '$count巻';
  }

  @override
  String bookChapterDisplay(Object bookName, Object chapterNumber) {
    return '$bookName $chapterNumber章';
  }

  @override
  String get editGroupName => 'グループ名を編集';

  @override
  String get groupNameHint => 'グループ名を入力...';

  @override
  String get editGroupAnnouncement => 'グループのお知らせを編集';

  @override
  String get announcementHint => 'お知らせを入力...';

  @override
  String get cancel => 'キャンセル';

  @override
  String get save => '保存';

  @override
  String saveFailed(Object error) {
    return '保存に失敗しました：$error';
  }

  @override
  String get removeFromGroup => 'グループから削除';

  @override
  String get removedFromGroup => 'グループから削除しました';

  @override
  String operationFailed(Object error) {
    return '操作に失敗しました：$error';
  }

  @override
  String get promoteToAdmin => '管理者に設定';

  @override
  String get promotedToAdmin => '管理者に設定しました';

  @override
  String get demoteAdmin => '管理者を解除';

  @override
  String get demotedAdmin => '管理者権限を解除しました';

  @override
  String get leaveGroup => 'グループを退出';

  @override
  String get confirmLeaveGroup => 'このグループを退出してもよろしいですか？';

  @override
  String leaveFailed(Object error) {
    return '退出に失敗しました：$error';
  }

  @override
  String get disbandGroup => 'グループを解散';

  @override
  String get confirmDisbandGroup =>
      '解散すると全メンバーが削除され、チャット履歴も削除されます。この操作は元に戻せません。解散してもよろしいですか？';

  @override
  String get groupInfo => 'グループ情報';

  @override
  String get group => 'グループ';

  @override
  String memberCount(Object count) {
    return '$count名のメンバー';
  }

  @override
  String get announcement => 'グループのお知らせ';

  @override
  String get clickToSetAnnouncement => 'タップしてお知らせを設定';

  @override
  String get noAnnouncement => 'お知らせはありません';

  @override
  String get groupFiles => 'グループのファイル';

  @override
  String members(Object count) {
    return 'メンバー ($count)';
  }

  @override
  String get you => 'あなた';

  @override
  String get admin => '管理者';

  @override
  String get groupOwner => 'オーナー';

  @override
  String createFailed(Object error) {
    return '作成に失敗しました：$error';
  }

  @override
  String get deleteFolder => 'フォルダを削除';

  @override
  String confirmDeleteFolder(Object folderName) {
    return '「$folderName」を削除しますか？フォルダ内のファイルはルートに戻され、削除されません。';
  }

  @override
  String get delete => '削除';

  @override
  String deleteFailed(Object error) {
    return '削除に失敗しました：$error';
  }

  @override
  String renameFailed(Object error) {
    return '名前の変更に失敗しました：$error';
  }

  @override
  String get createFolder => '新規フォルダ';

  @override
  String get uploadFile => 'ファイルをアップロード';

  @override
  String get renameFolder => 'フォルダ名を変更';

  @override
  String get folderName => 'フォルダ名';

  @override
  String get confirm => '確定';

  @override
  String moveFileTo(Object fileName) {
    return '「$fileName」の移動先';
  }

  @override
  String get rootDirectory => 'ルート';

  @override
  String moveFailed(Object error) {
    return '移動に失敗しました：$error';
  }

  @override
  String get cannotOpenFile => 'ファイルを開けません';

  @override
  String get files => 'ファイル';

  @override
  String get noSharedFiles => '共有ファイルはありません';

  @override
  String get folderEmpty => 'このフォルダは空です';

  @override
  String get emptyFilesHint => 'チャットで送信したファイルがここに表示されます\n右上をタップしてフォルダを作成できます';

  @override
  String get longPressToMoveFile => 'ファイルを長押しでここに移動できます';

  @override
  String get rename => '名前を変更';

  @override
  String fileCount(Object count) {
    return '$count 件のファイル';
  }

  @override
  String get moveToFolder => 'フォルダに移動';

  @override
  String get unknownFile => '不明なファイル';

  @override
  String get copiedToClipboard => 'クリップボードにコピーしました';

  @override
  String get selectConversation => 'トークを選択';

  @override
  String get privateChat => '個人チャット';

  @override
  String get sentToChat => 'チャットに送信しました';

  @override
  String noteTitle(Object chapterTitle) {
    return 'メモ · $chapterTitle';
  }

  @override
  String get noteHint => '気づきを書きましょう...';

  @override
  String get copyScripture => '聖句をコピー';

  @override
  String get sendToChat => 'チャットに送信';

  @override
  String selectedVerses(Object count) {
    return '$count 節を選択中';
  }

  @override
  String get copy => 'コピー';

  @override
  String get quoteToChat => 'チャットに引用';

  @override
  String get fontSizeSmall => '小';

  @override
  String get fontSizeNormal => '標準';

  @override
  String get fontSizeLarge => '大';

  @override
  String get fontSizeExtraLarge => '特大';

  @override
  String get previousChapter => '前の章';

  @override
  String get note => 'メモ';

  @override
  String get highlight => 'ハイライト';

  @override
  String get bookmark => 'お気に入り';

  @override
  String get quote => '引用';

  @override
  String get nextChapter => '次の章';

  @override
  String oldTestamentCount(Object count) {
    return '旧約 $count';
  }

  @override
  String crossReferenceTitle(Object chapterTitle, Object verse) {
    return '$chapterTitle $verse節 · 旧約からの引用';
  }

  @override
  String get chapterNotFound => '該当する章が見つかりません';

  @override
  String get scripture => '聖典';

  @override
  String get myBookmarks => 'マイブックマーク';

  @override
  String get savedPosts => '保存済み';

  @override
  String get bookmarkTabScripture => '聖典';

  @override
  String get bookmarkTabPosts => '投稿';

  @override
  String get noSavedPosts => '保存した投稿はまだありません';

  @override
  String get myPosts => '自分の投稿';

  @override
  String get lastReading => '前回の続き';

  @override
  String get allScriptures => 'すべての聖典';

  @override
  String get continueLabel => '続ける';

  @override
  String chapterCount(Object count) {
    return '$count 章';
  }

  @override
  String get noScriptureContent => '聖典のコンテンツがありません';

  @override
  String get noBookmarks => 'ブックマークはまだありません';

  @override
  String get bookmarkHint => '読みながらブックマークアイコンをタップして保存';

  @override
  String get deletedChapter => '削除された章';

  @override
  String get blockUserTitle => 'ユーザーをブロック';

  @override
  String blockUserConfirm(Object displayName) {
    return '$displayName さんをブロックしますか？';
  }

  @override
  String get block => 'ブロック';

  @override
  String get userBlocked => 'ユーザーをブロックしました';

  @override
  String directMessageFailed(Object error) {
    return 'メッセージの開始に失敗しました：$error';
  }

  @override
  String get settings => '設定';

  @override
  String get editProfile => 'プロフィールを編集';

  @override
  String get languageSettings => '言語を切り替え';

  @override
  String get logout => 'ログアウト';

  @override
  String get confirmLogout => 'ログアウトしてもよろしいですか？';

  @override
  String get confirmButton => 'ログアウト';

  @override
  String get userNotFound => 'ユーザーが存在しません';

  @override
  String get noPosts => '投稿はまだありません';

  @override
  String get posts => '投稿';

  @override
  String get followers => 'フォロワー';

  @override
  String get following => 'フォロー中';

  @override
  String get alreadyFollowing => 'フォロー中';

  @override
  String get directMessage => 'メッセージ';

  @override
  String get displayNameRequired => 'ニックネームを入力してください';

  @override
  String get savingSucceeded => '保存しました';

  @override
  String get clickToChangeAvatar => 'タップしてアバターを変更';

  @override
  String get displayName => 'ニックネーム';

  @override
  String get bio => '自己紹介';

  @override
  String get region => '地域';

  @override
  String get notSet => '未設定';

  @override
  String get languagePreference => '言語設定';

  @override
  String get languageChinese => '中国語';

  @override
  String get languageEnglish => 'English';

  @override
  String get regionBeijing => '北京';

  @override
  String get regionShanghai => '上海';

  @override
  String get regionGuangdong => '広東';

  @override
  String get regionZhejiang => '浙江';

  @override
  String get regionJiangsu => '江蘇';

  @override
  String get regionSichuan => '四川';

  @override
  String get regionHongKong => '香港';

  @override
  String get regionTaiwan => '台湾';

  @override
  String get regionSingapore => 'シンガポール';

  @override
  String get regionMalaysia => 'マレーシア';

  @override
  String get regionUSA => 'アメリカ';

  @override
  String get regionCanada => 'カナダ';

  @override
  String get regionAustralia => 'オーストラリア';

  @override
  String get regionUK => 'イギリス';

  @override
  String get regionJapan => '日本';

  @override
  String get regionSouthKorea => '韓国';

  @override
  String get regionOther => 'その他';

  @override
  String followersList(Object displayName) {
    return '$displayNameのフォロワー';
  }

  @override
  String followingList(Object displayName) {
    return '$displayNameのフォロー中';
  }

  @override
  String get noFollowers => 'フォロワーはいません';

  @override
  String get noFollowing => 'まだ誰もフォローしていません';

  @override
  String followerCount(Object count) {
    return 'フォロワー $count 人';
  }

  @override
  String joinLivestreamFailed(Object error) {
    return 'ライブ配信への参加に失敗しました：$error';
  }

  @override
  String sendFailed(Object error) {
    return '送信に失敗しました：$error';
  }

  @override
  String get blockedCannotSend => '相手にブロックされているため、メッセージを送信できません';

  @override
  String get microphonePermissionRequired => '録音するにはマイクの許可が必要です';

  @override
  String get attachmentTitle => '送信';

  @override
  String get attachmentPhoto => '写真';

  @override
  String get attachmentVideo => '動画';

  @override
  String get attachmentCamera => '撮影';

  @override
  String blockUserConfirm2(Object name) {
    return '$name さんをブロックしますか？';
  }

  @override
  String userBlocked2(Object name) {
    return '$name さんをブロックしました';
  }

  @override
  String get online => 'オンライン';

  @override
  String get voiceCall => '音声通話';

  @override
  String get videoCall => 'ビデオ通話';

  @override
  String get startLivestream => 'ライブ配信を開始';

  @override
  String get groupLivestreamOngoing => 'グループでライブ配信中';

  @override
  String get joinLivestream => 'タップして参加';

  @override
  String get sendFirstMessage => '最初のメッセージを送りましょう！';

  @override
  String get recording => '録音中';

  @override
  String get messages => 'メッセージ';

  @override
  String get searchConversations => 'チャットを検索...';

  @override
  String get noMessages => 'まだメッセージがありません';

  @override
  String get noSearchResults => '該当する会話が見つかりません';

  @override
  String get createNewChat => '右上のアイコンをタップして新しいチャットを始めましょう';

  @override
  String get noMessagePreview => 'メッセージなし';

  @override
  String get searchUsers => 'ユーザー名またはニックネームで検索';

  @override
  String get groupChatName => 'グループ名';

  @override
  String get searchMembers => '検索してメンバーを追加';

  @override
  String createFailed2(Object error) {
    return '作成に失敗しました：$error';
  }

  @override
  String createGroupButton(Object count) {
    return 'グループを作成（$count 人）';
  }

  @override
  String get recall => '取り消し';

  @override
  String get recallTimeLimit => 'メッセージは2分以内のみ取り消せます';

  @override
  String get messageDeleted => 'メッセージが取り消されました';

  @override
  String audioPlayFailed(Object error) {
    return '再生に失敗しました：$error';
  }

  @override
  String scriptureQuote(Object scripture, Object chapter) {
    return '$scripture $chapter';
  }

  @override
  String get downloading => 'ダウンロード中…';

  @override
  String cannotOpen(Object message) {
    return '開けません：$message';
  }

  @override
  String openFailed(Object error) {
    return '開くのに失敗しました：$error';
  }

  @override
  String get today => '今日';

  @override
  String get yesterday => '昨日';

  @override
  String get square => 'ひろば';

  @override
  String get latest => '最新';

  @override
  String get hot => '人気';

  @override
  String get topics => 'トピック';

  @override
  String get emptyFollowingSubtitle => 'ひろばで面白い人を見つけよう！';

  @override
  String get emptyPostsHint => 'まだ投稿がありません。最初の一件を投稿しよう！';

  @override
  String newPostsNotification(Object count) {
    return '新着投稿が $count 件。タップして更新';
  }

  @override
  String get emptyTopicPosts => 'このトピックにはまだ投稿がありません';

  @override
  String get searchTopicsHint => 'トピックを検索...';

  @override
  String get emptyTopics => 'トピックがありません';

  @override
  String get hotTopics => '人気のトピック';

  @override
  String get postTitle => '投稿';

  @override
  String get publish => '公開';

  @override
  String get shareThoughtsHint => 'あなたの考えをシェア...';

  @override
  String get addTopicHint => 'トピックを追加 #';

  @override
  String get postDetail => '投稿の詳細';

  @override
  String get comments => 'コメント';

  @override
  String get emptyComments => 'まだコメントがありません。最初のコメントをどうぞ！';

  @override
  String get writeCommentHint => 'コメントを入力...';

  @override
  String commentFailed(Object error) {
    return 'コメントに失敗しました：$error';
  }

  @override
  String get deletePost => '投稿を削除';

  @override
  String get deletePostConfirm => 'この投稿を削除しますか？この操作は取り消せません。';

  @override
  String get deleteComment => 'コメントを削除';

  @override
  String get deleteCommentConfirm => 'このコメントを削除しますか？この操作は取り消せません。';

  @override
  String get unknownUser => '不明なユーザー';

  @override
  String get searchHint => 'ユーザー・投稿・聖書を検索...';

  @override
  String get users => 'ユーザー';

  @override
  String get posts2 => '投稿';

  @override
  String get search => '検索';

  @override
  String get searchEmptySubtitle => 'ユーザー・投稿・聖書を探す';

  @override
  String get emptyUsers => '該当するユーザーが見つかりません';

  @override
  String get emptyPosts => '該当する投稿が見つかりません';

  @override
  String get emptyScriptures => '該当する聖書が見つかりません';

  @override
  String get notifications => '通知';

  @override
  String get markAllRead => 'すべて既読にする';

  @override
  String get emptyNotifications => '通知はありません';

  @override
  String get emptyNotificationsSubtitle => '新しいやり取りはここでお知らせします';

  @override
  String publishFailed(Object error) {
    return '公開に失敗しました：$error';
  }

  @override
  String connectionFailed(Object error) {
    return '接続に失敗しました：$error';
  }

  @override
  String get inCall => '通話中';

  @override
  String get ringing => '呼び出し中...';

  @override
  String get callDeclined => '通話を拒否されました';

  @override
  String get callEnded => '通話が終了しました';

  @override
  String get connecting => '接続中...';

  @override
  String get mute => 'ミュート';

  @override
  String get unmute => 'ミュート解除';

  @override
  String get cameraOff => 'カメラオフ';

  @override
  String get cameraOn => 'カメラオン';

  @override
  String get earpiece => '受話口';

  @override
  String get speaker => 'スピーカー';

  @override
  String get waitingForHost => 'ホストの配信開始を待っています…';

  @override
  String get micOn => 'マイクオン';

  @override
  String get flipCamera => '切り替え';

  @override
  String get endLivestream => '配信を終了';

  @override
  String get incomingCall => '着信';

  @override
  String get livestreamInvite => '配信への招待';

  @override
  String callInvitation(Object typeLabel) {
    return '$typeLabelの招待…';
  }

  @override
  String get decline => '拒否';

  @override
  String get accept => '応答';

  @override
  String get appName => 'Omega';

  @override
  String get appTagline => '古典を受け継ぎ、ともに築く';

  @override
  String get welcomeBack => 'おかえりなさい';

  @override
  String get email => 'メールアドレス';

  @override
  String get invalidEmailError => '有効なメールアドレスを入力してください';

  @override
  String get password => 'パスワード';

  @override
  String get passwordTooShortError => 'パスワードは6文字以上で入力してください';

  @override
  String get login => 'ログイン';

  @override
  String get noAccountRegisterNow => 'アカウントをお持ちでない方は今すぐ登録';

  @override
  String get networkError => 'ネットワークエラーです。接続を確認して再試行してください';

  @override
  String get sessionExpired => 'セッションが切れました。再度ログインしてください';

  @override
  String get loginFailedGeneric => 'メールまたはパスワードが正しくありません';

  @override
  String loginFailed(Object error) {
    return 'ログインに失敗しました：$error';
  }

  @override
  String get createAccount => 'アカウントを作成';

  @override
  String get nicknameRequiredError => 'ニックネームを入力してください';

  @override
  String get register => '登録';

  @override
  String get hasAccountGoLogin => 'アカウントをお持ちの方はログイン';

  @override
  String registerFailed(Object error) {
    return '登録に失敗しました：$error';
  }

  @override
  String get tabProfile => 'マイページ';

  @override
  String acceptCallFailed(Object error) {
    return '応答に失敗しました：$error';
  }

  @override
  String get imagePlaceholder => '[画像]';

  @override
  String get videoPlaceholder => '[動画]';

  @override
  String get filePlaceholder => '[ファイル]';

  @override
  String get audioPlaceholder => '[音声]';

  @override
  String get scripturePlaceholder => '[聖句の引用]';

  @override
  String notificationLiked(Object actor) {
    return '$actorさんがあなたの投稿にいいねしました';
  }

  @override
  String notificationCommented(Object actor) {
    return '$actorさんがあなたの投稿にコメントしました';
  }

  @override
  String notificationFollowed(Object actor) {
    return '$actorさんがあなたをフォローしました';
  }

  @override
  String get someone => '誰か';

  @override
  String get newNotification => '新しい通知があります';

  @override
  String get action => '操作';

  @override
  String blockUserConfirm3(Object name) {
    return '$nameさんをブロックしますか？';
  }

  @override
  String get unblock => 'ブロックを解除';

  @override
  String get categoryDaoism => '道教';

  @override
  String get categoryBuddhism => '仏典';

  @override
  String get categoryChrisiandity => 'キリスト教';

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
  String get send => '送信';

  @override
  String get messageHint => 'メッセージを入力...';

  @override
  String get thisUser => 'このユーザー';

  @override
  String callStartFailed(Object error) {
    return '通話の開始に失敗しました：$error';
  }

  @override
  String livestreamStartFailed(Object error) {
    return '配信の開始に失敗しました：$error';
  }

  @override
  String get regionCNBJ => '北京';

  @override
  String get regionCNSH => '上海';

  @override
  String get regionCNGD => '広東';

  @override
  String get regionCNZJ => '浙江';

  @override
  String get regionCNJS => '江蘇';

  @override
  String get regionCNSC => '四川';

  @override
  String get regionHK => '香港';

  @override
  String get regionTW => '台湾';

  @override
  String get regionSG => 'シンガポール';

  @override
  String get regionMY => 'マレーシア';

  @override
  String get regionUS => 'アメリカ';

  @override
  String get regionCA => 'カナダ';

  @override
  String get regionAU => 'オーストラリア';

  @override
  String get regionGB => 'イギリス';

  @override
  String get regionJP => '日本';

  @override
  String get regionKR => '韓国';

  @override
  String get regionOTHER => 'その他';

  @override
  String get recordingTooShort => '録音が短すぎるため送信されませんでした';

  @override
  String get onlineMembers => 'オンラインメンバー';

  @override
  String get me => '自分';

  @override
  String get hostLabel => '配信者';

  @override
  String get deleteAccount => 'アカウントを削除';

  @override
  String get deleteAccountConfirm =>
      'アカウントを削除してもよろしいですか？この操作は取り消せません。削除すると、すべての投稿、コメント、メッセージ、およびプロフィールデータが永久に削除されます。';

  @override
  String get deleteAccountSuccess => 'アカウントが削除されました。';

  @override
  String deleteAccountFailed(Object error) {
    return 'アカウント削除に失敗しました：$error';
  }

  @override
  String get report => '通報';

  @override
  String get reportUser => 'ユーザーを通報';

  @override
  String get blockThisUser => 'このユーザーをブロック';

  @override
  String get blockedInteraction => 'このユーザーをブロックしているため、これ以上やり取りできません。';

  @override
  String get reportReason => '通報の理由を選択してください';

  @override
  String get reportReasonSpam => 'スパムまたは広告';

  @override
  String get reportReasonHarassment => '嫌がらせやヘイトスピーチ';

  @override
  String get reportReasonObjectionable => '不適切または有害なコンテンツ';

  @override
  String get reportReasonViolence => '暴力または不穏な表現';

  @override
  String get reportReasonOther => 'その他の問題';

  @override
  String get reportSuccess => '通報が送信されました。24時間以内に審査いたします。';

  @override
  String reportFailed(Object error) {
    return '通報に失敗しました。後でもう一度お試しください。$error';
  }

  @override
  String get eulaMustAgree => '先に利用規約とプライバシーポリシーに同意してください';

  @override
  String get agreeIntro => '以下に同意します：';

  @override
  String get userAgreement => '利用規約';

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String get and => 'と';

  @override
  String get blockedUsers => 'ブロックしたユーザー';

  @override
  String get noBlockedUsers => 'ブロックしたユーザーはいません';

  @override
  String get contentBlocked => '不適切な語句が含まれています。修正してください。';

  @override
  String get forgotPassword => 'パスワードをお忘れですか？';

  @override
  String get resetPassword => 'パスワードを再設定';

  @override
  String get resetEmailHint => '登録メールを入力';

  @override
  String get sendCode => 'コードを送信';

  @override
  String get resendCode => '再送信';

  @override
  String get codeHint => '6桁のコード';

  @override
  String get newPasswordHint => '新しいパスワード（6文字以上）';

  @override
  String get resetCodeSent => 'コードを送信しました。メールをご確認ください。';

  @override
  String get resetSuccess => 'パスワードを再設定しました。新しいパスワードでログインしてください。';

  @override
  String get resetFailed => '再設定に失敗しました。コードを確認するか後でお試しください。';

  @override
  String get emailRequired => 'メールを入力してください';

  @override
  String get codeRequired => 'コードを入力してください';

  @override
  String get verifyEmailTitle => 'メール認証';

  @override
  String verifyEmailHint(Object email) {
    return '$email に認証コードを送信しました。メール内のコードを入力して登録を完了してください。';
  }

  @override
  String get verifyEmailButton => '登録を完了';

  @override
  String get verifyEmailSuccess => 'メール認証が完了しました。ようこそ';

  @override
  String get verifyEmailFailed => '認証に失敗しました。コードを確認するか後でもう一度お試しください';

  @override
  String get friends => '友だち';

  @override
  String get friendRequests => 'リクエスト';

  @override
  String get addFriend => '友だち追加';

  @override
  String get friendRequestSent => '申請済み';

  @override
  String get friendRequestPending => '承認待ち';

  @override
  String get friendRequestSentToast => '友だち申請を送信しました';

  @override
  String get friendRequestAccepted => '友だちになりました';

  @override
  String get acceptRequest => '申請を承認';

  @override
  String get cancelRequest => '申請を取消';

  @override
  String get cancelRequestConfirm => 'この友だち申請を取り消しますか？';

  @override
  String get alreadyFriends => '友だち';

  @override
  String get removeFriend => '友だち解除';

  @override
  String removeFriendConfirm(String name) {
    return '$nameさんを友だちから解除しますか？';
  }

  @override
  String get noFriends => 'まだ友だちがいません';

  @override
  String get noFriendsSubtitle => '右上からユーザー名を検索して追加';

  @override
  String get noFriendRequests => '友だち申請はありません';

  @override
  String get outgoingRequests => '送信した申請';

  @override
  String get searchUsersHint => 'ユーザー名で検索';

  @override
  String get notFriendsCannotDm => '友だちになるとメッセージを送れます';
}
