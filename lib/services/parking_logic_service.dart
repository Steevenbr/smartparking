import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/registro.dart';
import '../models/parqueadero.dart';
import 'parqueadero_service.dart';

// Lógica de entrada/salida y cálculo de tarifa (RF-05, RF-06, RF-15, RF-23).
class ParkingLogicService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ParqueaderoService _parqueaderos = ParqueaderoService();

  CollectionReference get _col => _db.collection('registros');

  // RF-05: Registrar entrada. Guarda snapshot del garaje + puesto asignado.
  Future<String> registrarEntrada(Parqueadero p) async {
    final user = _auth.currentUser!;
    final ocupados = (p.espaciosTotales - p.espaciosLibres).clamp(0, p.espaciosTotales);
    final numeroPuesto = (ocupados + 1).clamp(1, p.espaciosTotales < 1 ? 1 : p.espaciosTotales);
    final puesto = 'P-${numeroPuesto.toString().padLeft(2, '0')}';

    // 👤 Obtener el nombre registrado en la colección 'usuarios'
    String nombreUsuario = user.displayName ?? '';
    if (nombreUsuario.trim().isEmpty) {
      try {
        final docUser = await _db.collection('usuarios').doc(user.uid).get();
        if (docUser.exists && docUser.data() != null) {
          nombreUsuario = docUser.data()!['nombre'] ?? '';
        }
      } catch (_) {}
    }

    final ref = await _col.add({
      'usuarioId': user.uid,
      'usuarioNombre': nombreUsuario, // 👈 ¡CLAVE! Se guarda el nombre del conductor
      'usuarioEmail': user.email ?? '',
      'duenoId': p.ownerId,
      'parqueaderoId': p.id,
      'parqueaderoNombre': p.nombre,
      'parqueaderoDireccion': p.direccion,
      'parqueaderoLatitud': p.latitud,
      'parqueaderoLongitud': p.longitud,
      'espaciosTotales': p.espaciosTotales,
      'horaApertura': p.horaApertura,
      'horaCierre': p.horaCierre,
      'puesto': puesto,
      'tarifaHora': p.tarifaHora,
      'minutosFraccion': p.minutosFraccion,
      'horaEntrada': FieldValue.serverTimestamp(),
      'horaSalida': null,
      'costo': 0,
      'estado': 'activa',
    });
    await _parqueaderos.cambiarEspacios(p.id, -1);
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

  // RF-05 + RF-06: Registrar salida.
  Future<double> registrarSalida(
      String registroId,
      String parqueaderoId,
      DateTime horaEntradaRespaldo,
      double tarifaHoraRespaldo,
      int minutosFraccionRespaldo,
      ) async {

    final docRegistroRef = _db.collection('registros').doc(registroId);
    final docRegistroSnap = await docRegistroRef.get();

    if (docRegistroSnap.exists) {
      await docRegistroRef.update({
        'horaSalida': FieldValue.serverTimestamp(),
        'estado': 'finalizada',
      });

      DateTime entrada = horaEntradaRespaldo;
      DateTime salida = DateTime.now();
      double tarifaHora = tarifaHoraRespaldo;
      int minutosFraccion = minutosFraccionRespaldo;

      try {
        final doc = await docRegistroRef.get(const GetOptions(source: Source.server));
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
      } catch (_) {}

      final costo = calcularCosto(entrada, salida, tarifaHora, minutosFraccion);
      await docRegistroRef.update({'costo': costo, 'montoPagado': costo});
      await _parqueaderos.cambiarEspacios(parqueaderoId, 1);
      return costo;

    } else {
      final docReservaRef = _db.collection('reservas').doc(registroId);
      final docReservaSnap = await docReservaRef.get();

      if (docReservaSnap.exists) {
        await docReservaRef.update({
          'horaSalida': FieldValue.serverTimestamp(),
          'estado': 'finalizada',
        });

        DateTime entrada = horaEntradaRespaldo;
        DateTime salida = DateTime.now();
        double tarifaHora = tarifaHoraRespaldo;
        int minutosFraccion = minutosFraccionRespaldo;

        try {
          final doc = await docReservaRef.get(const GetOptions(source: Source.server));
          final data = doc.data() as Map<String, dynamic>;
          if (data['creadoEn'] is Timestamp) {
            entrada = (data['creadoEn'] as Timestamp).toDate();
          } else if (data['horaEntrada'] is Timestamp) {
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
        } catch (_) {}

        final costo = calcularCosto(entrada, salida, tarifaHora, minutosFraccion);
        await docReservaRef.update({
          'costoTotal': costo,
          'costo': costo,
          'montoPagado': costo,
        });

        await _parqueaderos.cambiarEspacios(parqueaderoId, 1);
        return costo;
      } else {
        throw Exception('No se encontró el documento en registros ni en reservas.');
      }
    }
  }

  Stream<List<Registro>> escucharHistorial() {
    final uid = _auth.currentUser?.uid ?? '';
    return _col
        .where('usuarioId', isEqualTo: uid)
        .snapshots()
        .map((snap) =>
        snap.docs.map((d) => Registro.fromFirestore(d)).toList());
  }

  Future<DocumentSnapshot?> obtenerSesionActiva() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final snapSesion = await FirebaseFirestore.instance
        .collection('registros')
        .where('usuarioId', isEqualTo: user.uid)
        .where('estado', whereIn: ['activo', 'activa'])
        .limit(1)
        .get();

    if (snapSesion.docs.isNotEmpty) {
      return snapSesion.docs.first;
    }

    final snapReserva = await FirebaseFirestore.instance
        .collection('reservas')
        .where('usuarioId', isEqualTo: user.uid)
        .where('estado', isEqualTo: 'activa')
        .limit(1)
        .get();

    if (snapReserva.docs.isNotEmpty) {
      return snapReserva.docs.first;
    }

    return null;
  }
}