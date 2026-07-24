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

  // 🛡️ Verifica si el usuario tiene una entrada física o reserva activa
  Future<bool> tieneOperacionActiva() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    // A) Verificar en entradas físicas directas (registros)
    final snapRegistros = await _db
        .collection('registros')
        .where('usuarioId', isEqualTo: user.uid)
        .where('estado', whereIn: ['activo', 'activa'])
        .limit(1)
        .get();

    if (snapRegistros.docs.isNotEmpty) return true;

    // B) Verificar en reservas activas
    final snapReservas = await _db
        .collection('reservas')
        .where('usuarioId', isEqualTo: user.uid)
        .where('estado', isEqualTo: 'activa')
        .limit(1)
        .get();

    return snapReservas.docs.isNotEmpty;
  }

  // 🛡️ Método para validar fecha de reserva al crearla
  static void validarFechaReserva(DateTime fechaHoraSeleccionada) {
    final ahora = DateTime.now();
    if (fechaHoraSeleccionada.isBefore(ahora.add(const Duration(minutes: 2)))) {
      throw Exception('La fecha y hora de la reserva debe ser posterior al momento actual.');
    }
  }

  // RF-05: Registrar entrada directa física.
  Future<String> registrarEntrada(Parqueadero p) async {
    if (await tieneOperacionActiva()) {
      throw Exception('Ya tienes una entrada registrada o reserva activa en curso. Debes finalizarla antes de iniciar otra.');
    }

    final user = _auth.currentUser!;
    final ocupados = (p.espaciosTotales - p.espaciosLibres).clamp(0, p.espaciosTotales);
    final numeroPuesto = (ocupados + 1).clamp(1, p.espaciosTotales < 1 ? 1 : p.espaciosTotales);
    final puesto = 'P-${numeroPuesto.toString().padLeft(2, '0')}';

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
      'usuarioNombre': nombreUsuario,
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

  // RF-05 + RF-06: Registrar salida con BLOQUEO RIGUROSO de reservas futuras.
  Future<double> registrarSalida(
      String registroId,
      String parqueaderoId,
      DateTime horaEntradaRespaldo,
      double tarifaHoraRespaldo,
      int minutosFraccionRespaldo,
      ) async {

    final docRegistroRef = _db.collection('registros').doc(registroId);
    final docRegistroSnap = await docRegistroRef.get();

    // 1️⃣ CASO A: Entrada física directa (Colección 'registros')
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
      // 2️⃣ CASO B: Reserva Programada (Colección 'reservas')
      final docReservaRef = _db.collection('reservas').doc(registroId);
      final docReservaSnap = await docReservaRef.get();

      if (docReservaSnap.exists) {
        final dataReserva = docReservaSnap.data() as Map<String, dynamic>;
        final ahora = DateTime.now();
        DateTime? fechaHoraProgramada;

        // 🔍 Intentar parsear la fecha/hora desde campos de texto ("DD/MM/YYYY" y "HH:MM")
        try {
          final strFecha = dataReserva['fecha']?.toString(); // Ej: "23/07/2026"
          final strHora = dataReserva['hora']?.toString();   // Ej: "20:00"

          if (strFecha != null && strFecha.contains('/') && strHora != null && strHora.contains(':')) {
            final partesFecha = strFecha.split('/');
            final partesHora = strHora.split(':');

            final dia = int.parse(partesFecha[0]);
            final mes = int.parse(partesFecha[1]);
            final anio = int.parse(partesFecha[2]);

            final hora = int.parse(partesHora[0]);
            final minuto = int.parse(partesHora[1]);

            fechaHoraProgramada = DateTime(anio, mes, dia, hora, minuto);
          }
        } catch (_) {}

        // 🔍 Respaldo por Timestamp de Firestore
        if (fechaHoraProgramada == null) {
          if (dataReserva['horaEntrada'] is Timestamp) {
            fechaHoraProgramada = (dataReserva['horaEntrada'] as Timestamp).toDate();
          } else if (dataReserva['fechaReserva'] is Timestamp) {
            fechaHoraProgramada = (dataReserva['fechaReserva'] as Timestamp).toDate();
          }
        }

        // 🛑 VALIDACIÓN RIGUROSA DE FECHA FUTURA:
        if (fechaHoraProgramada != null) {
          // Si el momento actual es menor a la hora programada (con margen de 5 minutos)
          if (ahora.isBefore(fechaHoraProgramada.subtract(const Duration(minutes: 5)))) {
            final formatoHora = '${fechaHoraProgramada.day.toString().padLeft(2, '0')}/${fechaHoraProgramada.month.toString().padLeft(2, '0')}/${fechaHoraProgramada.year} a las ${fechaHoraProgramada.hour.toString().padLeft(2, '0')}:${fechaHoraProgramada.minute.toString().padLeft(2, '0')}';
            throw Exception('No puedes registrar la salida. Tu reserva está programada para el $formatoHora y aún no ha iniciado. Puedes cancelarla en la pantalla Mis Reservas');
          }
        }

        // Si ya llegó la hora, procede a marcar salida
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