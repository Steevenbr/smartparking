import 'package:flutter/material.dart';
import '../models/parqueadero.dart';
import '../services/parqueadero_service.dart';
import 'detalle_parqueadero_screen.dart';

// RF-02 (versión sin Google Maps): muestra los parqueaderos con su ubicación.
class MapaScreen extends StatelessWidget {
  const MapaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = ParqueaderoService();
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa del Parqueadero')),
      body: StreamBuilder<List<Parqueadero>>(
        stream: service.escucharParqueaderos(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final lista = snapshot.data ?? [];
          if (lista.isEmpty) {
            return const Center(
              child: Text('No hay parqueaderos. Crea datos en "Espacios Disponibles".'),
            );
          }
          return Column(
            children: [
              Container(
                color: Colors.blue.shade50,
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Parqueaderos cercanos y sus coordenadas. '
                        'Toca uno para ver el detalle.',
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: lista.length,
                  itemBuilder: (context, i) {
                    final p = lista[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.purple,
                          child: Icon(Icons.place, color: Colors.white),
                        ),
                        title: Text(p.nombre),
                        subtitle: Text(
                          '${p.direccion}\nLat: ${p.latitud}  Long: ${p.longitud}',
                        ),
                        isThreeLine: true,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                DetalleParqueaderoScreen(parqueadero: p),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
