import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/parqueadero.dart';
import '../services/parqueadero_service.dart';
import 'disponibilidad_screen.dart';

// RF-06 y RF-23: calculadora de tarifa usando la tarifa y fracción del GARAJE.
class TarifasScreen extends StatefulWidget {
  const TarifasScreen({super.key});

  @override
  State<TarifasScreen> createState() => _TarifasScreenState();
}

class _TarifasScreenState extends State<TarifasScreen> {
  final _parqueaderos = ParqueaderoService();
  final _minutosCtrl = TextEditingController(text: '90');

  String? _garajeId;
  List<Parqueadero> _lista = [];
  double _resultado = 0;

  // Devuelve el garaje seleccionado (o null).
  Parqueadero? _garajeSeleccionado() {
    for (final p in _lista) {
      if (p.id == _garajeId) return p;
    }
    return null;
  }

  void _calcular() {
    final garaje = _garajeSeleccionado();
    if (garaje == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un garaje primero.')),
      );
      return;
    }
    final minutos = int.tryParse(_minutosCtrl.text) ?? 0;
    final minutosCobrados = minutos < 1 ? 1 : minutos;
    final fracciones = (minutosCobrados / garaje.minutosFraccion).ceil();
    setState(() => _resultado = fracciones * garaje.precioFraccion);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cálculo de Tarifas')),
      body: StreamBuilder<List<Parqueadero>>(
        stream: _parqueaderos.escucharParqueaderos(),
        builder: (context, snapshot) {
          _lista = snapshot.data ?? [];
          if (_garajeId != null && !_lista.any((p) => p.id == _garajeId)) {
            _garajeId = null;
          }
          final garaje = _garajeSeleccionado();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Garaje',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _garajeId,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(border: OutlineInputBorder()),
                  hint: const Text('Selecciona un garaje'),
                  items: _lista
                      .map((p) => DropdownMenuItem<String>(
                            value: p.id,
                            child: Text('${p.nombre}  (\$${p.tarifaHora}/h)',
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _garajeId = v;
                    _resultado = 0;
                  }),
                ),
                const SizedBox(height: 20),

                // Tarjeta con la tarifa del garaje elegido.
                Card(
                  color: kAccentSoft,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tarifa del garaje',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(garaje == null
                            ? 'Elige un garaje para ver su tarifa.'
                            : '• \$${garaje.tarifaHora} por hora'),
                        if (garaje != null) ...[
                          Text(
                              '• \$${garaje.precioFraccion.toStringAsFixed(2)} por cada ${garaje.minutosFraccion} minutos'),
                          Text(
                              '• Horario: ${garaje.horaApertura} a ${garaje.horaCierre}'),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                const Text('Simular costo por tiempo',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                TextField(
                  controller: _minutosCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Minutos de estancia',
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
                        color: kAccent),
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
                    MaterialPageRoute(
                        builder: (_) => const DisponibilidadScreen()),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
