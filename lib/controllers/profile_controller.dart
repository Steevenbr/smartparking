// lib/controllers/profile_controller.dart
import '../models/profile_model.dart';

class ProfileController {
  // RF-11: Lógica para procesar la edición del vehículo
  Future<bool> saveProfileChanges(ProfileModel profile) async {
    try {
      // Aquí iría la llamada a Firestore: 'users/{uid}/vehicle'
      print("Guardando datos: ${profile.plate}, ${profile.model}");
      return true;
    } catch (e) {
      return false;
    }
  }
}