import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Añadido para obtener el UID actual del conductor
import '../models/parqueadero.dart';

// Servicio de parqueaderos sobre Firestore (RF-02, RF-03, RF-20, RF-27).
class ParqueaderoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _col => _db.collection('parqueaderos');

  // RF-03 / RF-27: Escucha en tiempo real la lista de parqueaderos (conductor).
  Stream<List<Parqueadero>> escucharParqueaderos() {
    return _col.where('activo', isEqualTo: true).snapshots().map(
          (snap) => snap.docs.map((d) => Parqueadero.fromFirestore(d)).toList(),
    );
  }

  // RF-20: Escucha solo los garajes de un dueño en particular.
  Stream<List<Parqueadero>> escucharMisGarajes(String ownerId) {
    return _col.where('ownerId', isEqualTo: ownerId).snapshots().map(
          (snap) => snap.docs.map((d) => Parqueadero.fromFirestore(d)).toList(),
    );
  }

  // RF-20: Crear un parqueadero (admin).
  Future<void> crearParqueadero(Parqueadero p) async {
    await _col.add(p.toMap());
  }

  // RF-20 + RF-21: Editar los datos de un parqueadero existente.
  Future<void> actualizarParqueadero(
      String id, Map<String, dynamic> datos) async {
    await _col.doc(id).update(datos);
  }

  // RF-20: Desactivar un parqueadero (borrado lógico).
  Future<void> desactivarParqueadero(String id) async {
    await _col.doc(id).update({'activo': false});
  }

  // RF-20: Reactivar un parqueadero desactivado.
  Future<void> reactivarParqueadero(String id) async {
    await _col.doc(id).update({'activo': true});
  }

  // RF-27: Ajusta la cantidad de espacios libres (+1 al salir, -1 al entrar).
  Future<void> cambiarEspacios(String id, int delta) async {
    await _col.doc(id).update({
      'espaciosLibres': FieldValue.increment(delta),
    });
  }

  // RF-13: Agrega o elimina un parqueadero de la lista de favoritos del usuario
  Future<void> alternarFavorito(String parqueaderoId, bool yaEsFavorito) async {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) throw 'No hay ninguna sesión activa.';

    final docRef = _db.collection('usuarios').doc(uid);

    if (yaEsFavorito) {
      // Si ya era favorito, lo removemos del arreglo en Firestore
      await docRef.update({
        'favoritos': FieldValue.arrayRemove([parqueaderoId])
      });
    } else {
      // Si no, lo agregamos usando arrayUnion para evitar duplicados
      await docRef.update({
        'favoritos': FieldValue.arrayUnion([parqueaderoId])
      });
    }
  }

  // RF-13: Escucha en tiempo real la lista de IDs favoritos del usuario actual
  Stream<DocumentSnapshot> escucharFavoritosUsuario() {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return _db.collection('usuarios').doc(uid).snapshots();
  }
} 