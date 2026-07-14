import 'package:flutter/material.dart';
import '../models/parqueadero.dart';
import '../services/reserva_service.dart';

// Pago anticipado de la reserva (pago simulado).
class PagoReservaScreen extends StatefulWidget {
  final Parqueadero parqueadero;
  final String fecha;
  final String hora;
  final int duracionHoras;

  const PagoReservaScreen({
    super.key,
    required this.parqueadero,
    required this.fecha,
    required this.hora,
    required this.duracionHoras,
  });

  @override
  State<PagoReservaScreen> createState() => _PagoReservaScreenState();
}

class _PagoReservaScreenState extends State<PagoReservaScreen> {
  final _service = ReservaService();
  String _metodo = 'Tarjeta';
  bool _procesando = false;

  @override
  Widget build(BuildContext context) {
    final monto = _service.calcularMonto(
        widget.parqueadero.tarifaHora, widget.duracionHoras);
    final reembolso = _service.calcularReembolso(monto);
    final penalidadPct =
        (ReservaService.penalidadCancelacion * 100).toStringAsFixed(0);

    return Scaffold(
      appBar: AppBar(title: const Text('Pago anticipado')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Resumen de la reserva
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Resumen de tu reserva',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const Divider(height: 20),
                    _fila('Parqueadero', widget.parqueadero.nombre),
                    _fila('Fecha', widget.fecha),
                    _fila('Hora', widget.hora),
                    _fila('Duración', '${widget.duracionHoras} hora(s)'),
                    _fila('Tarifa por hora',
                        '\$${widget.parqueadero.tarifaHora.toStringAsFixed(2)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Total a pagar
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total a pagar',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('\$${monto.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: Colors.green.shade800,
                      )),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Método de pago
            const Text('Método de pago',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _metodo,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'Tarjeta', child: Text('Tarjeta')),
                DropdownMenuItem(
                    value: 'Transferencia', child: Text('Transferencia')),
                DropdownMenuItem(
                    value: 'Efectivo', child: Text('Efectivo en sitio')),
              ],
              onChanged: (v) => setState(() => _metodo = v!),
            ),
            const SizedBox(height: 20),

            // Aviso de política de cancelación
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 20, color: Colors.amber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Política de cancelación: si cancelas, se retiene el '
                      '$penalidadPct% como penalidad. Recibirías '
                      '\$${reembolso.toStringAsFixed(2)} de reembolso.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.green,
              ),
              onPressed: _procesando ? null : () => _pagar(monto),
              icon: _procesando
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.lock),
              label: Text(_procesando
                  ? 'Procesando pago...'
                  : 'Pagar \$${monto.toStringAsFixed(2)} y reservar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pagar(double monto) async {
    setState(() => _procesando = true);

    // Simulación del procesamiento del pago.
    await Future.delayed(const Duration(seconds: 2));

    try {
      await _service.crearReservaPagada(
        parqueaderoId: widget.parqueadero.id,
        parqueaderoNombre: widget.parqueadero.nombre,
        fecha: widget.fecha,
        hora: widget.hora,
        duracionHoras: widget.duracionHoras,
        tarifaHora: widget.parqueadero.tarifaHora,
        montoPagado: monto,
        metodoPago: _metodo,
      );

      if (!mounted) return;
      setState(() => _procesando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Pago de \$${monto.toStringAsFixed(2)} realizado. Reserva confirmada.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _fila(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(valor,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}