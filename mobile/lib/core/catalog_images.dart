/// Katalog rasmlari ilova ichida (assets/catalog, internetsiz ham ochiladi).
/// Manba — PlantVillage dataseti: AI modeli aynan shu rasmlarda o'qitilgan. Fayl nomi = kasallik sinfi (ai_label).
class CatalogImages {
  static const _labels = {
    'Apple_Black_rot', 'Apple_Cedar_rust', 'Apple_Scab', 'Apple_healthy', 'Cherry_Powdery_mildew', 'Cherry_healthy',
    'Corn_Common_rust', 'Corn_Gray_leaf_spot', 'Corn_Northern_Leaf_Blight', 'Corn_healthy', 'Grape_Black_rot', 'Grape_Esca',
    'Grape_Leaf_blight', 'Grape_healthy', 'Peach_Bacterial_spot', 'Peach_healthy', 'Pepper_Bacterial_spot', 'Pepper_healthy',
    'Potato_Early_blight', 'Potato_Late_blight', 'Potato_healthy', 'Squash_Powdery_mildew', 'Strawberry_Leaf_scorch',
    'Strawberry_healthy', 'Tomato_Bacterial_spot', 'Tomato_Early_blight', 'Tomato_Late_blight', 'Tomato_Leaf_Mold',
    'Tomato_Septoria_leaf_spot', 'Tomato_Spider_mites', 'Tomato_Target_Spot', 'Tomato_Yellow_Leaf_Curl_Virus',
    'Tomato_healthy', 'Tomato_mosaic_virus',
  };

  /// O'zbekcha ekin nomi → sinf prefiksi (ai-service/app/models/labels.py bilan bir xil).
  static const plantPrefix = {
    'Pomidor': 'Tomato', 'Kartoshka': 'Potato', 'Bolgar qalampiri': 'Pepper', 'Uzum': 'Grape', 'Olma': 'Apple',
    "Makkajo'xori": 'Corn', 'Shaftoli': 'Peach', 'Olcha': 'Cherry', 'Qulupnay': 'Strawberry', 'Qovoq': 'Squash',
    'Bodring': 'Cucumber',
  };

  /// Kasallik rasmi (asset yo'li) yoki null.
  static String? disease(String? aiLabel) => aiLabel != null && _labels.contains(aiLabel) ? 'assets/catalog/$aiLabel.jpg' : null;

  /// Ekinning sog'lom barg rasmi yoki null.
  static String? plant(String? plantName) {
    final p = plantPrefix[plantName];
    return p == null ? null : disease('${p}_healthy');
  }
}
