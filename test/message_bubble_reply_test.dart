import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_app/models/message.dart';
import 'package:social_app/widgets/message_bubble.dart';

Message _message({
  required String id,
  required String type,
  String? content,
  String? mediaUrl,
  Map<String, dynamic>? payload,
}) => Message(
  id: id,
  conversationId: 'conversation-1',
  senderId: 'user-1',
  content: content,
  messageType: type,
  mediaUrl: mediaUrl,
  createdAt: DateTime.utc(2026, 7, 10, 8, 30),
  payload: payload,
);

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('old generic file reply resolves the exact source file', (
    tester,
  ) async {
    final source = _message(
      id: 'file-1',
      type: 'file',
      content: 'meeting-notes.pdf',
      mediaUrl: 'https://example.com/meeting-notes.pdf',
      payload: {
        'name': 'meeting-notes.pdf',
        'size': 2 * 1024 * 1024,
        'mime': 'application/pdf',
      },
    );
    final reply = _message(
      id: 'reply-1',
      type: 'text',
      content: '收到',
      payload: {
        'reply_to': {
          'id': 'file-1',
          'sender': 'Alice',
          'preview': '[文件]',
          'type': 'file',
        },
      },
    );

    await tester.pumpWidget(
      _app(MessageBubble(message: reply, replySource: source, isMe: false)),
    );

    expect(find.textContaining('meeting-notes.pdf'), findsOneWidget);
    expect(find.textContaining('2.0 MB'), findsOneWidget);
    expect(find.byIcon(Icons.insert_drive_file_rounded), findsOneWidget);
  });

  testWidgets('a file sent as a reply keeps the quoted message visible', (
    tester,
  ) async {
    final replyFile = _message(
      id: 'file-reply',
      type: 'file',
      content: 'answer.docx',
      mediaUrl: 'https://example.com/answer.docx',
      payload: {
        'name': 'answer.docx',
        'size': 1024,
        'mime':
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'reply_to': {
          'id': 'video-1',
          'sender': 'Bob',
          'preview': '视频 · 8.0 MB · 17:20',
          'type': 'video',
          'size': 8 * 1024 * 1024,
          'sent_at': '2026-07-10T08:20:00.000Z',
        },
      },
    );

    await tester.pumpWidget(
      _app(MessageBubble(message: replyFile, isMe: true)),
    );

    expect(find.text('Bob'), findsOneWidget);
    expect(find.textContaining('视频 · 8.0 MB'), findsOneWidget);
    expect(find.text('answer.docx'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_fill_rounded), findsOneWidget);
  });
}
