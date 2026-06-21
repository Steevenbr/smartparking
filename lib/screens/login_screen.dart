import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';
import 'home_screen.dart';

// Pantalla de inicio de sesión (RF-01).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String? _error;
  bool _loading = false;

  Future<void> _login() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    final user = await _auth.login(_emailCtrl.text.trim(), _passCtrl.text);
    setState(() => _loading = false);

    if (user == null) {
      setState(() => _error = 'Correo o contraseña incorrectos.');
      return;
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.local_parking, size: 64, color: Colors.green),
              const SizedBox(height: 8),
              const Text(
                'SmartParking',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Inicia sesión para continuar',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Entrar'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                },
                child: const Text('¿No tienes cuenta? Crear una'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}