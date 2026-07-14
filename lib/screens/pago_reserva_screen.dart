import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/parqueadero.dart';
import '../services/comprobante_service.dart';
import '../services/reserva_service.dart';
import '../theme.dart';
import '../widgets/app_dialog.dart';

// Pago anticipado de la reserva (pago simulado).
// Tras pagar, descarga automáticamente el comprobante digital (RF-19).
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
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
            const SizedBox(height: 16),

            // Total a pagar
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total a pagar',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('\$${monto.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: Color(0xFF15803D),
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
              initialValue: _metodo,
              items: const [
                DropdownMenuItem(value: 'Tarjeta', child: Text('Tarjeta')),
                DropdownMenuItem(
                    value: 'Transferencia', child: Text('Transferencia')),
                DropdownMenuItem(
                    value: 'Efectivo', child: Text('Efectivo en sitio')),
              ],
              onChanged: (v) => setState(() => _metodo = v!),
            ),
            const SizedBox(height: 16),

            // Aviso RF-19
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kPrimarySoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kPrimary.withValues(alpha: 0.25)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.picture_as_pdf_outlined,
                      size: 20, color: kPrimary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Al confirmar el pago se descargará automáticamente '
                      'tu comprobante digital en PDF.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Aviso de política de cancelación
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 20, color: Colors.amber.shade800),
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
                minimumSize: const Size.fromHeight(52),
                backgroundColor: const Color(0xFF16A34A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
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
      final reservaId = await _service.crearReservaPagada(
        parqueaderoId: widget.parqueadero.id,
        parqueaderoNombre: widget.parqueadero.nombre,
        fecha: widget.fecha,
        hora: widget.hora,
        duracionHoras: widget.duracionHoras,
        tarifaHora: widget.parqueadero.tarifaHora,
        montoPagado: monto,
        metodoPago: _metodo,
      );

      final dataReserva = <String, dynamic>{
        'usuarioEmail': FirebaseAuth.instance.currentUser?.email ?? '',
        'parqueaderoNombre': widget.parqueadero.nombre,
        'parqueaderoDireccion': widget.parqueadero.direccion,
        'espaciosTotales': widget.parqueadero.espaciosTotales,
        'horaApertura': widget.parqueadero.horaApertura,
        'horaCierre': widget.parqueadero.horaCierre,
        'minutosFraccion': widget.parqueadero.minutosFraccion,
        'puesto': 'RESERVA',
        'fecha': widget.fecha,
        'hora': widget.hora,
        'duracionHoras': widget.duracionHoras,
        'tarifaHora': widget.parqueadero.tarifaHora,
        'montoPagado': monto,
        'metodoPago': _metodo,
        'estadoPago': 'pagado',
        'estado': 'activa',
        'pagadoEn': Timestamp.now(),
        'montoReembolsado': 0.0,
      };

      // RF-19: descarga automática del comprobante.
      String? nombreArchivo;
      String? errorDescarga;
      try {
        final guardado = await ComprobanteService().descargarComprobante(
          reservaId: reservaId,
          data: dataReserva,
        );
        nombreArchivo = guardado.nombreArchivo;
      } catch (e) {
        errorDescarga = '$e';
        debugPrint('Error generando comprobante: $e');
      }

      if (!mounted) return;
      setState(() => _procesando = false);

      final codigo = reservaId.length > 8
          ? reservaId.substring(0, 8).toUpperCase()
          : reservaId.toUpperCase();

      if (nombreArchivo == null) {
        await AppDialog.error(
          context: context,
          title: 'Reserva ok, pero fallo el PDF',
          message: errorDescarga ??
              'La reserva se creo, pero no se pudo generar el comprobante.',
        );
      } else {
        await AppDialog.success(
          context: context,
          title: '¡Reserva confirmada!',
          message: 'Comprobante PDF guardado en Descargas.',
          primaryLabel: 'Aceptar',
          extra: AppDialog.summaryBox(
            children: [
              AppDialog.summaryRow('No. comprobante', codigo),
              const SizedBox(height: 6),
              AppDialog.summaryRow('Parqueadero', widget.parqueadero.nombre),
              const SizedBox(height: 6),
              AppDialog.summaryRow('Fecha', widget.fecha),
              const SizedBox(height: 6),
              AppDialog.summaryRow('Hora', widget.hora),
              const SizedBox(height: 6),
              AppDialog.summaryRow(
                  'Duracion', '${widget.duracionHoras} hora(s)'),
              const SizedBox(height: 6),
              AppDialog.summaryRow('Metodo', _metodo),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1),
              ),
              AppDialog.summaryRow(
                'Total pagado',
                '\$${monto.toStringAsFixed(2)}',
                bold: true,
                large: true,
                valueColor: const Color(0xFF16A34A),
              ),
              const SizedBox(height: 8),
              AppDialog.summaryRow('Archivo', nombreArchivo),
            ],
          ),
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      await AppDialog.error(
        context: context,
        title: 'Error en el pago',
        message: '$e',
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