import 'package:flutter/material.dart';
import '../models/parqueadero.dart';
import '../services/parqueadero_service.dart';
import 'tarifa_config_screen.dart';

// Panel administrador (RF-20 y RF-21).
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel Administrador')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _opcion(
            context,
            icon: Icons.attach_money,
            color: Colors.teal,
            titulo: 'Tarifas y horarios',
            subtitulo: 'Configura el costo por fracción y el horario (RF-21)',
            destino: const TarifaConfigScreen(),
          ),
          _opcion(
            context,
            icon: Icons.add_business,
            color: Colors.indigo,
            titulo: 'Crear parqueadero',
            subtitulo: 'Agrega un nuevo parqueadero al sistema (RF-20)',
            onTap: () => _dialogoCrear(context),
          ),
        ],
      ),
    );
  }

  Widget _opcion(BuildContext context,
      {required IconData icon,
      required Color color,
      required String titulo,
      required String subtitulo,
      Widget? destino,
      VoidCallback? onTap}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(titulo,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitulo),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap ??
            () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => destino!),
                ),
      ),
    );
  }

  void _dialogoCrear(BuildContext context) {
    final nombreCtrl = TextEditingController();
    final dirCtrl = TextEditingController();
    final espaciosCtrl = TextEditingController(text: '20');
    final tarifaCtrl = TextEditingController(text: '1.0');
    final latCtrl = TextEditingController(text: '-0.9333');
    final longCtrl = TextEditingController(text: '-78.6167');
    final service = ParqueaderoService();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo parqueadero'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: dirCtrl,
                decoration: const InputDecoration(labelText: 'Dirección'),
              ),
              TextField(
                controller: espaciosCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Espacios totales'),
              ),
              TextField(
                controller: tarifaCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Tarifa por hora (\$)'),
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
                  const SnackBar(content: Text('Parqueadero creado.')),
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
