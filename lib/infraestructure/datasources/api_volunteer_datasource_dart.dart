import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:voluntariado_desktop_app/domain/volunteer/entities/volunteer.dart';

class ApiService {
  static String get _base {
    final apiUrl = dotenv.env['API_URL'];
    if (apiUrl == null || apiUrl.isEmpty) {
      throw Exception('API_URL no está definida en .env');
    }
    return apiUrl;
  }

  static Map<String, String> get _jsonHeaders => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  static Future<List<dynamic>> _getList(String path) async {
    final response = await http.get(Uri.parse('$_base$path'), headers: _jsonHeaders);
    if (response.statusCode != 200) {
      throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is List) return decoded;
    throw Exception('Se esperaba una lista');
  }

  static Future<Map<String, dynamic>> _getOne(String path) async {
    final response = await http.get(Uri.parse('$_base$path'), headers: _jsonHeaders);
    if (response.statusCode != 200) {
      throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$_base$path'),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('$_base$path'),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<void> _delete(String path) async {
    final response = await http.delete(Uri.parse('$_base$path'), headers: _jsonHeaders);
    if (response.statusCode != 200) {
      throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
    }
  }

  static String _qs({bool soloArchivados = false, String? q, String? tipoActividad}) {
    final parts = <String>[];
    if (soloArchivados) parts.add('soloArchivados=true');
    if (q != null && q.isNotEmpty) parts.add('q=${Uri.encodeQueryComponent(q)}');
    if (tipoActividad != null && tipoActividad.isNotEmpty) {
      parts.add('tipo_actividad=${Uri.encodeQueryComponent(tipoActividad)}');
    }
    return parts.isEmpty ? '' : '?${parts.join('&')}';
  }

  // --- Volunteers ---
  static Future<List<Voluntario>> getVoluntarios({bool soloArchivados = false}) async {
    final data = await _getList('/api/volunteers${_qs(soloArchivados: soloArchivados)}');
    return data.map((j) => Voluntario.fromJson(j)).toList();
  }

  static Future<Voluntario> getVoluntarioById(int id) async {
    return Voluntario.fromJson(await _getOne('/api/volunteers/$id'));
  }

  static Future<Voluntario> createVoluntario(Map<String, dynamic> body) async {
    return Voluntario.fromJson(await _post('/api/volunteers', body));
  }

  static Future<Voluntario> updateVoluntario(int id, Map<String, dynamic> body) async {
    return Voluntario.fromJson(await _put('/api/volunteers/$id', body));
  }

  static Future<void> archiveVoluntario(int id) => _delete('/api/volunteers/$id');

  static Future<Voluntario> restoreVoluntario(int id) async {
    return Voluntario.fromJson(await _post('/api/volunteers/$id/restaurar', {}));
  }

  static Future<void> deleteVoluntarioPermanente(int id) =>
      _delete('/api/volunteers/$id/permanente');

  static Future<void> actualizarEstatusVoluntario(
    int voluntarioId,
    String nuevoEstatus,
    String? fechaRetiro,
  ) async {
    await _put('/api/volunteers/$voluntarioId', {
      'estatus': nuevoEstatus,
      'fecha_retiro': fechaRetiro,
    });
  }

  // --- Labor Social ---
  static Future<List<LaborSocial>> getLaborSocialStudents({bool soloArchivados = false}) async {
    final data = await _getList(
      '/api/students/labor_social${_qs(soloArchivados: soloArchivados)}',
    );
    return data.map((j) => LaborSocial.fromJson(j)).toList();
  }

  static Future<LaborSocial> getLaborSocialStudentById(int id) async {
    return LaborSocial.fromJson(await _getOne('/api/students/labor_social/$id'));
  }

  static Future<LaborSocial> createLaborSocial(Map<String, dynamic> body) async {
    return LaborSocial.fromJson(await _post('/api/students/labor_social', body));
  }

  static Future<LaborSocial> updateLaborSocial(int id, Map<String, dynamic> body) async {
    return LaborSocial.fromJson(await _put('/api/students/labor_social/$id', body));
  }

  static Future<void> archiveLaborSocial(int id) =>
      _delete('/api/students/labor_social/$id');

  static Future<LaborSocial> restoreLaborSocial(int id) async {
    return LaborSocial.fromJson(
      await _post('/api/students/labor_social/$id/restaurar', {}),
    );
  }

  static Future<void> deleteLaborSocialPermanente(int id) =>
      _delete('/api/students/labor_social/$id/permanente');

  // --- Community Service ---
  static Future<List<ServicioComunitario>> getCommunityServiceStudents({
    bool soloArchivados = false,
  }) async {
    final data = await _getList(
      '/api/students/community_service${_qs(soloArchivados: soloArchivados)}',
    );
    return data.map((j) => ServicioComunitario.fromJson(j)).toList();
  }

  static Future<ServicioComunitario> getCommunityServiceStudentById(int id) async {
    return ServicioComunitario.fromJson(
      await _getOne('/api/students/community_service/$id'),
    );
  }

  static Future<ServicioComunitario> createCommunityService(Map<String, dynamic> body) async {
    return ServicioComunitario.fromJson(
      await _post('/api/students/community_service', body),
    );
  }

  static Future<ServicioComunitario> updateCommunityService(
    int id,
    Map<String, dynamic> body,
  ) async {
    return ServicioComunitario.fromJson(
      await _put('/api/students/community_service/$id', body),
    );
  }

  static Future<void> archiveCommunityService(int id) =>
      _delete('/api/students/community_service/$id');

  static Future<ServicioComunitario> restoreCommunityService(int id) async {
    return ServicioComunitario.fromJson(
      await _post('/api/students/community_service/$id/restaurar', {}),
    );
  }

  static Future<void> deleteCommunityServicePermanente(int id) =>
      _delete('/api/students/community_service/$id/permanente');

  // --- Internship ---
  static Future<List<PasantiaTesisProyecto>> getInternshipThesisProjectStudents({
    bool soloArchivados = false,
  }) async {
    final data = await _getList(
      '/api/students/internship_thesis_project${_qs(soloArchivados: soloArchivados)}',
    );
    return data.map((j) => PasantiaTesisProyecto.fromJson(j)).toList();
  }

  static Future<PasantiaTesisProyecto> getInternshipThesisProjectStudentById(int id) async {
    return PasantiaTesisProyecto.fromJson(
      await _getOne('/api/students/internship_thesis_project/$id'),
    );
  }

  static Future<PasantiaTesisProyecto> createInternship(Map<String, dynamic> body) async {
    return PasantiaTesisProyecto.fromJson(
      await _post('/api/students/internship_thesis_project', body),
    );
  }

  static Future<PasantiaTesisProyecto> updateInternship(
    int id,
    Map<String, dynamic> body,
  ) async {
    return PasantiaTesisProyecto.fromJson(
      await _put('/api/students/internship_thesis_project/$id', body),
    );
  }

  static Future<void> archiveInternship(int id) =>
      _delete('/api/students/internship_thesis_project/$id');

  static Future<PasantiaTesisProyecto> restoreInternship(int id) async {
    return PasantiaTesisProyecto.fromJson(
      await _post('/api/students/internship_thesis_project/$id/restaurar', {}),
    );
  }

  static Future<void> deleteInternshipPermanente(int id) =>
      _delete('/api/students/internship_thesis_project/$id/permanente');

  // --- Otros ---
  static Future<List<Otros>> getAllOtrosStudents({
    bool soloArchivados = false,
    String? tipoActividad,
  }) async {
    final data = await _getList(
      '/api/others${_qs(soloArchivados: soloArchivados, tipoActividad: tipoActividad)}',
    );
    return data.map((j) => Otros.fromJson(j)).toList();
  }

  static Future<Otros> getOtrosStudentById(int id) async {
    return Otros.fromJson(await _getOne('/api/others/$id'));
  }

  static Future<Otros> createOtros(Map<String, dynamic> body) async {
    return Otros.fromJson(await _post('/api/others', body));
  }

  static Future<Otros> updateOtros(int id, Map<String, dynamic> body) async {
    return Otros.fromJson(await _put('/api/others/$id', body));
  }

  static Future<void> archiveOtros(int id) => _delete('/api/others/$id');

  static Future<Otros> restoreOtros(int id) async {
    return Otros.fromJson(await _post('/api/others/$id/restaurar', {}));
  }

  static Future<void> deleteOtrosPermanente(int id) =>
      _delete('/api/others/$id/permanente');

  // --- Observaciones ---
  static Future<List<Observacion>> getObservaciones(String basePath, int id) async {
    final data = await _getList('$basePath/$id/observaciones');
    return data.map((j) => Observacion.fromJson(j)).toList();
  }

  static Future<Observacion> createObservacion(
    String basePath,
    int id,
    String texto, {
    String? autor,
  }) async {
    return Observacion.fromJson(
      await _post('$basePath/$id/observaciones', {
        'texto': texto,
        if (autor != null) 'autor': autor,
      }),
    );
  }

  static Future<Observacion> updateObservacion(int observacionId, String texto) async {
    return Observacion.fromJson(
      await _put('/api/observaciones/$observacionId', {'texto': texto}),
    );
  }

  static Future<void> deleteObservacion(int observacionId) =>
      _delete('/api/observaciones/$observacionId');

  // --- Importación Excel ---
  static Future<List<int>> descargarPlantilla(String modulePath) async {
    final response = await http.get(
      Uri.parse('$_base$modulePath/plantilla'),
      headers: {'Accept': '*/*'},
    );
    if (response.statusCode != 200) {
      String msg = response.body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['error'] != null) {
          msg = decoded['error'].toString();
        }
      } catch (_) {}
      if (response.statusCode == 400 && msg.contains('ID inválido')) {
        msg =
            'El backend está desactualizado. Cierre la ventana del API y ejecute npm start de nuevo en backend/.';
      }
      throw Exception(msg);
    }
    return response.bodyBytes;
  }

  static Future<Map<String, dynamic>> _importarExcel(
    String modulePath,
    List<int> bytes,
    String fileName, {
    required bool preview,
  }) async {
    final uri = Uri.parse(
      '$_base$modulePath/importar${preview ? '?preview=true' : ''}',
    );
    final request = http.MultipartRequest('POST', uri);
    request.headers['Accept'] = 'application/json';
    request.files.add(
      http.MultipartFile.fromBytes(
        'archivo',
        bytes,
        filename: fileName.endsWith('.xlsx') ? fileName : '$fileName.xlsx',
      ),
    );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      String msg = response.body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['error'] != null) {
          msg = decoded['error'].toString();
        }
      } catch (_) {}
      throw Exception(msg);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> previewImportacion(
    String modulePath,
    List<int> bytes,
    String fileName,
  ) =>
      _importarExcel(modulePath, bytes, fileName, preview: true);

  static Future<Map<String, dynamic>> ejecutarImportacion(
    String modulePath,
    List<int> bytes,
    String fileName,
  ) =>
      _importarExcel(modulePath, bytes, fileName, preview: false);
}
