import 'package:geolocator/geolocator.dart';
import '../models/parqueadero.dart';

// Servicio de parqueaderos (RF-02).
// Trae una lista de ejemplo y obtiene la ubicación actual del usuario.
class ParqueaderoService {
  // Lista simulada (en un proyecto real vendría de una base de datos o API).
  // Coordenadas de ejemplo en Latacunga, Ecuador.
  List<Parqueadero> getParqueaderos() {
    return const [
      Parqueadero(
        nombre: 'Parqueadero Central',
        direccion: 'Calle Quito y Sánchez de Orellana',
        latitud: -0.9347,
        longitud: -78.6156,
        espaciosLibres: 12,
      ),
      Parqueadero(
        nombre: 'Parking La Estación',
        direccion: 'Av. Marco Aurelio Subía',
        latitud: -0.9305,
        longitud: -78.6189,
        espaciosLibres: 5,
      ),
      Parqueadero(
        nombre: 'Estacionamiento El Salto',
        direccion: 'Mercado El Salto',
        latitud: -0.9361,
        longitud: -78.6142,
        espaciosLibres: 0,
      ),
      Parqueadero(
        nombre: 'Parqueadero La Cocha',
        direccion: 'Av. Unidad Nacional',
        latitud: -0.9412,
        longitud: -78.6098,
        espaciosLibres: 20,
      ),
      Parqueadero(
        nombre: 'Parking Plaza',
        direccion: 'Plaza de San Francisco',
        latitud: -0.9338,
        longitud: -78.6175,
        espaciosLibres: 8,
      ),
    ];
  }

  // Obtiene la ubicación actual del usuario por GPS.
  Future<Position> getUbicacionActual() async {
    // Verifica que el servicio de ubicación esté activo.
    bool servicioActivo = await Geolocator.isLocationServiceEnabled();
    if (!servicioActivo) {
      throw 'El servicio de ubicación está desactivado.';
    }

    // Verifica y pide permisos.
    LocationPermission permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied) {
        throw 'Permiso de ubicación denegado.';
      }
    }
    if (permiso == LocationPermission.deniedForever) {
      throw 'Permiso de ubicación denegado permanentemente.';
    }

    return await Geolocator.getCurrentPosition();
  }

  // Calcula la distancia en metros entre dos puntos.
  double distanciaMetros(
      double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }
}