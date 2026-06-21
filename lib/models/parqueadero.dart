// Modelo de un parqueadero (RF-02).
class Parqueadero {
  final String nombre;
  final String direccion;
  final double latitud;
  final double longitud;
  final int espaciosLibres;

  const Parqueadero({
    required this.nombre,
    required this.direccion,
    required this.latitud,
    required this.longitud,
    required this.espaciosLibres,
  });
}