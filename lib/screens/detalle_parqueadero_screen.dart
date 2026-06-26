// lib/screens/detalle_parqueadero_screen.dart
import 'package:flutter/material.dart';

class DetalleParqueaderoScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Detalle del Servicio")),
      body: Column(
        children: [
          // RF-15: Costo en tiempo real (usar un Timer para actualizar)
          Text("Costo acumulado: $0.00"),
          
          // RF-17: Sección de calificación
          ElevatedButton(
            onPressed: () { /* Abrir modal de calificación */ },
            child: Text("Calificar parqueadero"),
          ),
        ],
      ),
    );
  }
}