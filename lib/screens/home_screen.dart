import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'disponibilidad_screen.dart';
import 'reserva_screen.dart';
import 'historial_screen.dart';
import 'mapa_screen.dart';
import 'tarifas_screen.dart';
import 'mis_garajes_screen.dart';

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
        'color': kPrimary,
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
        'color': kAccent,
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
    ];

    final menu = esDueno ? menuDueno : menuConductor;

    return Scaffold(
      backgroundColor: kBg,
      body: _rol == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              bottom: false,
              child: CustomScrollView(
                slivers: [
                  // Encabezado con degradado.
                  SliverToBoxAdapter(child: _header(esDueno)),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 200,
                        childAspectRatio: 1.05,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _menuCard(context, menu[index]),
                        childCount: menu.length,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // Encabezado superior con degradado, saludo, rol y botón de salir.
  Widget _header(bool esDueno) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: kHeaderGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_parking_rounded,
                  color: Colors.white, size: 26),
              const SizedBox(width: 8),
              const Text(
                'SmartParking',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                tooltip: 'Cerrar sesión',
                onPressed: () async {
                  await AuthService().cerrarSesion(); // RF-09
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LoginScreen()),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '¡Hola de nuevo!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            esDueno
                ? 'Gestiona tus garajes, capacidad y tarifas.'
                : 'Encuentra, reserva y paga tu parqueo fácilmente.',
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  esDueno
                      ? Icons.store_mall_directory_rounded
                      : Icons.directions_car_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  esDueno ? 'Dueño de garaje' : 'Conductor',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Tarjeta de cada opción del menú.
  Widget _menuCard(BuildContext context, Map<String, dynamic> option) {
    final Color color = option['color'] as Color;
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => option['pantalla'] as Widget,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withOpacity(0.85),
                      color.withOpacity(0.55),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(option['icon'] as IconData,
                    size: 30, color: Colors.white),
              ),
              const SizedBox(height: 14),
              Text(
                option['title'] as String,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
