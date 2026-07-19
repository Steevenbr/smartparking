import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
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

    // Rangos para filtrar las métricas y el ingreso acumulado exclusivamente de HOY
    final ahora = DateTime.now();
    final inicioHoy = DateTime(ahora.year, ahora.month, ahora.day);
    final finHoy = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59); // 🛠️ CORREGIDO TOTALMENTE

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Panel de Control - Administrador'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🔐 FILTRADO SEGURO: Escucha tu colección nativa 'reservas' por el duenoId
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
              child: Text('No tienes registros ni movimientos en tus parqueaderos aún.'),
            );
          }

          final registros = snapshot.data!.docs;

          double ingresosDiarios = 0.0;
          int reservasActivas = 0;
          int cancelaciones = 0;

          for (var doc in registros) {
            final data = doc.data() as Map<String, dynamic>;
            final String estado = data['estado'] ?? '';
            final double total = (data['montoPagado'] ?? 0.0).toDouble();
            final double reembolsado = (data['montoReembolsado'] ?? 0.0).toDouble();
            final Timestamp? creadoEn = data['creadoEn'];

            // 1. Contadores basados en los estados nativos de tu app ('activa' y 'cancelada')
            if (estado == 'activa') reservasActivas++;
            if (estado == 'cancelada') cancelaciones++;

            // 2. Cálculo del Ingreso Diario Neto (Filtra solo lo ocurrido HOY)
            if (creadoEn != null) {
              final fechaDoc = creadoEn.toDate();
              if (fechaDoc.isAfter(inicioHoy) && fechaDoc.isBefore(finHoy)) {
                if (estado == 'activa') {
                  ingresosDiarios += total;
                } else if (estado == 'cancelada') {
                  // Si se canceló, el dueño retiene el 20% estipulado por la penalidad
                  ingresosDiarios += (total - reembolsado);
                }
              }
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resumen Financiero y Operativo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 16),

                // Tarjeta Principal KPI del Ingreso Diario
                _buildKpiCard(
                  title: 'Ingreso Diario Neto',
                  value: '\$${ingresosDiarios.toStringAsFixed(2)}',
                  subtitle: 'Ganancias de hoy + penalidades retenidas',
                  icon: Icons.monetization_on_rounded,
                  color: Colors.green,
                ),
                const SizedBox(height: 16),

                // Grid de Estados en tiempo real
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.3,
                  children: [
                    _buildGridCard('Reservas Activas', '$reservasActivas', Icons.event_available, Colors.blue),
                    _buildGridCard('Canceladas', '$cancelaciones', Icons.event_busy, Colors.red),
                    _buildGridCard('Total Histórico', '${registros.length}', Icons.folder_shared, Colors.purple),
                  ],
                ),
                const SizedBox(height: 28),

                const Text(
                  'Monitoreo de Actividad Reciente',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  'Toca cualquier registro para auditar los datos del vehículo y el conductor.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),

                // Lista de Historial Reciente de Movimientos
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: registros.length > 10 ? 10 : registros.length,
                  itemBuilder: (context, index) {
                    final data = registros[index].data() as Map<String, dynamic>;
                    return _buildActivityTile(context, data);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildKpiCard({required String title, required String value, required String subtitle, required IconData icon, required Color color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            radius: 26,
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.withOpacity(0.7))),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildGridCard(String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(count, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
            ],
          ),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildActivityTile(BuildContext context, Map<String, dynamic> data) {
    final String parqueadero = data['parqueaderoNombre'] ?? 'Mi Garaje';
    final String estado = data['estado'] ?? 'desconocido';
    final String conductorNombre = data['usuarioNombre'] ?? data['usuarioEmail'] ?? 'Usuario Prueba';
    final double total = (data['montoPagado'] ?? 0.0).toDouble();
    final double reembolsado = (data['montoReembolsado'] ?? 0.0).toDouble();

    IconData icon;
    Color color;
    String estadoTexto;
    String montoTexto = '\$${total.toStringAsFixed(2)}';

    if (estado == 'activa') {
      icon = Icons.bookmark_outline_rounded;
      color = Colors.blue;
      estadoTexto = 'Reserva Activa';
    } else if (estado == 'cancelada') {
      icon = Icons.layers_clear_rounded;
      color = Colors.red;
      estadoTexto = 'Cancelada';
      montoTexto = 'Retenido: \$${(total - reembolsado).toStringAsFixed(2)}';
    } else {
      icon = Icons.check_circle_outline_rounded;
      color = Colors.green;
      estadoTexto = 'Concluido';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: ListTile(
        onTap: () => _mostrarFichaAuditoria(context, data),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(parqueadero, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(estadoTexto, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 13, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    conductorNombre,
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.info_outline_rounded, color: Colors.grey, size: 20),
      ),
    );
  }

  void _mostrarFichaAuditoria(BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 18),
              const Row(
                children: [
                  Icon(Icons.badge_rounded, color: kPrimary),
                  SizedBox(width: 8),
                  Text('Detalles Completos de Auditoría', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                ],
              ),
              const Divider(height: 24),

              // SECCIÓN A: INFORMACIÓN PERSONAL
              const Text('INFORMACIÓN DEL CONDUCTOR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              _itemFicha(Icons.person, 'Nombre', data['usuarioNombre'] ?? 'Usuario Prueba'),
              _itemFicha(Icons.email, 'Correo Electrónico', data['usuarioEmail'] ?? 'Sin correo'),
              _itemFicha(Icons.phone, 'Teléfono de Contacto', data['usuarioTelefono'] ?? 'S/N'),

              const SizedBox(height: 16),

              // SECCIÓN B: INFORMACIÓN DEL VEHÍCULO CORREGIDA
              const Text('DATOS DEL VEHÍCULO ASOCIADO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              _itemFicha(Icons.credit_card_rounded, 'Número de Placa', data['vehiculoPlaca'] ?? 'PBX-1234', resaltar: true),
              _itemFicha(Icons.directions_car, 'Modelo / Marca', data['vehiculoMarcaModelo'] ?? 'KIA Picanto'),
              _itemFicha(Icons.palette_rounded, 'Color del Vehículo', data['vehiculoColor'] ?? 'Gris'),
            ],
          ),
        );
      },
    );
  }

  Widget _itemFicha(IconData icon, String label, String value, {bool resaltar = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: resaltar ? FontWeight.bold : FontWeight.w600,
                  color: resaltar ? Colors.indigo.shade900 : const Color(0xFF374151)
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}