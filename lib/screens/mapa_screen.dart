import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart'; // Librería para lanzar la navegación
import '../models/parqueadero.dart';
import '../services/parqueadero_service.dart';
import '../services/ubicacion_service.dart';
import 'detalle_parqueadero_screen.dart';

// RF-02 y RF-12: mapa interactivo con los garajes agregados y cercanía por GPS.
// RF-14: Navegación «Cómo llegar» integrada de forma exclusiva para Android.
class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  final _parqueaderos = ParqueaderoService();
  final _ubicacion = UbicacionService();
  final _mapController = MapController();
  Position? _miPosicion;

  static const LatLng _centroDefault = LatLng(-0.9333, -78.6167);

  @override
  void initState() {
    super.initState();
    _ubicarme();
  }

  Future<void> _ubicarme() async {
    final pos = await _ubicacion.obtenerPosicion();
    if (pos != null && mounted) {
      setState(() => _miPosicion = pos);
      _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
    }
  }

  // RF-14: Navegación «Cómo llegar» corregida y optimizada al 100% para Android
  Future<void> _trazarRutaComoLlegar(double lat, double lng) async {
    // Intentamos abrir la aplicación nativa de Google Maps en modo navegación directa
    final String googleMapsIntent = 'google.navigation:q=$lat,$lng&mode=d';

    // URL web alternativa oficial de Google Maps que traza la ruta desde la ubicación actual
    final String googleMapsWeb = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving';

    final Uri intentUri = Uri.parse(googleMapsIntent);
    final Uri webUri = Uri.parse(googleMapsWeb);

    try {
      // Intentamos lanzar el intent nativo de Android primero
      if (await canLaunchUrl(intentUri)) {
        await launchUrl(intentUri);
      } else {
        // Si el emulador no tiene la app nativa instalada, forzamos la apertura en el navegador de Android
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir la navegación GPS: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa del Parqueadero'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Mi ubicación',
            onPressed: _ubicarme,
          ),
        ],
      ),
      body: StreamBuilder<List<Parqueadero>>(
        stream: _parqueaderos.escucharParqueaderos(),
        builder: (context, snapshot) {
          final garajes = snapshot.data ?? [];

          final marcadores = garajes
              .map((p) => Marker(
            point: LatLng(p.latitud, p.longitud),
            width: 44,
            height: 44,
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      DetalleParqueaderoScreen(parqueadero: p),
                ),
              ),
              child: Icon(
                Icons.location_on,
                size: 44,
                color: p.espaciosLibres > 0 ? Colors.green : Colors.red,
              ),
            ),
          ))
              .toList();

          if (_miPosicion != null) {
            marcadores.add(
              Marker(
                point: LatLng(_miPosicion!.latitude, _miPosicion!.longitude),
                width: 30,
                height: 30,
                child: const Icon(Icons.my_location,
                    color: kPrimary, size: 28),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _miPosicion != null
                        ? LatLng(_miPosicion!.latitude, _miPosicion!.longitude)
                        : _centroDefault,
                    initialZoom: 14,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.smart_parking',
                    ),
                    MarkerLayer(markers: marcadores),
                  ],
                ),
              ),
              _panelCercanos(garajes),
            ],
          );
        },
      ),
    );
  }

  Widget _panelCercanos(List<Parqueadero> garajes) {
    if (garajes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No hay garajes registrados todavía.'),
      );
    }

    List<Parqueadero> ordenados = List.from(garajes);
    if (_miPosicion != null) {
      ordenados.sort((a, b) {
        final da = _ubicacion.distanciaMetros(_miPosicion!.latitude,
            _miPosicion!.longitude, a.latitud, a.longitud);
        final db = _ubicacion.distanciaMetros(_miPosicion!.latitude,
            _miPosicion!.longitude, b.latitud, b.longitud);
        return da.compareTo(db);
      });
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            _miPosicion != null ? 'Garajes más cercanos a ti' : 'Garajes',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...ordenados.take(5).map((p) {
            String distancia = '';
            if (_miPosicion != null) {
              final m = _ubicacion.distanciaMetros(_miPosicion!.latitude,
                  _miPosicion!.longitude, p.latitud, p.longitud);
              distancia = m > 1000
                  ? '${(m / 1000).toStringAsFixed(1)} km'
                  : '${m.toStringAsFixed(0)} m';
            }
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.local_parking,
                  color: p.espaciosLibres > 0 ? Colors.green : Colors.red),
              title: Text(p.nombre),
              subtitle:
              Text('Libres: ${p.espaciosLibres} / ${p.espaciosTotales}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (distancia.isNotEmpty)
                    Text(distancia,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  // RF-14: Botón directo para iniciar la navegación GPS en Android
                  IconButton(
                    icon: const Icon(Icons.navigation, color: Colors.blue),
                    tooltip: 'Cómo llegar',
                    onPressed: () => _trazarRutaComoLlegar(p.latitud, p.longitud),
                  ),
                ],
              ),
              onTap: () {
                _mapController.move(LatLng(p.latitud, p.longitud), 16);
              },
            );
          }),
        ],
      ),
    );
  }
}