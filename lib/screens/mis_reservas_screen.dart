import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/reserva_service.dart';

// RF-18: Cancelación de reservas con reembolso parcial.
// Muestra las reservas del usuario, lo que pagó, y permite cancelar las activas.
class MisReservasScreen extends StatelessWidget {
  const MisReservasScreen({super.key});

  Future<void> _confirmarCancelacion(
    BuildContext context,
    String reservaId,
    String nombre,
    double montoPagado,
  ) async {
    final service = ReservaService();
    final reembolso = service.calcularReembolso(montoPagado);
    final penalidad = montoPagado - reembolso;
    final penalidadPct =
        (ReservaService.penalidadCancelacion * 100).toStringAsFixed(0);

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar reserva'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Seguro que deseas cancelar tu reserva en $nombre?'),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _filaDialogo('Pagaste', '\$${montoPagado.toStringAsFixed(2)}'),
            _filaDialogo(
              'Penalidad ($penalidadPct%)',
              '-\$${penalidad.toStringAsFixed(2)}',
              color: Colors.red,
            ),
            const SizedBox(height: 6),
            _filaDialogo(
              'Se te reembolsará',
              '\$${reembolso.toStringAsFixed(2)}',
              negrita: true,
              color: Colors.green,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final devuelto = await service.cancelarReserva(reservaId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Reserva cancelada. Reembolso: \$${devuelto.toStringAsFixed(2)}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  static Widget _filaDialogo(String label, String valor,
      {bool negrita = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13.5)),
          Text(
            valor,
            style: TextStyle(
              fontSize: 14,
              fontWeight: negrita ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis reservas')),
      body: StreamBuilder<QuerySnapshot>(
        stream: ReservaService().escucharReservas(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Todavía no tienes reservas.\n'
                  'Crea una desde "Reservar Lugar".',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }

          // Mostramos primero las reservas activas.
          docs.sort((a, b) {
            final ea = (a.data() as Map<String, dynamic>)['estado'] ?? '';
            final eb = (b.data() as Map<String, dynamic>)['estado'] ?? '';
            if (ea == eb) return 0;
            return ea == 'activa' ? -1 : 1;
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;

              final activa = data['estado'] == 'activa';
              final nombre = data['parqueaderoNombre'] ?? 'Parqueadero';
              final montoPagado = (data['montoPagado'] ?? 0).toDouble();
              final montoReembolsado = (data['montoReembolsado'] ?? 0).toDouble();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Encabezado: nombre y estado
                      Row(
                        children: [
                          Icon(
                            activa ? Icons.event_available : Icons.event_busy,
                            color: activa ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              nombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Chip(
                            label: Text(
                              activa ? 'ACTIVA' : 'CANCELADA',
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor: activa
                                ? Colors.green.shade100
                                : Colors.grey.shade300,
                          ),
                        ],
                      ),
                      const Divider(height: 20),

                      // Fecha y hora
                      Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text('${data['fecha'] ?? ''}'),
                          const SizedBox(width: 16),
                          const Icon(Icons.access_time,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text('${data['hora'] ?? ''}'),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Duración
                      Row(
                        children: [
                          const Icon(Icons.hourglass_bottom,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text('${data['duracionHoras'] ?? 0} hora(s)'),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Monto pagado por adelantado
                      Row(
                        children: [
                          const Icon(Icons.payments_outlined,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            'Pagado: \$${montoPagado.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (data['metodoPago'] != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '(${data['metodoPago']})',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ],
                      ),

                      // Si fue cancelada, mostramos el reembolso
                      if (!activa && montoReembolsado > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.replay_circle_filled_outlined,
                                size: 16, color: Colors.blueGrey),
                            const SizedBox(width: 6),
                            Text(
                              'Reembolsado: \$${montoReembolsado.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: Colors.blueGrey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Botón de cancelar (solo si está activa)
                      if (activa) ...[
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            minimumSize: const Size.fromHeight(42),
                          ),
                          onPressed: () => _confirmarCancelacion(
                            context,
                            doc.id,
                            nombre,
                            montoPagado,
                          ),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Cancelar reserva'),
                        ),
                      ],
                    ],
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