import '../../core/utils/format.dart';
import 'user.dart';

class ChatMessage {
  ChatMessage({required this.id, required this.senderId, this.content, this.imageUrl, this.isRead = false, this.createdAt});
  final String id, senderId;
  final String? content, imageUrl;
  final bool isRead;
  final DateTime? createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'],
        senderId: j['sender_id'],
        content: j['content'],
        imageUrl: j['image_url'],
        isRead: j['is_read'] ?? false,
        createdAt: parseDate(j['created_at']),
      );
}

class Conversation {
  Conversation({required this.id, required this.participants, this.lastMessage, this.unread = 0});
  final String id;
  final List<AppUser> participants;
  final ChatMessage? lastMessage;
  final int unread;

  AppUser? get other => participants.isEmpty ? null : participants.first;

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: j['id'],
        participants: [for (final u in (j['participants'] as List? ?? [])) AppUser.fromJson(u)],
        lastMessage: j['last_message'] == null ? null : ChatMessage.fromJson(j['last_message']),
        unread: j['unread_count'] ?? 0,
      );
}

class AIMessage {
  AIMessage({required this.role, required this.content, this.createdAt});
  final String role, content;
  final DateTime? createdAt;
  bool get isUser => role == 'user';

  factory AIMessage.fromJson(Map<String, dynamic> j) =>
      AIMessage(role: j['role'], content: j['content'], createdAt: parseDate(j['created_at']));
}
