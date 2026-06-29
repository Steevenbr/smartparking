import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Servicio de reservas de estacionamiento (RF-04).
class ReservaService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _col => _db.collection('reservas');

  // RF-04: Crear una reserva.
  Future<void> crearReserva({
    required String parqueaderoId,
    required String parqueaderoNombre,
    required String fecha,
    required String hora,
    required int duracionHoras,
  }) async {
    final user = _auth.currentUser!;
    await _col.add({
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
  }

  // Escucha las reservas del usuario actual.
  Stream<QuerySnapshot> escucharReservas() {
    final uid = _auth.currentUser?.uid ?? '';
    return _col.where('usuarioId', isEqualTo: uid).snapshots();
  }

  // RF-18: Cancelar una reserva.
  Future<void> cancelarReserva(String id) async {
    await _col.doc(id).update({'estado': 'cancelada'});
  }
}
