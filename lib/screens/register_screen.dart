import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Conexión real a Firebase
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // 🚗 Controladores opcionales para el vehículo
  final _placaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _colorController = TextEditingController();

  bool _isPasswordVisible = false;
  final bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  String _rol = 'conductor'; // RF-22: rol seleccionado

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _placaController.dispose();
    _modeloController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  void _submitRegister() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Registra en Auth y guarda el perfil (nombre + rol + datos opcionales) en Firestore.
        await AuthService().registrar(
          nombre: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          rol: _rol,
          // 🔹 Se pasan los datos del vehículo (si está seleccionado rol conductor)
          placa: _rol == 'conductor' ? _placaController.text.trim().toUpperCase() : '',
          modeloMarca: _rol == 'conductor' ? _modeloController.text.trim() : '',
          color: _rol == 'conductor' ? _colorController.text.trim() : '',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Cuenta creada con éxito en Firebase! Ya puedes iniciar sesión.'),
              backgroundColor: Colors.green,
            ),
          );
          // Retornar automáticamente al Login
          Navigator.pop(context);
        }
      } on FirebaseAuthException catch (e) {
        String errorMessage = 'Ocurrió un error al registrarse.';

        if (e.code == 'email-already-in-use') {
          errorMessage = 'Este correo ya está registrado en la plataforma.';
        } else if (e.code == 'weak-password') {
          errorMessage = 'La contraseña proporcionada es muy débil (mínimo 6 caracteres).';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'El formato del correo electrónico no es válido.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      } catch (e) {
        // Captura cualquier otro error (por ejemplo, reglas de Firestore).
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cuenta creada, pero hubo un detalle al guardar el perfil: $e'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pop(context);
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24.0),
            margin: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 40.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Crear Cuenta',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),

                  // Selector de rol (RF-22)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('¿Cómo te vas a registrar?',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _RolCard(
                          icon: Icons.directions_car_rounded,
                          titulo: 'Conductor',
                          seleccionado: _rol == 'conductor',
                          onTap: () => setState(() => _rol = 'conductor'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RolCard(
                          icon: Icons.store_mall_directory_rounded,
                          titulo: 'Dueño de garaje',
                          seleccionado: _rol == 'dueno',
                          onTap: () => setState(() => _rol = 'dueno'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Campo de Nombre
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Nombre Completo',
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Ingresa tu nombre';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Campo de Correo
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Correo Electrónico',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Ingresa tu correo';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Campo de Contraseña
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Ingresa una contraseña';
                      if (value.length < 6) return 'Debe tener al menos 6 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Campo de Confirmar Contraseña
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: !_isConfirmPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Confirmar Contraseña',
                      prefixIcon: const Icon(Icons.lock_clock_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Confirma tu contraseña';
                      if (value != _passwordController.text) return 'Las contraseñas no coinciden';
                      return null;
                    },
                  ),

                  // 🚗 CAMPOS OPCIONALES DEL VEHÍCULO (Solo se muestran si es Conductor)
                  if (_rol == 'conductor') ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Text(
                          'Datos del Vehículo',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Opcional',
                            style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Campo Placa (OPCIONAL)
                    TextFormField(
                      controller: _placaController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'Número de Placa (ej. ABC-1234)',
                        prefixIcon: const Icon(Icons.credit_card_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (_) => null, // Opcional
                    ),
                    const SizedBox(height: 12),

                    // Campo Modelo/Marca (OPCIONAL)
                    TextFormField(
                      controller: _modeloController,
                      decoration: InputDecoration(
                        labelText: 'Modelo / Marca (ej. Chevrolet Sail)',
                        prefixIcon: const Icon(Icons.directions_car_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (_) => null, // Opcional
                    ),
                    const SizedBox(height: 12),

                    // Campo Color (OPCIONAL)
                    TextFormField(
                      controller: _colorController,
                      decoration: InputDecoration(
                        labelText: 'Color del vehículo (ej. Rojo)',
                        prefixIcon: const Icon(Icons.palette_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (_) => null, // Opcional
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Botón de Registrarse / Cargando
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                    onPressed: _submitRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Registrarse', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Tarjeta seleccionable de rol (RF-22).
class _RolCard extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final bool seleccionado;
  final VoidCallback onTap;

  const _RolCard({
    required this.icon,
    required this.titulo,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: seleccionado ? kPrimarySoft : Colors.transparent,
          border: Border.all(
            color: seleccionado ? kPrimary : Colors.grey.shade400,
            width: seleccionado ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: seleccionado ? kPrimary : Colors.grey),
            const SizedBox(height: 8),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: seleccionado ? kPrimary : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}