import 'package:flutter/material.dart';
import 'login_screen.dart'; // Para poder cerrar sesión y volver

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Lista de opciones del menú basadas en los módulos de tu proyecto
    final List<Map<String, dynamic>> menuOptions = [
      {
        'title': 'Espacios Disponibles',
        'icon': Icons.directions_car_rounded,
        'color': Colors.blue,
        'route': 'disponibilidad',
      },
      {
        'title': 'Reservar Lugar',
        'icon': Icons.bookmark_add_rounded,
        'color': Colors.green,
        'route': 'reservas',
      },
      {
        'title': 'Mi Historial',
        'icon': Icons.history_rounded,
        'color': Colors.orange,
        'route': 'historial',
      },
      {
        'title': 'Mapa del Parqueadero',
        'icon': Icons.map_rounded,
        'color': Colors.purple,
        'route': 'mapas',
      },
      {
        'title': 'Cálculo de Tarifas',
        'icon': Icons.monetization_on_rounded,
        'color': Colors.teal,
        'route': 'tarifas',
      },
      {
        'title': 'Panel Administrador',
        'icon': Icons.admin_panel_settings_rounded,
        'color': Colors.redAccent,
        'route': 'admin',
      },
    ];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      // Barra Superior (AppBar)
      appBar: AppBar(
        title: const Text(
          'SmartParking Panel',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blue,
        elevation: 2,
        actions: [
          // Botón para Cerrar Sesión
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Cerrar Sesión',
            onPressed: () {
              // Regresa al Login quitando la pantalla de Home del historial
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
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
              // Sección de Bienvenida
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

              // Grilla Responsiva para las Opciones
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200, // Ancho máximo de cada tarjeta
                  childAspectRatio: 1.1,   // Proporción de la tarjeta
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
                        // Por ahora solo muestra un mensaje de qué modulo se presionó
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Módulo en desarrollo: ${option['title']}'),
                            duration: const Duration(seconds: 1),
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