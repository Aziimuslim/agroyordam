/// A02 Saqlangan element. `exists=false` — obyekt o'chirilgan (yoki muallif bloklangan): placeholder ko'rsatiladi.
class Bookmark {
  Bookmark({required this.kind, required this.targetId, this.exists = true, this.title, this.subtitle, this.imageUrl, this.aiLabel, this.createdAt});
  final String kind, targetId;
  final bool exists;
  final String? title, subtitle, imageUrl, aiLabel;
  final DateTime? createdAt;

  String get key => '$kind:$targetId';

  /// Ochiladigan sahifa (S13/S20/S21/S22).
  String get route => switch (kind) {
        'post' => '/community/$targetId',
        'plant' => '/catalog/plant/$targetId',
        'disease' => '/catalog/disease/$targetId',
        _ => '/catalog/medicine/$targetId',
      };

  factory Bookmark.fromJson(Map<String, dynamic> j) => Bookmark(
        kind: j['kind'],
        targetId: j['target_id'],
        exists: j['exists'] ?? true,
        title: j['title'],
        subtitle: j['subtitle'],
        imageUrl: j['image_url'],
        aiLabel: j['ai_label'],
        createdAt: j['created_at'] == null ? null : DateTime.tryParse(j['created_at']),
      );
}
