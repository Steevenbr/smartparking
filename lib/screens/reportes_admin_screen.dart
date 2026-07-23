import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/reporte_pdf_service.dart';
import '../theme.dart';

enum FiltroTiempo { hoy, semanal, mensual, todos }

class ReportesAdminScreen extends StatefulWidget {
  const ReportesAdminScreen({super.key});

  @override
  State<ReportesAdminScreen> createState() => _ReportesAdminScreenState();
}

class _ReportesAdminScreenState extends State<ReportesAdminScreen> {
  final _authService = AuthService();
  FiltroTiempo _filtroSeleccionado = FiltroTiempo.hoy;

  bool _estaEnRango(DateTime fecha, FiltroTiempo filtro) {
    final ahora = DateTime.now();
    switch (filtro) {
      case FiltroTiempo.hoy:
        final inicioHoy = DateTime(ahora.year, ahora.month, ahora.day);
        final finHoy = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59);
        return fecha.isAfter(inicioHoy.subtract(const Duration(seconds: 1))) &&
            fecha.isBefore(finHoy);
      case FiltroTiempo.semanal:
        final haceSieteDias = ahora.subtract(const Duration(days: 7));
        return fecha.isAfter(haceSieteDias);
      case FiltroTiempo.mensual:
        final haceTreintaDias = ahora.subtract(const Duration(days: 30));
        return fecha.isAfter(haceTreintaDias);
      case FiltroTiempo.todos:
        return true;
    }
  }

  String _obtenerTextoFiltro(FiltroTiempo filtro) {
    switch (filtro) {
      case FiltroTiempo.hoy:
        return 'Hoy';
      case FiltroTiempo.semanal:
        return 'Semanal';
      case FiltroTiempo.mensual:
        return 'Mensual';
      case FiltroTiempo.todos:
        return 'Todos';
    }
  }

  Future<String> _obtenerNombreUsuario(String usuarioId, String nombreActual, String emailActual) async {
    if (nombreActual.trim().isNotEmpty && !nombreActual.contains('@')) {
      return nombreActual;
    }
    if (usuarioId.isEmpty) {
      return emailActual.isNotEmpty ? emailActual : 'Conductor sin nombre';
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(usuarioId).get();
      if (doc.exists && doc.data() != null) {
        final nombreProfile = doc.data()!['nombre'] ?? '';
        if (nombreProfile.toString().trim().isNotEmpty) {
          return nombreProfile;
        }
      }
    } catch (_) {}

    return emailActual.isNotEmpty ? emailActual : 'Conductor sin nombre';
  }

  @override
  Widget build(BuildContext context) {
    final adminId = _authService.uid;

    if (adminId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No se pudo verificar la sesión del administrador.')),
      );
    }

    final ahora = DateTime.now();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('reservas').snapshots(),
      builder: (context, snapshotReservas) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('registros').snapshots(),
          builder: (context, snapshotRegistros) {
            if (snapshotReservas.connectionState == ConnectionState.waiting ||
                snapshotRegistros.connectionState == ConnectionState.waiting) {
              return Scaffold(
                backgroundColor: kBg,
                appBar: AppBar(title: const Text('Panel de Control')),
                body: const Center(child: CircularProgressIndicator()),
              );
            }

            final docsReservas = snapshotReservas.data?.docs ?? [];
            final docsRegistros = snapshotRegistros.data?.docs ?? [];

            final listaReservas = docsReservas
                .map((doc) {
              final m = Map<String, dynamic>.from(doc.data() as Map);
              m['origenTipo'] = 'RESERVA';
              m['docId'] = doc.id;
              m['duenoRef'] = m['duenoId'] ?? m['ownerId'] ?? '';
              return m;
            })
                .where((m) => m['duenoRef'] == adminId || m['duenoRef'] == '')
                .toList();

            final listaRegistros = docsRegistros
                .map((doc) {
              final m = Map<String, dynamic>.from(doc.data() as Map);
              m['origenTipo'] = 'HISTORIAL';
              m['docId'] = doc.id;
              m['duenoRef'] = m['duenoId'] ?? m['ownerId'] ?? '';
              return m;
            })
                .where((m) => m['duenoRef'] == adminId || m['duenoRef'] == '')
                .toList();

            final todosLosDocumentos = [...listaReservas, ...listaRegistros];

            todosLosDocumentos.sort((a, b) {
              final Timestamp? fA = a['horaEntrada'] ?? a['creadoEn'] ?? a['fecha'];
              final Timestamp? fB = b['horaEntrada'] ?? b['creadoEn'] ?? b['fecha'];
              if (fA == null || fB == null) return 0;
              return fB.compareTo(fA);
            });

            final documentosFiltrados = todosLosDocumentos.where((data) {
              final Timestamp? fechaRef = data['horaEntrada'] ?? data['creadoEn'] ?? data['fecha'];
              if (fechaRef == null) return true;
              return _estaEnRango(fechaRef.toDate(), _filtroSeleccionado);
            }).toList();

            double ingresosFiltrados = 0.0;
            int reservasActivas = 0;
            int cancelaciones = 0;
            int conteoHistorial = 0;
            int conteoReservas = 0;

            Map<String, int> usoPorParqueadero = {};
            Map<String, double> ingresosPorParqueadero = {};

            for (var data in documentosFiltrados) {
              final String estado = data['estado'] ?? 'finalizada';
              final String origen = data['origenTipo'] ?? 'HISTORIAL';
              final double total = (data['montoPagado'] ?? data['costo'] ?? 0.0).toDouble();
              final double reembolsado = (data['montoReembolsadoAnticipado'] ?? data['montoReembolsado'] ?? 0.0).toDouble();
              final String parqueaderoNombre = data['parqueaderoNombre'] ?? 'Mi Garaje';

              if (origen == 'RESERVA' && estado == 'activa') reservasActivas++;
              if (estado == 'cancelada') cancelaciones++;
              if (origen == 'HISTORIAL') conteoHistorial++;
              if (origen == 'RESERVA') conteoReservas++;

              usoPorParqueadero[parqueaderoNombre] = (usoPorParqueadero[parqueaderoNombre] ?? 0) + 1;

              double netoDoc = (estado == 'activa') ? total : (total - reembolsado);
              if (netoDoc < 0) netoDoc = 0;

              ingresosPorParqueadero[parqueaderoNombre] = (ingresosPorParqueadero[parqueaderoNombre] ?? 0) + netoDoc;
              ingresosFiltrados += netoDoc;
            }

            return Scaffold(
              backgroundColor: kBg,
              appBar: AppBar(
                title: const Text('Panel de Control'),
                actions: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<FiltroTiempo>(
                        value: _filtroSeleccionado,
                        dropdownColor: kPrimary,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        onChanged: (FiltroTiempo? nuevo) {
                          if (nuevo != null) {
                            setState(() => _filtroSeleccionado = nuevo);
                          }
                        },
                        items: FiltroTiempo.values.map((filtro) {
                          return DropdownMenuItem<FiltroTiempo>(
                            value: filtro,
                            child: Text(_obtenerTextoFiltro(filtro)),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    tooltip: 'Exportar Reporte PDF',
                    onPressed: () {
                      ReportePdfService.generarYDescargarReporte(
                        periodo: '${_obtenerTextoFiltro(_filtroSeleccionado)} (${ahora.day}/${ahora.month}/${ahora.year})',
                        totalIngresos: ingresosFiltrados,
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
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Resumen Financiero',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: kPrimary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Período: ${_obtenerTextoFiltro(_filtroSeleccionado)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kPrimary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    _buildKpiCard(
                      title: 'Ingreso Neto (${_obtenerTextoFiltro(_filtroSeleccionado)})',
                      value: '\$${ingresosFiltrados.toStringAsFixed(2)}',
                      subtitle: 'Recaudación real acumulada',
                      icon: Icons.monetization_on_rounded,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 12),

                    // 📐 Grilla ajustada a 3 columnas con tarjetas más pequeñas y compactas
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.15,
                      children: [
                        _buildGridCard('Historial', '$conteoHistorial', Icons.history_rounded, Colors.orange),
                        _buildGridCard('Reservas', '$conteoReservas', Icons.bookmark_added_rounded, Colors.indigo),
                        _buildGridCard('Activos', '$reservasActivas', Icons.event_available, Colors.blue),
                        _buildGridCard('Canceladas', '$cancelaciones', Icons.event_busy, Colors.red),
                        _buildGridCard('Total Operaciones', '${documentosFiltrados.length}', Icons.swap_horiz_rounded, Colors.purple),
                      ],
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Monitoreo de Actividad Reciente',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mostrando ${documentosFiltrados.length} registros para ${_obtenerTextoFiltro(_filtroSeleccionado).toLowerCase()}:',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 10),

                    if (documentosFiltrados.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text('No hay actividad registrada en este período.', style: TextStyle(color: Colors.grey)),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: documentosFiltrados.length > 20 ? 20 : documentosFiltrados.length,
                        itemBuilder: (context, index) {
                          final data = documentosFiltrados[index];
                          return _buildActivityTile(context, data);
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildKpiCard({required String title, required String value, required String subtitle, required IconData icon, required Color color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            radius: 22,
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                Text(subtitle, style: TextStyle(fontSize: 10.5, color: Colors.grey.withOpacity(0.7))),
              ],
            ),
          )
        ],
      ),
    );
  }

  // 📐 Tarjeta compacta para la grilla de 3 columnas
  Widget _buildGridCard(String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 18),
              Text(
                count,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
              ),
            ],
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTile(BuildContext context, Map<String, dynamic> data) {
    final String parqueadero = data['parqueaderoNombre'] ?? 'Mi Garaje';
    final String estado = data['estado'] ?? 'finalizada';
    final String origen = data['origenTipo'] ?? 'HISTORIAL';
    final String usuarioId = data['usuarioId'] ?? '';
    final String usuarioNombreActual = data['usuarioNombre'] ?? '';
    final String usuarioEmailActual = data['usuarioEmail'] ?? '';

    IconData icon;
    Color color;
    String estadoTexto;

    if (estado == 'activa' || estado == 'activo') {
      icon = Icons.directions_car_filled_rounded;
      color = Colors.blue;
      estadoTexto = origen == 'RESERVA' ? 'Reserva Activa' : 'En Curso';
    } else if (estado == 'cancelada') {
      icon = Icons.layers_clear_rounded;
      color = Colors.red;
      estadoTexto = 'Cancelada';
    } else {
      icon = Icons.check_circle_outline_rounded;
      color = Colors.green;
      estadoTexto = 'Finalizada';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: ListTile(
        onTap: () => _mostrarFichaAuditoria(context, data),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          radius: 18,
          child: Icon(icon, color: color, size: 18),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                parqueadero,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: origen == 'RESERVA' ? Colors.indigo.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: origen == 'RESERVA' ? Colors.indigo.shade200 : Colors.orange.shade200,
                ),
              ),
              child: Text(
                origen,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: origen == 'RESERVA' ? Colors.indigo.shade800 : Colors.orange.shade900,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 12, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: FutureBuilder<String>(
                    future: _obtenerNombreUsuario(usuarioId, usuarioNombreActual, usuarioEmailActual),
                    builder: (context, snapshot) {
                      final nombreMostrar = snapshot.data ?? (usuarioNombreActual.isNotEmpty ? usuarioNombreActual : usuarioEmailActual);
                      return Text(
                        nombreMostrar,
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade800, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ),
                Text(
                  ' • $estadoTexto',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11.5),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.info_outline_rounded, color: Colors.grey, size: 18),
      ),
    );
  }

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