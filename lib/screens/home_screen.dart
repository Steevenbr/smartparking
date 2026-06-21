import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'mapa_screen.dart';

// Pantalla de inicio (RF-01) + edición de perfil y vehículo (RF-11)
// + acceso a parqueaderos cercanos (RF-02).
class HomeScreen extends StatefulWidget {
  final AppUser user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late AppUser user;

  @override
  void initState() {
    super.initState();
    user = widget.user;
  }

  Future<void> _abrirEditar() async {
    final actualizado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(user: user)),
    );
    // Si se guardó algún cambio, refrescamos la pantalla.
    if (actualizado == true) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final esAdmin = user.role == 'administrador';
    final tieneVehiculo = user.placa.isNotEmpty || user.modelo.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartParking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: esAdmin ? Colors.orange : Colors.green,
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: const TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Text(user.name,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            Text(user.email, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Chip(
              label: Text(user.role.toUpperCase()),
              backgroundColor:
                  esAdmin ? Colors.orange.shade100 : Colors.green.shade100,
            ),
            const SizedBox(height: 24),

            // Tarjeta con los datos del vehículo (RF-11)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.directions_car, size: 20),
                        SizedBox(width: 8),
                        Text('Mi vehículo',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (tieneVehiculo) ...[
                      Text('Placa: ${user.placa.isEmpty ? "—" : user.placa}'),
                      Text('Modelo: ${user.modelo.isEmpty ? "—" : user.modelo}'),
                      Text('Color: ${user.color.isEmpty ? "—" : user.color}'),
                    ] else
                      const Text('Aún no has registrado tu vehículo.',
                          style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Botón para editar perfil y vehículo (RF-11)
            FilledButton.icon(
              onPressed: _abrirEditar,
              icon: const Icon(Icons.edit),
              label: const Text('Editar perfil y vehículo'),
            ),
            const SizedBox(height: 16),

            // Botón para ver parqueaderos cercanos (RF-02)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MapaScreen()),
                );
              },
              icon: const Icon(Icons.map),
              label: const Text('Buscar parqueaderos cercanos'),
            ),
            const SizedBox(height: 16),

            if (esAdmin)
              Card(
                color: Colors.orange.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Tienes acceso al panel de administración.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}