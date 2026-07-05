import 'dart:async';

final _profileUpdatedController = StreamController<void>.broadcast();

Stream<void> get onProfileUpdated => _profileUpdatedController.stream;

void notifyProfileUpdated() => _profileUpdatedController.add(null);

final _userBlockedController = StreamController<String>.broadcast();

Stream<String> get onUserBlocked => _userBlockedController.stream;

void notifyUserBlocked(String userId) => _userBlockedController.add(userId);
