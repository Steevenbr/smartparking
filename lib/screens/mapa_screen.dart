import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/parqueadero.dart';
import '../services/parqueadero_service.dart';

// Pantalla de geolocalización y búsqueda de parqueaderos (RF-02).
class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  final _service = ParqueaderoService();
  final _buscarCtrl = TextEditingController();

  List<Parqueadero> _todos = [];
  List<Parqueadero> _filtrados = [];
  Position? _miUbicacion;
  String _estado = 'Obteniendo ubicación...';
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    _todos = _service.getParqueaderos();
    _filtrados = List.from(_todos);

    try {
      final pos = await _service.getUbicacionActual();
      setState(() {
        _miUbicacion = pos;
        _estado = 'Ubicación obtenida';
        _ordenarPorDistancia();
        _cargando = false;
      });
    } catch (e) {
      // Si falla el GPS, igual mostramos la lista sin distancias.
      setState(() {
        _estado = 'No se pudo obtener tu ubicación: $e';
        _cargando = false;
      });
    }
  }

  void _ordenarPorDistancia() {
    if (_miUbicacion == null) return;
    _filtrados.sort((a, b) {
      final da = _service.distanciaMetros(_miUbicacion!.latitude,
          _miUbicacion!.longitude, a.latitud, a.longitud);
      final db = _service.distanciaMetros(_miUbicacion!.latitude,
          _miUbicacion!.longitude, b.latitud, b.longitud);
      return da.compareTo(db);
    });
  }

  void _buscar(String texto) {
    final q = texto.toLowerCase();
    setState(() {
      _filtrados = _todos.where((p) {
        return p.nombre.toLowerCase().contains(q) ||
            p.direccion.toLowerCase().contains(q);
      }).toList();
      _ordenarPorDistancia();
    });
  }

  String _distanciaTexto(Parqueadero p) {
    if (_miUbicacion == null) return '';
    final metros = _service.distanciaMetros(_miUbicacion!.latitude,
        _miUbicacion!.longitude, p.latitud, p.longitud);
    if (metros < 1000) return '${metros.toStringAsFixed(0)} m';
    return '${(metros / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parqueaderos cercanos')),
      body: Column(
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _buscarCtrl,
              onChanged: _buscar,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o ubicación',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // Estado del GPS
          if (_cargando)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    _miUbicacion != null
                        ? Icons.gps_fixed
                        : Icons.gps_off,
                    size: 16,
                    color: _miUbicacion != null ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_estado,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Lista de parqueaderos
            Expanded(
              child: _filtrados.isEmpty
                  ? const Center(child: Text('No se encontraron parqueaderos.'))
                  : ListView.builder(
                      itemCount: _filtrados.length,
                      itemBuilder: (context, i) {
                        final p = _filtrados[i];
                        final hayEspacio = p.espaciosLibres > 0;
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: hayEspacio
                                  ? Colors.green.shade100
                                  : Colors.red.shade100,
                              child: Icon(
                                Icons.local_parking,
                                color: hayEspacio ? Colors.green : Colors.red,
                              ),
                            ),
                            title: Text(p.nombre,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.direccion),
                                const SizedBox(height: 2),
                                Text(
                                  hayEspacio
                                      ? '${p.espaciosLibres} espacios libres'
                                      : 'Sin espacios',
                                  style: TextStyle(
                                    color:
                                        hayEspacio ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Text(
                              _distanciaTexto(p),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}