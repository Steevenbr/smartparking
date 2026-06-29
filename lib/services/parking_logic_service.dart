import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/registro.dart';
import '../models/tarifa_config.dart';
import '../models/parqueadero.dart';
import 'parqueadero_service.dart';
import 'tarifa_service.dart';

// Lógica de entrada/salida y cálculo de tarifa (RF-05, RF-06, RF-15, RF-23).
class ParkingLogicService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ParqueaderoService _parqueaderos = ParqueaderoService();
  final TarifaService _tarifas = TarifaService();

  CollectionReference get _col => _db.collection('registros');

  // RF-05: Registrar entrada. La hora la pone el SERVIDOR (no el teléfono),
  // para que nadie pueda manipular el reloj y pagar de menos.
  Future<String> registrarEntrada(Parqueadero p) async {
    final user = _auth.currentUser!;
    final ref = await _col.add({
      'usuarioId': user.uid,
      'usuarioEmail': user.email ?? '',
      'parqueaderoId': p.id,
      'parqueaderoNombre': p.nombre,
      'tarifaHora': p.tarifaHora,
      'horaEntrada': FieldValue.serverTimestamp(), // hora real del servidor
      'horaSalida': null,
      'costo': 0,
      'estado': 'activo',
    });
    await _parqueaderos.cambiarEspacios(p.id, -1); // RF-27
    return ref.id;
  }

  // RF-06 + RF-23: Cálculo de tarifa con fracciones.
  // Cobra por cada fracción empezada (ej. cada 15 min).
  double calcularCosto(DateTime entrada, DateTime salida, TarifaConfig cfg) {
    final minutos = salida.difference(entrada).inMinutes;
    final minutosCobrados = minutos < 1 ? 1 : minutos;
    final fracciones = (minutosCobrados / cfg.minutosFraccion).ceil();
    return fracciones * cfg.tarifaFraccion;
  }

  // RF-05 + RF-06: Registrar salida. El costo se calcula con las horas
  // REALES del servidor, no con el reloj del teléfono.
  Future<double> registrarSalida(String registroId, String parqueaderoId,
      DateTime horaEntradaRespaldo) async {
    final cfg = await _tarifas.getConfig();

    // 1. Marcamos la salida con la hora del servidor.
    await _col.doc(registroId).update({
      'horaSalida': FieldValue.serverTimestamp(),
      'estado': 'finalizado',
    });

    // 2. Leemos del SERVIDOR las horas reales de entrada y salida.
    DateTime entrada = horaEntradaRespaldo;
    DateTime salida = DateTime.now();
    try {
      final doc = await _col
          .doc(registroId)
          .get(const GetOptions(source: Source.server));
      final data = doc.data() as Map<String, dynamic>;
      if (data['horaEntrada'] is Timestamp) {
        entrada = (data['horaEntrada'] as Timestamp).toDate();
      }
      if (data['horaSalida'] is Timestamp) {
        salida = (data['horaSalida'] as Timestamp).toDate();
      }
    } catch (_) {
      // Si no hay conexión al servidor, usamos las horas locales como respaldo.
    }

    // 3. Calculamos el costo con esas horas y lo guardamos.
    final costo = calcularCosto(entrada, salida, cfg);
    await _col.doc(registroId).update({'costo': costo});
    await _parqueaderos.cambiarEspacios(parqueaderoId, 1); // RF-27
    return costo;
  }

  // RF-07: Historial de parqueos del usuario actual.
  Stream<List<Registro>> escucharHistorial() {
    final uid = _auth.currentUser?.uid ?? '';
    return _col
        .where('usuarioId', isEqualTo: uid)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Registro.fromFirestore(d)).toList());
  }
}
