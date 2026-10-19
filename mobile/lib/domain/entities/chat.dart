import '../../core/utils/format.dart';
import 'user.dart';

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.senderId,
    this.content,
    this.imageUrl,
    List<String>? imageUrls,
    this.isRead = false,
    this.delivered = false,
    this.createdAt,
  }) : imageUrls = imageUrls ?? [if (imageUrl != null) imageUrl];
  final String id, senderId;
  final String? content, imageUrl;

  /// TZ S16: bitta xabarda 5 tagacha rasm.
  final List<String> imageUrls;
  final bool isRead;

  /// Qabul qiluvchi qurilmasi oldi — faqat server event bilan.
  final bool delivered;
  final DateTime? createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'],
        senderId: j['sender_id'],
        content: j['content'],
        imageUrl: j['image_url'],
        imageUrls: j['image_urls'] == null ? null : [for (final u in j['image_urls'] as List) u as String],
        isRead: j['is_read'] ?? false,
        delivered: j['delivered'] ?? (j['is_read'] ?? false),
        createdAt: parseDate(j['created_at']),
      );

  ChatMessage copyWith({bool? isRead, bool? delivered}) => ChatMessage(
        id: id,
        senderId: senderId,
        content: content,
        imageUrl: imageUrl,
        imageUrls: imageUrls,
        isRead: isRead ?? this.isRead,
        delivered: delivered ?? this.delivered,
        createdAt: createdAt,
      );
}

class Conversation {
  Conversation({required this.id, required this.participants, this.lastMessage, this.unread = 0, this.blocked = false, this.muted = false});
  final String id;
  final List<AppUser> participants;
  final ChatMessage? lastMessage;
  final int unread;

  /// A08: bloklash bor — yozib bo'lmaydi.
  final bool blocked;

  /// TZ S15: ovozsiz — bu suhbatdan bildirishnoma kelmaydi.
  final bool muted;

  AppUser? get other => participants.isEmpty ? null : participants.first;

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: j['id'],
        participants: [for (final u in (j['participants'] as List? ?? [])) AppUser.fromJson(u)],
        lastMessage: j['last_message'] == null ? null : ChatMessage.fromJson(j['last_message']),
        unread: j['unread_count'] ?? 0,
        blocked: j['blocked'] ?? false,
        muted: j['muted'] ?? false,
      );
}

class AIMessage {
  AIMessage({this.id, required this.role, required this.content, this.conversationId, this.replyToId, this.status = 'done', this.createdAt});
  final String? id, conversationId, replyToId;
  final String role, content;

  /// done | partial — to'xtatilgan/uzilgan javob tugallangan deb ko'rsatilmaydi (TZ S10).
  final String status;
  final DateTime? createdAt;
  bool get isUser => role == 'user';
  bool get isPartial => status == 'partial';

  factory AIMessage.fromJson(Map<String, dynamic> j) => AIMessage(
        id: j['id'],
        role: j['role'],
        content: j['content'],
        conversationId: j['conversation_id'],
        replyToId: j['reply_to_id'],
        status: j['status'] ?? 'done',
        createdAt: parseDate(j['created_at']),
      );
}

/// TZ S09: alohida AI suhbat.
class AIConversation {
  AIConversation({required this.id, required this.title, this.lastMessage, this.messageCount = 0, this.updatedAt});
  final String id, title;
  final String? lastMessage;
  final int messageCount;
  final DateTime? updatedAt;

  factory AIConversation.fromJson(Map<String, dynamic> j) => AIConversation(
        id: j['id'],
        title: j['title'],
        lastMessage: j['last_message'],
        messageCount: j['message_count'] ?? 0,
        updatedAt: parseDate(j['updated_at']),
      );
}

/// AI oqim hodisasi: user (savol saqlandi) | delta (javob bo'lagi) | done (javob tugadi) | error.
class AIStreamEvent {
  AIStreamEvent(this.type, this.data);
  final String type;
  final Map<String, dynamic> data;
}
