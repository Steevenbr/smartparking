import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/parqueadero.dart';
import '../services/parqueadero_service.dart';
import '../services/ubicacion_service.dart';
import 'detalle_parqueadero_screen.dart';

// RF-02: Búsqueda y Filtro de parqueaderos.
// RF-12: Cercanía por GPS.
// RF-13: Visualización de Parqueaderos Favoritos filtrados en el mapa.
// RF-14: Navegación «Cómo llegar» interna.
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

  String _filtroBusqueda = '';
  final _searchController = TextEditingController();

  // VARIABLE NUEVA: Controla si estamos viendo solo los favoritos o todos
  bool _verSoloFavoritos = false;

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
      body: StreamBuilder<DocumentSnapshot>(
        // Escuchamos primero al usuario para saber cuáles son sus IDs favoritos actuales
        stream: _parqueaderos.escucharFavoritosUsuario(),
        builder: (context, userSnapshot) {
          List<dynamic> favoritosIds = [];
          if (userSnapshot.hasData && userSnapshot.data!.exists) {
            final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
            favoritosIds = userData?['favoritos'] ?? [];
          }

          return StreamBuilder<List<Parqueadero>>(
            stream: _parqueaderos.escucharParqueaderos(),
            builder: (context, snapshot) {
              final todosLosGarajes = snapshot.data ?? [];

              // MODIFICADO: Aplicamos el filtro combinando la barra de búsqueda y el botón de favoritos del RF-13
              final garajesFiltrados = todosLosGarajes.where((p) {
                final query = _filtroBusqueda.toLowerCase();
                final matchesNombre = p.nombre.toLowerCase().contains(query);

                if (_verSoloFavoritos) {
                  return matchesNombre && favoritosIds.contains(p.id);
                }
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
                      _panelCercanos(garajesFiltrados, favoritosIds),
                    ],
                  ),

                  // RF-02 e RF-13: Interfaz superior flotante con barra de búsqueda e interruptor de favoritos
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: [
                        Expanded(
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
                        const SizedBox(width: 8),
                        // BOTÓN DE FILTRO RÁPIDO PARA VER FAVORITOS
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _verSoloFavoritos = !_verSoloFavoritos;
                            });
                          },
                          child: Container(
                            height: 48,
                            width: 48,
                            decoration: BoxDecoration(
                              color: _verSoloFavoritos ? Colors.red : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))
                              ],
                            ),
                            child: Icon(
                              _verSoloFavoritos ? Icons.favorite : Icons.favorite_border,
                              color: _verSoloFavoritos ? Colors.white : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _panelCercanos(List<Parqueadero> garajes, List<dynamic> favoritosIds) {
    if (garajes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(_verSoloFavoritos
            ? 'No tienes parqueaderos guardados como favoritos.'
            : 'No se encontraron garajes.'),
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
            _verSoloFavoritos
                ? 'Mis Parqueaderos Favoritos'
                : (_miPosicion != null ? 'Resultados más cercanos a ti' : 'Resultados'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...ordenados.take(5).map((p) {
            String distancia = '';
            if (_miPosicion != null) {
              final m = _ubicacion.distanciaMetros(_miPosicion!.latitude, _miPosicion!.longitude, p.latitud, p.longitud);
              distancia = m > 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '${m.toStringAsFixed(0)} m';
            }

            final bool esFav = favoritosIds.contains(p.id);

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
                  const SizedBox(width: 4),

                  IconButton(
                    icon: Icon(
                      esFav ? Icons.favorite : Icons.favorite_border,
                      color: esFav ? Colors.red : Colors.grey,
                      size: 22,
                    ),
                    tooltip: esFav ? 'Quitar de favoritos' : 'Guardar en favoritos',
                    onPressed: () async {
                      try {
                        await _parqueaderos.alternarFavorito(p.id, esFav);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al modificar favoritos: $e')),
                        );
                      }
                    },
                  ),

                  IconButton(
                    icon: const Icon(Icons.navigation, color: Colors.blue, size: 22),
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