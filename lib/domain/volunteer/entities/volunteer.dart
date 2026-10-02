class Persona {
  final int id;
  final String ci;
  final String nombre;
  final String apellido;
  final String telefono;
  final String email;
  final DateTime? fechaNacimiento;
  final String residencia;
  final DateTime? fechaInduccion;

  Persona({
    required this.id,
    required this.ci,
    required this.nombre,
    required this.apellido,
    required this.telefono,
    required this.email,
    this.fechaNacimiento,
    required this.residencia,
    this.fechaInduccion,
  });

  factory Persona.fromJson(Map<String, dynamic> json) {
    return Persona(
      id: json['persona_id'] ?? 0,
      ci: json['ci']?.toString() ?? 'No registrado',
      nombre: (json['nombre'] ?? json['name'] ?? 'No especificado').toString(),
      apellido: json['apellido']?.toString() ?? 'No especificado',
      telefono: json['telefono']?.toString() ?? 'No registrado',
      email: json['email']?.toString() ?? 'No registrado',
      fechaNacimiento: _parseDate(json['fecha_nacimiento'] ?? json['birth_date']),
      residencia: json['residencia']?.toString() ?? 'No especificado',
      fechaInduccion: _parseDate(json['fecha_induccion']),
    );
  }

  Map<String, dynamic> toJson() => {
        'persona_id': id,
        'ci': ci,
        'nombre': nombre,
        'apellido': apellido,
        'telefono': telefono,
        'email': email,
        'fecha_nacimiento': fechaNacimiento?.toIso8601String(),
        'residencia': residencia,
        'fecha_induccion': fechaInduccion?.toIso8601String(),
      };
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

String _fmt(DateTime? d) =>
    d != null ? '${d.day}/${d.month}/${d.year}' : 'No especificada';

class Voluntario extends Persona {
  final int voluntarioId;
  String estatus;
  final String profesionOficio;
  final String institucion;
  final DateTime? fechaInicio;
  DateTime? fechaRetiro;
  final int? asistencias;
  final String? actividad;
  final bool activo;

  Voluntario({
    required this.voluntarioId,
    required super.ci,
    required super.nombre,
    required super.apellido,
    required super.telefono,
    required super.email,
    super.fechaNacimiento,
    required super.residencia,
    required this.estatus,
    required this.profesionOficio,
    String? institucion,
    super.fechaInduccion,
    this.fechaInicio,
    this.fechaRetiro,
    this.asistencias,
    this.actividad,
    this.activo = true,
  })  : institucion = institucion ?? 'No registrada',
        super(id: voluntarioId);

  factory Voluntario.fromJson(Map<String, dynamic> json) {
    return Voluntario(
      voluntarioId: json['id'] ?? 0,
      ci: json['ci']?.toString() ?? 'No registrado',
      nombre: (json['name'] ?? json['nombre'] ?? 'Error al cargar').toString(),
      apellido: json['apellido']?.toString() ?? 'Error al cargar',
      telefono: json['telefono']?.toString() ?? 'No registrado',
      email: json['email']?.toString() ?? 'No registrado',
      fechaNacimiento: _parseDate(json['birth_date'] ?? json['fecha_nacimiento']),
      estatus: (json['status'] ?? json['estatus'] ?? 'Desconocido').toString(),
      profesionOficio: json['profesion_oficio']?.toString() ?? 'No especificado',
      institucion: json['institucion']?.toString() ?? 'No registrada',
      fechaInduccion: _parseDate(json['fecha_induccion']),
      fechaInicio: _parseDate(json['fecha_inicio']),
      fechaRetiro: _parseDate(json['fecha_retiro']),
      residencia: json['residencia']?.toString() ?? 'No especificado',
      asistencias: json['asistencias'] is int
          ? json['asistencias']
          : int.tryParse('${json['asistencias'] ?? ''}'),
      actividad: json['actividad']?.toString(),
      activo: json['activo'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
        'ci': ci,
        'nombre': nombre,
        'apellido': apellido,
        'telefono': telefono,
        'email': email,
        'fecha_nacimiento': fechaNacimiento?.toIso8601String(),
        'residencia': residencia,
        'fecha_induccion': fechaInduccion?.toIso8601String(),
        'estatus': estatus,
        'profesion_oficio': profesionOficio,
        'lugar_trabajo': institucion,
        'institucion': institucion,
        'fecha_inicio': fechaInicio?.toIso8601String(),
        'fecha_retiro': fechaRetiro?.toIso8601String(),
        'asistencias': asistencias,
        'actividad': actividad,
      };

  String get formattedStartDate => _fmt(fechaInicio);
}

class LaborSocial {
  final int id;
  final Persona persona;
  final String colegio;
  final String nivel;
  final String? carrera;
  final String? expediente;
  final int? anio;
  final String? estatus;
  final DateTime? fechaInicio;
  final DateTime? fechaCulminacion;
  final String? representante;
  final String? telefonoRepresentante;
  final String? emailRepresentante;
  final String? actividadApoyo;
  final DateTime? fechaCartaCulminacion;
  final bool activo;

  LaborSocial({
    required this.id,
    required this.persona,
    required this.colegio,
    required this.nivel,
    this.carrera,
    this.expediente,
    this.anio,
    this.estatus,
    this.fechaInicio,
    this.fechaCulminacion,
    this.representante,
    this.telefonoRepresentante,
    this.emailRepresentante,
    this.actividadApoyo,
    this.fechaCartaCulminacion,
    this.activo = true,
  });

  factory LaborSocial.fromJson(Map<String, dynamic> json) {
    return LaborSocial(
      id: json['id'] ?? 0,
      persona: Persona.fromJson(json),
      colegio: json['colegio']?.toString() ?? 'No especificado',
      nivel: json['nivel']?.toString() ?? 'Sin nivel registrado',
      carrera: json['carrera']?.toString(),
      expediente: json['expediente']?.toString(),
      anio: json['anio'] is int ? json['anio'] : int.tryParse('${json['anio'] ?? ''}'),
      estatus: json['estatus']?.toString(),
      fechaInicio: _parseDate(json['fecha_inicio']),
      fechaCulminacion: _parseDate(json['fecha_culminacion']),
      representante: json['representante']?.toString(),
      telefonoRepresentante: json['telefono_representante']?.toString(),
      emailRepresentante: json['email_representante']?.toString(),
      actividadApoyo: json['actividad_apoyo']?.toString(),
      fechaCartaCulminacion: _parseDate(json['fecha_carta_culminacion']),
      activo: json['activo'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
        ...persona.toJson(),
        'colegio': colegio,
        'nivel': nivel,
        'carrera': carrera,
        'expediente': expediente,
        'anio': anio,
        'estatus': estatus,
        'fecha_inicio': fechaInicio?.toIso8601String(),
        'fecha_culminacion': fechaCulminacion?.toIso8601String(),
        'representante': representante,
        'telefono_representante': telefonoRepresentante,
        'email_representante': emailRepresentante,
        'actividad_apoyo': actividadApoyo,
        'fecha_carta_culminacion': fechaCartaCulminacion?.toIso8601String(),
      };

  String get formattedFechaInicio => _fmt(fechaInicio);
  String get formattedFechaCulminacion => _fmt(fechaCulminacion);
}

class ServicioComunitario {
  final int id;
  final Persona persona;
  final String instituto;
  final String carrera;
  final String proyecto;
  final int? anio;
  final String? estatus;
  final DateTime? fechaInicio;
  final DateTime? fechaCulminacion;
  final bool activo;

  ServicioComunitario({
    required this.id,
    required this.persona,
    required this.instituto,
    required this.carrera,
    required this.proyecto,
    this.anio,
    this.estatus,
    this.fechaInicio,
    this.fechaCulminacion,
    this.activo = true,
  });

  factory ServicioComunitario.fromJson(Map<String, dynamic> json) {
    return ServicioComunitario(
      id: json['id'] ?? 0,
      persona: Persona.fromJson(json),
      instituto: json['instituto']?.toString() ?? 'No especificado',
      carrera: json['carrera']?.toString() ?? 'No registrada',
      proyecto: json['proyecto']?.toString() ?? 'No definido',
      anio: json['anio'] is int ? json['anio'] : int.tryParse('${json['anio'] ?? ''}'),
      estatus: json['estatus']?.toString(),
      fechaInicio: _parseDate(json['fecha_inicio']),
      fechaCulminacion: _parseDate(json['fecha_culminacion']),
      activo: json['activo'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
        ...persona.toJson(),
        'instituto': instituto,
        'carrera': carrera,
        'proyecto': proyecto,
        'anio': anio,
        'estatus': estatus,
        'fecha_inicio': fechaInicio?.toIso8601String(),
        'fecha_culminacion': fechaCulminacion?.toIso8601String(),
      };

  String get formattedFechaInicio => _fmt(fechaInicio);
  String get formattedFechaCulminacion => _fmt(fechaCulminacion);
}

class PasantiaTesisProyecto {
  final int id;
  final String tipo;
  final String carrera;
  final String instituto;
  final String tutorAcademico;
  final String tutorInstitucional;
  final int? anio;
  final String? estatus;
  final DateTime? fechaInicio;
  final DateTime? fechaCulminacion;
  final Persona persona;
  final bool activo;

  PasantiaTesisProyecto({
    required this.id,
    required this.tipo,
    required this.carrera,
    required this.instituto,
    required this.tutorAcademico,
    required this.tutorInstitucional,
    this.anio,
    this.estatus,
    this.fechaInicio,
    this.fechaCulminacion,
    required this.persona,
    this.activo = true,
  });

  factory PasantiaTesisProyecto.fromJson(Map<String, dynamic> json) {
    return PasantiaTesisProyecto(
      id: json['id'] ?? 0,
      tipo: json['tipo']?.toString() ?? 'No especificado',
      carrera: json['carrera']?.toString() ?? 'No registrada',
      instituto: json['instituto']?.toString() ?? 'No definido',
      tutorAcademico: json['tutor_academico']?.toString() ?? 'No asignado',
      tutorInstitucional: json['tutor_institucional']?.toString() ?? 'No asignado',
      anio: json['anio'] is int ? json['anio'] : int.tryParse('${json['anio'] ?? ''}'),
      estatus: json['estatus']?.toString(),
      fechaInicio: _parseDate(json['fecha_inicio']),
      fechaCulminacion: _parseDate(json['fecha_culminacion']),
      persona: Persona.fromJson(json),
      activo: json['activo'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
        ...persona.toJson(),
        'tipo': tipo,
        'carrera': carrera,
        'instituto': instituto,
        'tutor_academico': tutorAcademico,
        'tutor_institucional': tutorInstitucional,
        'anio': anio,
        'estatus': estatus,
        'fecha_inicio': fechaInicio?.toIso8601String(),
        'fecha_culminacion': fechaCulminacion?.toIso8601String(),
      };

  String get formattedFechaInicio => _fmt(fechaInicio);
  String get formattedFechaCulminacion => _fmt(fechaCulminacion);
}

class Otros {
  final int id;
  final String tipoActividad;
  final String institucion;
  final String? carrera;
  final int? anio;
  final String? estatus;
  final DateTime? fechaInicio;
  final DateTime? fechaCulminacion;
  final Persona persona;
  final bool activo;

  Otros({
    required this.id,
    required this.tipoActividad,
    required this.institucion,
    this.carrera,
    this.anio,
    this.estatus,
    this.fechaInicio,
    this.fechaCulminacion,
    required this.persona,
    this.activo = true,
  });

  factory Otros.fromJson(Map<String, dynamic> json) {
    return Otros(
      id: json['id'] ?? json['otros_id'] ?? 0,
      tipoActividad: json['tipo_actividad']?.toString() ?? 'No especificado',
      institucion: json['institucion']?.toString() ?? 'No registrada',
      carrera: json['carrera']?.toString(),
      anio: json['anio'] is int ? json['anio'] : int.tryParse('${json['anio'] ?? ''}'),
      estatus: json['estatus']?.toString(),
      fechaInicio: _parseDate(json['fecha_inicio']),
      fechaCulminacion: _parseDate(json['fecha_culminacion']),
      persona: Persona.fromJson(json),
      activo: json['activo'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
        ...persona.toJson(),
        'tipo_actividad': tipoActividad,
        'institucion': institucion,
        'carrera': carrera,
        'anio': anio,
        'estatus': estatus,
        'fecha_inicio': fechaInicio?.toIso8601String(),
        'fecha_culminacion': fechaCulminacion?.toIso8601String(),
      };

  String get formattedFechaInicio => _fmt(fechaInicio);
  String get formattedFechaCulminacion => _fmt(fechaCulminacion);
}

class Observacion {
  final int id;
  final String entidad;
  final int entidadId;
  final String texto;
  final DateTime? fecha;
  final String? autor;
  final String origen;

  Observacion({
    required this.id,
    required this.entidad,
    required this.entidadId,
    required this.texto,
    this.fecha,
    this.autor,
    this.origen = 'manual',
  });

  factory Observacion.fromJson(Map<String, dynamic> json) {
    return Observacion(
      id: json['id'] ?? json['observacion_id'] ?? 0,
      entidad: json['entidad']?.toString() ?? '',
      entidadId: json['entidad_id'] ?? 0,
      texto: json['texto']?.toString() ?? '',
      fecha: _parseDate(json['fecha']),
      autor: json['autor']?.toString(),
      origen: json['origen']?.toString() ?? 'manual',
    );
  }

  Map<String, dynamic> toJson() => {
        'texto': texto,
        'autor': autor,
        'origen': origen,
      };
}
