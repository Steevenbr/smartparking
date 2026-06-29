import 'package:flutter/material.dart';
import '../models/parqueadero.dart';
import '../services/parqueadero_service.dart';
import '../services/auth_service.dart';

// RF-20: el dueño gestiona sus propios garajes (crear, ver, desactivar).
class MisGarajesScreen extends StatelessWidget {
  const MisGarajesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = ParqueaderoService();
    final ownerId = AuthService().uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Garajes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _dialogoCrear(context, service, ownerId),
        icon: const Icon(Icons.add),
        label: const Text('Agregar garaje'),
      ),
      body: StreamBuilder<List<Parqueadero>>(
        stream: service.escucharMisGarajes(ownerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final lista = snapshot.data ?? [];
          if (lista.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aún no has registrado ningún garaje.\n'
                  'Toca "Agregar garaje" para crear el primero.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lista.length,
            itemBuilder: (context, i) {
              final p = lista[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.indigo,
                    child: Icon(Icons.store, color: Colors.white),
                  ),
                  title: Text(p.nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${p.direccion}\n'
                    'Capacidad: ${p.espaciosTotales}  ·  Libres: ${p.espaciosLibres}  ·  \$${p.tarifaHora}/h',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Desactivar',
                    onPressed: () => service.desactivarParqueadero(p.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _dialogoCrear(
      BuildContext context, ParqueaderoService service, String ownerId) {
    final nombreCtrl = TextEditingController();
    final dirCtrl = TextEditingController();
    final espaciosCtrl = TextEditingController(text: '20');
    final tarifaCtrl = TextEditingController(text: '1.0');
    final latCtrl = TextEditingController(text: '-0.9333');
    final longCtrl = TextEditingController(text: '-78.6167');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo garaje'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre del garaje'),
              ),
              TextField(
                controller: dirCtrl,
                decoration: const InputDecoration(labelText: 'Dirección'),
              ),
              TextField(
                controller: espaciosCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Capacidad (espacios)'),
              ),
              TextField(
                controller: tarifaCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Tarifa por hora (\$)'),
              ),
              TextField(
                controller: latCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                decoration: const InputDecoration(labelText: 'Latitud'),
              ),
              TextField(
                controller: longCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                decoration: const InputDecoration(labelText: 'Longitud'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tip: la latitud y longitud marcan el garaje en el mapa.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final espacios = int.tryParse(espaciosCtrl.text) ?? 0;
              final p = Parqueadero(
                ownerId: ownerId, // queda ligado al dueño (RF-20)
                nombre: nombreCtrl.text.trim(),
                direccion: dirCtrl.text.trim(),
                latitud: double.tryParse(latCtrl.text) ?? -0.9333,
                longitud: double.tryParse(longCtrl.text) ?? -78.6167,
                espaciosTotales: espacios,
                espaciosLibres: espacios,
                tarifaHora: double.tryParse(tarifaCtrl.text) ?? 1.0,
              );
              await service.crearParqueadero(p);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Garaje creado.')),
                );
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }
}
