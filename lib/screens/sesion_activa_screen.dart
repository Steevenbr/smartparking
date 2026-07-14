import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/parqueadero.dart';
import '../services/comprobante_service.dart';
import '../services/parking_logic_service.dart';
import '../widgets/app_dialog.dart';

// RF-15 / RF-06 / RF-19: sesión activa + descarga de comprobante al salir.
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
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _transcurrido = DateTime.now().difference(widget.horaEntrada);
        _costo = _logic.calcularCosto(
          widget.horaEntrada,
          DateTime.now(),
          widget.parqueadero.tarifaHora,
          widget.parqueadero.minutosFraccion,
        );
      });
    });
  }

  String _formato(Duration d) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(d.inHours)}:${dos(d.inMinutes % 60)}:${dos(d.inSeconds % 60)}';
  }

  Future<void> _registrarSalida() async {
    setState(() => _cerrando = true);
    try {
      final total = await _logic.registrarSalida(
        widget.registroId,
        widget.parqueadero.id,
        widget.horaEntrada,
        widget.parqueadero.tarifaHora,
        widget.parqueadero.minutosFraccion,
      );
      _timer?.cancel();

      String? archivo;
      String? errorPdf;
      try {
        final snap = await FirebaseFirestore.instance
            .collection('registros')
            .doc(widget.registroId)
            .get();
        final data = Map<String, dynamic>.from(snap.data() ?? {});
        final p = widget.parqueadero;

        data['parqueaderoNombre'] = data['parqueaderoNombre'] ?? p.nombre;
        data['parqueaderoDireccion'] =
            data['parqueaderoDireccion'] ?? p.direccion;
        data['tarifaHora'] = data['tarifaHora'] ?? p.tarifaHora;
        data['minutosFraccion'] = data['minutosFraccion'] ?? p.minutosFraccion;
        data['horaApertura'] = data['horaApertura'] ?? p.horaApertura;
        data['horaCierre'] = data['horaCierre'] ?? p.horaCierre;
        data['espaciosTotales'] = data['espaciosTotales'] ?? p.espaciosTotales;
        data['puesto'] = data['puesto'] ?? 'N/A';
        data['costo'] = total;
        data['horaEntrada'] ??= Timestamp.fromDate(widget.horaEntrada);
        data['horaSalida'] ??= Timestamp.fromDate(DateTime.now());

        final guardado = await ComprobanteService().descargarComprobanteSesion(
          registroId: widget.registroId,
          data: data,
        );
        archivo = guardado.nombreArchivo;
      } catch (e) {
        errorPdf = '$e';
      }

      if (!mounted) return;
      final p = widget.parqueadero;
      await AppDialog.success(
        context: context,
        title:
            archivo != null ? 'Comprobante descargado' : 'Sesion finalizada',
        message: archivo != null
            ? 'Abre Archivos > Descargas > SmartParking en tu telefono.'
            : (errorPdf ??
                'La sesion termino, pero el PDF no se pudo descargar.'),
        primaryLabel: 'Aceptar',
        extra: AppDialog.summaryBox(
          children: [
            AppDialog.summaryRow('Garaje', p.nombre),
            const SizedBox(height: 6),
            AppDialog.summaryRow('Direccion', p.direccion),
            const SizedBox(height: 6),
            AppDialog.summaryRow('Tiempo', _formato(_transcurrido)),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1),
            ),
            AppDialog.summaryRow(
              'Precio a pagar',
              '\$${total.toStringAsFixed(2)}',
              bold: true,
              large: true,
              valueColor: const Color(0xFF16A34A),
            ),
            if (archivo != null) ...[
              const SizedBox(height: 8),
              AppDialog.summaryRow('Archivo', archivo),
            ],
          ],
        ),
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _cerrando = false);
      await AppDialog.error(
        context: context,
        title: 'Error al registrar salida',
        message: '$e',
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sesión de parqueo activa'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                      color: Colors.white.withValues(alpha: 0.2),
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
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.circle, size: 10, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
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
                ],
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: const Icon(Icons.download_rounded),
              onPressed: _cerrando ? null : _registrarSalida,
              label: Text(
                _cerrando
                    ? 'Descargando comprobante...'
                    : 'Registrar salida y descargar comprobante',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
