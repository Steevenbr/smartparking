import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/parqueadero.dart';
import '../services/parking_logic_service.dart';

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
  Timer? _timer;
  Duration _transcurrido = Duration.zero;
  double _costo = 0;
  bool _cerrando = false;

  @override
  void initState() {
    super.initState();
    // RF-15: actualiza cada segundo el tiempo y el costo.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _transcurrido = DateTime.now().difference(widget.horaEntrada);
        _costo = _logic.calcularCosto(widget.horaEntrada, DateTime.now(),
            widget.parqueadero.tarifaHora, widget.parqueadero.minutosFraccion);
      });
    });
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
      widget.parqueadero.tarifaHora,
      widget.parqueadero.minutosFraccion,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tarjeta del garaje con degradado.
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: kHeaderGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.local_parking_rounded,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.parqueadero.nombre,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '\$${widget.parqueadero.tarifaHora}/hora · fracción ${widget.parqueadero.minutosFraccion} min',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tarjeta destacada: estado, tiempo y costo.
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Indicador "En curso".
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'EN CURSO',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('TIEMPO TRANSCURRIDO',
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                          letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(
                    _formato(_transcurrido),
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                      letterSpacing: 2,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Divider(),
                  ),
                  Text('COSTO ACUMULADO',
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                          letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(
                    '\$${_costo.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: kAccent,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: kAccentSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt, size: 14, color: kAccent),
                        const SizedBox(width: 4),
                        Text(
                          'Actualizándose en tiempo real',
                          style: TextStyle(
                              color: kAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Botón de salida.
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: const Icon(Icons.logout),
              onPressed: _cerrando ? null : _registrarSalida,
              label: Text(
                  _cerrando ? 'Procesando...' : 'Registrar salida y pagar'),
            ),
          ],
        ),
      ),
    );
  }
}
