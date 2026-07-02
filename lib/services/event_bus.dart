import 'dart:async';
import '../models/post.dart';

final _postCreatedController = StreamController<void>.broadcast();

Stream<void> get onPostCreated => _postCreatedController.stream;

void notifyPostCreated() => _postCreatedController.add(null);

final _profileUpdatedController = StreamController<void>.broadcast();

Stream<void> get onProfileUpdated => _profileUpdatedController.stream;

void notifyProfileUpdated() => _profileUpdatedController.add(null);

final _postInteractedController = StreamController<Post>.broadcast();

Stream<Post> get onPostInteracted => _postInteractedController.stream;

void notifyPostInteracted(Post post) => _postInteractedController.add(post);

final _postDeletedController = StreamController<String>.broadcast();

Stream<String> get onPostDeleted => _postDeletedController.stream;

void notifyPostDeleted(String postId) => _postDeletedController.add(postId);

final _userBlockedController = StreamController<String>.broadcast();

Stream<String> get onUserBlocked => _userBlockedController.stream;

void notifyUserBlocked(String userId) => _userBlockedController.add(userId);
