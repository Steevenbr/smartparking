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
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      await _db.collection('usuarios').doc(cred.user!.uid).set({
        'nombre': nombre.trim(),
        'email': email.trim(),
        'rol': rol, // RF-22
        'favoritos': [], // RF-13: Inicializa la lista vacía para evitar nulos en favoritos
        'creadoEn': Timestamp.now(),
      });
    } catch (e) {
      throw _manejarErrorAuth(e);
    }
  }

  // RF-01: Inicio de sesión.
  Future<void> iniciarSesion(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } catch (e) {
      throw _manejarErrorAuth(e);
    }
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

  // RF-10: Recuperación de contraseña (dentro de la clase de manera correcta)
  Future<void> recuperarContrasena(String email) async {
    try {
      await _auth.setLanguageCode("es"); // Asegura el correo en español
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      throw _manejarErrorAuth(e);
    }
  }

  // NUEVA FUNCIÓN: Permite cambiar el correo electrónico del usuario (Auth + Firestore)
  Future<void> actualizarEmail(String nuevoEmail) async {
    final user = _auth.currentUser;
    final id = uid;

    if (user == null || id.isEmpty) {
      throw 'No hay ninguna sesión activa.';
    }

    try {
      // 1. Envía correo de confirmación al nuevo mail y lo encola para actualización en Auth
      await user.verifyBeforeUpdateEmail(nuevoEmail.trim());

      // 2. Sincroniza el nuevo email en el documento de la base de datos de Firestore
      await _db.collection('usuarios').doc(id).update({
        'email': nuevoEmail.trim(),
      });
    } catch (e) {
      throw _manejarErrorAuth(e);
    }
  }

  // Estructura para centralizar y mapear los errores comunes de Firebase Auth
  String _manejarErrorAuth(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No existe ningún usuario registrado con este correo.';
        case 'wrong-password':
          return 'La contraseña ingresada es incorrecta.';
        case 'email-already-in-use':
          return 'Este correo electrónico ya se encuentra registrado.';
        case 'invalid-email':
          return 'El formato del correo electrónico no es válido.';
        case 'weak-password':
          return 'La contraseña es demasiado débil (mínimo 6 caracteres).';
        case 'requires-recent-login':
          return 'Por seguridad, esta acción requiere que vuelvas a iniciar sesión recientemente.';
        default:
          return e.message ?? 'Ocurrió un error en la autenticación.';
      }
    }
    return e.toString();
  }

  // RF-11: Actualiza los datos de perfil y vehículo del usuario en Firestore
  Future<void> actualizarPerfilYVehiculo({
    required String nombre,
    required String placa,
    required String modelo,
    required String color,
  }) async {
    final id = uid;
    if (id.isEmpty) throw 'No hay ninguna sesión activa.';

    try {
      await _db.collection('usuarios').doc(id).update({
        'nombre': nombre.trim(),
        'vehiculo': {
          'placa': placa.trim().toUpperCase(),
          'modelo': modelo.trim(),
          'color': color.trim(),
        },
        'actualizadoEn': Timestamp.now(),
      });
    } catch (e) {
      throw 'Error al actualizar los datos: $e';
    }
  }
}