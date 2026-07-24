import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Servicio de autenticación y datos de usuario (RF-01, RF-22).
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get usuarioActual => _auth.currentUser;
  String get uid => _auth.currentUser?.uid ?? '';

  // 🚗 Verifica si el usuario tiene registrados la placa, modelo y color de su vehículo
  Future<bool> tieneDatosVehiculoCompletos() async {
    final id = uid;
    if (id.isEmpty) return false;

    try {
      final doc = await _db.collection('usuarios').doc(id).get();
      if (!doc.exists || doc.data() == null) return false;

      final data = doc.data()!;
      final placa = (data['placa'] ?? '').toString().trim();
      final modelo = (data['modelo_marca'] ?? data['modelo'] ?? '').toString().trim();
      final color = (data['color'] ?? '').toString().trim();

      return placa.isNotEmpty && modelo.isNotEmpty && color.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // RF-01 + RF-22: Registro con rol ('conductor' o 'dueno') y campos opcionales de vehículo.
  Future<void> registrar({
    required String nombre,
    required String email,
    required String password,
    required String rol,
    String placa = '',
    String modeloMarca = '',
    String color = '',
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // Guardar perfil en Firestore
      await _db.collection('usuarios').doc(cred.user!.uid).set({
        'nombre': nombre.trim(),
        'email': email.trim(),
        'rol': rol, // RF-22
        'favoritos': [], // RF-13
        'placa': placa.trim().toUpperCase(), // Campo opcional
        'modelo_marca': modeloMarca.trim(),  // Campo opcional
        'color': color.trim(),               // Campo opcional
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

  // RF-10: Recuperación de contraseña.
  Future<void> recuperarContrasena(String email) async {
    try {
      await _auth.setLanguageCode("es"); // Asegura el correo en español
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      throw _manejarErrorAuth(e);
    }
  }

  // Permite cambiar el correo electrónico del usuario (Auth + Firestore).
  Future<void> actualizarEmail(String nuevoEmail) async {
    final user = _auth.currentUser;
    final id = uid;

    if (user == null || id.isEmpty) {
      throw 'No hay ninguna sesión activa.';
    }

    try {
      // 1. Envía correo de confirmación al nuevo mail
      await user.verifyBeforeUpdateEmail(nuevoEmail.trim());

      // 2. Sincroniza en Firestore
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

  // RF-11: Actualiza los datos de perfil y vehículo del usuario en Firestore.
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
        'placa': placa.trim().toUpperCase(),
        'modelo_marca': modelo.trim(),
        'color': color.trim(),
        'actualizadoEn': Timestamp.now(),
      });
    } catch (e) {
      throw 'Error al actualizar los datos: $e';
    }
  }
}