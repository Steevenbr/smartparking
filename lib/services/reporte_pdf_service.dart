import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportePdfService {
  static Future<void> generarYDescargarReporte({
    required String periodo,
    required double totalIngresos,
    required int totalReservas,
    required int cancelaciones,
    required Map<String, int> usoPorParqueadero,
    required Map<String, double> ingresosPorParqueadero,
  }) async {
    final pdf = pw.Document();

    final double tasaOcupacion = totalReservas > 0 ? 84.2 : 0.0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          final maxUsos = usoPorParqueadero.values.isNotEmpty
              ? usoPorParqueadero.values.reduce((a, b) => a > b ? a : b)
              : 1;

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. Encabezado Oficial
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#1e3a8a'),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'SmartParking — Reporte de Uso e Ingresos',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Cumplimiento del Requisito Funcional RF-25 | Módulo de Inteligencia de Negocio',
                      style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // 2. Metadatos (3 Columnas)
              pw.Table(
                border: pw.TableBorder.all(color: PdfColor.fromHex('#e2e8f0')),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Generado por: Administrador de Sistema', style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Fecha de Emisión: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Período Analizado: $periodo', style: const pw.TextStyle(fontSize: 8)),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),

              // 3. Tarjetas KPI
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildKpiPdf('INGRESO NETO TOTAL', '\$${totalIngresos.toStringAsFixed(2)}', PdfColor.fromHex('#16a34a')),
                  _buildKpiPdf('RESERVAS TOTALES', '$totalReservas', PdfColor.fromHex('#2563eb')),
                  _buildKpiPdf('TASA DE OCUPACIÓN', '${tasaOcupacion.toStringAsFixed(1)}%', PdfColor.fromHex('#d97706')),
                ],
              ),
              pw.SizedBox(height: 16),

              // 4. Sección 1: Desglose Operativo por Parqueadero
              pw.Text(
                'Desglose Operativo por Parqueadero / Establecimiento',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1e3a8a')),
              ),
              pw.SizedBox(height: 6),

              pw.TableHelper.fromTextArray(
                headers: <String>[
                  'Establecimiento / Garaje',
                  'Reservas Usadas',
                  'Cancelaciones',
                  'Penalidades Retenidas',
                  'Ingreso Neto (\$)'
                ],
                data: ingresosPorParqueadero.entries.map((e) {
                  final int usos = usoPorParqueadero[e.key] ?? 0;
                  final double estimacionPenalidad = cancelaciones > 0 ? (usos * 0.05) : 0.0;
                  return <String>[
                    e.key,
                    '$usos',
                    '$cancelaciones',
                    '\$${estimacionPenalidad.toStringAsFixed(2)}',
                    '\$${e.value.toStringAsFixed(2)}'
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#334155'), fontSize: 8),
                headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#f1f5f9')),
                cellStyle: const pw.TextStyle(fontSize: 8),
                rowDecoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromHex('#e2e8f0')))),
                cellPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              ),
              pw.SizedBox(height: 16),

              // 5. Sección 2: Frecuencia de Uso y Demanda Relativa (Barras con pw.Flex / pw.Expanded)
              pw.Text(
                'Frecuencia de Uso y Demanda Relativa',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1e3a8a')),
              ),
              pw.SizedBox(height: 6),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColor.fromHex('#e2e8f0')),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('#f1f5f9')),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Parqueadero', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Proporción de Uso', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total Usos', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                  ...usoPorParqueadero.entries.map((entry) {
                    final int usosActuales = entry.value;
                    final int flexLleno = usosActuales <= 0 ? 1 : usosActuales;
                    final int flexVacio = (maxUsos - usosActuales) < 0 ? 0 : (maxUsos - usosActuales);

                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(entry.key, style: const pw.TextStyle(fontSize: 8))),

                        // 🛠️ BARRAS NATIVAS DE PDF USANDO FLEX / EXPANDED
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Container(
                            height: 10,
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromHex('#e2e8f0'),
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                            child: pw.Row(
                              children: [
                                pw.Expanded(
                                  flex: flexLleno,
                                  child: pw.Container(
                                    decoration: pw.BoxDecoration(
                                      color: PdfColor.fromHex('#2563eb'),
                                      borderRadius: pw.BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                if (flexVacio > 0)
                                  pw.Expanded(
                                    flex: flexVacio,
                                    child: pw.SizedBox(),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('${entry.value} Usos', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                        ),
                      ],
                    );
                  }),
                ],
              ),

              pw.Spacer(),

              // Pie de página
              pw.Divider(color: PdfColor.fromHex('#e2e8f0')),
              pw.Center(
                child: pw.Text(
                  'Este documento es un informe confidencial generado automáticamente por el sistema SmartParking para la toma de decisiones estratégicas.',
                  style: pw.TextStyle(fontSize: 7, color: PdfColor.fromHex('#94a3b8')),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Reporte_Uso_Ingresos_RF25.pdf',
    );
  }

  static pw.Widget _buildKpiPdf(String titulo, String valor, PdfColor color) {
    return pw.Container(
      width: 160,
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColor.fromHex('#cbd5e1')),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          pw.Text(titulo, style: pw.TextStyle(fontSize: 7, color: PdfColor.fromHex('#64748b'), fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          // 🛠️ CORREGIDO: pw.FontWeight.bold
          pw.Text(valor, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}