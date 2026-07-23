import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/reserva_service.dart';
import '../services/comprobante_service.dart';
import '../theme.dart';
import '../widgets/app_dialog.dart';

// RF-18: Cancelación de reservas con reembolso parcial.
// RF-19: Comprobante digital descargable (PDF).
class MisReservasScreen extends StatefulWidget {
  const MisReservasScreen({super.key});

  @override
  State<MisReservasScreen> createState() => _MisReservasScreenState();
}

class _MisReservasScreenState extends State<MisReservasScreen> {
  bool _descargando = false;

  Future<void> _descargarComprobante(
      String reservaId,
      Map<String, dynamic> data,
      ) async {
    if (_descargando) return;
    setState(() => _descargando = true);
    try {
      final guardado = await ComprobanteService().descargarComprobante(
        reservaId: reservaId,
        data: data,
      );
      if (!mounted) return;

      await AppDialog.success(
        context: context,
        title: 'Comprobante descargado',
        message: 'El PDF se guardó en tu dispositivo.',
        primaryLabel: 'Aceptar',
        extra: AppDialog.summaryBox(
          children: [
            AppDialog.summaryRow('Archivo', guardado.nombreArchivo),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await AppDialog.error(
        context: context,
        title: 'No se pudo descargar',
        message: '$e',
      );
    } finally {
      if (mounted) setState(() => _descargando = false);
    }
  }

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

    final confirmar = await AppDialog.confirm(
      context: context,
      title: 'Cancelar reserva',
      message: '¿Seguro que deseas cancelar tu reserva en $nombre?',
      icon: Icons.cancel_outlined,
      iconColor: Colors.red.shade600,
      confirmLabel: 'Sí, cancelar',
      cancelLabel: 'No, volver',
      confirmColor: Colors.red.shade600,
      extra: AppDialog.summaryBox(
        children: [
          AppDialog.summaryRow(
            'Pagaste',
            '\$${montoPagado.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 8),
          AppDialog.summaryRow(
            'Penalidad ($penalidadPct%)',
            '-\$${penalidad.toStringAsFixed(2)}',
            valueColor: Colors.red.shade600,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          AppDialog.summaryRow(
            'Se te reembolsará',
            '\$${reembolso.toStringAsFixed(2)}',
            bold: true,
            large: true,
            valueColor: const Color(0xFF16A34A),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final devuelto = await service.cancelarReserva(reservaId);
      if (!context.mounted) return;
      await AppDialog.success(
        context: context,
        title: 'Reserva cancelada',
        message: 'Tu espacio fue liberado y el reembolso quedó registrado.',
        extra: AppDialog.summaryBox(
          children: [
            AppDialog.summaryRow(
              'Reembolso',
              '\$${devuelto.toStringAsFixed(2)}',
              bold: true,
              large: true,
              valueColor: const Color(0xFF16A34A),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      await AppDialog.error(
        context: context,
        title: 'No se pudo cancelar',
        message: '$e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: const BoxDecoration(
                        color: kPrimarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.event_note_outlined,
                          size: 42, color: kPrimary),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Todavía no tienes reservas',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Crea una desde "Reservar Lugar" y aquí\n'
                          'podrás ver el comprobante digital.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          docs.sort((a, b) {
            final ea = (a.data() as Map<String, dynamic>)['estado'] ?? '';
            final eb = (b.data() as Map<String, dynamic>)['estado'] ?? '';
            if (ea == eb) return 0;
            return ea == 'activa' ? -1 : 1;
          });

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              return _ReservaCard(
                reservaId: doc.id,
                data: data,
                descargando: _descargando,
                onDescargar: () => _descargarComprobante(doc.id, data),
                onCancelar: () => _confirmarCancelacion(
                  context,
                  doc.id,
                  data['parqueaderoNombre'] ?? 'Parqueadero',
                  (data['montoPagado'] ?? 0).toDouble(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ReservaCard extends StatelessWidget {
  final String reservaId;
  final Map<String, dynamic> data;
  final bool descargando;
  final VoidCallback onDescargar;
  final VoidCallback onCancelar;

  const _ReservaCard({
    required this.reservaId,
    required this.data,
    required this.descargando,
    required this.onDescargar,
    required this.onCancelar,
  });

  @override
  Widget build(BuildContext context) {
    final String estado = data['estado'] ?? '';
    final bool activa = estado == 'activa';
    final bool concluida = estado == 'concluido' || estado == 'finalizada' || estado == 'finalizado' || estado == 'completada';
    final bool cancelada = estado == 'cancelada';

    final nombre = data['parqueaderoNombre'] ?? 'Parqueadero';
    final montoPagado = (data['montoPagado'] ?? 0).toDouble();
    final montoReembolsado = (data['montoReembolsado'] ?? 0).toDouble();
    final metodoPago = data['metodoPago'];

    // Configuración dinámica según el estado real de la reserva
    Color colorFranja;
    Color colorFondoTag;
    Color colorTextoTag;
    String textoEstado;
    IconData iconoEstado;

    if (activa) {
      colorFranja = const Color(0xFF22C55E);
      colorFondoTag = const Color(0xFFDCFCE7);
      colorTextoTag = const Color(0xFF15803D);
      textoEstado = 'ACTIVA';
      iconoEstado = Icons.event_available;
    } else if (concluida) {
      colorFranja = const Color(0xFF0284C7);
      colorFondoTag = const Color(0xFFE0F2FE);
      colorTextoTag = const Color(0xFF0369A1);
      textoEstado = 'FINALIZADA';
      iconoEstado = Icons.check_circle_outline_rounded;
    } else {
      colorFranja = Colors.grey.shade400;
      colorFondoTag = Colors.grey.shade200;
      colorTextoTag = Colors.grey.shade700;
      textoEstado = 'CANCELADA';
      iconoEstado = Icons.event_busy;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: activa ? kPrimary.withValues(alpha: 0.18) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Franja superior de color dinámico
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: colorFranja,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: colorFondoTag,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        iconoEstado,
                        color: colorTextoTag,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombre,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Reserva ${_codigoCorto(reservaId)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: colorFondoTag,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        textoEstado,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colorTextoTag,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _metaItem(
                              Icons.calendar_today_outlined,
                              '${data['fecha'] ?? ''}',
                            ),
                          ),
                          Expanded(
                            child: _metaItem(
                              Icons.access_time,
                              '${data['hora'] ?? ''}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _metaItem(
                              Icons.hourglass_bottom,
                              '${data['duracionHoras'] ?? 0} hora(s)',
                            ),
                          ),
                          Expanded(
                            child: _metaItem(
                              Icons.payments_outlined,
                              '\$${montoPagado.toStringAsFixed(2)}'
                                  '${metodoPago != null ? ' · $metodoPago' : ''}',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (cancelada && montoReembolsado > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.replay_circle_filled_outlined,
                            size: 18, color: kPrimary),
                        const SizedBox(width: 8),
                        Text(
                          'Reembolsado: \$${montoReembolsado.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: kPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                // RF-19: botón de comprobante
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPrimary,
                    side: const BorderSide(color: kPrimary),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: descargando ? null : onDescargar,
                  icon: descargando
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(
                    descargando
                        ? 'Generando...'
                        : 'Descargar comprobante',
                  ),
                ),
                if (activa) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      side: BorderSide(color: Colors.red.shade300),
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onCancelar,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancelar reserva'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _codigoCorto(String id) {
    if (id.length <= 8) return id.toUpperCase();
    return id.substring(0, 8).toUpperCase();
  }

  Widget _metaItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}