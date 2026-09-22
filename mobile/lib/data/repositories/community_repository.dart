import '../../domain/entities/entities.dart';
import 'base.dart';

class CommunityRepository extends BaseRepository {
  CommunityRepository(super.api);

  Future<List<Post>> posts({String? category, String? userId, String feed = 'all'}) => call(() async => list(
      (await dio.get('/posts', queryParameters: {
        'feed': feed,
        if (category != null) 'category': category,
        if (userId != null) 'user_id': userId,
      }))
          .data,
      Post.fromJson));
  Future<Post> post(String id) => call(() async => Post.fromJson((await dio.get('/posts/$id')).data));
  Future<Post> createPost(Map<String, dynamic> data) => call(() async => Post.fromJson((await dio.post('/posts', data: data)).data));
  Future<void> deletePost(String id) => call(() => dio.delete('/posts/$id'));
  Future<Post> like(String id, bool like) =>
      call(() async => Post.fromJson((like ? await dio.post('/posts/$id/like') : await dio.delete('/posts/$id/like')).data));
  Future<List<Comment>> comments(String id) => call(() async => list((await dio.get('/posts/$id/comments')).data, Comment.fromJson));
  Future<void> addComment(String id, String text) => call(() => dio.post('/posts/$id/comments', data: {'content': text}));
  Future<void> deleteComment(String id) => call(() => dio.delete('/comments/$id'));
  Future<void> report({String? postId, String? commentId, required String reason}) =>
      call(() => dio.post('/reports', data: {'post_id': postId, 'comment_id': commentId, 'reason': reason}));

  Future<UserProfile> profile(String userId) => call(() async => UserProfile.fromJson((await dio.get('/users/$userId')).data));
  Future<void> follow(String userId, bool follow) =>
      call(() => follow ? dio.post('/users/$userId/follow') : dio.delete('/users/$userId/follow'));

  // Chat
  Future<List<Conversation>> conversations() => call(() async => list((await dio.get('/conversations')).data, Conversation.fromJson));
  Future<Conversation> startConversation(String userId) =>
      call(() async => Conversation.fromJson((await dio.post('/conversations', data: {'user_id': userId})).data));
  Future<List<ChatMessage>> messages(String convId) =>
      call(() async => list((await dio.get('/conversations/$convId/messages')).data, ChatMessage.fromJson));
  Future<ChatMessage> send(String convId, String text) =>
      call(() async => ChatMessage.fromJson((await dio.post('/conversations/$convId/messages', data: {'content': text})).data));
  Future<void> markRead(String messageId) => call(() => dio.put('/messages/$messageId/read'));

  // AI Yordamchi
  Future<List<AIMessage>> aiHistory() => call(() async => list((await dio.get('/ai/chat/history')).data, AIMessage.fromJson));
  Future<AIMessage> aiAsk(String text) =>
      call(() async => AIMessage.fromJson((await dio.post('/ai/chat', data: {'message': text})).data['reply']));

  // Bildirishnomalar
  Future<List<AppNotification>> notifications() =>
      call(() async => list((await dio.get('/notifications')).data, AppNotification.fromJson));
  Future<void> readAll() => call(() => dio.put('/notifications/read-all'));
}
