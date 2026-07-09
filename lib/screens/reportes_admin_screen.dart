import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// RF-08: Pantalla de reportes analíticos de uso y ganancia para el Administrador
class ReportesAdminScreen extends StatelessWidget {
  const ReportesAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes de Uso y Ganancias'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('reservas').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar métricas: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          int totalServicios = docs.length;
          double ingresosTotales = 0.0;

          // Recorremos las reservas computando costos de forma matemática
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final costo = data['costoTotal'] ?? 0.0;
            ingresosTotales += double.tryParse(costo.toString()) ?? 0.0;
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Métricas Consolidadas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Tarjeta 1: Total Estacionamientos
              _cardMetrica(
                titulo: 'Estacionamientos Totales',
                valor: '$totalServicios usos',
                icon: Icons.directions_car_rounded,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),

              // Tarjeta 2: Ingresos de Caja
              _cardMetrica(
                titulo: 'Ganancia Total Bruta',
                valor: '\$${ingresosTotales.toStringAsFixed(2)}',
                icon: Icons.monetization_on_rounded,
                color: Colors.green,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _cardMetrica({
    required String titulo,
    required String valor,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 4),
                Text(valor, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }
}