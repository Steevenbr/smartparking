import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'disponibilidad_screen.dart';
import 'reserva_screen.dart';
import 'historial_screen.dart';
import 'mapa_screen.dart';
import 'tarifas_screen.dart';
import 'admin_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> menuOptions = [
      {
        'title': 'Espacios Disponibles',
        'icon': Icons.directions_car_rounded,
        'color': Colors.blue,
        'pantalla': const DisponibilidadScreen(),
      },
      {
        'title': 'Reservar Lugar',
        'icon': Icons.bookmark_add_rounded,
        'color': Colors.green,
        'pantalla': const ReservaScreen(),
      },
      {
        'title': 'Mi Historial',
        'icon': Icons.history_rounded,
        'color': Colors.orange,
        'pantalla': const HistorialScreen(),
      },
      {
        'title': 'Mapa del Parqueadero',
        'icon': Icons.map_rounded,
        'color': Colors.purple,
        'pantalla': const MapaScreen(),
      },
      {
        'title': 'Cálculo de Tarifas',
        'icon': Icons.monetization_on_rounded,
        'color': Colors.teal,
        'pantalla': const TarifasScreen(),
      },
      {
        'title': 'Panel Administrador',
        'icon': Icons.admin_panel_settings_rounded,
        'color': Colors.redAccent,
        'pantalla': const AdminScreen(),
      },
    ];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'SmartParking Panel',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blue,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Cerrar Sesión',
            onPressed: () async {
              await AuthService().cerrarSesion(); // RF-09
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¡Hola de nuevo!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Gestiona tus espacios y reservas de parqueo de forma fácil.',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  childAspectRatio: 1.1,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: menuOptions.length,
                itemBuilder: (context, index) {
                  final option = menuOptions[index];
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: Colors.white,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        // Ahora cada botón abre su pantalla real.
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => option['pantalla'] as Widget,
                          ),
                        );
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: option['color'].withOpacity(0.1),
                            child: Icon(
                              option['icon'],
                              size: 32,
                              color: option['color'],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            option['title'],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
