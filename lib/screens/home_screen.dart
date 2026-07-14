import 'dart:async'; // ⬅️ Necesario para el Timer en tiempo real
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/parking_logic_service.dart';
import '../theme.dart';
import '../models/parqueadero.dart';
import 'login_screen.dart';
import 'disponibilidad_screen.dart';
import 'reserva_screen.dart';
import 'historial_screen.dart';
import 'mapa_screen.dart';
import 'tarifas_screen.dart';
import 'mis_garajes_screen.dart';
import 'reportes_graficos_screen.dart';
import 'edit_profile_screen.dart';
import 'sesion_activa_screen.dart';
import 'mis_reservas_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _rol; // null mientras carga
  DocumentSnapshot? _sesionActivaDoc; // Almacena la sesión activa si existe
  bool _cargando = true;

  // Variables para controlar el cronómetro en el banner
  Timer? _bannerTimer;
  Duration _tiempoTranscurrido = Duration.zero;

  @override
  void initState() {
    super.initState();
    _inicializarDatos();
  }

  @override
  void dispose() {
    _detenerTimer();
    super.dispose();
  }

  void _detenerTimer() {
    _bannerTimer?.cancel();
    _bannerTimer = null;
  }

  // Carga el rol y verifica si hay sesión de parqueo en curso
  Future<void> _inicializarDatos() async {
    _detenerTimer(); // Detenemos cualquier temporizador previo
    setState(() => _cargando = true);
    try {
      final rol = await AuthService().obtenerRol();
      final sesion = await ParkingLogicService().obtenerSesionActiva();

      if (mounted) {
        setState(() {
          _rol = rol;
          _sesionActivaDoc = sesion;
          _cargando = false;
        });

        // Si hay una sesión activa, iniciamos el temporizador local para actualizar el Banner
        if (sesion != null) {
          _iniciarTimerBanner();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  // Actualiza localmente el contador de tiempo transcurrido cada segundo
  void _iniciarTimerBanner() {
    final data = _sesionActivaDoc!.data() as Map<String, dynamic>;
    final Timestamp? entradaTs = data['horaEntrada'];
    if (entradaTs == null) return;

    final horaEntrada = entradaTs.toDate();

    setState(() {
      _tiempoTranscurrido = DateTime.now().difference(horaEntrada);
    });

    _bannerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _tiempoTranscurrido = DateTime.now().difference(horaEntrada);
        });
      }
    });
  }

  // Formatea la duración en formato amigable HH:MM:SS
  String _formatoDuracion(Duration d) {
    String dosDigitos(int n) => n.toString().padLeft(2, '0');
    final horas = dosDigitos(d.inHours);
    final minutos = dosDigitos(d.inMinutes % 60);
    final segundos = dosDigitos(d.inSeconds % 60);
    return '$horas:$minutos:$segundos';
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
        'title': 'Mis Reservas',
        'icon': Icons.event_note_rounded,
        'color': Colors.teal,
        'pantalla': const MisReservasScreen(),
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
      {
        'title': 'Mi Perfil y Vehículo',
        'icon': Icons.manage_accounts_rounded,
        'color': Colors.blueGrey,
        'pantalla': const EditProfileScreen(),
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
        'title': 'Reportes y Ganancias',
        'icon': Icons.analytics_rounded,
        'color': Colors.orange.shade800,
        'pantalla': const ReportesGraficosScreen(),
      },
    ];

    final menu = esDueno ? menuDueno : menuConductor;

    return Scaffold(
      backgroundColor: kBg,
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _header(esDueno)),

            // BANNER INTERACTIVO EN TIEMPO REAL (Solo para conductores con parqueo activo)
            if (!esDueno && _sesionActivaDoc != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _buildBannerSesionActiva(),
                ),
              ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
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

  // Banner personalizado que muestra dinámicamente el contador HH:MM:SS
  Widget _buildBannerSesionActiva() {
    final data = _sesionActivaDoc!.data() as Map<String, dynamic>;

    final p = Parqueadero(
      id: data['parqueaderoId'] ?? '',
      nombre: data['parqueaderoNombre'] ?? 'Garaje',
      direccion: '',
      latitud: 0.0,
      longitud: 0.0,
      tarifaHora: (data['tarifaHora'] ?? 0.0).toDouble(),
      minutosFraccion: (data['minutosFraccion'] ?? 15) as int,
      espaciosLibres: 0,
      espaciosTotales: 0,
    );

    final Timestamp entradaTs = data['horaEntrada'] ?? Timestamp.now();

    return Material(
      color: Colors.amber.shade50,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          _detenerTimer(); // Apagamos el timer local antes de saltar a la pantalla de detalle
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SesionActivaScreen(
                registroId: _sesionActivaDoc!.id,
                parqueadero: p,
                horaEntrada: entradaTs.toDate(),
              ),
            ),
          );
          _inicializarDatos(); // Al volver, refresca para actualizar o remover el banner
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.amber.shade300, width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade200,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bolt, color: Colors.amber, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tienes un parqueo activo',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Garaje: ${p.nombre}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    // AQUÍ SE MUESTRA EL TIEMPO EN TIEMPO REAL
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 13.5, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          'Tiempo: ${_formatoDuracion(_tiempoTranscurrido)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16),
            ],
          ),
        ),
      ),
    );
  }

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
              const Icon(Icons.local_parking_rounded, color: Colors.white, size: 26),
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
                icon: const Icon(Icons.account_circle_outlined, color: Colors.white),
                tooltip: 'Editar Perfil',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                  ).then((_) => _inicializarDatos());
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                tooltip: 'Cerrar sesión',
                onPressed: () async {
                  await AuthService().cerrarSesion();
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
                  esDueno ? Icons.store_mall_directory_rounded : Icons.directions_car_rounded,
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
          ).then((_) => _inicializarDatos());
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
                child: Icon(option['icon'] as IconData, size: 30, color: Colors.white),
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