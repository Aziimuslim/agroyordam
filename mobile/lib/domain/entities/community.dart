import '../../core/utils/format.dart';
import 'user.dart';

class Post {
  Post({
    required this.id,
    required this.author,
    required this.title,
    this.content,
    this.imageUrl,
    List<String>? imageUrls,
    this.category,
    this.diagnosisId,
    this.likes = 0,
    this.comments = 0,
    this.likedByMe = false,
    this.createdAt,
  }) : imageUrls = imageUrls ?? [if (imageUrl != null) imageUrl];
  final String id, title;

  /// TZ S12: 0–5 rasm (birinchisi [imageUrl]).
  final List<String> imageUrls;
  final AppUser author;
  final String? content, imageUrl, category, diagnosisId;
  final int likes, comments;
  final bool likedByMe;
  final DateTime? createdAt;

  factory Post.fromJson(Map<String, dynamic> j) => Post(
        id: j['id'],
        author: AppUser.fromJson(j['author']),
        title: j['title'],
        content: j['content'],
        imageUrl: j['image_url'],
        imageUrls: j['image_urls'] == null ? null : [for (final u in j['image_urls'] as List) u as String],
        category: j['category'],
        diagnosisId: j['diagnosis_id'],
        likes: j['likes_count'] ?? 0,
        comments: j['comments_count'] ?? 0,
        likedByMe: j['liked_by_me'] ?? false,
        createdAt: parseDate(j['created_at']),
      );

  Post copyWith({bool? likedByMe, int? likes, int? comments}) => Post(
        id: id,
        author: author,
        title: title,
        content: content,
        imageUrl: imageUrl,
        imageUrls: imageUrls,
        category: category,
        diagnosisId: diagnosisId,
        likes: likes ?? this.likes,
        comments: comments ?? this.comments,
        likedByMe: likedByMe ?? this.likedByMe,
        createdAt: createdAt,
      );
}

class Comment {
  Comment({
    required this.id,
    required this.author,
    required this.content,
    this.parentId,
    this.replyToId,
    this.replyToName,
    this.deleted = false,
    this.edited = false,
    this.createdAt,
  });
  final String id, content;

  /// O'chirilgan izohda (javoblari saqlanadi) muallif yo'q.
  final AppUser? author;

  /// TZ S13: javob — ildiz izoh [parentId], aynan javob berilgan izoh [replyToId].
  final String? parentId, replyToId, replyToName;
  final bool deleted, edited;
  final DateTime? createdAt;

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
        id: j['id'],
        author: j['author'] == null ? null : AppUser.fromJson(j['author']),
        content: j['content'] ?? '',
        parentId: j['parent_id'],
        replyToId: j['reply_to_id'],
        replyToName: j['reply_to_name'],
        deleted: j['deleted'] ?? false,
        edited: j['edited'] ?? false,
        createdAt: parseDate(j['created_at']),
      );
}
