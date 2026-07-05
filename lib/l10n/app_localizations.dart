import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// No description provided for @deleteConversation.
  ///
  /// In zh, this message translates to:
  /// **'删除对话'**
  String get deleteConversation;

  /// No description provided for @deleteConversationConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除此对话吗？仅从你的列表移除，不影响对方。'**
  String get deleteConversationConfirm;

  /// No description provided for @conversationDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除对话'**
  String get conversationDeleted;

  /// No description provided for @noOneSharingCamera.
  ///
  /// In zh, this message translates to:
  /// **'还没有人开启摄像头'**
  String get noOneSharingCamera;

  /// No description provided for @unblockConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定取消拉黑「{name}」吗？取消后对方可以再次给你发消息。'**
  String unblockConfirm(Object name);

  /// No description provided for @userUnblocked.
  ///
  /// In zh, this message translates to:
  /// **'已取消拉黑「{name}」'**
  String userUnblocked(Object name);

  /// No description provided for @downloadForOffline.
  ///
  /// In zh, this message translates to:
  /// **'下载离线'**
  String get downloadForOffline;

  /// No description provided for @downloadedOffline.
  ///
  /// In zh, this message translates to:
  /// **'已下载，可离线阅读'**
  String get downloadedOffline;

  /// No description provided for @downloadComplete.
  ///
  /// In zh, this message translates to:
  /// **'下载完成，可离线阅读'**
  String get downloadComplete;

  /// No description provided for @downloadFailed.
  ///
  /// In zh, this message translates to:
  /// **'下载失败：{error}'**
  String downloadFailed(Object error);

  /// No description provided for @chatFiles.
  ///
  /// In zh, this message translates to:
  /// **'聊天文件'**
  String get chatFiles;

  /// No description provided for @addMembers.
  ///
  /// In zh, this message translates to:
  /// **'添加成员'**
  String get addMembers;

  /// No description provided for @membersAdded.
  ///
  /// In zh, this message translates to:
  /// **'已添加成员'**
  String get membersAdded;

  /// No description provided for @searchUserHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索用户名或昵称'**
  String get searchUserHint;

  /// No description provided for @loadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败：{error}'**
  String loadFailed(Object error);

  /// No description provided for @contents.
  ///
  /// In zh, this message translates to:
  /// **'目录'**
  String get contents;

  /// No description provided for @noChapterContent.
  ///
  /// In zh, this message translates to:
  /// **'暂无章节内容'**
  String get noChapterContent;

  /// No description provided for @continueReading.
  ///
  /// In zh, this message translates to:
  /// **'继续阅读'**
  String get continueReading;

  /// No description provided for @startReading.
  ///
  /// In zh, this message translates to:
  /// **'开始阅读'**
  String get startReading;

  /// No description provided for @chaptersCountLabel.
  ///
  /// In zh, this message translates to:
  /// **'{chaptersCount} 章'**
  String chaptersCountLabel(Object chaptersCount);

  /// No description provided for @readPercent.
  ///
  /// In zh, this message translates to:
  /// **'已读 {percent}%'**
  String readPercent(Object percent);

  /// No description provided for @bookGenesis.
  ///
  /// In zh, this message translates to:
  /// **'创世记'**
  String get bookGenesis;

  /// No description provided for @bookExodus.
  ///
  /// In zh, this message translates to:
  /// **'出埃及记'**
  String get bookExodus;

  /// No description provided for @bookLeviticus.
  ///
  /// In zh, this message translates to:
  /// **'利未记'**
  String get bookLeviticus;

  /// No description provided for @bookNumbers.
  ///
  /// In zh, this message translates to:
  /// **'民数记'**
  String get bookNumbers;

  /// No description provided for @bookDeuteronomy.
  ///
  /// In zh, this message translates to:
  /// **'申命记'**
  String get bookDeuteronomy;

  /// No description provided for @bookJoshua.
  ///
  /// In zh, this message translates to:
  /// **'约书亚记'**
  String get bookJoshua;

  /// No description provided for @bookJudges.
  ///
  /// In zh, this message translates to:
  /// **'士师记'**
  String get bookJudges;

  /// No description provided for @bookRuth.
  ///
  /// In zh, this message translates to:
  /// **'路得记'**
  String get bookRuth;

  /// No description provided for @book1Samuel.
  ///
  /// In zh, this message translates to:
  /// **'撒母耳记上'**
  String get book1Samuel;

  /// No description provided for @book2Samuel.
  ///
  /// In zh, this message translates to:
  /// **'撒母耳记下'**
  String get book2Samuel;

  /// No description provided for @book1Kings.
  ///
  /// In zh, this message translates to:
  /// **'列王纪上'**
  String get book1Kings;

  /// No description provided for @book2Kings.
  ///
  /// In zh, this message translates to:
  /// **'列王纪下'**
  String get book2Kings;

  /// No description provided for @book1Chronicles.
  ///
  /// In zh, this message translates to:
  /// **'历代志上'**
  String get book1Chronicles;

  /// No description provided for @book2Chronicles.
  ///
  /// In zh, this message translates to:
  /// **'历代志下'**
  String get book2Chronicles;

  /// No description provided for @bookEzra.
  ///
  /// In zh, this message translates to:
  /// **'以斯拉记'**
  String get bookEzra;

  /// No description provided for @bookNehemiah.
  ///
  /// In zh, this message translates to:
  /// **'尼希米记'**
  String get bookNehemiah;

  /// No description provided for @bookEsther.
  ///
  /// In zh, this message translates to:
  /// **'以斯帖记'**
  String get bookEsther;

  /// No description provided for @bookJob.
  ///
  /// In zh, this message translates to:
  /// **'约伯记'**
  String get bookJob;

  /// No description provided for @bookPsalms.
  ///
  /// In zh, this message translates to:
  /// **'诗篇'**
  String get bookPsalms;

  /// No description provided for @bookProverbs.
  ///
  /// In zh, this message translates to:
  /// **'箴言'**
  String get bookProverbs;

  /// No description provided for @bookEcclesiastes.
  ///
  /// In zh, this message translates to:
  /// **'传道书'**
  String get bookEcclesiastes;

  /// No description provided for @bookSongOfSongs.
  ///
  /// In zh, this message translates to:
  /// **'雅歌'**
  String get bookSongOfSongs;

  /// No description provided for @bookIsaiah.
  ///
  /// In zh, this message translates to:
  /// **'以赛亚书'**
  String get bookIsaiah;

  /// No description provided for @bookJeremiah.
  ///
  /// In zh, this message translates to:
  /// **'耶利米书'**
  String get bookJeremiah;

  /// No description provided for @bookLamentations.
  ///
  /// In zh, this message translates to:
  /// **'耶利米哀歌'**
  String get bookLamentations;

  /// No description provided for @bookEzekiel.
  ///
  /// In zh, this message translates to:
  /// **'以西结书'**
  String get bookEzekiel;

  /// No description provided for @bookDaniel.
  ///
  /// In zh, this message translates to:
  /// **'但以理书'**
  String get bookDaniel;

  /// No description provided for @bookHosea.
  ///
  /// In zh, this message translates to:
  /// **'何西阿书'**
  String get bookHosea;

  /// No description provided for @bookJoel.
  ///
  /// In zh, this message translates to:
  /// **'约珥书'**
  String get bookJoel;

  /// No description provided for @bookAmos.
  ///
  /// In zh, this message translates to:
  /// **'阿摩司书'**
  String get bookAmos;

  /// No description provided for @bookObadiah.
  ///
  /// In zh, this message translates to:
  /// **'俄巴底亚书'**
  String get bookObadiah;

  /// No description provided for @bookJonah.
  ///
  /// In zh, this message translates to:
  /// **'约拿书'**
  String get bookJonah;

  /// No description provided for @bookMicah.
  ///
  /// In zh, this message translates to:
  /// **'弥迦书'**
  String get bookMicah;

  /// No description provided for @bookNahum.
  ///
  /// In zh, this message translates to:
  /// **'那鸿书'**
  String get bookNahum;

  /// No description provided for @bookHabakkuk.
  ///
  /// In zh, this message translates to:
  /// **'哈巴谷书'**
  String get bookHabakkuk;

  /// No description provided for @bookZephaniah.
  ///
  /// In zh, this message translates to:
  /// **'西番雅书'**
  String get bookZephaniah;

  /// No description provided for @bookHaggai.
  ///
  /// In zh, this message translates to:
  /// **'哈该书'**
  String get bookHaggai;

  /// No description provided for @bookZechariah.
  ///
  /// In zh, this message translates to:
  /// **'撒迦利亚书'**
  String get bookZechariah;

  /// No description provided for @bookMalachi.
  ///
  /// In zh, this message translates to:
  /// **'玛拉基书'**
  String get bookMalachi;

  /// No description provided for @bookMatthew.
  ///
  /// In zh, this message translates to:
  /// **'马太福音'**
  String get bookMatthew;

  /// No description provided for @bookMark.
  ///
  /// In zh, this message translates to:
  /// **'马可福音'**
  String get bookMark;

  /// No description provided for @bookLuke.
  ///
  /// In zh, this message translates to:
  /// **'路加福音'**
  String get bookLuke;

  /// No description provided for @bookJohn.
  ///
  /// In zh, this message translates to:
  /// **'约翰福音'**
  String get bookJohn;

  /// No description provided for @bookActs.
  ///
  /// In zh, this message translates to:
  /// **'使徒行传'**
  String get bookActs;

  /// No description provided for @bookRomans.
  ///
  /// In zh, this message translates to:
  /// **'罗马书'**
  String get bookRomans;

  /// No description provided for @book1Corinthians.
  ///
  /// In zh, this message translates to:
  /// **'哥林多前书'**
  String get book1Corinthians;

  /// No description provided for @book2Corinthians.
  ///
  /// In zh, this message translates to:
  /// **'哥林多后书'**
  String get book2Corinthians;

  /// No description provided for @bookGalatians.
  ///
  /// In zh, this message translates to:
  /// **'加拉太书'**
  String get bookGalatians;

  /// No description provided for @bookEphesians.
  ///
  /// In zh, this message translates to:
  /// **'以弗所书'**
  String get bookEphesians;

  /// No description provided for @bookPhilippians.
  ///
  /// In zh, this message translates to:
  /// **'腓立比书'**
  String get bookPhilippians;

  /// No description provided for @bookColossians.
  ///
  /// In zh, this message translates to:
  /// **'歌罗西书'**
  String get bookColossians;

  /// No description provided for @book1Thessalonians.
  ///
  /// In zh, this message translates to:
  /// **'帖撒罗尼迦前书'**
  String get book1Thessalonians;

  /// No description provided for @book2Thessalonians.
  ///
  /// In zh, this message translates to:
  /// **'帖撒罗尼迦后书'**
  String get book2Thessalonians;

  /// No description provided for @book1Timothy.
  ///
  /// In zh, this message translates to:
  /// **'提摩太前书'**
  String get book1Timothy;

  /// No description provided for @book2Timothy.
  ///
  /// In zh, this message translates to:
  /// **'提摩太后书'**
  String get book2Timothy;

  /// No description provided for @bookTitus.
  ///
  /// In zh, this message translates to:
  /// **'提多书'**
  String get bookTitus;

  /// No description provided for @bookPhilemon.
  ///
  /// In zh, this message translates to:
  /// **'腓利门书'**
  String get bookPhilemon;

  /// No description provided for @bookHebrews.
  ///
  /// In zh, this message translates to:
  /// **'希伯来书'**
  String get bookHebrews;

  /// No description provided for @bookJames.
  ///
  /// In zh, this message translates to:
  /// **'雅各书'**
  String get bookJames;

  /// No description provided for @book1Peter.
  ///
  /// In zh, this message translates to:
  /// **'彼得前书'**
  String get book1Peter;

  /// No description provided for @book2Peter.
  ///
  /// In zh, this message translates to:
  /// **'彼得后书'**
  String get book2Peter;

  /// No description provided for @book1John.
  ///
  /// In zh, this message translates to:
  /// **'约翰一书'**
  String get book1John;

  /// No description provided for @book2John.
  ///
  /// In zh, this message translates to:
  /// **'约翰二书'**
  String get book2John;

  /// No description provided for @book3John.
  ///
  /// In zh, this message translates to:
  /// **'约翰三书'**
  String get book3John;

  /// No description provided for @bookJude.
  ///
  /// In zh, this message translates to:
  /// **'犹大书'**
  String get bookJude;

  /// No description provided for @bookRevelation.
  ///
  /// In zh, this message translates to:
  /// **'启示录'**
  String get bookRevelation;

  /// No description provided for @books.
  ///
  /// In zh, this message translates to:
  /// **'书卷'**
  String get books;

  /// No description provided for @chapters.
  ///
  /// In zh, this message translates to:
  /// **'章'**
  String get chapters;

  /// No description provided for @oldTestament.
  ///
  /// In zh, this message translates to:
  /// **'旧约'**
  String get oldTestament;

  /// No description provided for @newTestament.
  ///
  /// In zh, this message translates to:
  /// **'新约'**
  String get newTestament;

  /// No description provided for @selectBookFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先从书卷中选择一本书'**
  String get selectBookFirst;

  /// No description provided for @volumeCount.
  ///
  /// In zh, this message translates to:
  /// **'{count}卷'**
  String volumeCount(Object count);

  /// No description provided for @bookChapterDisplay.
  ///
  /// In zh, this message translates to:
  /// **'{bookName} 第{chapterNumber}章'**
  String bookChapterDisplay(Object bookName, Object chapterNumber);

  /// No description provided for @editGroupName.
  ///
  /// In zh, this message translates to:
  /// **'编辑群名称'**
  String get editGroupName;

  /// No description provided for @groupNameHint.
  ///
  /// In zh, this message translates to:
  /// **'输入群名称...'**
  String get groupNameHint;

  /// No description provided for @editGroupAnnouncement.
  ///
  /// In zh, this message translates to:
  /// **'编辑群公告'**
  String get editGroupAnnouncement;

  /// No description provided for @announcementHint.
  ///
  /// In zh, this message translates to:
  /// **'输入群公告内容...'**
  String get announcementHint;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @saveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败：{error}'**
  String saveFailed(Object error);

  /// No description provided for @removeFromGroup.
  ///
  /// In zh, this message translates to:
  /// **'移出群聊'**
  String get removeFromGroup;

  /// No description provided for @removedFromGroup.
  ///
  /// In zh, this message translates to:
  /// **'已移出群聊'**
  String get removedFromGroup;

  /// No description provided for @operationFailed.
  ///
  /// In zh, this message translates to:
  /// **'操作失败：{error}'**
  String operationFailed(Object error);

  /// No description provided for @promoteToAdmin.
  ///
  /// In zh, this message translates to:
  /// **'设为管理员'**
  String get promoteToAdmin;

  /// No description provided for @promotedToAdmin.
  ///
  /// In zh, this message translates to:
  /// **'已设为管理员'**
  String get promotedToAdmin;

  /// No description provided for @demoteAdmin.
  ///
  /// In zh, this message translates to:
  /// **'撤销管理员'**
  String get demoteAdmin;

  /// No description provided for @demotedAdmin.
  ///
  /// In zh, this message translates to:
  /// **'已撤销管理员权限'**
  String get demotedAdmin;

  /// No description provided for @leaveGroup.
  ///
  /// In zh, this message translates to:
  /// **'退出群聊'**
  String get leaveGroup;

  /// No description provided for @confirmLeaveGroup.
  ///
  /// In zh, this message translates to:
  /// **'确定要退出此群聊吗？'**
  String get confirmLeaveGroup;

  /// No description provided for @leaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'退出失败：{error}'**
  String leaveFailed(Object error);

  /// No description provided for @disbandGroup.
  ///
  /// In zh, this message translates to:
  /// **'解散群聊'**
  String get disbandGroup;

  /// No description provided for @confirmDisbandGroup.
  ///
  /// In zh, this message translates to:
  /// **'解散后所有成员将被移出，聊天记录将被删除，此操作不可恢复。确定要解散吗？'**
  String get confirmDisbandGroup;

  /// No description provided for @groupInfo.
  ///
  /// In zh, this message translates to:
  /// **'群聊信息'**
  String get groupInfo;

  /// No description provided for @group.
  ///
  /// In zh, this message translates to:
  /// **'群聊'**
  String get group;

  /// No description provided for @memberCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 名成员'**
  String memberCount(Object count);

  /// No description provided for @announcement.
  ///
  /// In zh, this message translates to:
  /// **'群公告'**
  String get announcement;

  /// No description provided for @clickToSetAnnouncement.
  ///
  /// In zh, this message translates to:
  /// **'点击设置群公告'**
  String get clickToSetAnnouncement;

  /// No description provided for @noAnnouncement.
  ///
  /// In zh, this message translates to:
  /// **'暂无公告'**
  String get noAnnouncement;

  /// No description provided for @groupFiles.
  ///
  /// In zh, this message translates to:
  /// **'群文件'**
  String get groupFiles;

  /// No description provided for @members.
  ///
  /// In zh, this message translates to:
  /// **'成员 ({count})'**
  String members(Object count);

  /// No description provided for @you.
  ///
  /// In zh, this message translates to:
  /// **'你'**
  String get you;

  /// No description provided for @admin.
  ///
  /// In zh, this message translates to:
  /// **'管理员'**
  String get admin;

  /// No description provided for @groupOwner.
  ///
  /// In zh, this message translates to:
  /// **'群主'**
  String get groupOwner;

  /// No description provided for @createFailed.
  ///
  /// In zh, this message translates to:
  /// **'新建失败：{error}'**
  String createFailed(Object error);

  /// No description provided for @deleteFolder.
  ///
  /// In zh, this message translates to:
  /// **'删除文件夹'**
  String get deleteFolder;

  /// No description provided for @confirmDeleteFolder.
  ///
  /// In zh, this message translates to:
  /// **'确定删除「{folderName}」吗？文件夹内的文件会移回根目录，不会被删除。'**
  String confirmDeleteFolder(Object folderName);

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @deleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败：{error}'**
  String deleteFailed(Object error);

  /// No description provided for @renameFailed.
  ///
  /// In zh, this message translates to:
  /// **'重命名失败：{error}'**
  String renameFailed(Object error);

  /// No description provided for @createFolder.
  ///
  /// In zh, this message translates to:
  /// **'新建文件夹'**
  String get createFolder;

  /// No description provided for @uploadFile.
  ///
  /// In zh, this message translates to:
  /// **'上传文件'**
  String get uploadFile;

  /// No description provided for @renameFolder.
  ///
  /// In zh, this message translates to:
  /// **'重命名文件夹'**
  String get renameFolder;

  /// No description provided for @folderName.
  ///
  /// In zh, this message translates to:
  /// **'文件夹名称'**
  String get folderName;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// No description provided for @moveFileTo.
  ///
  /// In zh, this message translates to:
  /// **'移动「{fileName}」到'**
  String moveFileTo(Object fileName);

  /// No description provided for @rootDirectory.
  ///
  /// In zh, this message translates to:
  /// **'根目录'**
  String get rootDirectory;

  /// No description provided for @moveFailed.
  ///
  /// In zh, this message translates to:
  /// **'移动失败：{error}'**
  String moveFailed(Object error);

  /// No description provided for @cannotOpenFile.
  ///
  /// In zh, this message translates to:
  /// **'无法打开文件'**
  String get cannotOpenFile;

  /// No description provided for @files.
  ///
  /// In zh, this message translates to:
  /// **'文件'**
  String get files;

  /// No description provided for @noSharedFiles.
  ///
  /// In zh, this message translates to:
  /// **'暂无共享文件'**
  String get noSharedFiles;

  /// No description provided for @folderEmpty.
  ///
  /// In zh, this message translates to:
  /// **'该文件夹为空'**
  String get folderEmpty;

  /// No description provided for @emptyFilesHint.
  ///
  /// In zh, this message translates to:
  /// **'在聊天中发送文件后会显示在这里\n点右上角可新建文件夹'**
  String get emptyFilesHint;

  /// No description provided for @longPressToMoveFile.
  ///
  /// In zh, this message translates to:
  /// **'长按文件可移动到这里'**
  String get longPressToMoveFile;

  /// No description provided for @rename.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get rename;

  /// No description provided for @fileCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个文件'**
  String fileCount(Object count);

  /// No description provided for @moveToFolder.
  ///
  /// In zh, this message translates to:
  /// **'移动到文件夹'**
  String get moveToFolder;

  /// No description provided for @unknownFile.
  ///
  /// In zh, this message translates to:
  /// **'未知文件'**
  String get unknownFile;

  /// No description provided for @copiedToClipboard.
  ///
  /// In zh, this message translates to:
  /// **'已复制到剪贴板'**
  String get copiedToClipboard;

  /// No description provided for @selectConversation.
  ///
  /// In zh, this message translates to:
  /// **'选择会话'**
  String get selectConversation;

  /// No description provided for @privateChat.
  ///
  /// In zh, this message translates to:
  /// **'私聊'**
  String get privateChat;

  /// No description provided for @sentToChat.
  ///
  /// In zh, this message translates to:
  /// **'已发送到聊天'**
  String get sentToChat;

  /// No description provided for @noteTitle.
  ///
  /// In zh, this message translates to:
  /// **'笔记 · {chapterTitle}'**
  String noteTitle(Object chapterTitle);

  /// No description provided for @noteHint.
  ///
  /// In zh, this message translates to:
  /// **'写下你的感悟...'**
  String get noteHint;

  /// No description provided for @copyScripture.
  ///
  /// In zh, this message translates to:
  /// **'复制经文'**
  String get copyScripture;

  /// No description provided for @sendToChat.
  ///
  /// In zh, this message translates to:
  /// **'发送到聊天'**
  String get sendToChat;

  /// No description provided for @selectedVerses.
  ///
  /// In zh, this message translates to:
  /// **'已选 {count} 节'**
  String selectedVerses(Object count);

  /// No description provided for @copy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get copy;

  /// No description provided for @quoteToChat.
  ///
  /// In zh, this message translates to:
  /// **'引用到聊天'**
  String get quoteToChat;

  /// No description provided for @fontSizeSmall.
  ///
  /// In zh, this message translates to:
  /// **'小字'**
  String get fontSizeSmall;

  /// No description provided for @fontSizeNormal.
  ///
  /// In zh, this message translates to:
  /// **'标准'**
  String get fontSizeNormal;

  /// No description provided for @fontSizeLarge.
  ///
  /// In zh, this message translates to:
  /// **'大字'**
  String get fontSizeLarge;

  /// No description provided for @fontSizeExtraLarge.
  ///
  /// In zh, this message translates to:
  /// **'特大'**
  String get fontSizeExtraLarge;

  /// No description provided for @previousChapter.
  ///
  /// In zh, this message translates to:
  /// **'上章'**
  String get previousChapter;

  /// No description provided for @note.
  ///
  /// In zh, this message translates to:
  /// **'笔记'**
  String get note;

  /// No description provided for @highlight.
  ///
  /// In zh, this message translates to:
  /// **'划线'**
  String get highlight;

  /// No description provided for @bookmark.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get bookmark;

  /// No description provided for @quote.
  ///
  /// In zh, this message translates to:
  /// **'引用'**
  String get quote;

  /// No description provided for @nextChapter.
  ///
  /// In zh, this message translates to:
  /// **'下章'**
  String get nextChapter;

  /// No description provided for @oldTestamentCount.
  ///
  /// In zh, this message translates to:
  /// **'旧约 {count}'**
  String oldTestamentCount(Object count);

  /// No description provided for @crossReferenceTitle.
  ///
  /// In zh, this message translates to:
  /// **'{chapterTitle} 第{verse}节 · 引用旧约'**
  String crossReferenceTitle(Object chapterTitle, Object verse);

  /// No description provided for @chapterNotFound.
  ///
  /// In zh, this message translates to:
  /// **'未找到对应章节'**
  String get chapterNotFound;

  /// No description provided for @scripture.
  ///
  /// In zh, this message translates to:
  /// **'经书'**
  String get scripture;

  /// No description provided for @myBookmarks.
  ///
  /// In zh, this message translates to:
  /// **'我的书签'**
  String get myBookmarks;

  /// No description provided for @savedPosts.
  ///
  /// In zh, this message translates to:
  /// **'我的收藏'**
  String get savedPosts;

  /// No description provided for @bookmarkTabScripture.
  ///
  /// In zh, this message translates to:
  /// **'经书'**
  String get bookmarkTabScripture;

  /// No description provided for @bookmarkTabPosts.
  ///
  /// In zh, this message translates to:
  /// **'帖子'**
  String get bookmarkTabPosts;

  /// No description provided for @noSavedPosts.
  ///
  /// In zh, this message translates to:
  /// **'还没有收藏的帖子'**
  String get noSavedPosts;

  /// No description provided for @myPosts.
  ///
  /// In zh, this message translates to:
  /// **'我的发帖'**
  String get myPosts;

  /// No description provided for @lastReading.
  ///
  /// In zh, this message translates to:
  /// **'上次阅读'**
  String get lastReading;

  /// No description provided for @allScriptures.
  ///
  /// In zh, this message translates to:
  /// **'全部经书'**
  String get allScriptures;

  /// No description provided for @continueLabel.
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get continueLabel;

  /// No description provided for @chapterCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 章'**
  String chapterCount(Object count);

  /// No description provided for @noScriptureContent.
  ///
  /// In zh, this message translates to:
  /// **'暂无经书内容'**
  String get noScriptureContent;

  /// No description provided for @noBookmarks.
  ///
  /// In zh, this message translates to:
  /// **'还没有书签'**
  String get noBookmarks;

  /// No description provided for @bookmarkHint.
  ///
  /// In zh, this message translates to:
  /// **'阅读经文时点击书签图标即可收藏'**
  String get bookmarkHint;

  /// No description provided for @deletedChapter.
  ///
  /// In zh, this message translates to:
  /// **'已删除章节'**
  String get deletedChapter;

  /// No description provided for @blockUserTitle.
  ///
  /// In zh, this message translates to:
  /// **'拉黑用户'**
  String get blockUserTitle;

  /// No description provided for @blockUserConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定拉黑 {displayName} 吗？'**
  String blockUserConfirm(Object displayName);

  /// No description provided for @block.
  ///
  /// In zh, this message translates to:
  /// **'拉黑'**
  String get block;

  /// No description provided for @userBlocked.
  ///
  /// In zh, this message translates to:
  /// **'已拉黑该用户'**
  String get userBlocked;

  /// No description provided for @directMessageFailed.
  ///
  /// In zh, this message translates to:
  /// **'发起私信失败：{error}'**
  String directMessageFailed(Object error);

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @editProfile.
  ///
  /// In zh, this message translates to:
  /// **'编辑资料'**
  String get editProfile;

  /// No description provided for @languageSettings.
  ///
  /// In zh, this message translates to:
  /// **'切换语言'**
  String get languageSettings;

  /// No description provided for @logout.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get logout;

  /// No description provided for @confirmLogout.
  ///
  /// In zh, this message translates to:
  /// **'确定要退出登录吗？'**
  String get confirmLogout;

  /// No description provided for @confirmButton.
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get confirmButton;

  /// No description provided for @userNotFound.
  ///
  /// In zh, this message translates to:
  /// **'用户不存在'**
  String get userNotFound;

  /// No description provided for @noPosts.
  ///
  /// In zh, this message translates to:
  /// **'还没有发帖'**
  String get noPosts;

  /// No description provided for @posts.
  ///
  /// In zh, this message translates to:
  /// **'帖子'**
  String get posts;

  /// No description provided for @followers.
  ///
  /// In zh, this message translates to:
  /// **'粉丝'**
  String get followers;

  /// No description provided for @following.
  ///
  /// In zh, this message translates to:
  /// **'关注'**
  String get following;

  /// No description provided for @alreadyFollowing.
  ///
  /// In zh, this message translates to:
  /// **'已关注'**
  String get alreadyFollowing;

  /// No description provided for @directMessage.
  ///
  /// In zh, this message translates to:
  /// **'私信'**
  String get directMessage;

  /// No description provided for @displayNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'昵称不能为空'**
  String get displayNameRequired;

  /// No description provided for @savingSucceeded.
  ///
  /// In zh, this message translates to:
  /// **'保存成功'**
  String get savingSucceeded;

  /// No description provided for @clickToChangeAvatar.
  ///
  /// In zh, this message translates to:
  /// **'点击更换头像'**
  String get clickToChangeAvatar;

  /// No description provided for @displayName.
  ///
  /// In zh, this message translates to:
  /// **'昵称'**
  String get displayName;

  /// No description provided for @bio.
  ///
  /// In zh, this message translates to:
  /// **'个人简介'**
  String get bio;

  /// No description provided for @region.
  ///
  /// In zh, this message translates to:
  /// **'所在地区'**
  String get region;

  /// No description provided for @notSet.
  ///
  /// In zh, this message translates to:
  /// **'不设置'**
  String get notSet;

  /// No description provided for @languagePreference.
  ///
  /// In zh, this message translates to:
  /// **'语言偏好'**
  String get languagePreference;

  /// No description provided for @languageChinese.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @regionBeijing.
  ///
  /// In zh, this message translates to:
  /// **'北京'**
  String get regionBeijing;

  /// No description provided for @regionShanghai.
  ///
  /// In zh, this message translates to:
  /// **'上海'**
  String get regionShanghai;

  /// No description provided for @regionGuangdong.
  ///
  /// In zh, this message translates to:
  /// **'广东'**
  String get regionGuangdong;

  /// No description provided for @regionZhejiang.
  ///
  /// In zh, this message translates to:
  /// **'浙江'**
  String get regionZhejiang;

  /// No description provided for @regionJiangsu.
  ///
  /// In zh, this message translates to:
  /// **'江苏'**
  String get regionJiangsu;

  /// No description provided for @regionSichuan.
  ///
  /// In zh, this message translates to:
  /// **'四川'**
  String get regionSichuan;

  /// No description provided for @regionHongKong.
  ///
  /// In zh, this message translates to:
  /// **'香港'**
  String get regionHongKong;

  /// No description provided for @regionTaiwan.
  ///
  /// In zh, this message translates to:
  /// **'台湾'**
  String get regionTaiwan;

  /// No description provided for @regionSingapore.
  ///
  /// In zh, this message translates to:
  /// **'新加坡'**
  String get regionSingapore;

  /// No description provided for @regionMalaysia.
  ///
  /// In zh, this message translates to:
  /// **'马来西亚'**
  String get regionMalaysia;

  /// No description provided for @regionUSA.
  ///
  /// In zh, this message translates to:
  /// **'美国'**
  String get regionUSA;

  /// No description provided for @regionCanada.
  ///
  /// In zh, this message translates to:
  /// **'加拿大'**
  String get regionCanada;

  /// No description provided for @regionAustralia.
  ///
  /// In zh, this message translates to:
  /// **'澳大利亚'**
  String get regionAustralia;

  /// No description provided for @regionUK.
  ///
  /// In zh, this message translates to:
  /// **'英国'**
  String get regionUK;

  /// No description provided for @regionJapan.
  ///
  /// In zh, this message translates to:
  /// **'日本'**
  String get regionJapan;

  /// No description provided for @regionSouthKorea.
  ///
  /// In zh, this message translates to:
  /// **'韩国'**
  String get regionSouthKorea;

  /// No description provided for @regionOther.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get regionOther;

  /// No description provided for @followersList.
  ///
  /// In zh, this message translates to:
  /// **'{displayName}的粉丝'**
  String followersList(Object displayName);

  /// No description provided for @followingList.
  ///
  /// In zh, this message translates to:
  /// **'{displayName}的关注'**
  String followingList(Object displayName);

  /// No description provided for @noFollowers.
  ///
  /// In zh, this message translates to:
  /// **'暂无粉丝'**
  String get noFollowers;

  /// No description provided for @noFollowing.
  ///
  /// In zh, this message translates to:
  /// **'还没有关注任何人'**
  String get noFollowing;

  /// No description provided for @followerCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 粉丝'**
  String followerCount(Object count);

  /// No description provided for @joinLivestreamFailed.
  ///
  /// In zh, this message translates to:
  /// **'加入直播失败：{error}'**
  String joinLivestreamFailed(Object error);

  /// No description provided for @sendFailed.
  ///
  /// In zh, this message translates to:
  /// **'发送失败：{error}'**
  String sendFailed(Object error);

  /// No description provided for @blockedCannotSend.
  ///
  /// In zh, this message translates to:
  /// **'对方已将你拉黑，消息无法送达'**
  String get blockedCannotSend;

  /// No description provided for @microphonePermissionRequired.
  ///
  /// In zh, this message translates to:
  /// **'需要麦克风权限才能录音'**
  String get microphonePermissionRequired;

  /// No description provided for @attachmentTitle.
  ///
  /// In zh, this message translates to:
  /// **'发送内容'**
  String get attachmentTitle;

  /// No description provided for @attachmentPhoto.
  ///
  /// In zh, this message translates to:
  /// **'图片'**
  String get attachmentPhoto;

  /// No description provided for @attachmentVideo.
  ///
  /// In zh, this message translates to:
  /// **'视频'**
  String get attachmentVideo;

  /// No description provided for @attachmentCamera.
  ///
  /// In zh, this message translates to:
  /// **'拍摄'**
  String get attachmentCamera;

  /// No description provided for @blockUserConfirm2.
  ///
  /// In zh, this message translates to:
  /// **'确定要拉黑 {name} 吗？'**
  String blockUserConfirm2(Object name);

  /// No description provided for @userBlocked2.
  ///
  /// In zh, this message translates to:
  /// **'已拉黑 {name}'**
  String userBlocked2(Object name);

  /// No description provided for @online.
  ///
  /// In zh, this message translates to:
  /// **'在线'**
  String get online;

  /// No description provided for @voiceCall.
  ///
  /// In zh, this message translates to:
  /// **'语音通话'**
  String get voiceCall;

  /// No description provided for @videoCall.
  ///
  /// In zh, this message translates to:
  /// **'视频通话'**
  String get videoCall;

  /// No description provided for @startLivestream.
  ///
  /// In zh, this message translates to:
  /// **'开始直播'**
  String get startLivestream;

  /// No description provided for @groupLivestreamOngoing.
  ///
  /// In zh, this message translates to:
  /// **'群内正在直播'**
  String get groupLivestreamOngoing;

  /// No description provided for @joinLivestream.
  ///
  /// In zh, this message translates to:
  /// **'点击加入'**
  String get joinLivestream;

  /// No description provided for @sendFirstMessage.
  ///
  /// In zh, this message translates to:
  /// **'发送第一条消息吧！'**
  String get sendFirstMessage;

  /// No description provided for @recording.
  ///
  /// In zh, this message translates to:
  /// **'录音中'**
  String get recording;

  /// No description provided for @messages.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get messages;

  /// No description provided for @searchConversations.
  ///
  /// In zh, this message translates to:
  /// **'搜索聊天...'**
  String get searchConversations;

  /// No description provided for @noMessages.
  ///
  /// In zh, this message translates to:
  /// **'还没有消息'**
  String get noMessages;

  /// No description provided for @noSearchResults.
  ///
  /// In zh, this message translates to:
  /// **'没有找到相关会话'**
  String get noSearchResults;

  /// No description provided for @createNewChat.
  ///
  /// In zh, this message translates to:
  /// **'点击右上角发起新的聊天吧'**
  String get createNewChat;

  /// No description provided for @noMessagePreview.
  ///
  /// In zh, this message translates to:
  /// **'暂无消息'**
  String get noMessagePreview;

  /// No description provided for @searchUsers.
  ///
  /// In zh, this message translates to:
  /// **'搜索用户名或昵称'**
  String get searchUsers;

  /// No description provided for @groupChatName.
  ///
  /// In zh, this message translates to:
  /// **'群聊名称'**
  String get groupChatName;

  /// No description provided for @searchMembers.
  ///
  /// In zh, this message translates to:
  /// **'搜索添加成员'**
  String get searchMembers;

  /// No description provided for @createFailed2.
  ///
  /// In zh, this message translates to:
  /// **'创建失败：{error}'**
  String createFailed2(Object error);

  /// No description provided for @createGroupButton.
  ///
  /// In zh, this message translates to:
  /// **'创建群聊（{count} 人）'**
  String createGroupButton(Object count);

  /// No description provided for @recall.
  ///
  /// In zh, this message translates to:
  /// **'撤回'**
  String get recall;

  /// No description provided for @recallTimeLimit.
  ///
  /// In zh, this message translates to:
  /// **'消息仅2分钟内可撤回'**
  String get recallTimeLimit;

  /// No description provided for @messageDeleted.
  ///
  /// In zh, this message translates to:
  /// **'消息已撤回'**
  String get messageDeleted;

  /// No description provided for @audioPlayFailed.
  ///
  /// In zh, this message translates to:
  /// **'播放失败：{error}'**
  String audioPlayFailed(Object error);

  /// No description provided for @scriptureQuote.
  ///
  /// In zh, this message translates to:
  /// **'《{scripture}》{chapter}'**
  String scriptureQuote(Object scripture, Object chapter);

  /// No description provided for @downloading.
  ///
  /// In zh, this message translates to:
  /// **'正在下载…'**
  String get downloading;

  /// No description provided for @cannotOpen.
  ///
  /// In zh, this message translates to:
  /// **'无法打开：{message}'**
  String cannotOpen(Object message);

  /// No description provided for @openFailed.
  ///
  /// In zh, this message translates to:
  /// **'打开失败：{error}'**
  String openFailed(Object error);

  /// No description provided for @today.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In zh, this message translates to:
  /// **'昨天'**
  String get yesterday;

  /// No description provided for @square.
  ///
  /// In zh, this message translates to:
  /// **'广场'**
  String get square;

  /// No description provided for @latest.
  ///
  /// In zh, this message translates to:
  /// **'最新'**
  String get latest;

  /// No description provided for @hot.
  ///
  /// In zh, this message translates to:
  /// **'热门'**
  String get hot;

  /// No description provided for @topics.
  ///
  /// In zh, this message translates to:
  /// **'话题'**
  String get topics;

  /// No description provided for @emptyFollowingSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'去广场发现有趣的人吧！'**
  String get emptyFollowingSubtitle;

  /// No description provided for @emptyPostsHint.
  ///
  /// In zh, this message translates to:
  /// **'还没有帖子，来发第一条吧！'**
  String get emptyPostsHint;

  /// No description provided for @newPostsNotification.
  ///
  /// In zh, this message translates to:
  /// **'有 {count} 条新帖子，点击刷新'**
  String newPostsNotification(Object count);

  /// No description provided for @emptyTopicPosts.
  ///
  /// In zh, this message translates to:
  /// **'该话题暂无帖子'**
  String get emptyTopicPosts;

  /// No description provided for @searchTopicsHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索话题...'**
  String get searchTopicsHint;

  /// No description provided for @emptyTopics.
  ///
  /// In zh, this message translates to:
  /// **'暂无话题'**
  String get emptyTopics;

  /// No description provided for @hotTopics.
  ///
  /// In zh, this message translates to:
  /// **'热门话题'**
  String get hotTopics;

  /// No description provided for @postTitle.
  ///
  /// In zh, this message translates to:
  /// **'发帖'**
  String get postTitle;

  /// No description provided for @publish.
  ///
  /// In zh, this message translates to:
  /// **'发布'**
  String get publish;

  /// No description provided for @shareThoughtsHint.
  ///
  /// In zh, this message translates to:
  /// **'分享你的想法...'**
  String get shareThoughtsHint;

  /// No description provided for @addTopicHint.
  ///
  /// In zh, this message translates to:
  /// **'添加话题 #'**
  String get addTopicHint;

  /// No description provided for @postDetail.
  ///
  /// In zh, this message translates to:
  /// **'帖子详情'**
  String get postDetail;

  /// No description provided for @comments.
  ///
  /// In zh, this message translates to:
  /// **'评论'**
  String get comments;

  /// No description provided for @emptyComments.
  ///
  /// In zh, this message translates to:
  /// **'暂无评论，来第一个评论吧！'**
  String get emptyComments;

  /// No description provided for @writeCommentHint.
  ///
  /// In zh, this message translates to:
  /// **'写评论...'**
  String get writeCommentHint;

  /// No description provided for @commentFailed.
  ///
  /// In zh, this message translates to:
  /// **'评论失败：{error}'**
  String commentFailed(Object error);

  /// No description provided for @deletePost.
  ///
  /// In zh, this message translates to:
  /// **'删除帖子'**
  String get deletePost;

  /// No description provided for @deletePostConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除这条帖子吗？此操作无法撤销。'**
  String get deletePostConfirm;

  /// No description provided for @deleteComment.
  ///
  /// In zh, this message translates to:
  /// **'删除评论'**
  String get deleteComment;

  /// No description provided for @deleteCommentConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除这条评论吗？此操作无法撤销。'**
  String get deleteCommentConfirm;

  /// No description provided for @unknownUser.
  ///
  /// In zh, this message translates to:
  /// **'未知用户'**
  String get unknownUser;

  /// No description provided for @searchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索用户、动态、经书...'**
  String get searchHint;

  /// No description provided for @users.
  ///
  /// In zh, this message translates to:
  /// **'用户'**
  String get users;

  /// No description provided for @posts2.
  ///
  /// In zh, this message translates to:
  /// **'动态'**
  String get posts2;

  /// No description provided for @search.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get search;

  /// No description provided for @searchEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'查找用户、动态或经书'**
  String get searchEmptySubtitle;

  /// No description provided for @emptyUsers.
  ///
  /// In zh, this message translates to:
  /// **'没有找到相关用户'**
  String get emptyUsers;

  /// No description provided for @emptyPosts.
  ///
  /// In zh, this message translates to:
  /// **'没有找到相关动态'**
  String get emptyPosts;

  /// No description provided for @emptyScriptures.
  ///
  /// In zh, this message translates to:
  /// **'没有找到相关经书'**
  String get emptyScriptures;

  /// No description provided for @notifications.
  ///
  /// In zh, this message translates to:
  /// **'通知'**
  String get notifications;

  /// No description provided for @markAllRead.
  ///
  /// In zh, this message translates to:
  /// **'全部已读'**
  String get markAllRead;

  /// No description provided for @emptyNotifications.
  ///
  /// In zh, this message translates to:
  /// **'暂无通知'**
  String get emptyNotifications;

  /// No description provided for @emptyNotificationsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'有新的互动会在这里提醒你'**
  String get emptyNotificationsSubtitle;

  /// No description provided for @publishFailed.
  ///
  /// In zh, this message translates to:
  /// **'发布失败：{error}'**
  String publishFailed(Object error);

  /// No description provided for @connectionFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接失败：{error}'**
  String connectionFailed(Object error);

  /// No description provided for @inCall.
  ///
  /// In zh, this message translates to:
  /// **'通话中'**
  String get inCall;

  /// No description provided for @ringing.
  ///
  /// In zh, this message translates to:
  /// **'呼叫中...'**
  String get ringing;

  /// No description provided for @callDeclined.
  ///
  /// In zh, this message translates to:
  /// **'对方已拒绝'**
  String get callDeclined;

  /// No description provided for @callEnded.
  ///
  /// In zh, this message translates to:
  /// **'通话已结束'**
  String get callEnded;

  /// No description provided for @connecting.
  ///
  /// In zh, this message translates to:
  /// **'连接中...'**
  String get connecting;

  /// No description provided for @mute.
  ///
  /// In zh, this message translates to:
  /// **'静音'**
  String get mute;

  /// No description provided for @unmute.
  ///
  /// In zh, this message translates to:
  /// **'取消静音'**
  String get unmute;

  /// No description provided for @cameraOff.
  ///
  /// In zh, this message translates to:
  /// **'关摄像头'**
  String get cameraOff;

  /// No description provided for @cameraOn.
  ///
  /// In zh, this message translates to:
  /// **'开摄像头'**
  String get cameraOn;

  /// No description provided for @earpiece.
  ///
  /// In zh, this message translates to:
  /// **'听筒'**
  String get earpiece;

  /// No description provided for @speaker.
  ///
  /// In zh, this message translates to:
  /// **'扬声器'**
  String get speaker;

  /// No description provided for @waitingForHost.
  ///
  /// In zh, this message translates to:
  /// **'等待主播开始直播...'**
  String get waitingForHost;

  /// No description provided for @micOn.
  ///
  /// In zh, this message translates to:
  /// **'开麦'**
  String get micOn;

  /// No description provided for @flipCamera.
  ///
  /// In zh, this message translates to:
  /// **'翻转'**
  String get flipCamera;

  /// No description provided for @endLivestream.
  ///
  /// In zh, this message translates to:
  /// **'结束直播'**
  String get endLivestream;

  /// No description provided for @incomingCall.
  ///
  /// In zh, this message translates to:
  /// **'来电'**
  String get incomingCall;

  /// No description provided for @livestreamInvite.
  ///
  /// In zh, this message translates to:
  /// **'直播邀请'**
  String get livestreamInvite;

  /// No description provided for @callInvitation.
  ///
  /// In zh, this message translates to:
  /// **'{typeLabel}邀请…'**
  String callInvitation(Object typeLabel);

  /// No description provided for @decline.
  ///
  /// In zh, this message translates to:
  /// **'拒绝'**
  String get decline;

  /// No description provided for @accept.
  ///
  /// In zh, this message translates to:
  /// **'接听'**
  String get accept;

  /// No description provided for @appName.
  ///
  /// In zh, this message translates to:
  /// **'Omega'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In zh, this message translates to:
  /// **'经典传承，社区共建'**
  String get appTagline;

  /// No description provided for @welcomeBack.
  ///
  /// In zh, this message translates to:
  /// **'欢迎回来'**
  String get welcomeBack;

  /// No description provided for @email.
  ///
  /// In zh, this message translates to:
  /// **'邮箱'**
  String get email;

  /// No description provided for @invalidEmailError.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效邮箱'**
  String get invalidEmailError;

  /// No description provided for @password.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get password;

  /// No description provided for @passwordTooShortError.
  ///
  /// In zh, this message translates to:
  /// **'密码至少6位'**
  String get passwordTooShortError;

  /// No description provided for @login.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get login;

  /// No description provided for @noAccountRegisterNow.
  ///
  /// In zh, this message translates to:
  /// **'还没有账号？立即注册'**
  String get noAccountRegisterNow;

  /// No description provided for @networkError.
  ///
  /// In zh, this message translates to:
  /// **'网络连接失败，请检查网络后重试'**
  String get networkError;

  /// No description provided for @sessionExpired.
  ///
  /// In zh, this message translates to:
  /// **'登录状态已失效，请重新登录后再试'**
  String get sessionExpired;

  /// No description provided for @loginFailedGeneric.
  ///
  /// In zh, this message translates to:
  /// **'邮箱或密码错误'**
  String get loginFailedGeneric;

  /// No description provided for @loginFailed.
  ///
  /// In zh, this message translates to:
  /// **'登录失败：{error}'**
  String loginFailed(Object error);

  /// No description provided for @createAccount.
  ///
  /// In zh, this message translates to:
  /// **'创建账号'**
  String get createAccount;

  /// No description provided for @nicknameRequiredError.
  ///
  /// In zh, this message translates to:
  /// **'请输入昵称'**
  String get nicknameRequiredError;

  /// No description provided for @register.
  ///
  /// In zh, this message translates to:
  /// **'注册'**
  String get register;

  /// No description provided for @hasAccountGoLogin.
  ///
  /// In zh, this message translates to:
  /// **'已有账号？去登录'**
  String get hasAccountGoLogin;

  /// No description provided for @registerFailed.
  ///
  /// In zh, this message translates to:
  /// **'注册失败：{error}'**
  String registerFailed(Object error);

  /// No description provided for @tabProfile.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get tabProfile;

  /// No description provided for @acceptCallFailed.
  ///
  /// In zh, this message translates to:
  /// **'接听失败：{error}'**
  String acceptCallFailed(Object error);

  /// No description provided for @imagePlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'[图片]'**
  String get imagePlaceholder;

  /// No description provided for @videoPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'[视频]'**
  String get videoPlaceholder;

  /// No description provided for @filePlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'[文件]'**
  String get filePlaceholder;

  /// No description provided for @audioPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'[语音]'**
  String get audioPlaceholder;

  /// No description provided for @scripturePlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'[经文引用]'**
  String get scripturePlaceholder;

  /// No description provided for @notificationLiked.
  ///
  /// In zh, this message translates to:
  /// **'{actor} 点赞了你的帖子'**
  String notificationLiked(Object actor);

  /// No description provided for @notificationCommented.
  ///
  /// In zh, this message translates to:
  /// **'{actor} 评论了你的帖子'**
  String notificationCommented(Object actor);

  /// No description provided for @notificationFollowed.
  ///
  /// In zh, this message translates to:
  /// **'{actor} 关注了你'**
  String notificationFollowed(Object actor);

  /// No description provided for @someone.
  ///
  /// In zh, this message translates to:
  /// **'有人'**
  String get someone;

  /// No description provided for @newNotification.
  ///
  /// In zh, this message translates to:
  /// **'你有一条新通知'**
  String get newNotification;

  /// No description provided for @action.
  ///
  /// In zh, this message translates to:
  /// **'操作'**
  String get action;

  /// No description provided for @blockUserConfirm3.
  ///
  /// In zh, this message translates to:
  /// **'确定拉黑 {name} 吗？'**
  String blockUserConfirm3(Object name);

  /// No description provided for @unblock.
  ///
  /// In zh, this message translates to:
  /// **'解除拉黑'**
  String get unblock;

  /// No description provided for @categoryDaoism.
  ///
  /// In zh, this message translates to:
  /// **'道家'**
  String get categoryDaoism;

  /// No description provided for @categoryBuddhism.
  ///
  /// In zh, this message translates to:
  /// **'佛经'**
  String get categoryBuddhism;

  /// No description provided for @categoryChrisiandity.
  ///
  /// In zh, this message translates to:
  /// **'基督教'**
  String get categoryChrisiandity;

  /// No description provided for @crossRefVerse.
  ///
  /// In zh, this message translates to:
  /// **'{chapterTitle} {verse}节'**
  String crossRefVerse(Object chapterTitle, Object verse);

  /// No description provided for @crossRefVerseRange.
  ///
  /// In zh, this message translates to:
  /// **'{chapterTitle} {verseStart}-{verseEnd}节'**
  String crossRefVerseRange(
    Object chapterTitle,
    Object verseStart,
    Object verseEnd,
  );

  /// No description provided for @send.
  ///
  /// In zh, this message translates to:
  /// **'发送'**
  String get send;

  /// No description provided for @messageHint.
  ///
  /// In zh, this message translates to:
  /// **'输入消息...'**
  String get messageHint;

  /// No description provided for @thisUser.
  ///
  /// In zh, this message translates to:
  /// **'该用户'**
  String get thisUser;

  /// No description provided for @callStartFailed.
  ///
  /// In zh, this message translates to:
  /// **'发起通话失败：{error}'**
  String callStartFailed(Object error);

  /// No description provided for @livestreamStartFailed.
  ///
  /// In zh, this message translates to:
  /// **'发起直播失败：{error}'**
  String livestreamStartFailed(Object error);

  /// No description provided for @regionCNBJ.
  ///
  /// In zh, this message translates to:
  /// **'北京'**
  String get regionCNBJ;

  /// No description provided for @regionCNSH.
  ///
  /// In zh, this message translates to:
  /// **'上海'**
  String get regionCNSH;

  /// No description provided for @regionCNGD.
  ///
  /// In zh, this message translates to:
  /// **'广东'**
  String get regionCNGD;

  /// No description provided for @regionCNZJ.
  ///
  /// In zh, this message translates to:
  /// **'浙江'**
  String get regionCNZJ;

  /// No description provided for @regionCNJS.
  ///
  /// In zh, this message translates to:
  /// **'江苏'**
  String get regionCNJS;

  /// No description provided for @regionCNSC.
  ///
  /// In zh, this message translates to:
  /// **'四川'**
  String get regionCNSC;

  /// No description provided for @regionHK.
  ///
  /// In zh, this message translates to:
  /// **'香港'**
  String get regionHK;

  /// No description provided for @regionTW.
  ///
  /// In zh, this message translates to:
  /// **'台湾'**
  String get regionTW;

  /// No description provided for @regionSG.
  ///
  /// In zh, this message translates to:
  /// **'新加坡'**
  String get regionSG;

  /// No description provided for @regionMY.
  ///
  /// In zh, this message translates to:
  /// **'马来西亚'**
  String get regionMY;

  /// No description provided for @regionUS.
  ///
  /// In zh, this message translates to:
  /// **'美国'**
  String get regionUS;

  /// No description provided for @regionCA.
  ///
  /// In zh, this message translates to:
  /// **'加拿大'**
  String get regionCA;

  /// No description provided for @regionAU.
  ///
  /// In zh, this message translates to:
  /// **'澳大利亚'**
  String get regionAU;

  /// No description provided for @regionGB.
  ///
  /// In zh, this message translates to:
  /// **'英国'**
  String get regionGB;

  /// No description provided for @regionJP.
  ///
  /// In zh, this message translates to:
  /// **'日本'**
  String get regionJP;

  /// No description provided for @regionKR.
  ///
  /// In zh, this message translates to:
  /// **'韩国'**
  String get regionKR;

  /// No description provided for @regionOTHER.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get regionOTHER;

  /// No description provided for @recordingTooShort.
  ///
  /// In zh, this message translates to:
  /// **'录音太短，未发送'**
  String get recordingTooShort;

  /// No description provided for @onlineMembers.
  ///
  /// In zh, this message translates to:
  /// **'在线成员'**
  String get onlineMembers;

  /// No description provided for @me.
  ///
  /// In zh, this message translates to:
  /// **'我'**
  String get me;

  /// No description provided for @hostLabel.
  ///
  /// In zh, this message translates to:
  /// **'主播'**
  String get hostLabel;

  /// No description provided for @deleteAccount.
  ///
  /// In zh, this message translates to:
  /// **'注销账号'**
  String get deleteAccount;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要注销账号吗？此操作无法撤销。注销后，您的所有帖子、评论、消息和个人资料都将被永久删除。'**
  String get deleteAccountConfirm;

  /// No description provided for @deleteAccountSuccess.
  ///
  /// In zh, this message translates to:
  /// **'账号注销成功。'**
  String get deleteAccountSuccess;

  /// No description provided for @deleteAccountFailed.
  ///
  /// In zh, this message translates to:
  /// **'注销失败：{error}'**
  String deleteAccountFailed(Object error);

  /// No description provided for @report.
  ///
  /// In zh, this message translates to:
  /// **'举报'**
  String get report;

  /// No description provided for @reportUser.
  ///
  /// In zh, this message translates to:
  /// **'举报用户'**
  String get reportUser;

  /// No description provided for @blockThisUser.
  ///
  /// In zh, this message translates to:
  /// **'拉黑该用户'**
  String get blockThisUser;

  /// No description provided for @blockedInteraction.
  ///
  /// In zh, this message translates to:
  /// **'已拉黑该用户，不能再互动'**
  String get blockedInteraction;

  /// No description provided for @reportReason.
  ///
  /// In zh, this message translates to:
  /// **'选择举报原因'**
  String get reportReason;

  /// No description provided for @reportReasonSpam.
  ///
  /// In zh, this message translates to:
  /// **'垃圾广告或营销'**
  String get reportReasonSpam;

  /// No description provided for @reportReasonHarassment.
  ///
  /// In zh, this message translates to:
  /// **'骚扰或仇恨言论'**
  String get reportReasonHarassment;

  /// No description provided for @reportReasonObjectionable.
  ///
  /// In zh, this message translates to:
  /// **'不良或不当内容'**
  String get reportReasonObjectionable;

  /// No description provided for @reportReasonViolence.
  ///
  /// In zh, this message translates to:
  /// **'暴力或血腥内容'**
  String get reportReasonViolence;

  /// No description provided for @reportReasonOther.
  ///
  /// In zh, this message translates to:
  /// **'其他问题'**
  String get reportReasonOther;

  /// No description provided for @reportSuccess.
  ///
  /// In zh, this message translates to:
  /// **'举报成功，我们将在 24 小时内进行审核处理。'**
  String get reportSuccess;

  /// No description provided for @reportFailed.
  ///
  /// In zh, this message translates to:
  /// **'举报失败，请稍后重试{error}'**
  String reportFailed(Object error);

  /// No description provided for @eulaMustAgree.
  ///
  /// In zh, this message translates to:
  /// **'请先阅读并同意用户协议与隐私政策'**
  String get eulaMustAgree;

  /// No description provided for @agreeIntro.
  ///
  /// In zh, this message translates to:
  /// **'我已阅读并同意'**
  String get agreeIntro;

  /// No description provided for @userAgreement.
  ///
  /// In zh, this message translates to:
  /// **'用户协议'**
  String get userAgreement;

  /// No description provided for @privacyPolicy.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策'**
  String get privacyPolicy;

  /// No description provided for @and.
  ///
  /// In zh, this message translates to:
  /// **'和'**
  String get and;

  /// No description provided for @blockedUsers.
  ///
  /// In zh, this message translates to:
  /// **'拉黑用户'**
  String get blockedUsers;

  /// No description provided for @noBlockedUsers.
  ///
  /// In zh, this message translates to:
  /// **'还没有拉黑任何人'**
  String get noBlockedUsers;

  /// No description provided for @contentBlocked.
  ///
  /// In zh, this message translates to:
  /// **'内容含违规词，请修改后再发'**
  String get contentBlocked;

  /// No description provided for @forgotPassword.
  ///
  /// In zh, this message translates to:
  /// **'忘记密码？'**
  String get forgotPassword;

  /// No description provided for @resetPassword.
  ///
  /// In zh, this message translates to:
  /// **'重置密码'**
  String get resetPassword;

  /// No description provided for @resetEmailHint.
  ///
  /// In zh, this message translates to:
  /// **'输入注册邮箱'**
  String get resetEmailHint;

  /// No description provided for @sendCode.
  ///
  /// In zh, this message translates to:
  /// **'发送验证码'**
  String get sendCode;

  /// No description provided for @resendCode.
  ///
  /// In zh, this message translates to:
  /// **'重新发送'**
  String get resendCode;

  /// No description provided for @codeHint.
  ///
  /// In zh, this message translates to:
  /// **'6位验证码'**
  String get codeHint;

  /// No description provided for @newPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'设置新密码（至少6位）'**
  String get newPasswordHint;

  /// No description provided for @resetCodeSent.
  ///
  /// In zh, this message translates to:
  /// **'验证码已发送，请查收邮箱'**
  String get resetCodeSent;

  /// No description provided for @resetSuccess.
  ///
  /// In zh, this message translates to:
  /// **'密码已重置，请用新密码登录'**
  String get resetSuccess;

  /// No description provided for @resetFailed.
  ///
  /// In zh, this message translates to:
  /// **'重置失败，请检查验证码或稍后重试'**
  String get resetFailed;

  /// No description provided for @emailRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入邮箱'**
  String get emailRequired;

  /// No description provided for @codeRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入验证码'**
  String get codeRequired;

  /// No description provided for @verifyEmailTitle.
  ///
  /// In zh, this message translates to:
  /// **'验证邮箱'**
  String get verifyEmailTitle;

  /// No description provided for @verifyEmailHint.
  ///
  /// In zh, this message translates to:
  /// **'我们已向 {email} 发送了一封验证码邮件，请输入邮件中的验证码完成注册。'**
  String verifyEmailHint(Object email);

  /// No description provided for @verifyEmailButton.
  ///
  /// In zh, this message translates to:
  /// **'完成注册'**
  String get verifyEmailButton;

  /// No description provided for @verifyEmailSuccess.
  ///
  /// In zh, this message translates to:
  /// **'邮箱验证成功，欢迎加入'**
  String get verifyEmailSuccess;

  /// No description provided for @verifyEmailFailed.
  ///
  /// In zh, this message translates to:
  /// **'验证失败，请检查验证码或稍后重试'**
  String get verifyEmailFailed;

  /// No description provided for @friends.
  ///
  /// In zh, this message translates to:
  /// **'好友'**
  String get friends;

  /// No description provided for @friendRequests.
  ///
  /// In zh, this message translates to:
  /// **'好友申请'**
  String get friendRequests;

  /// No description provided for @addFriend.
  ///
  /// In zh, this message translates to:
  /// **'加好友'**
  String get addFriend;

  /// No description provided for @friendRequestSent.
  ///
  /// In zh, this message translates to:
  /// **'已发送申请'**
  String get friendRequestSent;

  /// No description provided for @friendRequestPending.
  ///
  /// In zh, this message translates to:
  /// **'待你处理'**
  String get friendRequestPending;

  /// No description provided for @friendRequestSentToast.
  ///
  /// In zh, this message translates to:
  /// **'好友申请已发送'**
  String get friendRequestSentToast;

  /// No description provided for @friendRequestAccepted.
  ///
  /// In zh, this message translates to:
  /// **'已成为好友'**
  String get friendRequestAccepted;

  /// No description provided for @acceptRequest.
  ///
  /// In zh, this message translates to:
  /// **'接受申请'**
  String get acceptRequest;

  /// No description provided for @cancelRequest.
  ///
  /// In zh, this message translates to:
  /// **'取消申请'**
  String get cancelRequest;

  /// No description provided for @cancelRequestConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定取消这条好友申请吗？'**
  String get cancelRequestConfirm;

  /// No description provided for @alreadyFriends.
  ///
  /// In zh, this message translates to:
  /// **'已是好友'**
  String get alreadyFriends;

  /// No description provided for @removeFriend.
  ///
  /// In zh, this message translates to:
  /// **'解除好友'**
  String get removeFriend;

  /// No description provided for @removeFriendConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要解除与「{name}」的好友关系吗？'**
  String removeFriendConfirm(String name);

  /// No description provided for @noFriends.
  ///
  /// In zh, this message translates to:
  /// **'还没有好友'**
  String get noFriends;

  /// No description provided for @noFriendsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'点右上角搜索用户名，添加同伴'**
  String get noFriendsSubtitle;

  /// No description provided for @noFriendRequests.
  ///
  /// In zh, this message translates to:
  /// **'暂无好友申请'**
  String get noFriendRequests;

  /// No description provided for @outgoingRequests.
  ///
  /// In zh, this message translates to:
  /// **'我发出的申请'**
  String get outgoingRequests;

  /// No description provided for @searchUsersHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索用户名或昵称'**
  String get searchUsersHint;

  /// No description provided for @notFriendsCannotDm.
  ///
  /// In zh, this message translates to:
  /// **'加为好友后才能私信'**
  String get notFriendsCannotDm;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
