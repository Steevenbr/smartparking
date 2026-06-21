// lib/services/user_management_service.dart
import 'package:firebase_auth/firebase_auth.dart';

class UserManagementService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // RF-09: Cierre de sesión seguro
  Future<void> signOut() async => await _auth.signOut();

  // RF-10: Recuperación de contraseña
  Future<void> sendPasswordReset(String email) async => 
      await _auth.sendPasswordResetEmail(email: email);

  // RF-11: Actualizar perfil (placeholder para lógica Firestore)
  Future<void> updateProfileData(String plate, String model) async {
    // Implementar lógica de escritura en Firestore: 'users/{uid}'
  }
}