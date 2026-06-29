import 'package:geolocator/geolocator.dart';

// Servicio de ubicación del usuario (RF-02, RF-12).
class UbicacionService {
  // Pide permiso y devuelve la posición actual. Si no se puede, devuelve null.
  Future<Position?> obtenerPosicion() async {
    // ¿Está activado el GPS del dispositivo?
    final servicioActivo = await Geolocator.isLocationServiceEnabled();
    if (!servicioActivo) return null;

    // Revisa y pide permiso de ubicación.
    LocationPermission permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition();
  }

  // Distancia en metros entre dos puntos.
  double distanciaMetros(
      double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }
}
