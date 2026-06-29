import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/parqueadero.dart';
import '../services/parqueadero_service.dart';
import '../services/ubicacion_service.dart';
import 'detalle_parqueadero_screen.dart';

// RF-02 y RF-12: mapa interactivo con los garajes agregados y cercania por GPS.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa del Parqueadero'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Mi ubicacion',
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
        child: Text('No hay garajes registrados todavia.'),
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
            _miPosicion != null ? 'Garajes mas cercanos a ti' : 'Garajes',
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
              trailing: distancia.isNotEmpty
                  ? Text(distancia,
                      style: const TextStyle(fontWeight: FontWeight.bold))
                  : null,
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
