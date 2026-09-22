import '../../core/utils/format.dart';
import 'user.dart';

class Post {
  Post({
    required this.id,
    required this.author,
    required this.title,
    this.content,
    this.imageUrl,
    this.category,
    this.diagnosisId,
    this.likes = 0,
    this.comments = 0,
    this.likedByMe = false,
    this.createdAt,
  });
  final String id, title;
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
        category: j['category'],
        diagnosisId: j['diagnosis_id'],
        likes: j['likes_count'] ?? 0,
        comments: j['comments_count'] ?? 0,
        likedByMe: j['liked_by_me'] ?? false,
        createdAt: parseDate(j['created_at']),
      );
}

class Comment {
  Comment({required this.id, required this.author, required this.content, this.createdAt});
  final String id, content;
  final AppUser author;
  final DateTime? createdAt;

  factory Comment.fromJson(Map<String, dynamic> j) =>
      Comment(id: j['id'], author: AppUser.fromJson(j['author']), content: j['content'], createdAt: parseDate(j['created_at']));
}
