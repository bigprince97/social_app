import 'dart:async';

final _postCreatedController = StreamController<void>.broadcast();

Stream<void> get onPostCreated => _postCreatedController.stream;

void notifyPostCreated() => _postCreatedController.add(null);

final _profileUpdatedController = StreamController<void>.broadcast();

Stream<void> get onProfileUpdated => _profileUpdatedController.stream;

void notifyProfileUpdated() => _profileUpdatedController.add(null);

final _postInteractedController = StreamController<void>.broadcast();

Stream<void> get onPostInteracted => _postInteractedController.stream;

void notifyPostInteracted() => _postInteractedController.add(null);
