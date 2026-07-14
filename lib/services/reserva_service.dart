import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Servicio de reservas de estacionamiento (RF-04 y RF-18).
class ReservaService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _col => _db.collection('reservas');
  CollectionReference get _parqueaderos => _db.collection('parqueaderos');

  // RF-04: Crear una reserva.
  // Usa una transacción para validar disponibilidad y descontar el espacio
  // de forma segura (evita que dos personas reserven el último lugar a la vez).
  Future<void> crearReserva({
    required String parqueaderoId,
    required String parqueaderoNombre,
    required String fecha,
    required String hora,
    required int duracionHoras,
  }) async {
    final user = _auth.currentUser!;
    final refParqueadero = _parqueaderos.doc(parqueaderoId);
    final refReserva = _col.doc();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(refParqueadero);
      if (!snap.exists) {
        throw 'El parqueadero ya no existe.';
      }

      final data = snap.data() as Map<String, dynamic>;
      final libres = (data['espaciosLibres'] ?? 0) as int;

      // Validación de disponibilidad (RF-04)
      if (libres <= 0) {
        throw 'No hay espacios disponibles en este parqueadero.';
      }

      // Descontamos un espacio
      tx.update(refParqueadero, {'espaciosLibres': libres - 1});

      // Creamos la reserva
      tx.set(refReserva, {
        'usuarioId': user.uid,
        'usuarioEmail': user.email ?? '',
        'parqueaderoId': parqueaderoId,
        'parqueaderoNombre': parqueaderoNombre,
        'fecha': fecha,
        'hora': hora,
        'duracionHoras': duracionHoras,
        'estado': 'activa',
        'creadoEn': Timestamp.now(),
      });
    });
  }

  // Escucha las reservas del usuario actual (RF-18).
  Stream<QuerySnapshot> escucharReservas() {
    final uid = _auth.currentUser?.uid ?? '';
    return _col.where('usuarioId', isEqualTo: uid).snapshots();
  }

  // RF-18: Cancelar una reserva y devolver el espacio al parqueadero.
  Future<void> cancelarReserva(String reservaId) async {
    final refReserva = _col.doc(reservaId);

    await _db.runTransaction((tx) async {
      final snapReserva = await tx.get(refReserva);
      if (!snapReserva.exists) {
        throw 'La reserva no existe.';
      }

      final data = snapReserva.data() as Map<String, dynamic>;

      // No permitimos cancelar dos veces
      if (data['estado'] != 'activa') {
        throw 'Esta reserva ya no está activa.';
      }

      final parqueaderoId = data['parqueaderoId'] ?? '';
      final refParqueadero = _parqueaderos.doc(parqueaderoId);
      final snapParqueadero = await tx.get(refParqueadero);

      // Marcamos la reserva como cancelada
      tx.update(refReserva, {
        'estado': 'cancelada',
        'canceladaEn': Timestamp.now(),
      });

      // Devolvemos el espacio al parqueadero (si aún existe)
      if (snapParqueadero.exists) {
        final dataP = snapParqueadero.data() as Map<String, dynamic>;
        final libres = (dataP['espaciosLibres'] ?? 0) as int;
        final totales = (dataP['espaciosTotales'] ?? 0) as int;
        // No superamos el total de espacios
        final nuevos = (libres + 1) > totales ? totales : libres + 1;
        tx.update(refParqueadero, {'espaciosLibres': nuevos});
      }
    });
  }
}