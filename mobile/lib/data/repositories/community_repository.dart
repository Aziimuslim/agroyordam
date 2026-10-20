import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/i18n/i18n.dart';
import '../../core/network/api_exception.dart';
import '../../domain/entities/entities.dart';
import 'base.dart';

class CommunityRepository extends BaseRepository {
  CommunityRepository(super.api);

  Future<List<Post>> posts({String? category, String? userId, String feed = 'all', bool unanswered = false}) => call(() async => list(
      (await dio.get('/posts', queryParameters: {
        'feed': feed,
        if (unanswered) 'unanswered': true,
        if (category != null) 'category': category,
        if (userId != null) 'user_id': userId,
      }))
          .data,
      Post.fromJson));
  Future<Post> post(String id) => call(() async => Post.fromJson((await dio.get('/posts/$id')).data));
  Future<Post> createPost(Map<String, dynamic> data) => call(() async => Post.fromJson((await dio.post('/posts', data: data)).data));
  Future<void> deletePost(String id) => call(() => dio.delete('/posts/$id'));
  Future<Post> updatePost(String id, Map<String, dynamic> data) => call(() async => Post.fromJson((await dio.put('/posts/$id', data: data)).data));
  Future<Post> like(String id, bool like) =>
      call(() async => Post.fromJson((like ? await dio.post('/posts/$id/like') : await dio.delete('/posts/$id/like')).data));
  Future<List<Comment>> comments(String id) => call(() async => list((await dio.get('/posts/$id/comments')).data, Comment.fromJson));
  Future<void> addComment(String id, String text, {String? replyTo}) =>
      call(() => dio.post('/posts/$id/comments', data: {'content': text, if (replyTo != null) 'reply_to_id': replyTo}));
  Future<void> editComment(String id, String text) => call(() => dio.put('/comments/$id', data: {'content': text}));
  Future<void> deleteComment(String id) => call(() => dio.delete('/comments/$id'));
  Future<void> report({String? postId, String? commentId, String? messageId, required String reason, String? description}) =>
      call(() => dio.post('/reports', data: {
            if (postId != null) 'post_id': postId,
            if (commentId != null) 'comment_id': commentId,
            if (messageId != null) 'message_id': messageId,
            'reason': reason,
            if (description != null) 'description': description,
          }));

  // A02 Saqlanganlar
  Future<List<Bookmark>> bookmarks() => call(() async => list((await dio.get('/bookmarks')).data, Bookmark.fromJson));
  Future<void> addBookmark(String kind, String targetId) => call(() => dio.post('/bookmarks', data: {'kind': kind, 'target_id': targetId}));
  Future<void> removeBookmark(String kind, String targetId) => call(() => dio.delete('/bookmarks/$kind/$targetId'));

  // A07 qidiruv, A08 bloklash
  Future<List<AppUser>> searchUsers(String q) =>
      call(() async => list((await dio.get('/users/search', queryParameters: {'q': q})).data, AppUser.fromJson));
  Future<void> block(String userId, bool block) => call(() => block ? dio.post('/users/$userId/block') : dio.delete('/users/$userId/block'));
  Future<List<AppUser>> blocks() => call(() async => list((await dio.get('/users/me/blocks')).data, AppUser.fromJson));

  Future<UserProfile> profile(String userId) => call(() async => UserProfile.fromJson((await dio.get('/users/$userId')).data));
  Future<void> follow(String userId, bool follow) =>
      call(() => follow ? dio.post('/users/$userId/follow') : dio.delete('/users/$userId/follow'));

