import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Servicio de reservas de estacionamiento (RF-04, RF-18 y pago anticipado).
class ReservaService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Porcentaje que se retiene como penalidad al cancelar (0.20 = 20%).
  // Si el equipo define otro valor, cámbialo aquí.
  static const double penalidadCancelacion = 0.20;

  CollectionReference get _col => _db.collection('reservas');
  CollectionReference get _parqueaderos => _db.collection('parqueaderos');

  // Calcula el monto a pagar por adelantado.
  double calcularMonto(double tarifaHora, int duracionHoras) {
    return tarifaHora * duracionHoras;
  }

  // Calcula cuánto se devuelve si se cancela.
  double calcularReembolso(double montoPagado) {
    return montoPagado * (1 - penalidadCancelacion);
  }

  // RF-04 + pago anticipado: crea la reserva ya pagada.
  // La transacción valida disponibilidad y descuenta el espacio.
  Future<void> crearReservaPagada({
    required String parqueaderoId,
    required String parqueaderoNombre,
    required String fecha,
    required String hora,
    required int duracionHoras,
    required double tarifaHora,
    required double montoPagado,
    required String metodoPago,
  }) async {
    final user = _auth.currentUser!;
    final refParqueadero = _parqueaderos.doc(parqueaderoId);
    final refReserva = _col.doc();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(refParqueadero);
      if (!snap.exists) throw 'El parqueadero ya no existe.';

      final data = snap.data() as Map<String, dynamic>;
      final libres = (data['espaciosLibres'] ?? 0) as int;

      if (libres <= 0) {
        throw 'No hay espacios disponibles en este parqueadero.';
      }

      tx.update(refParqueadero, {'espaciosLibres': libres - 1});

      tx.set(refReserva, {
        'usuarioId': user.uid,
        'usuarioEmail': user.email ?? '',
        'parqueaderoId': parqueaderoId,
        'parqueaderoNombre': parqueaderoNombre,
        'fecha': fecha,
        'hora': hora,
        'duracionHoras': duracionHoras,
        'tarifaHora': tarifaHora,
        // Datos del pago anticipado
        'montoPagado': montoPagado,
        'metodoPago': metodoPago,
        'estadoPago': 'pagado',
        'pagadoEn': Timestamp.now(),
        'montoReembolsado': 0.0,
        // Estado de la reserva
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

  // RF-18: cancela la reserva, libera el espacio y aplica reembolso parcial.
  // Devuelve el monto reembolsado.
  Future<double> cancelarReserva(String reservaId) async {
    final refReserva = _col.doc(reservaId);
    double reembolso = 0;

    await _db.runTransaction((tx) async {
      final snapReserva = await tx.get(refReserva);
      if (!snapReserva.exists) throw 'La reserva no existe.';

      final data = snapReserva.data() as Map<String, dynamic>;
      if (data['estado'] != 'activa') {
        throw 'Esta reserva ya no está activa.';
      }

      final montoPagado = (data['montoPagado'] ?? 0).toDouble();
      reembolso = calcularReembolso(montoPagado);
      final penalidad = montoPagado - reembolso;

      final parqueaderoId = data['parqueaderoId'] ?? '';
      final refParqueadero = _parqueaderos.doc(parqueaderoId);
      final snapParqueadero = await tx.get(refParqueadero);

      tx.update(refReserva, {
        'estado': 'cancelada',
        'canceladaEn': Timestamp.now(),
        'estadoPago': 'reembolsado_parcial',
        'montoReembolsado': reembolso,
        'penalidadAplicada': penalidad,
      });

      // Devolvemos el espacio al parqueadero.
      if (snapParqueadero.exists) {
        final dataP = snapParqueadero.data() as Map<String, dynamic>;
        final libres = (dataP['espaciosLibres'] ?? 0) as int;
        final totales = (dataP['espaciosTotales'] ?? 0) as int;
        final nuevos = (libres + 1) > totales ? totales : libres + 1;
        tx.update(refParqueadero, {'espaciosLibres': nuevos});
      }
    });

    return reembolso;
  }
}