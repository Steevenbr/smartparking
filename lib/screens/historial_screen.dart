import 'package:flutter/material.dart';
import '../models/registro.dart';
import '../services/comprobante_service.dart';
import '../services/parking_logic_service.dart';
import '../theme.dart';
import '../widgets/app_dialog.dart';

// RF-07: historial de estacionamientos del usuario.
// RF-19: permite volver a descargar el comprobante PDF.
class HistorialScreen extends StatelessWidget {
  const HistorialScreen({super.key});

  String _fecha(DateTime d) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(d.day)}/${dos(d.month)}/${d.year}  ${dos(d.hour)}:${dos(d.minute)}';
  }

  Future<void> _descargar(BuildContext context, Registro r) async {
    try {
      final guardado = await ComprobanteService().descargarComprobanteSesion(
        registroId: r.id,
        data: r.toComprobanteMap(),
      );
      if (!context.mounted) return;
      await AppDialog.success(
        context: context,
        title: 'Comprobante descargado',
        message: 'Abre Archivos > Descargas > SmartParking en tu telefono.',
        primaryLabel: 'Aceptar',
        extra: AppDialog.summaryBox(
          children: [
            AppDialog.summaryRow('Archivo', guardado.nombreArchivo),
            const SizedBox(height: 6),
            AppDialog.summaryRow(
              'Precio',
              '\$${r.costo.toStringAsFixed(2)}',
              bold: true,
              valueColor: const Color(0xFF16A34A),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      await AppDialog.error(
        context: context,
        title: 'No se pudo descargar',
        message: '$e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final logic = ParkingLogicService();
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: const Text('Mi Historial')),
      body: StreamBuilder<List<Registro>>(
        stream: logic.escucharHistorial(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final lista = snapshot.data ?? [];
          lista.sort((a, b) => b.horaEntrada.compareTo(a.horaEntrada));
          if (lista.isEmpty) {
            return const Center(
              child: Text('Aún no tienes registros de parqueo.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lista.length,
            itemBuilder: (context, i) {
              final r = lista[i];
              final activo = r.estado == 'activo';
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: activo
                              ? Colors.orange.shade100
                              : Colors.green.shade100,
                          child: Icon(
                            activo ? Icons.timelapse : Icons.check,
                            color: activo ? Colors.orange : Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.parqueaderoNombre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (r.puesto.isNotEmpty)
                                Text(
                                  'Puesto ${r.puesto}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          activo ? 'En curso' : '\$${r.costo.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Llegada: ${_fecha(r.horaEntrada)}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    Text(
                      r.horaSalida != null
                          ? 'Salida: ${_fecha(r.horaSalida!)}'
                          : 'Salida: en curso...',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    if (!activo) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _descargar(context, r),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Descargar comprobante PDF'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(42),
                          foregroundColor: kPrimary,
                          side: const BorderSide(color: kPrimary),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
