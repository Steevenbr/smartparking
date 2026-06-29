import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Servicio de autenticación y datos de usuario (RF-01, RF-22).
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get usuarioActual => _auth.currentUser;
  String get uid => _auth.currentUser?.uid ?? '';

  // RF-01 + RF-22: Registro con rol ('conductor' o 'dueno').
  Future<void> registrar({
    required String nombre,
    required String email,
    required String password,
    required String rol,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    await _db.collection('usuarios').doc(cred.user!.uid).set({
      'nombre': nombre.trim(),
      'email': email.trim(),
      'rol': rol, // RF-22
      'creadoEn': Timestamp.now(),
    });
  }

  // RF-01: Inicio de sesión.
  Future<void> iniciarSesion(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  // RF-22: Devuelve el rol del usuario ('conductor' o 'dueno').
  Future<String> obtenerRol() async {
    final id = uid;
    if (id.isEmpty) return 'conductor';
    final doc = await _db.collection('usuarios').doc(id).get();
    if (!doc.exists) return 'conductor';
    return (doc.data()?['rol'] ?? 'conductor') as String;
  }

  // RF-09: Cierre de sesión.
  Future<void> cerrarSesion() async => await _auth.signOut();

  // RF-10: Recuperación de contraseña.
  Future<void> recuperarPassword(String email) async =>
      await _auth.sendPasswordResetEmail(email: email.trim());
}
