import 'package:flutter_test/flutter_test.dart';
import 'package:social_app/models/message.dart';
import 'package:social_app/services/message_sync_service.dart';

Message _message({
  required String id,
  String conversationId = 'conversation-1',
  String senderId = 'other-user',
  String? content,
  String messageType = 'text',
  String? mediaUrl,
  bool isDeleted = false,
  Map<String, dynamic>? payload,
}) {
  return Message(
    id: id,
    conversationId: conversationId,
    senderId: senderId,
    content: content ?? 'message-$id',
    messageType: messageType,
    mediaUrl: mediaUrl,
    isDeleted: isDeleted,
    createdAt: DateTime.utc(2026, 7, 11),
    payload: payload,
  );
}

void main() {
  group('MessageSyncStore inserts', () {
    test(
      'duplicate insert is rejected and does not increment unread twice',
      () {
        final store = MessageSyncStore();
        final message = _message(id: 'message-1');

        expect(
          store.acceptInsert(
            message: message,
            currentUserId: 'current-user',
            isCurrentConversation: false,
          ),
          isTrue,
        );
        expect(store.unreadCounts['conversation-1'], 1);

        expect(
          store.acceptInsert(
            message: message,
            currentUserId: 'current-user',
            isCurrentConversation: false,
          ),
          isFalse,
        );
        expect(store.unreadCounts['conversation-1'], 1);
        expect(store.totalUnread, 1);
      },
    );

    test('own message is accepted without increasing existing unread', () {
      final store = MessageSyncStore()..replaceUnread({'conversation-1': 4});

      expect(
        store.acceptInsert(
          message: _message(id: 'own-1', senderId: 'current-user'),
          currentUserId: 'current-user',
          isCurrentConversation: false,
        ),
        isTrue,
      );
      expect(store.unreadCounts['conversation-1'], 4);
      expect(store.totalUnread, 4);
    });

    test('message in current conversation keeps that conversation read', () {
      final store = MessageSyncStore()
        ..replaceUnread({'conversation-1': 7, 'conversation-2': 3});

      expect(
        store.acceptInsert(
          message: _message(id: 'current-1'),
          currentUserId: 'current-user',
          isCurrentConversation: true,
        ),
        isTrue,
      );
      expect(store.unreadCounts, {'conversation-1': 0, 'conversation-2': 3});
      expect(store.totalUnread, 3);
    });
  });

  group('MessageSyncStore unread state', () {
    test('replaceUnread replaces all values and clamps negatives to zero', () {
      final store = MessageSyncStore()
        ..replaceUnread({'old-conversation': 9})
        ..replaceUnread({'conversation-1': 5, 'conversation-2': -3});

      expect(store.unreadCounts, {'conversation-1': 5, 'conversation-2': 0});
      expect(store.unreadCounts.containsKey('old-conversation'), isFalse);
      expect(store.totalUnread, 5);
    });

    test('markRead clears only the selected conversation', () {
      final store = MessageSyncStore()
        ..replaceUnread({'conversation-1': 5, 'conversation-2': 2})
        ..markRead('conversation-1');

      expect(store.unreadCounts, {'conversation-1': 0, 'conversation-2': 2});
      expect(store.totalUnread, 2);
    });
  });

  group('MessageSyncStore updates', () {
    test('identical update is rejected while changed update is accepted', () {
      final store = MessageSyncStore();
      final original = _message(
        id: 'message-1',
        content: 'before',
        payload: {'edited_at': null},
      );
      final edited = _message(
        id: 'message-1',
        content: 'after',
        payload: {'edited_at': '2026-07-11T00:01:00.000Z'},
      );
      final recalled = _message(
        id: 'message-1',
        content: 'after',
        isDeleted: true,
        payload: {'edited_at': '2026-07-11T00:01:00.000Z'},
      );

      expect(store.acceptUpdate(original), isTrue);
      expect(store.acceptUpdate(original), isFalse);
      expect(store.acceptUpdate(edited), isTrue);
      expect(store.acceptUpdate(edited), isFalse);
      expect(store.acceptUpdate(recalled), isTrue);
      expect(store.acceptUpdate(recalled), isFalse);
    });
  });

  group('MessageSyncStore seenLimit', () {
    test('insert dedup evicts the oldest id after reaching the limit', () {
      final store = MessageSyncStore(seenLimit: 2);

      for (final id in ['message-1', 'message-2', 'message-3']) {
        expect(
          store.acceptInsert(
            message: _message(id: id),
            currentUserId: 'current-user',
            isCurrentConversation: false,
          ),
          isTrue,
        );
      }
      expect(store.totalUnread, 3);

      expect(
        store.acceptInsert(
          message: _message(id: 'message-1'),
          currentUserId: 'current-user',
          isCurrentConversation: false,
        ),
        isTrue,
      );
      expect(store.totalUnread, 4);
      expect(
        store.acceptInsert(
          message: _message(id: 'message-1'),
          currentUserId: 'current-user',
          isCurrentConversation: false,
        ),
        isFalse,
      );
    });

    test('update dedup evicts the oldest fingerprint at the same limit', () {
      final store = MessageSyncStore(seenLimit: 2);
      final first = _message(id: 'message-1');

      expect(store.acceptUpdate(first), isTrue);
      expect(store.acceptUpdate(_message(id: 'message-2')), isTrue);
      expect(store.acceptUpdate(_message(id: 'message-3')), isTrue);
      expect(store.acceptUpdate(first), isTrue);
      expect(store.acceptUpdate(first), isFalse);
    });
  });

  group('MessageSyncStore burst handling', () {
    test('accepts all 200 unique inserts and rejects their replay', () {
      final store = MessageSyncStore();
      final messages = List.generate(
        200,
        (index) => _message(id: 'burst-200-$index'),
      );

      final accepted = messages
          .where(
            (message) => store.acceptInsert(
              message: message,
              currentUserId: 'current-user',
              isCurrentConversation: false,
            ),
          )
          .length;
      final replayed = messages
          .where(
            (message) => store.acceptInsert(
              message: message,
              currentUserId: 'current-user',
              isCurrentConversation: false,
            ),
          )
          .length;

      expect(accepted, 200);
      expect(replayed, 0);
      expect(store.unreadCounts['conversation-1'], 200);
      expect(store.totalUnread, 200);
    });

    test(
      'accepts all 1000 unique inserts across conversations without loss',
      () {
        final store = MessageSyncStore();
        var accepted = 0;

        for (var index = 0; index < 1000; index++) {
          final conversationId = 'conversation-${index % 10}';
          if (store.acceptInsert(
            message: _message(
              id: 'burst-1000-$index',
              conversationId: conversationId,
            ),
            currentUserId: 'current-user',
            isCurrentConversation: false,
          )) {
            accepted++;
          }
        }

        expect(accepted, 1000);
        expect(store.unreadCounts.length, 10);
        for (var index = 0; index < 10; index++) {
          expect(store.unreadCounts['conversation-$index'], 100);
        }
        expect(store.totalUnread, 1000);
      },
    );
  });
}
