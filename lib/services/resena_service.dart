import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ResenaService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _col => _db.collection('resenas');

  // Registrar una nueva reseña (Calificación + Comentario)
  Future<void> crearResena({
    required String parqueaderoId,
    required String parqueaderoNombre,
    required double calificacion,
    required String comentario,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw 'Debes iniciar sesión para publicar una reseña.';

    // Consultamos el nombre del perfil actual para asociarlo
    final snapUsuario = await _db.collection('usuarios').doc(user.uid).get();
    final Map<String, dynamic> dataUser = snapUsuario.exists
        ? (snapUsuario.data() as Map<String, dynamic>)
        : {};

    final String usuarioNombre = dataUser['nombre'] ?? dataUser['nombreCompleto'] ?? user.email ?? 'Conductor Anónimo';

    await _col.add({
      'usuarioId': user.uid,
      'usuarioNombre': usuarioNombre,
      'usuarioEmail': user.email ?? '',
      'parqueaderoId': parqueaderoId,
      'parqueaderoNombre': parqueaderoNombre,
      'calificacion': calificacion,
      'comentario': comentario,
      'creadoEn': Timestamp.now(),
    });
  }

  // Escuchar todas las reseñas globales o filtradas por parqueadero
  Stream<QuerySnapshot> escucharResenas({String? parqueaderoId}) {
    if (parqueaderoId != null && parqueaderoId.isNotEmpty) {
      return _col
          .where('parqueaderoId', isEqualTo: parqueaderoId)
          .snapshots();
    }
    return _col.snapshots();
  }
}