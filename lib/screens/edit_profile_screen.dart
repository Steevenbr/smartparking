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
  final _emailController = TextEditingController();
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
    _emailController.dispose();
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
              _nombreController.text = data['nombre'] ?? '';
              _emailController.text = data['email'] ?? _authService.usuarioActual?.email ?? '';

              // 🔀 UNIFICACIÓN DE LECTURA: Lee la estructura directa requerida por el Admin
              _placaController.text = data['placa'] ?? '';
              _modeloController.text = data['modelo_marca'] ?? data['modelo'] ?? '';
              _colorController.text = data['color'] ?? '';
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

  Future<void> _guardarCambios() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      try {
        final uid = _authService.uid;
        final emailActual = _authService.usuarioActual?.email ?? '';
        final nuevoEmail = _emailController.text.trim();
        final nuevoNombre = _nombreController.text.trim();
        final nuevaPlaca = _placaController.text.trim().toUpperCase();
        final nuevoModelo = _modeloController.text.trim();
        final nuevoColor = _colorController.text.trim();

        if (uid.isEmpty) throw 'No se encontró una sesión activa.';

        bool correoModificado = false;
        if (nuevoEmail != emailActual && nuevoEmail.isNotEmpty) {
          await _authService.actualizarEmail(nuevoEmail);
          correoModificado = true;
        }

        // 1. Guardar o actualizar en la colección principal 'usuarios'
        await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
          'nombre': nuevoNombre,
          'email': nuevoEmail,
          'placa': nuevaPlaca,
          'modelo_marca': nuevoModelo,
          'color': nuevoColor,
          'rol': 'conductor',
        }, SetOptions(merge: true));

        // 2. 🔄 SINCRONIZACIÓN EN CASCADA: Actualiza los datos del vehículo en las reservas activas
        final reservasUsuario = await FirebaseFirestore.instance
            .collection('reservas')
            .where('usuarioId', isEqualTo: uid)
            .get();

        if (reservasUsuario.docs.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (var doc in reservasUsuario.docs) {
            batch.update(doc.reference, {
              'usuarioNombre': nuevoNombre,
              'usuarioEmail': nuevoEmail,
              'vehiculoPlaca': nuevaPlaca,
              'vehiculoMarcaModelo': nuevoModelo,
              'vehiculoColor': nuevoColor,
            });
          }
          await batch.commit();
        }

        if (mounted) {
          String mensajeExito = 'Perfil, vehículo y reservas actualizados correctamente.';
          if (correoModificado) {
            mensajeExito += ' Se envió un correo de confirmación a su nueva dirección.';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(mensajeExito),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
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
      backgroundColor: kBg,
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

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Correo Electrónico',
                  prefixIcon: const Icon(Icons.email_outlined),
                  hintText: 'ejemplo@correo.com',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa tu correo electrónico';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                    return 'El formato del correo electrónico no es válido';
                  }
                  return null;
                },
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