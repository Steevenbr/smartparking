import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    _calcularActualizacion();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _calcularActualizacion();
      }
    });
  }

  void _calcularActualizacion() {
    final ahora = DateTime.now();
    final bool esFutura = ahora.isBefore(widget.horaEntrada);

    setState(() {
      if (esFutura) {
        _transcurrido = Duration.zero;
        _costo = 0.0;
      } else {
        _transcurrido = ahora.difference(widget.horaEntrada);
        _costo = _logic.calcularCosto(
          widget.horaEntrada,
          ahora,
          widget.parqueadero.tarifaHora,
          widget.parqueadero.minutosFraccion,
        );
      }
    });
  }

  String _formato(Duration d) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(d.inHours)}:${dos(d.inMinutes % 60)}:${dos(d.inSeconds % 60)}';
  }

  // ⭐️ Modal emergente para calificar incluyendo el nombre real del usuario logueado
  Future<void> _mostrarDialogoResena(String parqueaderoId, String parqueaderoNombre) async {
    double calificacion = 5.0;
    final comentarioController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (contextDialog) {
        return StatefulBuilder(
          builder: (contextDialog, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Column(
                children: [
                  const Icon(Icons.stars_rounded, color: Colors.amber, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    '¿Qué tal tu experiencia en $parqueaderoNombre?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Tu opinión ayuda a otros conductores a encontrar el mejor lugar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final estrella = index + 1;
                      return IconButton(
                        icon: Icon(
                          estrella <= calificacion ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () {
                          setStateDialog(() {
                            calificacion = estrella.toDouble();
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: comentarioController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Escribe un comentario opcional...',
                      hintStyle: const TextStyle(fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(contextDialog),
                  child: const Text('Omitir', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      // 👤 Consulta del nombre registrado en la colección 'usuarios'
                      String usuarioNombre = user.displayName ?? '';

                      try {
                        final docUser = await FirebaseFirestore.instance
                            .collection('usuarios')
                            .doc(user.uid)
                            .get();

                        if (docUser.exists && docUser.data() != null) {
                          final data = docUser.data()!;
                          usuarioNombre = data['nombre'] ?? data['nombreCompleto'] ?? usuarioNombre;
                        }
                      } catch (_) {}

                      if (usuarioNombre.trim().isEmpty) {
                        usuarioNombre = user.email ?? 'Conductor';
                      }

                      await FirebaseFirestore.instance.collection('resenas').add({
                        'parqueaderoId': parqueaderoId,
                        'parqueaderoNombre': parqueaderoNombre,
                        'usuarioId': user.uid,
                        'usuarioNombre': usuarioNombre, // 👈 Nombre asignado
                        'usuarioEmail': user.email ?? '',
                        'calificacion': calificacion,
                        'comentario': comentarioController.text.trim(),
                        'tipoExperiencia': 'servicio_completado',
                        'creadoEn': FieldValue.serverTimestamp(),
                      });
                    }
                    if (contextDialog.mounted) Navigator.pop(contextDialog);
                  },
                  child: const Text('Enviar Reseña', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _registrarSalida() async {
    setState(() => _cerrando = true);
    try {
      final ahora = DateTime.now();

      // 1. Obtener los datos del documento (sea 'registros' o 'reservas')
      DocumentSnapshot snap = await FirebaseFirestore.instance
          .collection('registros')
          .doc(widget.registroId)
          .get();

      bool esReservaAnticipada = false;
      if (!snap.exists) {
        snap = await FirebaseFirestore.instance
            .collection('reservas')
            .doc(widget.registroId)
            .get();
        esReservaAnticipada = snap.exists;
      }

      final data = Map<String, dynamic>.from(snap.data() as Map? ?? {});
      final p = widget.parqueadero;

      // 2. Calcular el costo según el tiempo REAL utilizado
      final double costoRealUsado = _logic.calcularCosto(
        widget.horaEntrada,
        ahora,
        p.tarifaHora,
        p.minutosFraccion,
      );

      final double montoPagadoPrevio = (data['montoPagado'] ?? 0.0).toDouble();

      // 💰 Cálculo de Reembolso o Excedente
      double montoADevolver = 0.0;
      double montoAdicionalACobrar = 0.0;

      if (esReservaAnticipada && montoPagadoPrevio > 0) {
        if (montoPagadoPrevio > costoRealUsado) {
          montoADevolver = montoPagadoPrevio - costoRealUsado;
        } else if (costoRealUsado > montoPagadoPrevio) {
          montoAdicionalACobrar = costoRealUsado - montoPagadoPrevio;
        }
      }

      // 3. Registrar salida en Firestore y liberar el espacio
      await _logic.registrarSalida(
        widget.registroId,
        p.id,
        widget.horaEntrada,
        p.tarifaHora,
        p.minutosFraccion,
      );

      // Actualizar campos financieros exactos en Firestore
      final refDoc = FirebaseFirestore.instance
          .collection(esReservaAnticipada ? 'reservas' : 'registros')
          .doc(widget.registroId);

      await refDoc.update({
        'costoRealUsado': costoRealUsado,
        'montoReembolsadoAnticipado': montoADevolver,
        'estadoPago': montoADevolver > 0 ? 'reembolsado_parcial' : 'completado',
      });

      _timer?.cancel();

      // 4. Preparar datos para el PDF
      data['parqueaderoNombre'] = data['parqueaderoNombre'] ?? p.nombre;
      data['parqueaderoDireccion'] = data['parqueaderoDireccion'] ?? p.direccion;
      data['tarifaHora'] = data['tarifaHora'] ?? p.tarifaHora;
      data['minutosFraccion'] = data['minutosFraccion'] ?? p.minutosFraccion;
      data['costo'] = costoRealUsado; // Guarda el costo real por tiempo usado
      data['montoPagado'] = montoPagadoPrevio;
      data['montoReembolsado'] = montoADevolver;
      data['horaEntrada'] ??= Timestamp.fromDate(widget.horaEntrada);
      data['horaSalida'] = Timestamp.fromDate(ahora);

      String? archivo;
      String? errorPdf;
      try {
        final guardado = await ComprobanteService().descargarComprobanteSesion(
          registroId: widget.registroId,
          data: data,
        );
        archivo = guardado.nombreArchivo;
      } catch (e) {
        errorPdf = '$e';
      }

      if (!mounted) return;

      // 5. Diálogo de liquidación transparente
      await AppDialog.success(
        context: context,
        title: archivo != null ? 'Comprobante generado' : 'Sesión finalizada',
        message: archivo != null
            ? 'Comprobante guardado en Archivos > Descargas > SmartParking.'
            : (errorPdf ?? 'Salida registrada correctamente.'),
        primaryLabel: 'Aceptar',
        extra: AppDialog.summaryBox(
          children: [
            AppDialog.summaryRow('Garaje', p.nombre),
            const SizedBox(height: 6),
            AppDialog.summaryRow('Tiempo utilizado', _formato(_transcurrido)),
            const SizedBox(height: 6),
            AppDialog.summaryRow('Costo real del consumo', '\$${costoRealUsado.toStringAsFixed(2)}'),

            if (esReservaAnticipada && montoPagadoPrevio > 0) ...[
              const SizedBox(height: 6),
              AppDialog.summaryRow('Monto pagado al reservar', '\$${montoPagadoPrevio.toStringAsFixed(2)}'),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1),
              ),
              if (montoADevolver > 0)
                AppDialog.summaryRow(
                  'Diferencia a devolver',
                  '+\$${montoADevolver.toStringAsFixed(2)}',
                  bold: true,
                  large: true,
                  valueColor: const Color(0xFF16A34A), // Verde
                )
              else if (montoAdicionalACobrar > 0)
                AppDialog.summaryRow(
                  'Excedente a pagar',
                  '-\$${montoAdicionalACobrar.toStringAsFixed(2)}',
                  bold: true,
                  large: true,
                  valueColor: Colors.red,
                )
              else
                AppDialog.summaryRow(
                  'Diferencia',
                  '\$0.00',
                  bold: true,
                  large: true,
                  valueColor: Colors.blue,
                ),
            ] else ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1),
              ),
              AppDialog.summaryRow(
                'Total a pagar',
                '\$${costoRealUsado.toStringAsFixed(2)}',
                bold: true,
                large: true,
                valueColor: const Color(0xFF16A34A),
              ),
            ],
          ],
        ),
      );

      // 6. Lanzar el modal de estrellas/reseña tras cerrar la confirmación
      if (mounted) {
        await _mostrarDialogoResena(p.id, p.nombre);
      }

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
    final bool esFutura = DateTime.now().isBefore(widget.horaEntrada);
    final horaInicioStr = '${widget.horaEntrada.hour.toString().padLeft(2, '0')}:${widget.horaEntrada.minute.toString().padLeft(2, '0')}';

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.circle, size: 10, color: esFutura ? Colors.blue : Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        esFutura ? 'PROGRAMADA (Inicia $horaInicioStr)' : 'EN CURSO',
                        style: TextStyle(
                          color: esFutura ? Colors.blue.shade700 : Colors.green,
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.download_rounded),
              onPressed: _cerrando ? null : _registrarSalida,
              label: Text(
                _cerrando
                    ? 'Descargando comprobante...'
                    : 'Registrar salida y descargar comprobante',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}