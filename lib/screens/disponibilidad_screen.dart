import 'package:flutter/material.dart';
import '../models/parqueadero.dart';
import '../services/parqueadero_service.dart';
import 'detalle_parqueadero_screen.dart';

// RF-03 y RF-27: muestra los parqueaderos y su disponibilidad en tiempo real.
class DisponibilidadScreen extends StatelessWidget {
  const DisponibilidadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = ParqueaderoService();

    return Scaffold(
      appBar: AppBar(title: const Text('Espacios Disponibles')),
      body: StreamBuilder<List<Parqueadero>>(
        stream: service.escucharParqueaderos(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final lista = snapshot.data ?? [];
          if (lista.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_parking, size: 60, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'No hay parqueaderos registrados.\n'
                      'El administrador debe crearlos desde el Panel Administrador.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lista.length,
            itemBuilder: (context, i) {
              final p = lista[i];
              final lleno = p.espaciosLibres <= 0;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        lleno ? Colors.red.shade100 : Colors.green.shade100,
                    child: Icon(
                      Icons.local_parking,
                      color: lleno ? Colors.red : Colors.green,
                    ),
                  ),
                  title: Text(p.nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${p.direccion}\n'
                    'Libres: ${p.espaciosLibres} / ${p.espaciosTotales}  ·  \$${p.tarifaHora}/h',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetalleParqueaderoScreen(parqueadero: p),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
