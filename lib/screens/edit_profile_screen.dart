import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme.dart';

// RF-11: Permite al usuario editar sus datos personales y la información de su vehículo
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  // Controladores de texto para el perfil y vehículo
  final _nombreController = TextEditingController();
  final _placaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _colorController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cargarDatosActuales();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _placaController.dispose();
    _modeloController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  // Carga los datos existentes desde Firestore para mostrarlos en los inputs
  Future<void> _cargarDatosActuales() async {
    try {
      final uid = _authService.uid;

      if (uid.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();

      if (mounted) {
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            setState(() {
              // Muestra el nombre con el que el usuario inició sesión/se registró
              _nombreController.text = data['nombre'] ?? '';

              // Mapeo seguro si la estructura del coche existe
              if (data['vehiculo'] != null) {
                final vehiculo = data['vehiculo'] as Map<String, dynamic>;
                _placaController.text = vehiculo['placa'] ?? '';
                _modeloController.text = vehiculo['modelo'] ?? '';
                _colorController.text = vehiculo['color'] ?? '';
              }
            });
          }
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Aviso: Registra tus datos por primera vez ($e)'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  // Envía las modificaciones validadas a Firestore mediante el AuthService
  Future<void> _guardarCambios() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      try {
        await _authService.actualizarPerfilYVehiculo(
          nombre: _nombreController.text,
          placa: _placaController.text,
          modelo: _modeloController.text,
          color: _colorController.text,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Perfil y vehículo actualizados correctamente.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // Regresa al Home
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil y Vehículo'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sección 1: Datos Personales
              const Row(
                children: [
                  Icon(Icons.person, color: kPrimary),
                  SizedBox(width: 8),
                  Text(
                    'Datos Personales',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Input de Nombre Completo (Aparece cargado automáticamente con su cuenta)
              TextFormField(
                controller: _nombreController,
                decoration: InputDecoration(
                  labelText: 'Nombre Completo',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Ingresa tu nombre' : null,
              ),
              const SizedBox(height: 20),

              // Input de Correo Electrónico (Informativo, bloqueado para evitar inconsistencias de Auth)
              TextFormField(
                initialValue: _authService.usuarioActual?.email,
                enabled: false,
                decoration: InputDecoration(
                  labelText: 'Correo Electrónico (No modificable)',
                  prefixIcon: const Icon(Icons.email_outlined),
                  fillColor: Colors.grey[200],
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),

              // Sección 2: Información del Vehículo
              const Row(
                children: [
                  Icon(Icons.directions_car_rounded, color: kPrimary),
                  SizedBox(width: 8),
                  Text(
                    'Información del Vehículo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Input de Placa
              TextFormField(
                controller: _placaController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Placa del Vehículo',
                  hintText: 'Ej: PBX-1234',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Ingresa la placa del auto' : null,
              ),
              const SizedBox(height: 20),

              // Input de Modelo
              TextFormField(
                controller: _modeloController,
                decoration: InputDecoration(
                  labelText: 'Modelo / Marca',
                  hintText: 'Ej: Chevrolet Sail',
                  prefixIcon: const Icon(Icons.car_repair_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Ingresa el modelo' : null,
              ),
              const SizedBox(height: 20),

              // Input de Color
              TextFormField(
                controller: _colorController,
                decoration: InputDecoration(
                  labelText: 'Color del Vehículo',
                  hintText: 'Ej: Negro',
                  prefixIcon: const Icon(Icons.palette_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Ingresa el color' : null,
              ),
              const SizedBox(height: 40),

              // Botón de Guardar Cambios
              _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                onPressed: _guardarCambios,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Guardar Modificaciones', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}