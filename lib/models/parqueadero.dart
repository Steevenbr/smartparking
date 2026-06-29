import 'package:cloud_firestore/cloud_firestore.dart';

// Modelo de un parqueadero (RF-02, RF-03, RF-20, RF-27).
class Parqueadero {
  final String id;
  final String ownerId; // dueño que lo creó (RF-20, RF-22)
  final String nombre;
  final String direccion;
  final double latitud;
  final double longitud;
  final int espaciosTotales;
  final int espaciosLibres;
  final double tarifaHora;
  final bool activo;

  const Parqueadero({
    this.id = '',
    this.ownerId = '',
    required this.nombre,
    required this.direccion,
    required this.latitud,
    required this.longitud,
    required this.espaciosTotales,
    required this.espaciosLibres,
    required this.tarifaHora,
    this.activo = true,
  });

  // Convierte un documento de Firestore en un objeto Parqueadero.
  factory Parqueadero.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Parqueadero(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      nombre: data['nombre'] ?? '',
      direccion: data['direccion'] ?? '',
      latitud: (data['latitud'] ?? 0).toDouble(),
      longitud: (data['longitud'] ?? 0).toDouble(),
      espaciosTotales: data['espaciosTotales'] ?? 0,
      espaciosLibres: data['espaciosLibres'] ?? 0,
      tarifaHora: (data['tarifaHora'] ?? 0).toDouble(),
      activo: data['activo'] ?? true,
    );
  }

  // Convierte el objeto en un mapa para guardarlo en Firestore.
  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'nombre': nombre,
        'direccion': direccion,
        'latitud': latitud,
        'longitud': longitud,
        'espaciosTotales': espaciosTotales,
        'espaciosLibres': espaciosLibres,
        'tarifaHora': tarifaHora,
        'activo': activo,
      };
}
