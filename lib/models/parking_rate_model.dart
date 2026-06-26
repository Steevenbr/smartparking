// lib/models/parking_rate_model.dart
class ParkingRateModel {
  final String parkingId;
  final double ratePerHour;
  final DateTime entryTime;

  ParkingRateModel({
    required this.parkingId, 
    required this.ratePerHour, 
    required this.entryTime
  });
}