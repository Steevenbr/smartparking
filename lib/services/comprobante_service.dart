import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Resultado de la descarga del comprobante (RF-19).
class ComprobanteGuardado {
  final String ruta;
  final String nombreArchivo;

  const ComprobanteGuardado({
    required this.ruta,
    required this.nombreArchivo,
  });
}

/// RF-19: comprobante digital PDF de la sesión de parqueo.
class ComprobanteService {
  static const _downloadsChannel = MethodChannel('smart_parking/downloads');

  /// Descarga el comprobante de una sesión (entrada/salida).
  Future<ComprobanteGuardado> descargarComprobanteSesion({
    required String registroId,
    required Map<String, dynamic> data,
  }) async {
    final bytes = await _generarPdfSesion(registroId: registroId, data: data);
    if (bytes.isEmpty) {
      throw Exception('El PDF se genero vacio.');
    }
    final corto =
        registroId.length > 8 ? registroId.substring(0, 8) : registroId;
    return _guardarEnDescargas(
      bytes: bytes,
      nombreBase: 'comprobante_parqueo_$corto',
    );
  }

  /// Compatibilidad: comprobante de reserva pagada.
  Future<ComprobanteGuardado> descargarComprobante({
    required String reservaId,
    required Map<String, dynamic> data,
  }) async {
    final bytes = await _generarPdfReserva(reservaId: reservaId, data: data);
    if (bytes.isEmpty) {
      throw Exception('El PDF se genero vacio.');
    }
    final corto =
        reservaId.length > 8 ? reservaId.substring(0, 8) : reservaId;
    return _guardarEnDescargas(
      bytes: bytes,
      nombreBase: 'comprobante_reserva_$corto',
    );
  }

