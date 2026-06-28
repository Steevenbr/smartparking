import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Servicio de autenticación y datos de usuario (RF-01, RF-22).
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get usuarioActual => _auth.currentUser;

  // RF-01: Registro. Crea el usuario en Auth y guarda su perfil en Firestore.
  Future<void> registrar({
    required String nombre,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    // Guarda el perfil en la colección 'usuarios' con su rol por defecto.
    await _db.collection('usuarios').doc(cred.user!.uid).set({
      'nombre': nombre.trim(),
      'email': email.trim(),
      'rol': 'conductor', // RF-22: rol por defecto
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

  // RF-22: Devuelve el rol del usuario ('conductor' o 'admin').
  Future<String> obtenerRol() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 'conductor';
    final doc = await _db.collection('usuarios').doc(uid).get();
    if (!doc.exists) return 'conductor';
    return (doc.data()?['rol'] ?? 'conductor') as String;
  }

  // RF-09: Cierre de sesión.
  Future<void> cerrarSesion() async => await _auth.signOut();

  // RF-10: Recuperación de contraseña.
  Future<void> recuperarPassword(String email) async =>
      await _auth.sendPasswordResetEmail(email: email.trim());
}
