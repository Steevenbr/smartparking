import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/tarifa_config.dart';
import '../services/auth_service.dart';
import '../services/tarifa_service.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'tarifa_config_screen.dart';

// Pantalla de inicio (RF-01 + RF-11 + RF-21).
// Conductor: ve sus datos, su vehículo y las tarifas (solo lectura).
// Administrador: además puede configurar tarifas y horarios.
class HomeScreen extends StatefulWidget {
  final AppUser user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late AppUser user;
  TarifaConfig? _tarifa;

  @override
  void initState() {
    super.initState();
    user = widget.user;
    _cargarTarifa();
  }

  Future<void> _cargarTarifa() async {
    final config = await TarifaService().getConfig();
    if (!mounted) return;
    setState(() => _tarifa = config);
  }

  Future<void> _abrirEditar() async {
    final actualizado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(user: user)),
    );
    if (actualizado == true) setState(() {});
  }

  Future<void> _abrirConfigTarifa() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TarifaConfigScreen()),
    );
    // Al volver, recargamos por si el admin cambió las tarifas.
    _cargarTarifa();
  }

  @override
  Widget build(BuildContext context) {
    final esAdmin = user.role == 'administrador';
    final color = esAdmin ? Colors.orange : Colors.green;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // Encabezado con degradado
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: color,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                tooltip: 'Cerrar sesión',
                onPressed: () async {
                  await AuthService().logout();
                  if (!context.mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color.shade700, color.shade400],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.white,
                          child: Text(
                            user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 28,
                              color: color.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontSize: 22,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          user.email,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Contenido
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Rol
                Row(
                  children: [
                    Icon(
                      esAdmin
                          ? Icons.admin_panel_settings
                          : Icons.directions_car,
                      color: color,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      esAdmin ? 'Administrador' : 'Conductor',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Tarjeta del vehículo (RF-11)
                _buildVehiculoCard(),
                const SizedBox(height: 16),

                // Botón editar perfil (RF-11)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _abrirEditar,
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar perfil y vehículo'),
                ),
                const SizedBox(height: 24),

                // Tarjeta de tarifas (RF-21) — visible para todos
                _buildTarifaCard(esAdmin),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // Tarjeta con los datos del vehículo
  Widget _buildVehiculoCard() {
    final tieneVehiculo = user.placa.isNotEmpty || user.modelo.isNotEmpty;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.directions_car, color: Colors.green),
                SizedBox(width: 8),
                Text('Mi vehículo',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const Divider(height: 24),
            if (tieneVehiculo) ...[
              _filaInfo('Placa', user.placa.isEmpty ? '—' : user.placa),
              _filaInfo('Modelo', user.modelo.isEmpty ? '—' : user.modelo),
              _filaInfo('Color', user.color.isEmpty ? '—' : user.color),
            ] else
              const Text('Aún no has registrado tu vehículo.',
                  style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // Tarjeta de tarifas: solo lectura para conductor, con botón de config para admin
  Widget _buildTarifaCard(bool esAdmin) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.attach_money, color: Colors.teal),
                SizedBox(width: 8),
                Text('Tarifas y horario',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const Divider(height: 24),
            if (_tarifa == null)
              const Center(child: CircularProgressIndicator())
            else ...[
              _filaInfo(
                  'Por hora', '\$${_tarifa!.tarifaHora.toStringAsFixed(2)}'),
              _filaInfo('Por fracción',
                  '\$${_tarifa!.tarifaFraccion.toStringAsFixed(2)} (${_tarifa!.minutosFraccion} min)'),
              _filaInfo('Horario',
                  '${_tarifa!.horaApertura} - ${_tarifa!.horaCierre}'),
            ],
            if (esAdmin) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange,
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: _abrirConfigTarifa,
                icon: const Icon(Icons.settings),
                label: const Text('Configurar tarifas y horarios'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Fila tipo "etiqueta: valor"
  Widget _filaInfo(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(valor,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        ],
      ),
    );
  }
}