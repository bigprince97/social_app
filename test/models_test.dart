import 'package:flutter_test/flutter_test.dart';
import 'package:social_app/models/profile.dart';
import 'package:social_app/models/conversation.dart';
import 'package:social_app/models/notification.dart';
import 'package:social_app/services/friend_service.dart';

void main() {
  // ─── Profile ──────────────────────────────────────────────────────────────

  group('Profile.fromJson', () {
    final base = {
      'id': 'u1',
      'username': 'alice',
      'display_name': 'Alice',
      'avatar_url': null,
      'bio': null,
      'followers_count': 10,
      'following_count': 5,
      'posts_count': 3,
      'created_at': '2024-01-01T00:00:00.000Z',
      'region': 'SG',
      'language': 'zh',
    };

    test('parses all fields correctly', () {
      final p = Profile.fromJson(base);
      expect(p.id, 'u1');
      expect(p.username, 'alice');
      expect(p.displayName, 'Alice');
      expect(p.region, 'SG');
      expect(p.language, 'zh');
    });

    test('handles missing count fields (defaults to 0)', () {
      final sparse = Map<String, dynamic>.from(base)
        ..remove('followers_count')
        ..remove('following_count')
        ..remove('posts_count');
      final p = Profile.fromJson(sparse);
      expect(p.followersCount, 0);
      expect(p.followingCount, 0);
      expect(p.postsCount, 0);
    });

    test('copyWith updates only specified fields', () {
      final p = Profile.fromJson(base);
      final updated = p.copyWith(bio: 'hello');
      expect(updated.bio, 'hello');
      // unchanged fields preserved
      expect(updated.id, p.id);
      expect(updated.username, p.username);
    });

    test('copyWith with no args returns identical values', () {
      final p = Profile.fromJson(base);
      final copy = p.copyWith();
      expect(copy.id, p.id);
      expect(copy.displayName, p.displayName);
    });
  });

  // ─── Friendship ───────────────────────────────────────────────────────────

  group('Friendship', () {
    final profileJson = {
      'id': 'u2',
      'username': 'bob',
      'display_name': 'Bob',
      'avatar_url': null,
      'bio': null,
      'created_at': '2024-01-01T00:00:00.000Z',
      'region': null,
      'language': null,
    };

    Map<String, dynamic> baseRow({String status = 'pending'}) => {
          'id': 'f1',
          'requester_id': 'u1',
          'addressee_id': 'u2',
          'status': status,
          'created_at': '2024-06-01T00:00:00.000Z',
          'requester': null,
          'addressee': Map<String, dynamic>.from(profileJson),
        };

    test('fromJson picks the other side profile for requester', () {
      final f = Friendship.fromJson(baseRow(), 'u1');
      expect(f.other?.id, 'u2');
      expect(f.other?.username, 'bob');
    });

    test('statusFor: requester sees outgoingPending', () {
      final f = Friendship.fromJson(baseRow(), 'u1');
      expect(f.statusFor('u1'), FriendshipStatus.outgoingPending);
    });

    test('statusFor: addressee sees incomingPending', () {
      final f = Friendship.fromJson(baseRow(), 'u2');
      expect(f.statusFor('u2'), FriendshipStatus.incomingPending);
    });

    test('statusFor: accepted for both sides', () {
      final f = Friendship.fromJson(baseRow(status: 'accepted'), 'u1');
      expect(f.statusFor('u1'), FriendshipStatus.accepted);
      expect(f.statusFor('u2'), FriendshipStatus.accepted);
    });
  });

  // ─── Conversation ─────────────────────────────────────────────────────────

  group('Conversation', () {
    final baseConv = {
      'id': 'cv1',
      'type': 'direct',
      'name': null,
      'avatar_url': null,
      'created_by': null,
      'last_message_at': null,
      'last_message_preview': null,
      'created_at': '2024-01-01T00:00:00.000Z',
      'conversation_members': [],
      'announcement': null,
      'announcement_updated_at': null,
    };

    test('fromJson parses direct conversation', () {
      final c = Conversation.fromJson(baseConv);
      expect(c.id, 'cv1');
      expect(c.type, 'direct');
      expect(c.members, isEmpty);
      expect(c.unreadCount, 0);
    });

    test('displayName returns group name for group type', () {
      final json = Map<String, dynamic>.from(baseConv)
        ..['type'] = 'group'
        ..['name'] = '测试群';
      final c = Conversation.fromJson(json);
      expect(c.displayName('u1'), '测试群');
    });

    test('displayName returns fallback for group with no name', () {
      final json = Map<String, dynamic>.from(baseConv)
        ..['type'] = 'group';
      expect(Conversation.fromJson(json).displayName('u1'), '群聊');
    });

    test('displayName returns 未知用户 when members empty', () {
      expect(Conversation.fromJson(baseConv).displayName('u1'), '未知用户');
    });
  });

  // ─── AppNotification ──────────────────────────────────────────────────────

  group('AppNotification.fromJson', () {
    final baseNotif = {
      'id': 'n1',
      'user_id': 'u1',
      'actor_id': 'u2',
      'type': 'friend_request',
      'post_id': null,
      'comment_id': null,
      'is_read': false,
      'created_at': '2024-06-01T10:00:00.000Z',
      'profiles': null,
    };

    test('parses all fields', () {
      final n = AppNotification.fromJson(baseNotif);
      expect(n.id, 'n1');
      expect(n.type, 'friend_request');
      expect(n.isRead, false);
    });

    test('handles is_read=true', () {
      final json = Map<String, dynamic>.from(baseNotif)..['is_read'] = true;
      expect(AppNotification.fromJson(json).isRead, true);
    });

    test('friend_request body mentions request', () {
      final n = AppNotification.fromJson(baseNotif);
      expect(n.body, contains('好友'));
    });

    test('friend_accept body mentions acceptance', () {
      final json = Map<String, dynamic>.from(baseNotif)
        ..['type'] = 'friend_accept';
      expect(AppNotification.fromJson(json).body, contains('通过'));
    });
  });
}
