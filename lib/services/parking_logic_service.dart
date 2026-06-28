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

  // RF-05: Registrar entrada. Crea una sesión activa y descuenta un espacio.
  Future<String> registrarEntrada(Parqueadero p) async {
    final user = _auth.currentUser!;
    final registro = Registro(
      usuarioId: user.uid,
      usuarioEmail: user.email ?? '',
      parqueaderoId: p.id,
      parqueaderoNombre: p.nombre,
      tarifaHora: p.tarifaHora,
      horaEntrada: DateTime.now(),
      estado: 'activo',
    );
    final ref = await _col.add(registro.toMap());
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

  // RF-05 + RF-06: Registrar salida. Calcula el costo y cierra la sesión.
  Future<double> registrarSalida(String registroId, String parqueaderoId,
      DateTime horaEntrada) async {
    final cfg = await _tarifas.getConfig();
    final salida = DateTime.now();
    final costo = calcularCosto(horaEntrada, salida, cfg);
    await _col.doc(registroId).update({
      'horaSalida': Timestamp.fromDate(salida),
      'costo': costo,
      'estado': 'finalizado',
    });
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
