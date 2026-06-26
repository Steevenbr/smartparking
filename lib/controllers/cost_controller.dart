// lib/controllers/cost_controller.dart
import '../models/parking_rate_model.dart';

class CostController {
  // RF-15: Cálculo preciso del costo basado en tiempo transcurrido
  double calculateCost(ParkingRateModel model) {
    final duration = DateTime.now().difference(model.entryTime);
    final totalHours = duration.inMinutes / 60.0;
    return totalHours * model.ratePerHour;
  }
}