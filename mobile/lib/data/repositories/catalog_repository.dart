import '../../domain/entities/entities.dart';
import 'base.dart';

class CatalogRepository extends BaseRepository {
  CatalogRepository(super.api);

  Future<List<Plant>> plants() => call(() async => list((await dio.get('/plants')).data, Plant.fromJson));
  Future<List<Disease>> diseases({String? q, String? plantId}) => call(() async {
        final path = plantId != null ? '/plants/$plantId/diseases' : '/diseases';
        return list((await dio.get(path, queryParameters: {if (q != null && q.isNotEmpty) 'q': q})).data, Disease.fromJson);
      });
  Future<Disease> disease(String id) => call(() async => Disease.fromJson((await dio.get('/diseases/$id')).data));
  Future<List<Medicine>> medicines() => call(() async => list((await dio.get('/medicines')).data, Medicine.fromJson));

  // Admin
  Future<void> savePlant(Map<String, dynamic> data, {String? id}) =>
      call(() => id == null ? dio.post('/plants', data: data) : dio.put('/plants/$id', data: data));
  Future<void> deletePlant(String id) => call(() => dio.delete('/plants/$id'));
  Future<void> saveDisease(Map<String, dynamic> data, {String? id}) =>
      call(() => id == null ? dio.post('/diseases', data: data) : dio.put('/diseases/$id', data: data));
  Future<void> deleteDisease(String id) => call(() => dio.delete('/diseases/$id'));
  Future<void> saveMedicine(Map<String, dynamic> data, {String? id}) =>
      call(() => id == null ? dio.post('/medicines', data: data) : dio.put('/medicines/$id', data: data));
  Future<void> deleteMedicine(String id) => call(() => dio.delete('/medicines/$id'));
  Future<void> linkMedicines(String diseaseId, List<Map<String, dynamic>> items) =>
      call(() => dio.put('/diseases/$diseaseId/medicines', data: {'items': items}));
}
