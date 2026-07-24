import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/parqueadero.dart';
import '../services/parking_logic_service.dart';
import '../services/auth_service.dart'; // 👈 Importado para verificar datos de vehículo
import 'edit_profile_screen.dart'; // 👈 Importado para la redirección al perfil
import 'sesion_activa_screen.dart';

// RF-03 y RF-05: detalle de un parqueadero y registro de entrada.
class DetalleParqueaderoScreen extends StatelessWidget {
  final Parqueadero parqueadero;
  const DetalleParqueaderoScreen({super.key, required this.parqueadero});

  // 🚗 Diálogo emergente para solicitar completar los datos del vehículo
  Future<void> _mostrarDialogoCompletarVehiculo(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.directions_car_rounded, color: kPrimary),
            SizedBox(width: 8),
            Text('Datos del Vehículo'),
          ],
        ),
        content: const Text(
          'Para registrar una entrada, es necesario que ingreses la placa, modelo y color de tu vehículo en tu perfil.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              );
            },
            child: const Text('Completar Perfil'),
          ),
        ],
      ),
    );
  }

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
                  // 🛑 VALIDACIÓN PREVIA: Verificar que la información del vehículo esté completa
                  final authService = AuthService();
                  final vehiculoCompleto = await authService.tieneDatosVehiculoCompletos();

                  if (!vehiculoCompleto) {
                    if (!context.mounted) return;
                    await _mostrarDialogoCompletarVehiculo(context);
                    return;
                  }

                  final logic = ParkingLogicService();
                  final entrada = DateTime.now();

                  // 🛑 CAPTURA DE EXCEPCIONES Y VALIDACIÓN DE SERVICIO ACTIVO
                  try {
                    final registroId = await logic.registrarEntrada(p); // RF-05
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
                  } catch (e) {
                    if (!context.mounted) return;
                    // Despliega la alerta explicativa en rojo si ya tiene sesión/reserva
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          e.toString().replaceAll('Exception: ', ''),
                        ),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
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