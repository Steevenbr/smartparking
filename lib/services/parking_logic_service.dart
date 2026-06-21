// lib/services/parking_logic_service.dart
import 'package:url_launcher/url_launcher.dart';

class ParkingLogicService {
  // RF-12: Lógica de filtrado
  List<dynamic> filterParkings(List<dynamic> list, String query) {
    return list.where((p) => p.name.toLowerCase().contains(query.toLowerCase())).toList();
  }

  // RF-13: Favoritos
  Future<void> toggleFavorite(String parkingId) async {
    // Implementar lógica de guardado en subcolección 'favoritos'
  }

  // RF-14: Navegación (Cómo llegar)
  static Future<void> launchMaps(double lat, double lng) async {
    final url = Uri.parse('google.navigation:q=$lat,$lng');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}