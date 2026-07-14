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

// RF-02: Geolocalización en tiempo real.
// RF-12: Búsqueda y filtrado avanzado (Nombre, dirección, distancia, precio y disponibilidad).
// RF-13: Parqueaderos favoritos.
// RF-14: Navegación interna «Cómo llegar».
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

  // Variables de control de búsqueda y filtros (RF-12)
  String _filtroBusqueda = '';
  final _searchController = TextEditingController();
  bool _verSoloFavoritos = false;

  // Estado de los filtros avanzados (RF-12)
  double _maxDistanciaKm = 10.0; // Distancia máxima por defecto
  double _maxPrecioHora = 5.0;   // Tarifa por hora máxima por defecto
  bool _soloDisponibles = false; // Filtrar por espacios libres > 0

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

  // Muestra el modal inferior con los controles deslizantes de filtros (RF-12)
  void _mostrarPanelFiltros() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filtros de Parqueaderos',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),

                  // Filtro de Distancia (RF-12)
                  Text(
                    'Distancia máxima: ${_maxDistanciaKm.toStringAsFixed(1)} km',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Slider(
                    value: _maxDistanciaKm,
                    min: 1.0,
                    max: 20.0,
                    divisions: 19,
                    activeColor: kPrimary,
                    onChanged: (val) {
                      setModalState(() => _maxDistanciaKm = val);
                      setState(() => _maxDistanciaKm = val);
                    },
                  ),

                  // Filtro de Precio (RF-12)
                  Text(
                    'Precio máximo por hora: \$${_maxPrecioHora.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Slider(
                    value: _maxPrecioHora,
                    min: 0.5,
                    max: 5.0,
                    divisions: 9,
                    activeColor: kPrimary,
                    onChanged: (val) {
                      setModalState(() => _maxPrecioHora = val);
                      setState(() => _maxPrecioHora = val);
                    },
                  ),

                  // Filtro de Disponibilidad (RF-12)
                  SwitchListTile(
                    title: const Text('Mostrar solo disponibles (con espacios)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    contentPadding: EdgeInsets.zero,
                    value: _soloDisponibles,
                    activeThumbColor: kPrimary,
                    onChanged: (val) {
                      setModalState(() => _soloDisponibles = val);
                      setState(() => _soloDisponibles = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Botón para resetear filtros
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: kPrimary),
                      ),
                      onPressed: () {
                        setModalState(() {
                          _maxDistanciaKm = 10.0;
                          _maxPrecioHora = 5.0;
                          _soloDisponibles = false;
                        });
                        setState(() {
                          _maxDistanciaKm = 10.0;
                          _maxPrecioHora = 5.0;
                          _soloDisponibles = false;
                        });
                      },
                      child: const Text('Restablecer Filtros', style: TextStyle(color: kPrimary)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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

              // Lógica combinada de búsqueda y filtrado avanzado (RF-12)
              final garajesFiltrados = todosLosGarajes.where((p) {
                final query = _filtroBusqueda.toLowerCase();

                // 1. Filtrado por Nombre o Dirección
                final matchesNombre = p.nombre.toLowerCase().contains(query);
                final matchesDireccion = p.direccion.toLowerCase().contains(query);
                final matchesBusqueda = matchesNombre || matchesDireccion;

                // 2. Filtrado por Precio máximo por hora
                final matchesPrecio = p.tarifaHora <= _maxPrecioHora;

                // 3. Filtrado por Disponibilidad (Espacios libres)
                final matchesDisponibilidad = !_soloDisponibles || (p.espaciosLibres > 0);

                // 4. Filtrado por Distancia GPS
                bool matchesDistancia = true;
                if (_miPosicion != null) {
                  final distMetros = _ubicacion.distanciaMetros(
                    _miPosicion!.latitude, _miPosicion!.longitude, p.latitud, p.longitud,
                  );
                  matchesDistancia = (distMetros / 1000.0) <= _maxDistanciaKm;
                }

                // 5. Filtro de Favoritos (RF-13)
                if (_verSoloFavoritos) {
                  return matchesBusqueda && matchesPrecio && matchesDisponibilidad && matchesDistancia && favoritosIds.contains(p.id);
                }

                return matchesBusqueda && matchesPrecio && matchesDisponibilidad && matchesDistancia;
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

                  // Barra superior flotante con Buscador, Filtros Avanzados (RF-12) y Favoritos (RF-13)
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
                                hintText: 'Buscar por nombre o dirección...',
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

                        // BOTÓN DE FILTROS AVANZADOS (RF-12)
                        GestureDetector(
                          onTap: _mostrarPanelFiltros,
                          child: Container(
                            height: 48,
                            width: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))
                              ],
                            ),
                            child: const Icon(Icons.filter_list_rounded, color: kPrimary),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // BOTÓN DE FAVORITOS (RF-13)
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
            : 'No se encontraron parqueaderos con los filtros aplicados.'),
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
              subtitle: Text('Libres: ${p.espaciosLibres} / ${p.espaciosTotales} · \$${p.tarifaHora}/h'),
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