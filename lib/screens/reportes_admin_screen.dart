import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/reporte_pdf_service.dart';
import '../theme.dart';

class ReportesAdminScreen extends StatefulWidget {
  const ReportesAdminScreen({super.key});

  @override
  State<ReportesAdminScreen> createState() => _ReportesAdminScreenState();
}

class _ReportesAdminScreenState extends State<ReportesAdminScreen> {
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
    final inicioHoy = DateTime(ahora.year, ahora.month, ahora.day);
    final finHoy = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reservas')
          .where('duenoId', isEqualTo: adminId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: kBg,
            appBar: AppBar(title: const Text('Panel de Control - Administrador')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Scaffold(
            backgroundColor: kBg,
            appBar: AppBar(title: const Text('Panel de Control - Administrador')),
            body: const Center(
              child: Text('No tienes registros ni movimientos en tus parqueaderos aún.'),
            ),
          );
        }

        final registros = snapshot.data!.docs;

        double ingresosDiarios = 0.0;
        int reservasActivas = 0;
        int cancelaciones = 0;

        Map<String, int> usoPorParqueadero = {};
        Map<String, double> ingresosPorParqueadero = {};

        for (var doc in registros) {
          final data = doc.data() as Map<String, dynamic>;
          final String estado = data['estado'] ?? '';
          final double total = (data['montoPagado'] ?? 0.0).toDouble();
          final double reembolsado = (data['montoReembolsado'] ?? 0.0).toDouble();
          final Timestamp? creadoEn = data['creadoEn'];
          final String parqueaderoNombre = data['parqueaderoNombre'] ?? 'Mi Garaje';

          if (estado == 'activa') reservasActivas++;
          if (estado == 'cancelada') cancelaciones++;

          usoPorParqueadero[parqueaderoNombre] = (usoPorParqueadero[parqueaderoNombre] ?? 0) + 1;

          double netoDoc = estado == 'activa' ? total : (total - reembolsado);
          ingresosPorParqueadero[parqueaderoNombre] = (ingresosPorParqueadero[parqueaderoNombre] ?? 0) + netoDoc;

          if (creadoEn != null) {
            final fechaDoc = creadoEn.toDate();
            if (fechaDoc.isAfter(inicioHoy) && fechaDoc.isBefore(finHoy)) {
              ingresosDiarios += netoDoc;
            }
          }
        }

        return Scaffold(
          backgroundColor: kBg,
          appBar: AppBar(
            title: const Text('Panel de Control - Administrador'),
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_rounded),
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
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resumen Financiero y Operativo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 16),

                _buildKpiCard(
                  title: 'Ingreso Diario Neto',
                  value: '\$${ingresosDiarios.toStringAsFixed(2)}',
                  subtitle: 'Ganancias de hoy + penalidades retenidas',
                  icon: Icons.monetization_on_rounded,
                  color: Colors.green,
                ),
                const SizedBox(height: 16),

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
          ),
        );
      },
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

  // 🛠️ LISTA RESUMIDA: Se quitó la fila del vehículo para evitar inconsistencias visuales
  Widget _buildActivityTile(BuildContext context, Map<String, dynamic> data) {
    final String parqueadero = data['parqueaderoNombre'] ?? 'Mi Garaje';
    final String estado = data['estado'] ?? 'desconocido';

    final String conductorNombre = (data['usuarioNombre'] != null && data['usuarioNombre'].toString().trim().isNotEmpty)
        ? data['usuarioNombre']
        : (data['usuarioEmail'] ?? 'Conductor sin nombre');

    IconData icon;
    Color color;
    String estadoTexto;

    if (estado == 'activa') {
      icon = Icons.bookmark_outline_rounded;
      color = Colors.blue;
      estadoTexto = 'Reserva Activa';
    } else if (estado == 'cancelada') {
      icon = Icons.layers_clear_rounded;
      color = Colors.red;
      estadoTexto = 'Cancelada';
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
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.info_outline_rounded, color: Colors.grey, size: 20),
      ),
    );
  }

  // 🔍 FICHA COMPLETA: Consulta dinámicamente el perfil del usuario para mostrar datos reales
  void _mostrarFichaAuditoria(BuildContext context, Map<String, dynamic> data) async {
    final usuarioId = data['usuarioId'] ?? '';

    Map<String, dynamic> perfilActual = {};
    if (usuarioId.toString().isNotEmpty) {
      final docUser = await FirebaseFirestore.instance.collection('usuarios').doc(usuarioId).get();
      if (docUser.exists && docUser.data() != null) {
        perfilActual = docUser.data()!;
      }
    }

    final nombre = (perfilActual['nombre'] != null && perfilActual['nombre'].toString().trim().isNotEmpty)
        ? perfilActual['nombre']
        : ((data['usuarioNombre'] != null && data['usuarioNombre'].toString().trim().isNotEmpty)
        ? data['usuarioNombre']
        : (data['usuarioEmail'] ?? '-'));

    final email = perfilActual['email'] ?? data['usuarioEmail'] ?? '-';
    final telefono = perfilActual['telefono'] ?? data['usuarioTelefono'] ?? '-';

    final placa = perfilActual['placa'] ?? data['vehiculoPlaca'] ?? '-';
    final modelo = perfilActual['modelo_marca'] ?? data['vehiculoMarcaModelo'] ?? '-';
    final color = perfilActual['color'] ?? data['vehiculoColor'] ?? '-';

    if (!context.mounted) return;

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

              const Text('INFORMACIÓN DEL CONDUCTOR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              _itemFicha(Icons.person, 'Nombre', nombre),
              _itemFicha(Icons.email, 'Correo Electrónico', email),
              _itemFicha(Icons.phone, 'Teléfono de Contacto', telefono),

              const SizedBox(height: 16),

              const Text('DATOS DEL VEHÍCULO ASOCIADO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              _itemFicha(Icons.credit_card_rounded, 'Número de Placa', placa, resaltar: placa != '-'),
              _itemFicha(Icons.directions_car, 'Modelo / Marca', modelo),
              _itemFicha(Icons.palette_rounded, 'Color del Vehículo', color),
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
                  color: value == '-'
                      ? Colors.grey.shade400
                      : (resaltar ? Colors.indigo.shade900 : const Color(0xFF374151))
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}