import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/parqueadero.dart';
import '../services/parking_logic_service.dart';
import 'sesion_activa_screen.dart';

// RF-03 y RF-05: detalle de un parqueadero y registro de entrada.
class DetalleParqueaderoScreen extends StatelessWidget {
  final Parqueadero parqueadero;
  const DetalleParqueaderoScreen({super.key, required this.parqueadero});

  @override
  Widget build(BuildContext context) {
    final p = parqueadero;
    final lleno = p.espaciosLibres <= 0;

    return Scaffold(
      appBar: AppBar(title: Text(p.nombre)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fila(Icons.location_on_outlined, 'Dirección', p.direccion),
            _fila(Icons.directions_car_outlined, 'Espacios libres',
                '${p.espaciosLibres} de ${p.espaciosTotales}'),
            _fila(Icons.attach_money, 'Tarifa', '\$${p.tarifaHora} por hora'),
            _fila(Icons.map_outlined, 'Ubicación',
                '${p.latitud}, ${p.longitud}'),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.login),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: lleno
                    ? null
                    : () async {
                        final logic = ParkingLogicService();
                        final entrada = DateTime.now();
                        final registroId =
                            await logic.registrarEntrada(p); // RF-05
                        if (!context.mounted) return;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SesionActivaScreen(
                              registroId: registroId,
                              parqueadero: p,
                              horaEntrada: entrada,
                            ),
                          ),
                        );
                      },
                label: Text(lleno ? 'Sin espacios disponibles' : 'Registrar entrada'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fila(IconData icon, String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kPrimary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                const SizedBox(height: 2),
                Text(valor,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
