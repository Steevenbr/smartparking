import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

// Pantalla de edición de perfil y vehículo (RF-11).
class EditProfileScreen extends StatefulWidget {
  final AppUser user;
  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _auth = AuthService();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _placaCtrl;
  late final TextEditingController _modeloCtrl;
  late final TextEditingController _colorCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Cargamos los datos actuales del usuario en los campos.
    _nameCtrl = TextEditingController(text: widget.user.name);
    _placaCtrl = TextEditingController(text: widget.user.placa);
    _modeloCtrl = TextEditingController(text: widget.user.modelo);
    _colorCtrl = TextEditingController(text: widget.user.color);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _placaCtrl.dispose();
    _modeloCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre no puede estar vacío.')),
      );
      return;
    }

    setState(() => _loading = true);

    // Actualizamos los datos del usuario.
    widget.user.name = _nameCtrl.text.trim();
    widget.user.placa = _placaCtrl.text.trim().toUpperCase();
    widget.user.modelo = _modeloCtrl.text.trim();
    widget.user.color = _colorCtrl.text.trim();

    await _auth.updateUser(widget.user);

    setState(() => _loading = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Perfil actualizado correctamente.')),
    );
    Navigator.pop(context, true); // devolvemos true para refrescar el Home
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil y vehículo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Datos personales',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre completo',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              enabled: false,
              decoration: InputDecoration(
                labelText: 'Correo (no editable)',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.email_outlined),
                hintText: widget.user.email,
              ),
            ),
            const SizedBox(height: 28),
            const Text('Datos del vehículo',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: _placaCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Placa',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.confirmation_number_outlined),
                hintText: 'Ej. PCA-1234',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _modeloCtrl,
              decoration: const InputDecoration(
                labelText: 'Modelo',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.directions_car_outlined),
                hintText: 'Ej. Toyota Corolla',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _colorCtrl,
              decoration: const InputDecoration(
                labelText: 'Color',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.palette_outlined),
                hintText: 'Ej. Rojo',
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }
}