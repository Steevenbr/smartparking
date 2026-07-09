import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // Librería estadística para el RF-25

// RF-25: Reportes y gráficos de uso e ingresos por periodo para la toma de decisiones
class ReportesGraficosScreen extends StatefulWidget {
  const ReportesGraficosScreen({super.key});

  @override
  State<ReportesGraficosScreen> createState() => _ReportesGraficosScreenState();
}

class _ReportesGraficosScreenState extends State<ReportesGraficosScreen> {
  // Filtro por defecto para cumplir con el análisis por periodo (RF-25)
  String _periodoSeleccionado = '2026';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Análisis e Ingresos'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('reservas').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error al cargar datos analíticos: ${snapshot.error}'),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          // Estructura para mapear las ganancias de los primeros 6 meses del año
          Map<int, double> ingresosMensuales = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};
          int totalServiciosPeriodo = 0;
          double totalGananciasPeriodo = 0.0;

          // Procesamiento matemático y filtrado por periodo en tiempo real (RF-25)
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final fechaStr = data['fecha'] ?? ''; // Formato esperado "DD/MM/AAAA"
            final costo = double.tryParse(data['costoTotal'].toString()) ?? 0.0;

            // Filtramos únicamente las reservas que correspondan al año seleccionado
            if (fechaStr.contains(_periodoSeleccionado)) {
              totalServiciosPeriodo++;
              totalGananciasPeriodo += costo;

              // Parseamos la cadena de fecha para extraer el mes
              final partes = fechaStr.split('/');
              if (partes.length == 3) {
                final mes = int.tryParse(partes[1]) ?? 1;
                if (ingresosMensuales.containsKey(mes)) {
                  ingresosMensuales[mes] = ingresosMensuales[mes]! + costo;
                }
              }
            }
          }

          return ListView(
            // Se añade un padding generoso al fondo (bottom: 40) para un scroll fluido
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              // Fila del Filtro por Periodo (RF-25)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filtrar por Año:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  DropdownButton<String>(
                    value: _periodoSeleccionado,
                    items: ['2025', '2026']
                        .map((ano) => DropdownMenuItem(value: ano, child: Text(ano)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _periodoSeleccionado = val);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Fila de Tarjetas de Métricas de Uso y Ganancia (RF-08)
              Row(
                children: [
                  Expanded(
                    child: _cardEstadistica(
                        'Servicios',
                        '$totalServiciosPeriodo usos',
                        Icons.local_parking_rounded,
                        Colors.blue
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _cardEstadistica(
                        'Ingresos',
                        '\$${totalGananciasPeriodo.toStringAsFixed(2)}',
                        Icons.monetization_on_rounded,
                        Colors.green
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              const Text(
                'Gráfico de Ingresos Mensuales (\$)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // CONTENEDOR OPTIMIZADO DEL GRÁFICO (Se bajó a 180 de altura para corregir el desborde)
              SizedBox(
                height: 180,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16, left: 8),
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      // Altura máxima dinámica del eje Y basada en los ingresos generados
                      maxY: totalGananciasPeriodo > 0 ? totalGananciasPeriodo + 10 : 20,
                      barGroups: ingresosMensuales.entries.map((entry) {
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value,
                              color: Colors.indigo,
                              width: 16, // Ancho estilizado para evitar superposiciones
                              borderRadius: BorderRadius.circular(4),
                            )
                          ],
                        );
                      }).toList(),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: true, reservedSize: 30),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              const meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun'];
                              final index = value.toInt() - 1;
                              if (index >= 0 && index < meses.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                      meses[index],
                                      style: const TextStyle(fontSize: 11, color: Colors.grey)
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                      ),
                      gridData: const FlGridData(show: true, drawVerticalLine: false),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Widget auxiliar para construir las tarjetas de los KPIs
  Widget _cardEstadistica(String titulo, String valor, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(titulo, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              valor,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}