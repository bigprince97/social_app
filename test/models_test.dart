import 'package:flutter_test/flutter_test.dart';
import 'package:social_app/models/post.dart';
import 'package:social_app/models/profile.dart';
import 'package:social_app/models/conversation.dart';
import 'package:social_app/models/notification.dart';
import 'package:social_app/models/message.dart';

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
      expect(p.followersCount, 10);
      expect(p.followingCount, 5);
      expect(p.postsCount, 3);
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
      final updated = p.copyWith(followersCount: 99, bio: 'hello');
      expect(updated.followersCount, 99);
      expect(updated.bio, 'hello');
      // unchanged fields preserved
      expect(updated.id, p.id);
      expect(updated.username, p.username);
      expect(updated.followingCount, p.followingCount);
    });

    test('copyWith with no args returns identical values', () {
      final p = Profile.fromJson(base);
      final copy = p.copyWith();
      expect(copy.id, p.id);
      expect(copy.followersCount, p.followersCount);
    });
  });

  // ─── Post ─────────────────────────────────────────────────────────────────

  group('Post.fromJson', () {
    final basePost = {
      'id': 'p1',
      'user_id': 'u1',
      'content': 'Hello world',
      'image_urls': ['https://example.com/a.jpg'],
      'video_url': null,
      'audio_url': null,
      'topics': ['信仰', '分享'],
      'scripture_quote': null,
      'likes_count': 42,
      'comments_count': 7,
      'created_at': '2024-06-01T12:00:00.000Z',
      'profiles': null,
    };

    test('parses required fields', () {
      final post = Post.fromJson(basePost);
      expect(post.id, 'p1');
      expect(post.content, 'Hello world');
      expect(post.imageUrls, ['https://example.com/a.jpg']);
      expect(post.topics, ['信仰', '分享']);
      expect(post.likesCount, 42);
      expect(post.commentsCount, 7);
    });

    test('defaults to isLiked=false', () {
      expect(Post.fromJson(basePost).isLiked, false);
    });

    test('handles null image_urls (defaults to empty list)', () {
      final json = Map<String, dynamic>.from(basePost)..['image_urls'] = null;
      expect(Post.fromJson(json).imageUrls, isEmpty);
    });

    test('handles null topics (defaults to empty list)', () {
      final json = Map<String, dynamic>.from(basePost)..['topics'] = null;
      expect(Post.fromJson(json).topics, isEmpty);
    });

    test('handles missing likes_count and comments_count', () {
      final json = Map<String, dynamic>.from(basePost)
        ..remove('likes_count')
        ..remove('comments_count');
      final post = Post.fromJson(json);
      expect(post.likesCount, 0);
      expect(post.commentsCount, 0);
    });

    test(
      'parses dynamic relationship counts from post_likes and post_comments',
      () {
        final json = Map<String, dynamic>.from(basePost)
          ..remove('likes_count')
          ..remove('comments_count')
          ..['post_likes'] = [
            {'count': 5},
          ]
          ..['post_comments'] = [
            {'count': 12},
          ];
        final post = Post.fromJson(json);
        expect(post.likesCount, 5);
        expect(post.commentsCount, 12);
      },
    );

    test('parses nested profile author', () {
      final json = Map<String, dynamic>.from(basePost)
        ..['profiles'] = {
          'id': 'u1',
          'username': 'alice',
          'display_name': 'Alice',
          'avatar_url': null,
          'bio': null,
          'followers_count': 0,
          'following_count': 0,
          'posts_count': 0,
          'created_at': '2024-01-01T00:00:00.000Z',
          'region': null,
          'language': null,
        };
      final post = Post.fromJson(json);
      expect(post.author?.username, 'alice');
    });
  });

  group('PostComment.fromJson', () {
    test('parses basic comment', () {
      final c = PostComment.fromJson({
        'id': 'c1',
        'post_id': 'p1',
        'user_id': 'u1',
        'content': '好文章',
        'created_at': '2024-06-01T13:00:00.000Z',
        'profiles': null,
      });
      expect(c.id, 'c1');
      expect(c.content, '好文章');
      expect(c.author, isNull);
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
      final json = Map<String, dynamic>.from(baseConv)..['type'] = 'group';
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
      'type': 'like',
      'post_id': 'p1',
      'comment_id': null,
      'is_read': false,
      'created_at': '2024-06-01T10:00:00.000Z',
      'profiles': null,
    };

    test('parses all fields', () {
      final n = AppNotification.fromJson(baseNotif);
      expect(n.id, 'n1');
      expect(n.type, 'like');
      expect(n.postId, 'p1');
      expect(n.isRead, false);
    });

    test('handles is_read=true', () {
      final json = Map<String, dynamic>.from(baseNotif)..['is_read'] = true;
      expect(AppNotification.fromJson(json).isRead, true);
    });

    test('handles null post_id', () {
      final json = Map<String, dynamic>.from(baseNotif)..['post_id'] = null;
      expect(AppNotification.fromJson(json).postId, isNull);
    });
  });

  // ─── Message reply metadata ──────────────────────────────────────────────

  group('Message reply metadata', () {
    Map<String, dynamic> messageJson({
      required String type,
      String? content,
      String? mediaUrl,
      Map<String, dynamic>? payload,
    }) => {
      'id': 'm1',
      'conversation_id': 'cv1',
      'sender_id': 'u1',
      'content': content,
      'message_type': type,
      'media_url': mediaUrl,
      'is_deleted': false,
      'created_at': '2026-07-10T08:30:00.000Z',
      'payload': payload,
      'profiles': {
        'id': 'u1',
        'username': 'alice',
        'display_name': 'Alice',
        'avatar_url': null,
        'bio': null,
        'followers_count': 0,
        'following_count': 0,
        'posts_count': 0,
        'created_at': '2024-01-01T00:00:00.000Z',
      },
    };

    test('video reply stores its real thumbnail, size and time', () {
      final video = Message.fromJson(
        messageJson(
          type: 'video',
          mediaUrl: 'https://example.com/video.mp4',
          payload: {
            'size': 10 * 1024 * 1024,
            'thumbnail': 'https://example.com/video-thumb.jpg',
          },
        ),
      );

      final reply = video.toReplyMetadata();
      expect(reply['sender'], 'Alice');
      expect(reply['type'], 'video');
      expect(reply['thumb'], 'https://example.com/video-thumb.jpg');
      expect(reply['preview'], contains('视频'));
      expect(reply['preview'], contains('10.0 MB'));
      expect(reply['sent_at'], isNotNull);
    });

    test('file reply identifies the exact file name and size', () {
      final file = Message.fromJson(
        messageJson(
          type: 'file',
          content: 'meeting-notes.pdf',
          mediaUrl: 'https://example.com/meeting-notes.pdf',
          payload: {
            'name': 'meeting-notes.pdf',
            'size': 2 * 1024 * 1024,
            'mime': 'application/pdf',
          },
        ),
      );

      final reply = file.toReplyMetadata();
      expect(file.displayContent, '[文件] meeting-notes.pdf');
      expect(reply['file_name'], 'meeting-notes.pdf');
      expect(reply['preview'], contains('meeting-notes.pdf'));
      expect(reply['preview'], contains('2.0 MB'));
    });

    test('reply getters remain compatible with stored payload maps', () {
      final message = Message.fromJson(
        messageJson(
          type: 'text',
          content: '收到',
          payload: {
            'reply_to': {
              'id': 'video-1',
              'sender': 'Bob',
              'preview': '视频 · 8.0 MB · 17:20',
              'type': 'video',
              'thumb': 'https://example.com/thumb.jpg',
              'size': 8 * 1024 * 1024,
              'sent_at': '2026-07-10T08:20:00.000Z',
            },
          },
        ),
      );

      expect(message.replyToId, 'video-1');
      expect(message.replyToSender, 'Bob');
      expect(message.replyToType, 'video');
      expect(message.replyToThumb, 'https://example.com/thumb.jpg');
      expect(message.replyToSize, 8 * 1024 * 1024);
      expect(message.replyToSentAt, isNotNull);
    });
  });

  // ─── Topic aggregation logic ───────────────────────────────────────────────

  group('Topic frequency aggregation', () {
    // Mirrors the logic in _TopicsTab._loadHotTopics
    List<String> aggregateTopics(
      List<Map<String, dynamic>> rows, {
      int take = 30,
    }) {
      final Map<String, int> freq = {};
      for (final row in rows) {
        final tags =
            (row['topics'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [];
        for (final tag in tags) {
          freq[tag] = (freq[tag] ?? 0) + 1;
        }
      }
      final sorted = freq.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return sorted.take(take).map((e) => e.key).toList();
    }

    test('returns topics sorted by frequency', () {
      final rows = [
        {
          'topics': ['信仰', '祷告'],
        },
        {
          'topics': ['信仰', '圣经'],
        },
        {
          'topics': ['信仰'],
        },
        {
          'topics': ['祷告'],
        },
      ];
      final result = aggregateTopics(rows);
      expect(result.first, '信仰'); // appears 3 times
      expect(result[1], '祷告'); // appears 2 times
      expect(result[2], '圣经'); // appears 1 time
    });

    test('handles null topics', () {
      final rows = [
        {'topics': null},
        {
          'topics': ['福音'],
        },
      ];
      expect(aggregateTopics(rows), ['福音']);
    });

    test('respects take limit', () {
      final rows = List.generate(
        50,
        (i) => {
          'topics': ['topic_$i'],
        },
      );
      expect(aggregateTopics(rows, take: 10).length, 10);
    });

    test('empty input returns empty list', () {
      expect(aggregateTopics([]), isEmpty);
    });
  });
}
