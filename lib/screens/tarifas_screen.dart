import 'package:flutter/material.dart';
import '../models/tarifa_config.dart';
import '../services/tarifa_service.dart';
import 'disponibilidad_screen.dart';

// RF-06 y RF-23: calculadora de tarifa con fracciones.
class TarifasScreen extends StatefulWidget {
  const TarifasScreen({super.key});

  @override
  State<TarifasScreen> createState() => _TarifasScreenState();
}

class _TarifasScreenState extends State<TarifasScreen> {
  final _tarifas = TarifaService();
  final _minutosCtrl = TextEditingController(text: '90');
  TarifaConfig _cfg = TarifaConfig();
  double _resultado = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final cfg = await _tarifas.getConfig();
    setState(() {
      _cfg = cfg;
      _loading = false;
    });
  }

  void _calcular() {
    final minutos = int.tryParse(_minutosCtrl.text) ?? 0;
    final minutosCobrados = minutos < 1 ? 1 : minutos;
    final fracciones = (minutosCobrados / _cfg.minutosFraccion).ceil();
    setState(() => _resultado = fracciones * _cfg.tarifaFraccion);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Cálculo de Tarifas')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.teal.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tarifa vigente',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('• \$${_cfg.tarifaFraccion} por cada ${_cfg.minutosFraccion} minutos'),
                    Text('• Horario: ${_cfg.horaApertura} a ${_cfg.horaCierre}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Simular costo por tiempo',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: _minutosCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minutos de estancia',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.timer_outlined),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _calcular,
              child: const Text('Calcular costo'),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                '\$${_resultado.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Se cobra por cada fracción empezada (RF-23).',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const Divider(height: 48),
            OutlinedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('Registrar entrada en un parqueadero'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DisponibilidadScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
