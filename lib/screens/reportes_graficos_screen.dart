import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/auth_service.dart';
import '../services/reporte_pdf_service.dart';
import '../theme.dart';

class ReportesGraficosScreen extends StatefulWidget {
  const ReportesGraficosScreen({super.key});

  @override
  State<ReportesGraficosScreen> createState() => _ReportesGraficosScreenState();
}

class _ReportesGraficosScreenState extends State<ReportesGraficosScreen> {
  final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final adminId = _authService.uid;

    if (adminId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No se pudo verificar la sesión del administrador.')),
      );
    }

    final ahora = DateTime.now();

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Análisis Gráfico e Indicadores'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('reservas').snapshots(),
        builder: (context, snapshotReservas) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('registros').snapshots(),
            builder: (context, snapshotRegistros) {
              if (snapshotReservas.connectionState == ConnectionState.waiting ||
                  snapshotRegistros.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docsReservas = snapshotReservas.data?.docs ?? [];
              final docsRegistros = snapshotRegistros.data?.docs ?? [];

              // Filtrar por duenoRef (duenoId u ownerId)
              final listaReservas = docsReservas
                  .map((doc) {
                final m = Map<String, dynamic>.from(doc.data() as Map);
                m['duenoRef'] = m['duenoId'] ?? m['ownerId'] ?? '';
                return m;
              })
                  .where((m) => m['duenoRef'] == adminId || m['duenoRef'] == '')
                  .toList();

              final listaRegistros = docsRegistros
                  .map((doc) {
                final m = Map<String, dynamic>.from(doc.data() as Map);
                m['duenoRef'] = m['duenoId'] ?? m['ownerId'] ?? '';
                return m;
              })
                  .where((m) => m['duenoRef'] == adminId || m['duenoRef'] == '')
                  .toList();

              final todosLosDocs = [...listaReservas, ...listaRegistros];

              if (todosLosDocs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'No hay suficientes datos registrados para generar las métricas gráficas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                  ),
                );
              }

              double ingresosDiarios = 0.0;
              int reservasActivas = 0;
              int cancelaciones = 0;

              Map<String, int> usoPorParqueadero = {};
              Map<String, double> ingresosPorParqueadero = {};

              final inicioHoy = DateTime(ahora.year, ahora.month, ahora.day);
              final finHoy = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59);

              for (var data in todosLosDocs) {
                final String parqueadero = data['parqueaderoNombre'] ?? 'Mi Garaje';
                final String estado = data['estado'] ?? 'finalizada';
                final double monto = (data['montoPagado'] ?? data['costo'] ?? 0.0).toDouble();
                final double reembolsado = (data['montoReembolsadoAnticipado'] ?? data['montoReembolsado'] ?? 0.0).toDouble();
                final Timestamp? creadoEn = data['creadoEn'] ?? data['horaEntrada'] ?? data['fecha'];

                if (estado == 'activa' || estado == 'activo') reservasActivas++;
                if (estado == 'cancelada') cancelaciones++;

                usoPorParqueadero[parqueadero] = (usoPorParqueadero[parqueadero] ?? 0) + 1;

                double neto = (estado == 'activa' || estado == 'activo') ? monto : (monto - reembolsado);
                if (neto < 0) neto = 0;

                ingresosPorParqueadero[parqueadero] = (ingresosPorParqueadero[parqueadero] ?? 0) + neto;

                if (creadoEn != null) {
                  final fechaDoc = creadoEn.toDate();
                  if (fechaDoc.isAfter(inicioHoy) && fechaDoc.isBefore(finHoy)) {
                    ingresosDiarios += neto;
                  }
                }
              }

              // 📊 ORDENAR PARQUEADEROS DE MAYOR A MENOR USO
              final listaOrdenadaUso = usoPorParqueadero.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              final int maxUso = listaOrdenadaUso.first.value;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Frecuencia de Uso',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf_rounded, color: kPrimary),
                          tooltip: 'Exportar Reporte PDF',
                          onPressed: () {
                            ReportePdfService.generarYDescargarReporte(
                              periodo: 'Hoy (${ahora.day}/${ahora.month}/${ahora.year})',
                              totalIngresos: ingresosDiarios,
                              totalReservas: reservasActivas,
                              cancelaciones: cancelaciones,
                              usoPorParqueadero: usoPorParqueadero,
                              ingresosPorParqueadero: ingresosPorParqueadero,
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Volumen de usos por parqueadero (mayor a menor):',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    // 📊 GRÁFICO DE BARRAS HORIZONTALES CON CANTIDAD DE USOS VISIBLES
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: Column(
                        children: listaOrdenadaUso.map((entry) {
                          final nombre = entry.key;
                          final usos = entry.value;
                          final porcentaje = (usos / (maxUso > 0 ? maxUso : 1)).clamp(0.05, 1.0);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        nombre,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF374151)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: kPrimary.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$usos usos',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: kPrimary),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Stack(
                                  children: [
                                    // Barra de fondo neutra
                                    Container(
                                      height: 14,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    // Barra horizontal rellena proporcional al uso
                                    FractionallySizedBox(
                                      widthFactor: porcentaje,
                                      child: Container(
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: kPrimary,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 28),

                    const Text(
                      'Desglose Monetario por Parqueadero',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                    ),
                    const SizedBox(height: 12),

                    Column(
                      children: listaOrdenadaUso.map((entry) {
                        final nombre = entry.key;
                        final usos = entry.value;
                        final ingresos = ingresosPorParqueadero[nombre] ?? 0.0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: kPrimary.withOpacity(0.12),
                                child: const Icon(Icons.local_parking_rounded, color: kPrimary),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    const SizedBox(height: 2),
                                    Text('$usos servicios completados', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              Text(
                                '\$${ingresos.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
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