import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  String _periodoSeleccionado = 'Hoy';

  bool _estaEnPeriodo(DateTime fechaDoc) {
    final ahora = DateTime.now();
    final hoyInicio = DateTime(ahora.year, ahora.month, ahora.day);

    if (_periodoSeleccionado == 'Hoy') {
      return fechaDoc.isAfter(hoyInicio);
    } else if (_periodoSeleccionado == 'Semana') {
      final inicioSemana = hoyInicio.subtract(Duration(days: ahora.weekday - 1));
      return fechaDoc.isAfter(inicioSemana);
    } else if (_periodoSeleccionado == 'Mes') {
      final inicioMes = DateTime(ahora.year, ahora.month, 1);
      return fechaDoc.isAfter(inicioMes);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final adminId = _authService.uid;

    if (adminId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Sesión de administrador no válida.')),
      );
    }

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Reportes Gráficos e Ingresos'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reservas')
            .where('duenoId', isEqualTo: adminId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No hay datos registrados para generar reportes.'),
            );
          }

          final todosLosDocs = snapshot.data!.docs;

          final docsFiltrados = todosLosDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final Timestamp? creadoEn = data['creadoEn'];
            if (creadoEn == null) return false;
            return _estaEnPeriodo(creadoEn.toDate());
          }).toList();

          double totalIngresos = 0;
          int totalUsoReservas = 0;
          int cancelaciones = 0;
          Map<String, int> usoPorParqueadero = {};
          Map<String, double> ingresosPorParqueadero = {};

          for (var doc in docsFiltrados) {
            final data = doc.data() as Map<String, dynamic>;
            final estado = data['estado'] ?? '';
            final monto = (data['montoPagado'] ?? 0.0).toDouble();
            final reembolsado = (data['montoReembolsado'] ?? 0.0).toDouble();
            final pNombre = data['parqueaderoNombre'] ?? 'Garaje';

            if (estado == 'activa') {
              totalIngresos += monto;
              totalUsoReservas++;
            } else if (estado == 'cancelada') {
              totalIngresos += (monto - reembolsado);
              cancelaciones++;
            }

            usoPorParqueadero[pNombre] = (usoPorParqueadero[pNombre] ?? 0) + 1;
            ingresosPorParqueadero[pNombre] = (ingresosPorParqueadero[pNombre] ?? 0) +
                (estado == 'activa' ? monto : (monto - reembolsado));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Período de Análisis:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    DropdownButton<String>(
                      value: _periodoSeleccionado,
                      borderRadius: BorderRadius.circular(12),
                      items: ['Hoy', 'Semana', 'Mes', 'Todo'].map((p) {
                        return DropdownMenuItem(value: p, child: Text(p));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _periodoSeleccionado = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _kpiCard(
                        'Total Recaudado',
                        '\$${totalIngresos.toStringAsFixed(2)}',
                        Icons.attach_money_rounded,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _kpiCard(
                        'Uso de Espacios',
                        '$totalUsoReservas reservas',
                        Icons.directions_car_rounded,
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Frecuencia de Uso por Parqueadero', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
                      tooltip: 'Exportar PDF del período',
                      onPressed: () {
                        ReportePdfService.generarYDescargarReporte(
                          periodo: _periodoSeleccionado,
                          totalIngresos: totalIngresos,
                          totalReservas: totalUsoReservas,
                          cancelaciones: cancelaciones,
                          usoPorParqueadero: usoPorParqueadero,
                          ingresosPorParqueadero: ingresosPorParqueadero,
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _graficoBarrasUso(usoPorParqueadero),

                const SizedBox(height: 28),

                const Text('Desglose Financiero por Establecimiento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...ingresosPorParqueadero.entries.map((entry) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: kPrimary,
                        child: Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
                      ),
                      title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Reservas en período: ${usoPorParqueadero[entry.key] ?? 0}'),
                      trailing: Text(
                        '\$${entry.value.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _kpiCard(String titulo, String valor, IconData icono, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color, size: 28),
          const SizedBox(height: 8),
          Text(titulo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(valor, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _graficoBarrasUso(Map<String, int> datos) {
    if (datos.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Sin datos en este período.'),
        ),
      );
    }

    final maxVal = datos.values.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        children: datos.entries.map((entry) {
          final porcentaje = maxVal > 0 ? (entry.value / maxVal) : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('${entry.value} usos', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kPrimary)),
                  ],
                ),
                const SizedBox(height: 6),
                Stack(
                  children: [
                    Container(height: 12, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6))),
                    FractionallySizedBox(
                      widthFactor: porcentaje == 0 ? 0.02 : porcentaje,
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [kPrimary, Colors.blueAccent]),
                          borderRadius: BorderRadius.circular(6),
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
    );
  }
}