  // Chat
  Future<List<Conversation>> conversations() => call(() async => list((await dio.get('/conversations')).data, Conversation.fromJson));
  Future<Conversation> startConversation(String userId) =>
      call(() async => Conversation.fromJson((await dio.post('/conversations', data: {'user_id': userId})).data));
  /// Oxirgi [limit] ta xabar; [before] — shu xabardan oldingilari (eski xabarlar sahifasi).
  Future<List<ChatMessage>> messages(String convId, {int limit = 50, String? before}) => call(() async => list(
      (await dio.get('/conversations/$convId/messages', queryParameters: {'limit': limit, if (before != null) 'before': before})).data,
      ChatMessage.fromJson));
  Future<ChatMessage> send(String convId, String text, {List<String> images = const []}) => call(() async => ChatMessage.fromJson(
      (await dio.post('/conversations/$convId/messages', data: {'content': text, if (images.isNotEmpty) 'image_urls': images})).data));
  Future<void> markRead(String messageId) => call(() => dio.put('/messages/$messageId/read'));
  // TZ S15 suhbat menyusi
  Future<void> readConversation(String convId) => call(() => dio.put('/conversations/$convId/read'));
  Future<Conversation> muteConversation(String convId, bool muted) =>
      call(() async => Conversation.fromJson((await dio.put('/conversations/$convId/mute', data: {'muted': muted})).data));
  Future<void> hideConversation(String convId) => call(() => dio.delete('/conversations/$convId'));

  // AI Yordamchi (TZ S09/S10)
  Future<List<AIConversation>> aiConversations({String? q}) => call(() async =>
      list((await dio.get('/ai/conversations', queryParameters: {if (q != null && q.trim().isNotEmpty) 'q': q.trim()})).data, AIConversation.fromJson));
  Future<List<AIMessage>> aiMessages(String convId) => call(() async => list((await dio.get('/ai/conversations/$convId/messages')).data, AIMessage.fromJson));
  Future<void> aiRename(String convId, String title) => call(() => dio.patch('/ai/conversations/$convId', data: {'title': title}));
  Future<void> aiDelete(String convId) => call(() => dio.delete('/ai/conversations/$convId'));

  /// Savol yuborish — javob oqim (SSE) bilan keladi. [cancel] — "To'xtatish": server qisman javobni saqlaydi.
  Stream<AIStreamEvent> aiSend(String text, {String? conversationId, CancelToken? cancel}) =>
      _sse('/ai/messages', {'message': text, if (conversationId != null) 'conversation_id': conversationId}, cancel);

  /// Qayta javob — aynan shu savolga bog'langan javob almashtiriladi (limitdan hisoblanmaydi).
  Stream<AIStreamEvent> aiRetry(String messageId, {CancelToken? cancel}) => _sse('/ai/messages/$messageId/retry', null, cancel);

  Stream<AIStreamEvent> _sse(String path, Object? body, CancelToken? cancel) async* {
    final Response<ResponseBody> r;
    try {
      r = await dio.post<ResponseBody>(path,
          data: body,
          cancelToken: cancel,
          options: Options(responseType: ResponseType.stream, headers: {'Accept': 'text/event-stream'}, validateStatus: (_) => true));
    } catch (e) {
      throw ApiException.from(e);
    }
    final lines = r.data!.stream.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter());
    final code = r.statusCode ?? 0;
    if (code >= 400) {
      final raw = await lines.join('\n');
      String msg = tr("So'rov bajarilmadi");
      try {
        final d = jsonDecode(raw)['detail'];
        if (d is String) msg = tr(d);
        if (d is List && d.isNotEmpty) msg = '${(d.first as Map)['msg']}'.replaceFirst('Value error, ', '');
      } catch (_) {}
      throw ApiException(msg, statusCode: code);
    }
    String? event;
    final data = StringBuffer();
    await for (final line in lines) {
      if (line.isEmpty) {
        if (event != null && data.isNotEmpty) yield AIStreamEvent(event, Map<String, dynamic>.from(jsonDecode(data.toString())));
        event = null;
        data.clear();
      } else if (line.startsWith('event: ')) {
        event = line.substring(7);
      } else if (line.startsWith('data: ')) {
        data.write(line.substring(6));
      }
    }
  }

  // Bildirishnomalar
  Future<List<AppNotification>> notifications() =>
      call(() async => list((await dio.get('/notifications')).data, AppNotification.fromJson));
  Future<Map<String, bool>> notificationSettings() =>
      call(() async => Map<String, bool>.from((await dio.get('/users/me/notification-settings')).data as Map));
  Future<Map<String, bool>> saveNotificationSettings(Map<String, bool> v) =>
      call(() async => Map<String, bool>.from((await dio.put('/users/me/notification-settings', data: v)).data as Map));
  Future<void> readAll() => call(() => dio.put('/notifications/read-all'));
  Future<void> readOne(String id) => call(() => dio.put('/notifications/$id/read'));
}
