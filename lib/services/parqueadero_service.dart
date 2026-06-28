import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/parqueadero.dart';

// Servicio de parqueaderos sobre Firestore (RF-02, RF-03, RF-20, RF-27).
class ParqueaderoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _col => _db.collection('parqueaderos');

  // RF-03 / RF-27: Escucha en tiempo real la lista de parqueaderos.
  Stream<List<Parqueadero>> escucharParqueaderos() {
    return _col.where('activo', isEqualTo: true).snapshots().map(
          (snap) => snap.docs.map((d) => Parqueadero.fromFirestore(d)).toList(),
        );
  }

  // RF-20: Crear un parqueadero (admin).
  Future<void> crearParqueadero(Parqueadero p) async {
    await _col.add(p.toMap());
  }

  // RF-20: Desactivar un parqueadero (admin).
  Future<void> desactivarParqueadero(String id) async {
    await _col.doc(id).update({'activo': false});
  }

  // RF-27: Ajusta la cantidad de espacios libres (+1 al salir, -1 al entrar).
  Future<void> cambiarEspacios(String id, int delta) async {
    await _col.doc(id).update({
      'espaciosLibres': FieldValue.increment(delta),
    });
  }

  // Crea datos de prueba si la colección está vacía (para la demo).
  Future<void> sembrarDatosDemo() async {
    final existentes = await _col.limit(1).get();
    if (existentes.docs.isNotEmpty) return; // ya hay datos, no duplica

    final demo = <Parqueadero>[
      const Parqueadero(
        nombre: 'Parqueadero Central ESPE-L',
        direccion: 'Av. General Rumiñahui, Latacunga',
        latitud: -0.9145,
        longitud: -78.6171,
        espaciosTotales: 50,
        espaciosLibres: 32,
        tarifaHora: 1.0,
      ),
      const Parqueadero(
        nombre: 'Parqueadero La Estación',
        direccion: 'Calle Marqués de Maenza, Latacunga',
        latitud: -0.9320,
        longitud: -78.6150,
        espaciosTotales: 30,
        espaciosLibres: 8,
        tarifaHora: 0.75,
      ),
      const Parqueadero(
        nombre: 'Parqueadero El Salto',
        direccion: 'Mercado El Salto, Latacunga',
        latitud: -0.9355,
        longitud: -78.6190,
        espaciosTotales: 40,
        espaciosLibres: 0,
        tarifaHora: 1.25,
      ),
    ];
    for (final p in demo) {
      await _col.add(p.toMap());
    }
  }
}