  /// Guarda el PDF en Descargas publicas (visible en Archivos > Descargas).
  Future<ComprobanteGuardado> _guardarEnDescargas({
    required Uint8List bytes,
    required String nombreBase,
  }) async {
    final nombreArchivo = '$nombreBase.pdf';

    // 1) Android nativo via MediaStore (aparece como descarga real).
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final ruta = await _downloadsChannel.invokeMethod<String>(
          'savePdfToDownloads',
          <String, dynamic>{
            'fileName': nombreArchivo,
            'bytes': bytes,
          },
        );
        if (ruta != null && ruta.isNotEmpty) {
          debugPrint('PDF MediaStore guardado: $ruta');
          return ComprobanteGuardado(
            ruta: ruta,
            nombreArchivo: nombreArchivo,
          );
        }
      } on PlatformException catch (e) {
        debugPrint('MediaStore error: ${e.code} ${e.message}');
      } catch (e) {
        debugPrint('Canal downloads error: $e');
      }
    }

    // 2) FileSaver (iOS / web / respaldo).
    try {
      final ruta = await FileSaver.instance.saveFile(
        name: nombreBase,
        bytes: bytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
      if (ruta.trim().isNotEmpty) {
        debugPrint('PDF FileSaver: $ruta');
        return ComprobanteGuardado(ruta: ruta, nombreArchivo: nombreArchivo);
      }
    } catch (e) {
      debugPrint('FileSaver error: $e');
    }

    // 3) Ultimo respaldo (puede no verse en Descargas del sistema).
    if (!kIsWeb) {
      final docs = await getApplicationDocumentsDirectory();
      final carpeta = Directory('${docs.path}/SmartParking');
      if (!await carpeta.exists()) {
        await carpeta.create(recursive: true);
      }
      final file = File('${carpeta.path}/$nombreArchivo');
      await file.writeAsBytes(bytes, flush: true);
      throw Exception(
        'No se pudo guardar en Descargas publicas. '
        'Archivo interno: ${file.path}',
      );
    }

    throw Exception('No se pudo descargar el PDF en este dispositivo.');
  }

  Future<Uint8List> _generarPdfSesion({
    required String registroId,
    required Map<String, dynamic> data,
  }) async {
    final pdf = pw.Document();

    final nombre = _textoSeguro(data['parqueaderoNombre'] ?? 'Parqueadero');
    final direccion = _textoSeguro(data['parqueaderoDireccion'] ?? '-');
    final tarifaHora = _toDouble(data['tarifaHora']);
    final minutosFraccion = data['minutosFraccion'] ?? 15;
    final horaApertura = _textoSeguro(data['horaApertura'] ?? '-');
    final horaCierre = _textoSeguro(data['horaCierre'] ?? '-');
    final espaciosTotales = data['espaciosTotales'] ?? '-';
    final puesto = _textoSeguro(data['puesto'] ?? 'N/A');
    final email = _textoSeguro(data['usuarioEmail'] ?? '-');
    final costo = _toDouble(data['costo']);
    final entrada = _formatearTimestamp(data['horaEntrada']);
    final salida = _formatearTimestamp(data['horaSalida']);
    final emitido = _formatearFecha(DateTime.now());
    final codigo = registroId.length > 8
        ? registroId.substring(0, 8).toUpperCase()
        : registroId.toUpperCase();

    Duration? duracion;
    if (data['horaEntrada'] is Timestamp && data['horaSalida'] is Timestamp) {
      duracion = (data['horaSalida'] as Timestamp)
          .toDate()
          .difference((data['horaEntrada'] as Timestamp).toDate());
    }
    final tiempoTexto = duracion != null ? _formatoDuracion(duracion) : '-';

    final azul = PdfColor.fromHex('#2563EB');
    final azulOscuro = PdfColor.fromHex('#1E40AF');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 1.2),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  color: azul,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'SMARTPARKING',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'COMPROBANTE DIGITAL DE PARQUEO',
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(20),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          _meta('No. COMPROBANTE', codigo),
                          _meta('EMITIDO', emitido),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      _meta('ID SESION', registroId),
                      pw.SizedBox(height: 16),
                      pw.Divider(color: PdfColors.grey300),
                      pw.SizedBox(height: 12),
                      _tituloSeccion('DATOS DEL GARAJE', azulOscuro),
                      _fila('Nombre', nombre),
                      _fila('Direccion', direccion),
                      _fila(
                        'Tarifa por hora',
                        '\$${tarifaHora.toStringAsFixed(2)}',
                      ),
                      _fila('Fraccion de cobro', '$minutosFraccion min'),
                      _fila('Horario', '$horaApertura - $horaCierre'),
                      _fila('Espacios totales', '$espaciosTotales'),
                      pw.SizedBox(height: 14),
                      _tituloSeccion('DATOS DE LA SESION', azulOscuro),
                      _fila('Cliente', email),
                      _fila('Puesto ocupado', puesto),
                      _fila('Hora de llegada', entrada),
                      _fila('Hora de salida', salida),
                      _fila('Tiempo total', tiempoTexto),
                      pw.SizedBox(height: 14),
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.all(14),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#E7EEFE'),
                          borderRadius: pw.BorderRadius.circular(8),
                          border: pw.Border.all(color: azul, width: 0.8),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'PRECIO A PAGAR',
                              style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold,
                                color: azulOscuro,
                              ),
                            ),
                            pw.Text(
                              '\$${costo.toStringAsFixed(2)} USD',
                              style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                                color: azul,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 18),
                      pw.Text(
                        'Documento descargado automaticamente por SmartParking. '
                        'Conservelo como respaldo de su parqueo.',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey600,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> _generarPdfReserva({
    required String reservaId,
    required Map<String, dynamic> data,
  }) async {
    // Reutiliza el formato de sesión con campos de reserva adaptados.
    final adaptado = <String, dynamic>{
      'parqueaderoNombre': data['parqueaderoNombre'],
      'parqueaderoDireccion': data['parqueaderoDireccion'] ?? '-',
      'tarifaHora': data['tarifaHora'],
      'minutosFraccion': data['minutosFraccion'] ?? 60,
      'horaApertura': data['horaApertura'] ?? '-',
      'horaCierre': data['horaCierre'] ?? '-',
      'espaciosTotales': data['espaciosTotales'] ?? '-',
      'puesto': data['puesto'] ?? 'RESERVA',
      'usuarioEmail': data['usuarioEmail'],
      'costo': data['montoPagado'] ?? data['costo'] ?? 0,
      'horaEntrada': data['pagadoEn'],
      'horaSalida': null,
      ...data,
    };
    // Texto especial: llegada/salida como fecha-hora de reserva.
    final pdf = pw.Document();
    final nombre = _textoSeguro(adaptado['parqueaderoNombre'] ?? 'Parqueadero');
    final monto = _toDouble(adaptado['montoPagado'] ?? adaptado['costo']);
    final fecha = _textoSeguro(data['fecha'] ?? '-');
    final hora = _textoSeguro(data['hora'] ?? '-');
    final duracion = data['duracionHoras'] ?? 0;
    final metodo = _textoSeguro(data['metodoPago'] ?? '-');
    final email = _textoSeguro(data['usuarioEmail'] ?? '-');
    final codigo = reservaId.length > 8
        ? reservaId.substring(0, 8).toUpperCase()
        : reservaId.toUpperCase();
    final azul = PdfColor.fromHex('#2563EB');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              color: azul,
              child: pw.Text(
                'SMARTPARKING - COMPROBANTE DE RESERVA',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 16),
            _fila('No. comprobante', codigo),
            _fila('Parqueadero', nombre),
            _fila('Cliente', email),
            _fila('Fecha', fecha),
            _fila('Hora', hora),
            _fila('Duracion', '$duracion hora(s)'),
            _fila('Metodo de pago', metodo),
            pw.SizedBox(height: 12),
            _fila('Total pagado', '\$${monto.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
    return pdf.save();
  }

  pw.Widget _tituloSeccion(String t, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        t,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  pw.Widget _meta(String label, String valor) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        pw.SizedBox(height: 3),
        pw.Text(valor,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  pw.Widget _fila(String label, String valor) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.6),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style:
                  const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.SizedBox(width: 12),
          pw.Flexible(
            child: pw.Text(
              valor,
              textAlign: pw.TextAlign.right,
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0.0;
  }

  String _textoSeguro(dynamic value) {
    var text = '$value';
    const mapa = {
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u',
      'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U',
      'ñ': 'n', 'Ñ': 'N', 'ü': 'u', 'Ü': 'U',
      'º': 'o', '°': 'o', '—': '-', '–': '-',
    };
    mapa.forEach((k, v) => text = text.replaceAll(k, v));
    return text.replaceAll(RegExp(r'[^\x09\x0A\x0D\x20-\x7E\xA0-\xFF]'), '');
  }

  String _formatearFecha(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year} $hh:$mi';
  }

  String _formatearTimestamp(dynamic value) {
    if (value is Timestamp) return _formatearFecha(value.toDate());
    if (value is DateTime) return _formatearFecha(value);
    return '-';
  }

  String _formatoDuracion(Duration d) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(d.inHours)}:${dos(d.inMinutes % 60)}:${dos(d.inSeconds % 60)}';
  }
}
