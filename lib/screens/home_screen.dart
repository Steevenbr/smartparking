import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'disponibilidad_screen.dart';
import 'reserva_screen.dart';
import 'historial_screen.dart';
import 'mapa_screen.dart';
import 'tarifas_screen.dart';
import 'mis_garajes_screen.dart';
import 'tarifa_config_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _rol; // null mientras carga

  @override
  void initState() {
    super.initState();
    _cargarRol();
  }

  Future<void> _cargarRol() async {
    final rol = await AuthService().obtenerRol(); // RF-22
    if (mounted) setState(() => _rol = rol);
  }

  @override
  Widget build(BuildContext context) {
    // Menú según el rol del usuario.
    final esDueno = _rol == 'dueno';

    final List<Map<String, dynamic>> menuConductor = [
      {
        'title': 'Mapa del Parqueadero',
        'icon': Icons.map_rounded,
        'color': Colors.purple,
        'pantalla': const MapaScreen(),
      },
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
        'title': 'Cálculo de Tarifas',
        'icon': Icons.monetization_on_rounded,
        'color': Colors.teal,
        'pantalla': const TarifasScreen(),
      },
      {
        'title': 'Mi Historial',
        'icon': Icons.history_rounded,
        'color': Colors.orange,
        'pantalla': const HistorialScreen(),
      },
    ];

    final List<Map<String, dynamic>> menuDueno = [
      {
        'title': 'Mis Garajes',
        'icon': Icons.store_mall_directory_rounded,
        'color': Colors.indigo,
        'pantalla': const MisGarajesScreen(),
      },
      {
        'title': 'Tarifas y Horarios',
        'icon': Icons.tune_rounded,
        'color': Colors.teal,
        'pantalla': const TarifaConfigScreen(),
      },
    ];

    final menu = esDueno ? menuDueno : menuConductor;

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
      body: _rol == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                      esDueno
                          ? 'Gestiona tus garajes, su capacidad y tarifas.'
                          : 'Encuentra, reserva y paga tu parqueo fácilmente.',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: esDueno
                            ? Colors.indigo.shade50
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        esDueno ? 'Rol: Dueño de garaje' : 'Rol: Conductor',
                        style: TextStyle(
                          color: esDueno ? Colors.indigo : Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 200,
                        childAspectRatio: 1.1,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: menu.length,
                      itemBuilder: (context, index) {
                        final option = menu[index];
                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          color: Colors.white,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      option['pantalla'] as Widget,
                                ),
                              );
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor:
                                      option['color'].withOpacity(0.1),
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
