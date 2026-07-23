import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_parking/screens/reportes_admin_screen.dart';
import '../services/auth_service.dart';
import '../services/parking_logic_service.dart';
import '../theme.dart';
import '../models/parqueadero.dart';
import 'login_screen.dart';
import 'disponibilidad_screen.dart';
import 'reserva_screen.dart';
import 'mis_reservas_screen.dart';
import 'historial_screen.dart';
import 'mapa_screen.dart';
import 'tarifas_screen.dart';
import 'mis_garajes_screen.dart';
import 'reportes_graficos_screen.dart';
import 'edit_profile_screen.dart';
import 'sesion_activa_screen.dart';
import 'resenas_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _rol;
  DocumentSnapshot? _sesionActivaDoc;
  bool _cargando = true;
  bool _esInvitado = true;

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

  Future<void> _inicializarDatos() async {
    _detenerTimer();
    setState(() => _cargando = true);

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _rol = 'conductor';
          _esInvitado = true;
          _sesionActivaDoc = null;
          _cargando = false;
        });
      }
      return;
    }

    try {
      final rol = await AuthService().obtenerRol();
      final sesion = await ParkingLogicService().obtenerSesionActiva();

      if (mounted) {
        setState(() {
          _rol = rol;
          _esInvitado = false;
          _sesionActivaDoc = sesion;
          _cargando = false;
        });

        if (sesion != null) {
          _iniciarTimerBanner();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _iniciarTimerBanner() {
    if (_sesionActivaDoc == null) return;

    final data = _sesionActivaDoc!.data() as Map<String, dynamic>;

    // Evalúa la fecha programada o de entrada
    final Timestamp? entradaTs = data['fechaProgramada'] ?? data['horaEntrada'] ?? data['creadoEn'];
    if (entradaTs == null) return;

    final horaInicio = entradaTs.toDate();
    final ahora = DateTime.now();

    if (ahora.isBefore(horaInicio)) {
      setState(() {
        _tiempoTranscurrido = Duration.zero;
      });
    } else {
      setState(() {
        _tiempoTranscurrido = ahora.difference(horaInicio);
      });
    }

    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        final actual = DateTime.now();
        if (actual.isBefore(horaInicio)) {
          setState(() {
            _tiempoTranscurrido = Duration.zero;
          });
        } else {
          setState(() {
            _tiempoTranscurrido = actual.difference(horaInicio);
          });
        }
      }
    });
  }

  String _formatoDuracion(Duration d) {
    String dosDigitos(int n) => n.toString().padLeft(2, '0');
    return '${dosDigitos(d.inHours)}:${dosDigitos(d.inMinutes % 60)}:${dosDigitos(d.inSeconds % 60)}';
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
        'requiereAuth': false,
      },
      {
        'title': 'Espacios Disponibles',
        'icon': Icons.directions_car_rounded,
        'color': kPrimary,
        'pantalla': const DisponibilidadScreen(),
        'requiereAuth': false,
      },
      {
        'title': 'Reservar Lugar',
        'icon': Icons.bookmark_add_rounded,
        'color': Colors.green,
        'pantalla': const ReservaScreen(),
        'requiereAuth': true,
      },
      {
        'title': 'Cálculo de Tarifas',
        'icon': Icons.monetization_on_rounded,
        'color': kAccent,
        'pantalla': const TarifasScreen(),
        'requiereAuth': false,
      },
      {
        'title': 'Mis Reservas',
        'icon': Icons.event_note_rounded,
        'color': Colors.indigo,
        'pantalla': const MisReservasScreen(),
        'requiereAuth': true,
      },
      {
        'title': 'Mi Historial',
        'icon': Icons.history_rounded,
        'color': Colors.orange,
        'pantalla': const HistorialScreen(),
        'requiereAuth': true,
      },
      {
        'title': 'Reseñas y Opiniones',
        'icon': Icons.star_rate_rounded,
        'color': Colors.amber.shade800,
        'pantalla': const ResenasScreen(),
        'requiereAuth': false,
      },
      {
        'title': 'Mi Perfil y Vehículo',
        'icon': Icons.manage_accounts_rounded,
        'color': Colors.blueGrey,
        'pantalla': const EditProfileScreen(),
        'requiereAuth': true,
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
        'title': 'Monitoreo y Auditoría',
        'icon': Icons.badge_rounded,
        'color': Colors.orange.shade800,
        'pantalla': const ReportesAdminScreen(),
      },
      {
        'title': 'Reportes Gráficos',
        'icon': Icons.bar_chart_rounded,
        'color': Colors.teal.shade700,
        'pantalla': const ReportesGraficosScreen(),
      },
      {
        'title': 'Reseñas de Clientes',
        'icon': Icons.rate_review_rounded,
        'color': Colors.teal,
        'pantalla': const ResenasScreen(),
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
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              _esInvitado
                  ? IconButton(
                icon: const Icon(Icons.login_rounded, color: Colors.white),
                tooltip: 'Iniciar Sesión',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                ).then((_) => _inicializarDatos()),
              )
                  : IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                tooltip: 'Cerrar sesión',
                onPressed: () async {
                  await AuthService().cerrarSesion();
                  _inicializarDatos();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _esInvitado ? '¡Bienvenido!' : '¡Hola de nuevo!',
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            esDueno
                ? 'Gestiona tus garajes, capacidad y tarifas.'
                : 'Encuentra, reserva y paga tu parqueo fácilmente.',
            style: const TextStyle(color: Colors.white70, fontSize: 15),
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
          if (_esInvitado && (option['requiereAuth'] ?? false)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Para acceder a esta función debes iniciar sesión primero.')),
            );
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            ).then((_) => _inicializarDatos());
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => option['pantalla'] as Widget),
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
                    colors: [color.withOpacity(0.85), color.withOpacity(0.55)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(option['icon'] as IconData, size: 30, color: Colors.white),
              ),
              const SizedBox(height: 14),
              Text(
                option['title'] as String,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBannerSesionActiva() {
    final data = _sesionActivaDoc!.data() as Map<String, dynamic>;
    final p = Parqueadero(
      id: data['parqueaderoId'] ?? '',
      nombre: data['parqueaderoNombre'] ?? 'Garaje',
      direccion: '', latitud: 0.0, longitud: 0.0,
      tarifaHora: (data['tarifaHora'] ?? 0.0).toDouble(),
      minutosFraccion: (data['minutosFraccion'] ?? 15) as int,
      espaciosLibres: 0, espaciosTotales: 0,
    );

    // Mapeo seguro de la fecha programada o fecha de entrada
    final Timestamp entradaTs = data['fechaProgramada'] ?? data['horaEntrada'] ?? data['creadoEn'] ?? Timestamp.now();
    final DateTime fechaInicioReal = entradaTs.toDate();
    final bool esFutura = DateTime.now().isBefore(fechaInicioReal);

    final horaInicioStr = '${fechaInicioReal.hour.toString().padLeft(2, '0')}:${fechaInicioReal.minute.toString().padLeft(2, '0')}';

    return Material(
      color: esFutura ? Colors.blue.shade50 : Colors.amber.shade50,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          _detenerTimer();
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SesionActivaScreen(
                registroId: _sesionActivaDoc!.id,
                parqueadero: p,
                horaEntrada: fechaInicioReal,
              ),
            ),
          );
          _inicializarDatos();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: esFutura ? Colors.blue.shade300 : Colors.amber.shade300, width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: esFutura ? Colors.blue.shade100 : Colors.amber.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  esFutura ? Icons.schedule_rounded : Icons.bolt,
                  color: esFutura ? Colors.blue.shade800 : Colors.amber.shade900,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      esFutura ? 'Reserva Programada' : 'Tienes un parqueo activo',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text('Garaje: ${p.nombre}', style: TextStyle(fontSize: 12.5, color: Colors.grey[700])),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          esFutura ? Icons.access_time_rounded : Icons.timer_outlined,
                          size: 13.5,
                          color: esFutura ? Colors.blue.shade700 : Colors.amber.shade900,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          esFutura
                              ? 'Inicia hoy a las $horaInicioStr'
                              : 'Tiempo: ${_formatoDuracion(_tiempoTranscurrido)}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: esFutura ? Colors.blue.shade700 : Colors.amber.shade900,
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
}