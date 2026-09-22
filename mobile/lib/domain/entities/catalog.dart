class Plant {
  Plant({required this.id, required this.name, this.scientificName, this.description, this.careInfo, this.imageUrl});
  final String id, name;
  final String? scientificName, description, careInfo, imageUrl;

  factory Plant.fromJson(Map<String, dynamic> j) => Plant(
        id: j['id'],
        name: j['name'],
        scientificName: j['scientific_name'],
        description: j['description'],
        careInfo: j['care_info'],
        imageUrl: j['image_url'],
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
  });
  final String id, name;
  final String? activeIngredient, description, usage, precautions, manufacturer, recommendation;

  factory Medicine.fromJson(Map<String, dynamic> j) => Medicine(
        id: j['id'],
        name: j['name'],
        activeIngredient: j['active_ingredient'],
        description: j['description'],
        usage: j['usage'],
        precautions: j['precautions'],
        manufacturer: j['manufacturer'],
        recommendation: j['recommendation'],
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
  });
  final String id, name;
  final String? plantId, plantName, aiLabel, description, symptoms, causes, treatment, prevention, riskLevel;
  final List<Medicine> medicines;

  factory Disease.fromJson(Map<String, dynamic> j) => Disease(
        id: j['id'],
        name: j['name'],
        plantId: j['plant_id'],
        plantName: j['plant_name'],
        aiLabel: j['ai_label'],
        description: j['description'],
        symptoms: j['symptoms'],
        causes: j['causes'],
        treatment: j['treatment'],
        prevention: j['prevention'],
        riskLevel: j['risk_level'],
        medicines: [for (final m in (j['medicines'] as List? ?? [])) Medicine.fromJson(m)],
      );
}
