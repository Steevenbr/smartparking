import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../models/parqueadero.dart';
import '../services/parqueadero_service.dart';
import '../services/ubicacion_service.dart';
import 'detalle_parqueadero_screen.dart';

// RF-02: Geolocalización y BÚSQUEDA de parqueaderos (Filtro por nombre/ubicación).
// RF-12: Cercanía por GPS.
// RF-14: Navegación «Cómo llegar» integrada de forma interna.
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

  List<LatLng> _puntosRuta = [];
  bool _cargandoRuta = false;

  // Variable de control para el buscador del RF-02
  String _filtroBusqueda = '';
  final _searchController = TextEditingController();

  static const LatLng _centroDefault = LatLng(-0.9333, -78.6167);

  @override
  void initState() {
    super.initState();
    _ubicarme();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _ubicarme() async {
    final pos = await _ubicacion.obtenerPosicion();
    if (pos != null && mounted) {
      setState(() => _miPosicion = pos);
      _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
    }
  }

  Future<void> _obtenerRutaInterna(double latDestino, double lngDestino) async {
    if (_miPosicion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se puede trazar la ruta sin tu ubicación GPS.')),
      );
      return;
    }

    setState(() {
      _cargandoRuta = true;
      _puntosRuta.clear();
    });

    final double latOrigen = _miPosicion!.latitude;
    final double lngOrigen = _miPosicion!.longitude;
    final String url =
        'https://router.project-osrm.org/route/v1/driving/$lngOrigen,$latOrigen;$lngDestino,$latDestino?overview=full&geometries=geojson';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final List coordinates = data['routes'][0]['geometry']['coordinates'];
          final listaPuntos = coordinates.map((c) => LatLng(c[1] as double, c[0] as double)).toList();

          setState(() {
            _puntosRuta = listaPuntos;
          });
          _mapController.move(LatLng(latDestino, lngDestino), 15);
        }
      } else {
        throw 'Error en el servicio de rutas';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo calcular la ruta: $e')),
        );
      }
    } finally {
      setState(() {
        _cargandoRuta = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa del Parqueadero'),
        actions: [
          if (_cargandoRuta)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
              ),
            ),
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
          final todosLosGarajes = snapshot.data ?? [];

          // RF-02: Filtramos los parqueaderos en tiempo real según el texto ingresado (Nombre o Ubicación)
          final garajesFiltrados = todosLosGarajes.where((p) {
            final query = _filtroBusqueda.toLowerCase();
            final matchesNombre = p.nombre.toLowerCase().contains(query);
            // Si tu modelo 'Parqueadero' tiene un campo dirección/ubicación lo puedes concatenar aquí
            return matchesNombre;
          }).toList();

          final marcadores = garajesFiltrados
              .map((p) => Marker(
            point: LatLng(p.latitud, p.longitud),
            width: 44,
            height: 44,
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetalleParqueaderoScreen(parqueadero: p),
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
                child: const Icon(Icons.my_location, color: kPrimary, size: 28),
              ),
            );
          }

          return Stack(
            children: [
              Column(
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
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.smart_parking',
                        ),
                        if (_puntosRuta.isNotEmpty)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _puntosRuta,
                                color: Colors.blueAccent,
                                strokeWidth: 5.0,
                              ),
                            ],
                          ),
                        MarkerLayer(markers: marcadores),
                      ],
                    ),
                  ),
                  _panelCercanos(garajesFiltrados),
                ],
              ),

              // RF-02: Interfaz superior flotante de la barra de búsqueda
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o ubicación...',
                      border: InputBorder.none,
                      icon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _filtroBusqueda.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _filtroBusqueda = '';
                          });
                        },
                      )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _filtroBusqueda = value;
                      });
                    },
                  ),
                ),
              ),
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
        child: Text('No se encontraron garajes.'),
      );
    }

    List<Parqueadero> ordenados = List.from(garajes);
    if (_miPosicion != null) {
      ordenados.sort((a, b) {
        final da = _ubicacion.distanciaMetros(_miPosicion!.latitude, _miPosicion!.longitude, a.latitud, a.longitud);
        final db = _ubicacion.distanciaMetros(_miPosicion!.latitude, _miPosicion!.longitude, b.latitud, b.longitud);
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
            _miPosicion != null ? 'Resultados más cercanos a ti' : 'Resultados',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...ordenados.take(5).map((p) {
            String distancia = '';
            if (_miPosicion != null) {
              final m = _ubicacion.distanciaMetros(_miPosicion!.latitude, _miPosicion!.longitude, p.latitud, p.longitud);
              distancia = m > 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '${m.toStringAsFixed(0)} m';
            }
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.local_parking, color: p.espaciosLibres > 0 ? Colors.green : Colors.red),
              title: Text(p.nombre),
              subtitle: Text('Libres: ${p.espaciosLibres} / ${p.espaciosTotales}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (distancia.isNotEmpty)
                    Text(distancia, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.navigation, color: Colors.blue),
                    tooltip: 'Cómo llegar',
                    onPressed: () => _obtenerRutaInterna(p.latitud, p.longitud),
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