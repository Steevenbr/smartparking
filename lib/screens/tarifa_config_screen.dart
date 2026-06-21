import 'package:flutter/material.dart';
import '../models/tarifa_config.dart';
import '../services/tarifa_service.dart';

// Pantalla de configuración de tarifas y horarios (RF-21). Solo para administrador.
class TarifaConfigScreen extends StatefulWidget {
  const TarifaConfigScreen({super.key});

  @override
  State<TarifaConfigScreen> createState() => _TarifaConfigScreenState();
}

class _TarifaConfigScreenState extends State<TarifaConfigScreen> {
  final _service = TarifaService();
  final _horaCtrl = TextEditingController();
  final _fraccionCtrl = TextEditingController();
  final _minutosCtrl = TextEditingController();
  String _apertura = '08:00';
  String _cierre = '20:00';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final config = await _service.getConfig();
    _horaCtrl.text = config.tarifaHora.toString();
    _fraccionCtrl.text = config.tarifaFraccion.toString();
    _minutosCtrl.text = config.minutosFraccion.toString();
    _apertura = config.horaApertura;
    _cierre = config.horaCierre;
    setState(() => _loading = false);
  }

  Future<void> _pickHora(bool esApertura) async {
    final partes = (esApertura ? _apertura : _cierre).split(':');
    final inicial = TimeOfDay(
        hour: int.tryParse(partes[0]) ?? 8,
        minute: int.tryParse(partes[1]) ?? 0);
    final elegida = await showTimePicker(context: context, initialTime: inicial);
    if (elegida == null) return;
    final texto =
        '${elegida.hour.toString().padLeft(2, '0')}:${elegida.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (esApertura) {
        _apertura = texto;
      } else {
        _cierre = texto;
      }
    });
  }

  Future<void> _guardar() async {
    final config = TarifaConfig(
      tarifaHora: double.tryParse(_horaCtrl.text) ?? 0,
      tarifaFraccion: double.tryParse(_fraccionCtrl.text) ?? 0,
      minutosFraccion: int.tryParse(_minutosCtrl.text) ?? 15,
      horaApertura: _apertura,
      horaCierre: _cierre,
    );
    await _service.saveConfig(config);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuración guardada correctamente.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Tarifas y horarios')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Tarifas',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: _horaCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Tarifa por hora (\$)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _fraccionCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Tarifa por fracción (\$)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.money),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _minutosCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minutos por fracción',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.timelapse),
                hintText: 'Ej. 15',
              ),
            ),
            const SizedBox(height: 28),
            const Text('Horario de atención',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              leading: const Icon(Icons.wb_sunny_outlined),
              title: const Text('Hora de apertura'),
              trailing: Text(_apertura,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              onTap: () => _pickHora(true),
            ),
            const SizedBox(height: 12),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              leading: const Icon(Icons.nightlight_outlined),
              title: const Text('Hora de cierre'),
              trailing: Text(_cierre,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              onTap: () => _pickHora(false),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _guardar,
              child: const Text('Guardar configuración'),
            ),
          ],
        ),
      ),
    );
  }
}