import 'package:cloud_firestore/cloud_firestore.dart';

// Modelo de un registro de parqueo: entrada, salida y costo (RF-05, RF-06, RF-07, RF-15, RF-19).
class Registro {
  final String id;
  final String usuarioId;
  final String usuarioEmail;
  final String parqueaderoId;
  final String parqueaderoNombre;
  final String parqueaderoDireccion;
  final String puesto;
  final double tarifaHora;
  final int minutosFraccion;
  final int espaciosTotales;
  final String horaApertura;
  final String horaCierre;
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
    this.parqueaderoDireccion = '',
    this.puesto = '',
    required this.tarifaHora,
    this.minutosFraccion = 15,
    this.espaciosTotales = 0,
    this.horaApertura = '08:00',
    this.horaCierre = '20:00',
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
      parqueaderoDireccion: data['parqueaderoDireccion'] ?? '',
      puesto: data['puesto'] ?? '',
      tarifaHora: (data['tarifaHora'] ?? 0).toDouble(),
      minutosFraccion: data['minutosFraccion'] ?? 15,
      espaciosTotales: data['espaciosTotales'] ?? 0,
      horaApertura: data['horaApertura'] ?? '08:00',
      horaCierre: data['horaCierre'] ?? '20:00',
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

  Map<String, dynamic> toComprobanteMap() => {
        'usuarioEmail': usuarioEmail,
        'parqueaderoNombre': parqueaderoNombre,
        'parqueaderoDireccion': parqueaderoDireccion,
        'puesto': puesto.isEmpty ? 'N/A' : puesto,
        'tarifaHora': tarifaHora,
        'minutosFraccion': minutosFraccion,
        'espaciosTotales': espaciosTotales,
        'horaApertura': horaApertura,
        'horaCierre': horaCierre,
        'horaEntrada': Timestamp.fromDate(horaEntrada),
        'horaSalida':
            horaSalida != null ? Timestamp.fromDate(horaSalida!) : null,
        'costo': costo,
        'estado': estado,
      };
}
