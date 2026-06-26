import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // <--- Importante
import 'firebase_options.dart'; // <--- Importante
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Verifica si Firebase ya está inicializado por el plugin nativo
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    // Si da un error controlado, se puede imprimir en consola sin colgar la app
    print("Firebase ya estaba inicializado: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartParking',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}