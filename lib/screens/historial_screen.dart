import 'package:flutter/material.dart';
import '../models/registro.dart';
import '../services/parking_logic_service.dart';

// RF-07: historial de estacionamientos del usuario.
class HistorialScreen extends StatelessWidget {
  const HistorialScreen({super.key});

  String _fecha(DateTime d) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(d.day)}/${dos(d.month)}/${d.year}  ${dos(d.hour)}:${dos(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final logic = ParkingLogicService();
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Historial')),
      body: StreamBuilder<List<Registro>>(
        stream: logic.escucharHistorial(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final lista = snapshot.data ?? [];
          // Ordena del más reciente al más antiguo.
          lista.sort((a, b) => b.horaEntrada.compareTo(a.horaEntrada));
          if (lista.isEmpty) {
            return const Center(
              child: Text('Aún no tienes registros de parqueo.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lista.length,
            itemBuilder: (context, i) {
              final r = lista[i];
              final activo = r.estado == 'activo';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        activo ? Colors.orange.shade100 : Colors.green.shade100,
                    child: Icon(
                      activo ? Icons.timelapse : Icons.check,
                      color: activo ? Colors.orange : Colors.green,
                    ),
                  ),
                  title: Text(r.parqueaderoNombre,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'Entrada: ${_fecha(r.horaEntrada)}\n'
                    '${r.horaSalida != null ? "Salida: ${_fecha(r.horaSalida!)}" : "En curso..."}',
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    activo ? '—' : '\$${r.costo.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
