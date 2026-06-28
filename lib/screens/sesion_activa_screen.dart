import 'dart:async';
import 'package:flutter/material.dart';
import '../models/parqueadero.dart';
import '../models/tarifa_config.dart';
import '../services/parking_logic_service.dart';
import '../services/tarifa_service.dart';

// RF-15: muestra el tiempo y el costo acumulado en tiempo real.
// RF-06: registra la salida y calcula el costo final con fracciones.
class SesionActivaScreen extends StatefulWidget {
  final String registroId;
  final Parqueadero parqueadero;
  final DateTime horaEntrada;

  const SesionActivaScreen({
    super.key,
    required this.registroId,
    required this.parqueadero,
    required this.horaEntrada,
  });

  @override
  State<SesionActivaScreen> createState() => _SesionActivaScreenState();
}

class _SesionActivaScreenState extends State<SesionActivaScreen> {
  final _logic = ParkingLogicService();
  final _tarifas = TarifaService();
  Timer? _timer;
  TarifaConfig _cfg = TarifaConfig();
  Duration _transcurrido = Duration.zero;
  double _costo = 0;
  bool _cerrando = false;

  @override
  void initState() {
    super.initState();
    _cargarConfig();
    // RF-15: actualiza cada segundo el tiempo y el costo.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _transcurrido = DateTime.now().difference(widget.horaEntrada);
        _costo = _logic.calcularCosto(widget.horaEntrada, DateTime.now(), _cfg);
      });
    });
  }

  Future<void> _cargarConfig() async {
    final cfg = await _tarifas.getConfig();
    setState(() => _cfg = cfg);
  }

  String _formato(Duration d) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(d.inHours)}:${dos(d.inMinutes % 60)}:${dos(d.inSeconds % 60)}';
  }

  Future<void> _registrarSalida() async {
    setState(() => _cerrando = true);
    final total = await _logic.registrarSalida(
      widget.registroId,
      widget.parqueadero.id,
      widget.horaEntrada,
    );
    _timer?.cancel();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Comprobante de salida'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Parqueadero: ${widget.parqueadero.nombre}'),
            Text('Tiempo: ${_formato(_transcurrido)}'),
            const SizedBox(height: 8),
            Text('Total a pagar: \$${total.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // cierra diálogo
              Navigator.pop(context); // vuelve atrás
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sesión de parqueo activa')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.parqueadero.nombre,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              const Text('Tiempo transcurrido'),
              Text(_formato(_transcurrido),
                  style: const TextStyle(
                      fontSize: 40, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              const Text('Costo acumulado (en tiempo real)'),
              Text('\$${_costo.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal)),
              const SizedBox(height: 12),
              Text(
                'Tarifa: \$${_cfg.tarifaFraccion} cada ${_cfg.minutosFraccion} min',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.logout),
                  onPressed: _cerrando ? null : _registrarSalida,
                  label: Text(_cerrando ? 'Procesando...' : 'Registrar salida y pagar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
