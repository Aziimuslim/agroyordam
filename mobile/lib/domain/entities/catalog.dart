import '../../core/utils/format.dart';

class Plant {
  Plant({required this.id, required this.name, this.scientificName, this.description, this.careInfo, this.imageUrl, this.category});
  final String id, name;
  final String? scientificName, description, careInfo, imageUrl;

  /// vegetable | fruit | vine | grain | berry | melon (null — tasniflanmagan)
  final String? category;

  factory Plant.fromJson(Map<String, dynamic> j) => Plant(
        id: j['id'],
        name: j['name'],
        scientificName: j['scientific_name'],
        description: j['description'],
        careInfo: j['care_info'],
        imageUrl: j['image_url'],
        category: j['category'],
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'scientific_name': scientificName,
        'description': description,
        'care_info': careInfo,
      };
}

class Medicine {
  Medicine({
    required this.id,
    required this.name,
    this.activeIngredient,
    this.description,
    this.usage,
    this.precautions,
    this.manufacturer,
    this.recommendation,
    this.category,
    this.kind,
    this.labelVerified = false,
    this.source,
    this.updatedAt,
  });
  final String id, name;
  final String? activeIngredient, description, usage, precautions, manufacturer, recommendation;

  /// fungicide | insecticide | acaricide | biological | other
  final String? category;

  /// active (faol modda) | product (tayyor mahsulot) | mixture
  final String? kind;

  /// Me'yor aniq mahsulot yorlig'i bo'yicha tasdiqlangan. false — doza dehqonga ko'rsatilmaydi (TZ S22).
  final bool labelVerified;
  final String? source;
  final DateTime? updatedAt;

  factory Medicine.fromJson(Map<String, dynamic> j) => Medicine(
        id: j['id'],
        name: j['name'],
        activeIngredient: j['active_ingredient'],
        description: j['description'],
        usage: j['usage'],
        precautions: j['precautions'],
        manufacturer: j['manufacturer'],
        recommendation: j['recommendation'],
        category: j['category'],
        kind: j['kind'],
        labelVerified: j['label_verified'] ?? false,
        source: j['source'],
        updatedAt: parseDate(j['updated_at']),
      );
}

class Disease {
  Disease({
    required this.id,
    required this.name,
    this.plantId,
    this.plantName,
    this.aiLabel,
    this.description,
    this.symptoms,
    this.causes,
    this.treatment,
    this.prevention,
    this.riskLevel,
    this.medicines = const [],
    this.recommendation,
    this.imageUrl,
    this.source,
    this.updatedAt,
  });
  final String id, name;
  final String? plantId, plantName, aiLabel, description, symptoms, causes, treatment, prevention, riskLevel, imageUrl;
  final String? source;
  final DateTime? updatedAt;

  /// Dori sahifasida: shu kasallikka qarshi me'yor.
  final String? recommendation;
  final List<Medicine> medicines;

  factory Disease.fromJson(Map<String, dynamic> j) => Disease(
        id: j['id'],
        name: j['name'],
        plantId: j['plant_id'],
        plantName: j['plant_name'],
        aiLabel: j['ai_label'],
        imageUrl: j['image_url'],
        description: j['description'],
        symptoms: j['symptoms'],
        causes: j['causes'],
        treatment: j['treatment'],
        prevention: j['prevention'],
        riskLevel: j['risk_level'],
        medicines: [for (final m in (j['medicines'] as List? ?? [])) Medicine.fromJson(m)],
        recommendation: j['recommendation'],
        source: j['source'],
        updatedAt: parseDate(j['updated_at']),
      );
}
