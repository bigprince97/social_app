// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String loadFailed(Object error) {
    return 'Load failed: $error';
  }

  @override
  String get contents => 'Contents';

  @override
  String get noChapterContent => 'No chapter content';

  @override
  String get continueReading => 'Continue Reading';

  @override
  String get startReading => 'Start Reading';

  @override
  String chaptersCountLabel(Object chaptersCount) {
    return '$chaptersCount chapters';
  }

  @override
  String readPercent(Object percent) {
    return '$percent% read';
  }

  @override
  String get bookGenesis => 'Genesis';

  @override
  String get bookExodus => 'Exodus';

  @override
  String get bookLeviticus => 'Leviticus';

  @override
  String get bookNumbers => 'Numbers';

  @override
  String get bookDeuteronomy => 'Deuteronomy';

  @override
  String get bookJoshua => 'Joshua';

  @override
  String get bookJudges => 'Judges';

  @override
  String get bookRuth => 'Ruth';

  @override
  String get book1Samuel => '1 Samuel';

  @override
  String get book2Samuel => '2 Samuel';

  @override
  String get book1Kings => '1 Kings';

  @override
  String get book2Kings => '2 Kings';

  @override
  String get book1Chronicles => '1 Chronicles';

  @override
  String get book2Chronicles => '2 Chronicles';

  @override
  String get bookEzra => 'Ezra';

  @override
  String get bookNehemiah => 'Nehemiah';

  @override
  String get bookEsther => 'Esther';

  @override
  String get bookJob => 'Job';

  @override
  String get bookPsalms => 'Psalms';

  @override
  String get bookProverbs => 'Proverbs';

  @override
  String get bookEcclesiastes => 'Ecclesiastes';

  @override
  String get bookSongOfSongs => 'Song of Songs';

  @override
  String get bookIsaiah => 'Isaiah';

  @override
  String get bookJeremiah => 'Jeremiah';

  @override
  String get bookLamentations => 'Lamentations';

  @override
  String get bookEzekiel => 'Ezekiel';

  @override
  String get bookDaniel => 'Daniel';

  @override
  String get bookHosea => 'Hosea';

  @override
  String get bookJoel => 'Joel';

  @override
  String get bookAmos => 'Amos';

  @override
  String get bookObadiah => 'Obadiah';

  @override
  String get bookJonah => 'Jonah';

  @override
  String get bookMicah => 'Micah';

  @override
  String get bookNahum => 'Nahum';

  @override
  String get bookHabakkuk => 'Habakkuk';

  @override
  String get bookZephaniah => 'Zephaniah';

  @override
  String get bookHaggai => 'Haggai';

  @override
  String get bookZechariah => 'Zechariah';

  @override
  String get bookMalachi => 'Malachi';

  @override
  String get bookMatthew => 'Matthew';

  @override
  String get bookMark => 'Mark';

  @override
  String get bookLuke => 'Luke';

  @override
  String get bookJohn => 'John';

  @override
  String get bookActs => 'Acts';

  @override
  String get bookRomans => 'Romans';

  @override
  String get book1Corinthians => '1 Corinthians';

  @override
  String get book2Corinthians => '2 Corinthians';

  @override
  String get bookGalatians => 'Galatians';

  @override
  String get bookEphesians => 'Ephesians';

  @override
  String get bookPhilippians => 'Philippians';

  @override
  String get bookColossians => 'Colossians';

  @override
  String get book1Thessalonians => '1 Thessalonians';

  @override
  String get book2Thessalonians => '2 Thessalonians';

  @override
  String get book1Timothy => '1 Timothy';

  @override
  String get book2Timothy => '2 Timothy';

  @override
  String get bookTitus => 'Titus';

  @override
  String get bookPhilemon => 'Philemon';

  @override
  String get bookHebrews => 'Hebrews';

  @override
  String get bookJames => 'James';

  @override
  String get book1Peter => '1 Peter';

  @override
  String get book2Peter => '2 Peter';

  @override
  String get book1John => '1 John';

  @override
  String get book2John => '2 John';

  @override
  String get book3John => '3 John';

  @override
  String get bookJude => 'Jude';

  @override
  String get bookRevelation => 'Revelation';

  @override
  String get books => 'Books';

  @override
  String get chapters => 'Chapters';

  @override
  String get oldTestament => 'Old Testament';

  @override
  String get newTestament => 'New Testament';

  @override
  String get selectBookFirst => 'Please select a book first';

  @override
  String volumeCount(Object count) {
    return '$count books';
  }

  @override
  String bookChapterDisplay(Object bookName, Object chapterNumber) {
    return '$bookName $chapterNumber';
  }

  @override
  String get editGroupAnnouncement => 'Edit Group Announcement';

  @override
  String get announcementHint => 'Enter announcement...';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String saveFailed(Object error) {
    return 'Save failed: $error';
  }

  @override
  String get removeFromGroup => 'Remove from Group';

  @override
  String get removedFromGroup => 'Removed from group';

  @override
  String operationFailed(Object error) {
    return 'Operation failed: $error';
  }

  @override
  String get promoteToAdmin => 'Make Admin';

  @override
  String get promotedToAdmin => 'Set as admin';

  @override
  String get demoteAdmin => 'Remove Admin';

  @override
  String get demotedAdmin => 'Admin removed';

  @override
  String get leaveGroup => 'Leave Group';

  @override
  String get confirmLeaveGroup => 'Are you sure you want to leave this group?';

  @override
  String leaveFailed(Object error) {
    return 'Failed to leave: $error';
  }

  @override
  String get disbandGroup => 'Disband Group';

  @override
  String get confirmDisbandGroup =>
      'After disbanding, all members will be removed and chat history will be deleted. This cannot be undone. Are you sure?';

  @override
  String get groupInfo => 'Group Info';

  @override
  String get group => 'Group';

  @override
  String memberCount(Object count) {
    return '$count members';
  }

  @override
  String get announcement => 'Group Announcement';

  @override
  String get clickToSetAnnouncement => 'Tap to set a group announcement';

  @override
  String get noAnnouncement => 'No announcements';

  @override
  String get groupFiles => 'Group Files';

  @override
  String members(Object count) {
    return 'Members ($count)';
  }

  @override
  String get you => 'You';

  @override
  String get admin => 'Admin';

  @override
  String createFailed(Object error) {
    return 'Failed to create: $error';
  }

  @override
  String get deleteFolder => 'Delete Folder';

  @override
  String confirmDeleteFolder(Object folderName) {
    return 'Delete \"$folderName\"? Files inside will be moved back to the root directory, not deleted.';
  }

  @override
  String get delete => 'Delete';

  @override
  String deleteFailed(Object error) {
    return 'Failed to delete: $error';
  }

  @override
  String renameFailed(Object error) {
    return 'Failed to rename: $error';
  }

  @override
  String get createFolder => 'New Folder';

  @override
  String get renameFolder => 'Rename Folder';

  @override
  String get folderName => 'Folder name';

  @override
  String get confirm => 'OK';

  @override
  String moveFileTo(Object fileName) {
    return 'Move \"$fileName\" to';
  }

  @override
  String get rootDirectory => 'Root Directory';

  @override
  String moveFailed(Object error) {
    return 'Failed to move: $error';
  }

  @override
  String get cannotOpenFile => 'Cannot open file';

  @override
  String get files => 'Files';

  @override
  String get noSharedFiles => 'No shared files';

  @override
  String get folderEmpty => 'This folder is empty';

  @override
  String get emptyFilesHint =>
      'Files sent in chat will appear here.\nTap the top-right corner to create a folder.';

  @override
  String get longPressToMoveFile => 'Long-press a file to move it here';

  @override
  String get rename => 'Rename';

  @override
  String fileCount(Object count) {
    return '$count files';
  }

  @override
  String get moveToFolder => 'Move to Folder';

  @override
  String get unknownFile => 'Unknown file';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get selectConversation => 'Select Conversation';

  @override
  String get privateChat => 'Private Chat';

  @override
  String get sentToChat => 'Sent to chat';

  @override
  String noteTitle(Object chapterTitle) {
    return 'Note · $chapterTitle';
  }

  @override
  String get noteHint => 'Write down your thoughts...';

  @override
  String get copyScripture => 'Copy Scripture';

  @override
  String get sendToChat => 'Send to Chat';

  @override
  String selectedVerses(Object count) {
    return '$count verses selected';
  }

  @override
  String get copy => 'Copy';

  @override
  String get quoteToChat => 'Quote in Chat';

  @override
  String get fontSizeSmall => 'Small';

  @override
  String get fontSizeNormal => 'Normal';

  @override
  String get fontSizeLarge => 'Large';

  @override
  String get fontSizeExtraLarge => 'Extra Large';

  @override
  String get previousChapter => 'Previous Chapter';

  @override
  String get note => 'Note';

  @override
  String get highlight => 'Highlight';

  @override
  String get bookmark => 'Bookmark';

  @override
  String get quote => 'Quote';

  @override
  String get nextChapter => 'Next Chapter';

  @override
  String oldTestamentCount(Object count) {
    return 'Old Testament $count';
  }

  @override
  String crossReferenceTitle(Object chapterTitle, Object verse) {
    return '$chapterTitle Verse $verse · Old Testament Reference';
  }

  @override
  String get chapterNotFound => 'Chapter not found';

  @override
  String get scripture => 'Scripture';

  @override
  String get myBookmarks => 'My Bookmarks';

  @override
  String get lastReading => 'Last Read';

  @override
  String get allScriptures => 'All Scriptures';

  @override
  String get continueLabel => 'Continue';

  @override
  String chapterCount(Object count) {
    return '$count chapters';
  }

  @override
  String get noScriptureContent => 'No scripture content';

  @override
  String get noBookmarks => 'No bookmarks yet';

  @override
  String get bookmarkHint => 'Tap the bookmark icon while reading to save';

  @override
  String get deletedChapter => 'Deleted chapter';

  @override
  String get blockUserTitle => 'Block User';

  @override
  String blockUserConfirm(Object displayName) {
    return 'Block $displayName?';
  }

  @override
  String get block => 'Block';

  @override
  String get userBlocked => 'User blocked';

  @override
  String directMessageFailed(Object error) {
    return 'Failed to start message: $error';
  }

  @override
  String get settings => 'Settings';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get languageSettings => 'Language';

  @override
  String get logout => 'Log Out';

  @override
  String get confirmLogout => 'Are you sure you want to log out?';

  @override
  String get confirmButton => 'Log Out';

  @override
  String get userNotFound => 'User not found';

  @override
  String get noPosts => 'No posts yet';

  @override
  String get posts => 'Posts';

  @override
  String get followers => 'Followers';

  @override
  String get following => 'Following';

  @override
  String get alreadyFollowing => 'Following';

  @override
  String get directMessage => 'Message';

  @override
  String get displayNameRequired => 'Display name is required';

  @override
  String get savingSucceeded => 'Saved successfully';

  @override
  String get clickToChangeAvatar => 'Tap to change avatar';

  @override
  String get displayName => 'Display Name';

  @override
  String get bio => 'Bio';

  @override
  String get region => 'Region';

  @override
  String get notSet => 'Not set';

  @override
  String get languagePreference => 'Language Preference';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get regionBeijing => 'Beijing';

  @override
  String get regionShanghai => 'Shanghai';

  @override
  String get regionGuangdong => 'Guangdong';

  @override
  String get regionZhejiang => 'Zhejiang';

  @override
  String get regionJiangsu => 'Jiangsu';

  @override
  String get regionSichuan => 'Sichuan';

  @override
  String get regionHongKong => 'Hong Kong';

  @override
  String get regionTaiwan => 'Taiwan';

  @override
  String get regionSingapore => 'Singapore';

  @override
  String get regionMalaysia => 'Malaysia';

  @override
  String get regionUSA => 'United States';

  @override
  String get regionCanada => 'Canada';

  @override
  String get regionAustralia => 'Australia';

  @override
  String get regionUK => 'United Kingdom';

  @override
  String get regionJapan => 'Japan';

  @override
  String get regionSouthKorea => 'South Korea';

  @override
  String get regionOther => 'Other';

  @override
  String followersList(Object displayName) {
    return '$displayName\'s Followers';
  }

  @override
  String followingList(Object displayName) {
    return '$displayName\'s Following';
  }

  @override
  String get noFollowers => 'No followers yet';

  @override
  String get noFollowing => 'Not following anyone yet';

  @override
  String followerCount(Object count) {
    return '$count followers';
  }

  @override
  String joinLivestreamFailed(Object error) {
    return 'Failed to join livestream: $error';
  }

  @override
  String sendFailed(Object error) {
    return 'Failed to send: $error';
  }

  @override
  String get microphonePermissionRequired =>
      'Microphone permission is required to record';

  @override
  String get attachmentTitle => 'Send';

  @override
  String get attachmentPhoto => 'Photo';

  @override
  String get attachmentVideo => 'Video';

  @override
  String get attachmentCamera => 'Camera';

  @override
  String blockUserConfirm2(Object name) {
    return 'Block $name?';
  }

  @override
  String userBlocked2(Object name) {
    return '$name blocked';
  }

  @override
  String get online => 'Online';

  @override
  String get voiceCall => 'Voice Call';

  @override
  String get videoCall => 'Video Call';

  @override
  String get startLivestream => 'Start Livestream';

  @override
  String get groupLivestreamOngoing => 'Livestream in progress';

  @override
  String get joinLivestream => 'Tap to join';

  @override
  String get sendFirstMessage => 'Send the first message!';

  @override
  String get recording => 'Recording';

  @override
  String get messages => 'Messages';

  @override
  String get searchConversations => 'Search chats...';

  @override
  String get noMessages => 'No messages yet';

  @override
  String get noSearchResults => 'No matching conversations';

  @override
  String get createNewChat => 'Tap the top-right icon to start a new chat';

  @override
  String get noMessagePreview => 'No messages';

  @override
  String get searchUsers => 'Search by username or nickname';

  @override
  String get groupChatName => 'Group name';

  @override
  String get searchMembers => 'Search to add members';

  @override
  String createFailed2(Object error) {
    return 'Failed to create: $error';
  }

  @override
  String createGroupButton(Object count) {
    return 'Create Group ($count)';
  }

  @override
  String get recall => 'Recall';

  @override
  String get recallTimeLimit =>
      'Messages can only be recalled within 2 minutes';

  @override
  String get messageDeleted => 'Message recalled';

  @override
  String audioPlayFailed(Object error) {
    return 'Playback failed: $error';
  }

  @override
  String scriptureQuote(Object scripture, Object chapter) {
    return '$scripture $chapter';
  }

  @override
  String get downloading => 'Downloading…';

  @override
  String cannotOpen(Object message) {
    return 'Cannot open: $message';
  }

  @override
  String openFailed(Object error) {
    return 'Failed to open: $error';
  }

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get square => 'Square';

  @override
  String get latest => 'Latest';

  @override
  String get hot => 'Hot';

  @override
  String get topics => 'Topics';

  @override
  String get emptyFollowingSubtitle =>
      'Head to the Square to find interesting people!';

  @override
  String get emptyPostsHint => 'No posts yet. Be the first to post!';

  @override
  String newPostsNotification(Object count) {
    return '$count new posts. Tap to refresh';
  }

  @override
  String get emptyTopicPosts => 'No posts in this topic yet';

  @override
  String get searchTopicsHint => 'Search topics...';

  @override
  String get emptyTopics => 'No topics yet';

  @override
  String get hotTopics => 'Trending Topics';

  @override
  String get postTitle => 'New Post';

  @override
  String get publish => 'Publish';

  @override
  String get shareThoughtsHint => 'Share your thoughts...';

  @override
  String get addTopicHint => 'Add topic #';

  @override
  String get postDetail => 'Post';

  @override
  String get comments => 'Comments';

  @override
  String get emptyComments => 'No comments yet. Be the first to comment!';

  @override
  String get writeCommentHint => 'Write a comment...';

  @override
  String commentFailed(Object error) {
    return 'Comment failed: $error';
  }

  @override
  String get deletePost => 'Delete Post';

  @override
  String get deletePostConfirm =>
      'Delete this post? This action cannot be undone.';

  @override
  String get unknownUser => 'Unknown User';

  @override
  String get searchHint => 'Search users, posts, scriptures...';

  @override
  String get users => 'Users';

  @override
  String get posts2 => 'Posts';

  @override
  String get search => 'Search';

  @override
  String get searchEmptySubtitle => 'Find users, posts, or scriptures';

  @override
  String get emptyUsers => 'No matching users found';

  @override
  String get emptyPosts => 'No matching posts found';

  @override
  String get emptyScriptures => 'No matching scriptures found';

  @override
  String get notifications => 'Notifications';

  @override
  String get markAllRead => 'Mark all as read';

  @override
  String get emptyNotifications => 'No notifications';

  @override
  String get emptyNotificationsSubtitle => 'New interactions will show up here';

  @override
  String publishFailed(Object error) {
    return 'Publish failed: $error';
  }

  @override
  String connectionFailed(Object error) {
    return 'Connection failed: $error';
  }

  @override
  String get inCall => 'In call';

  @override
  String get ringing => 'Calling...';

  @override
  String get callDeclined => 'Call declined';

  @override
  String get callEnded => 'Call ended';

  @override
  String get connecting => 'Connecting...';

  @override
  String get mute => 'Mute';

  @override
  String get unmute => 'Unmute';

  @override
  String get cameraOff => 'Camera off';

  @override
  String get cameraOn => 'Camera on';

  @override
  String get earpiece => 'Earpiece';

  @override
  String get speaker => 'Speaker';

  @override
  String get waitingForHost => 'Waiting for the host to start the livestream…';

  @override
  String get micOn => 'Unmute';

  @override
  String get flipCamera => 'Flip';

  @override
  String get endLivestream => 'End Livestream';

  @override
  String get incomingCall => 'Incoming Call';

  @override
  String get livestreamInvite => 'Livestream Invite';

  @override
  String callInvitation(Object typeLabel) {
    return '$typeLabel invitation…';
  }

  @override
  String get decline => 'Decline';

  @override
  String get accept => 'Accept';

  @override
  String get appName => 'Church Community';

  @override
  String get appTagline => 'Timeless classics, built together';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get email => 'Email';

  @override
  String get invalidEmailError => 'Please enter a valid email';

  @override
  String get password => 'Password';

  @override
  String get passwordTooShortError => 'Password must be at least 6 characters';

  @override
  String get login => 'Log In';

  @override
  String get noAccountRegisterNow => 'Don\'t have an account? Sign up now';

  @override
  String loginFailed(Object error) {
    return 'Login failed: $error';
  }

  @override
  String get createAccount => 'Create Account';

  @override
  String get nicknameRequiredError => 'Please enter a nickname';

  @override
  String get register => 'Sign Up';

  @override
  String get hasAccountGoLogin => 'Already have an account? Log in';

  @override
  String registerFailed(Object error) {
    return 'Sign-up failed: $error';
  }

  @override
  String get tabProfile => 'Me';

  @override
  String acceptCallFailed(Object error) {
    return 'Failed to accept call: $error';
  }

  @override
  String get imagePlaceholder => '[Photo]';

  @override
  String get videoPlaceholder => '[Video]';

  @override
  String get filePlaceholder => '[File]';

  @override
  String get audioPlaceholder => '[Voice]';

  @override
  String get scripturePlaceholder => '[Scripture]';

  @override
  String notificationLiked(Object actor) {
    return '$actor liked your post';
  }

  @override
  String notificationCommented(Object actor) {
    return '$actor commented on your post';
  }

  @override
  String notificationFollowed(Object actor) {
    return '$actor followed you';
  }

  @override
  String get someone => 'Someone';

  @override
  String get newNotification => 'You have a new notification';

  @override
  String get action => 'Actions';

  @override
  String blockUserConfirm3(Object name) {
    return 'Block $name?';
  }

  @override
  String get unblock => 'Unblock';

  @override
  String get categoryDaoism => 'Taoism';

  @override
  String get categoryBuddhism => 'Buddhist Sutras';

  @override
  String get categoryChrisiandity => 'Christianity';

  @override
  String crossRefVerse(Object chapterTitle, Object verse) {
    return '$chapterTitle:$verse';
  }

  @override
  String crossRefVerseRange(
    Object chapterTitle,
    Object verseStart,
    Object verseEnd,
  ) {
    return '$chapterTitle:$verseStart-$verseEnd';
  }

  @override
  String get send => 'Send';

  @override
  String get messageHint => 'Message...';

  @override
  String get thisUser => 'this user';

  @override
  String callStartFailed(Object error) {
    return 'Failed to start call: $error';
  }

  @override
  String livestreamStartFailed(Object error) {
    return 'Failed to start livestream: $error';
  }

  @override
  String get regionCNBJ => 'Beijing';

  @override
  String get regionCNSH => 'Shanghai';

  @override
  String get regionCNGD => 'Guangdong';

  @override
  String get regionCNZJ => 'Zhejiang';

  @override
  String get regionCNJS => 'Jiangsu';

  @override
  String get regionCNSC => 'Sichuan';

  @override
  String get regionHK => 'Hong Kong';

  @override
  String get regionTW => 'Taiwan';

  @override
  String get regionSG => 'Singapore';

  @override
  String get regionMY => 'Malaysia';

  @override
  String get regionUS => 'USA';

  @override
  String get regionCA => 'Canada';

  @override
  String get regionAU => 'Australia';

  @override
  String get regionGB => 'UK';

  @override
  String get regionJP => 'Japan';

  @override
  String get regionKR => 'South Korea';

  @override
  String get regionOTHER => 'Other';

  @override
  String get recordingTooShort => 'Recording too short, not sent';

  @override
  String get onlineMembers => 'Online Members';

  @override
  String get me => 'Me';

  @override
  String get hostLabel => 'Host';
}
