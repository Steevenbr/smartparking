import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/registro.dart';
import '../models/parqueadero.dart';
import 'parqueadero_service.dart';

// Lógica de entrada/salida y cálculo de tarifa (RF-05, RF-06, RF-15, RF-23).
// Todo el cobro usa la tarifa y la fracción DEL GARAJE, no una config global.
class ParkingLogicService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ParqueaderoService _parqueaderos = ParqueaderoService();

  CollectionReference get _col => _db.collection('registros');

  // RF-05: Registrar entrada. La hora la pone el SERVIDOR. Se guarda la tarifa
  // y la fracción del garaje para que el cobro sea siempre el de ese garaje.
  Future<String> registrarEntrada(Parqueadero p) async {
    final user = _auth.currentUser!;
    final ref = await _col.add({
      'usuarioId': user.uid,
      'usuarioEmail': user.email ?? '',
      'parqueaderoId': p.id,
      'parqueaderoNombre': p.nombre,
      'tarifaHora': p.tarifaHora,
      'minutosFraccion': p.minutosFraccion,
      'horaEntrada': FieldValue.serverTimestamp(), // hora real del servidor
      'horaSalida': null,
      'costo': 0,
      'estado': 'activo',
    });
    await _parqueaderos.cambiarEspacios(p.id, -1); // RF-27
    return ref.id;
  }

  // RF-06 + RF-23: costo con la tarifa por hora del garaje y su fracción.
  double calcularCosto(DateTime entrada, DateTime salida, double tarifaHora,
      int minutosFraccion) {
    final minutos = salida.difference(entrada).inMinutes;
    final minutosCobrados = minutos < 1 ? 1 : minutos;
    final fracciones = (minutosCobrados / minutosFraccion).ceil();
    final precioFraccion = tarifaHora * (minutosFraccion / 60.0);
    return fracciones * precioFraccion;
  }

  // RF-05 + RF-06: Registrar salida. Costo con horas del servidor y la tarifa
  // del garaje guardada en el registro.
  Future<double> registrarSalida(
    String registroId,
    String parqueaderoId,
    DateTime horaEntradaRespaldo,
    double tarifaHoraRespaldo,
    int minutosFraccionRespaldo,
  ) async {
    // 1. Marcamos la salida con la hora del servidor.
    await _col.doc(registroId).update({
      'horaSalida': FieldValue.serverTimestamp(),
      'estado': 'finalizado',
    });

    // 2. Leemos del SERVIDOR las horas reales y los datos de tarifa.
    DateTime entrada = horaEntradaRespaldo;
    DateTime salida = DateTime.now();
    double tarifaHora = tarifaHoraRespaldo;
    int minutosFraccion = minutosFraccionRespaldo;
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
      if (data['tarifaHora'] != null) {
        tarifaHora = (data['tarifaHora']).toDouble();
      }
      if (data['minutosFraccion'] != null) {
        minutosFraccion = data['minutosFraccion'];
      }
    } catch (_) {
      // Sin conexión al servidor: usamos los valores locales de respaldo.
    }

    // 3. Calculamos el costo y lo guardamos.
    final costo = calcularCosto(entrada, salida, tarifaHora, minutosFraccion);
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
