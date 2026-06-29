import 'package:cloud_firestore/cloud_firestore.dart';

// Modelo de un registro de parqueo: entrada, salida y costo (RF-05, RF-06, RF-07, RF-15).
class Registro {
  final String id;
  final String usuarioId;
  final String usuarioEmail;
  final String parqueaderoId;
  final String parqueaderoNombre;
  final double tarifaHora;
  final DateTime horaEntrada;
  final DateTime? horaSalida;
  final double costo;
  final String estado; // 'activo' o 'finalizado'

  const Registro({
    this.id = '',
    required this.usuarioId,
    required this.usuarioEmail,
    required this.parqueaderoId,
    required this.parqueaderoNombre,
    required this.tarifaHora,
    required this.horaEntrada,
    this.horaSalida,
    this.costo = 0,
    this.estado = 'activo',
  });

  factory Registro.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Registro(
      id: doc.id,
      usuarioId: data['usuarioId'] ?? '',
      usuarioEmail: data['usuarioEmail'] ?? '',
      parqueaderoId: data['parqueaderoId'] ?? '',
      parqueaderoNombre: data['parqueaderoNombre'] ?? '',
      tarifaHora: (data['tarifaHora'] ?? 0).toDouble(),
      horaEntrada: data['horaEntrada'] != null
          ? (data['horaEntrada'] as Timestamp).toDate()
          : DateTime.now(),
      horaSalida: data['horaSalida'] != null
          ? (data['horaSalida'] as Timestamp).toDate()
          : null,
      costo: (data['costo'] ?? 0).toDouble(),
      estado: data['estado'] ?? 'activo',
    );
  }

  Map<String, dynamic> toMap() => {
        'usuarioId': usuarioId,
        'usuarioEmail': usuarioEmail,
        'parqueaderoId': parqueaderoId,
        'parqueaderoNombre': parqueaderoNombre,
        'tarifaHora': tarifaHora,
        'horaEntrada': Timestamp.fromDate(horaEntrada),
        'horaSalida': horaSalida != null ? Timestamp.fromDate(horaSalida!) : null,
        'costo': costo,
        'estado': estado,
      };
}
