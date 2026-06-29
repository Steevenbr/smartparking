// lib/views/profile_view.dart
import 'package:flutter/material.dart';
import '../controllers/profile_controller.dart';
import '../models/profile_model.dart';

class ProfileView extends StatelessWidget {
  final ProfileController _controller = ProfileController();
  final TextEditingController _plateCtrl = TextEditingController();

  ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Editar Vehículo")),
      body: Column(
        children: [
          TextField(controller: _plateCtrl, decoration: InputDecoration(labelText: "Placa")),
          ElevatedButton(
            onPressed: () async {
              ProfileModel p = ProfileModel(plate: _plateCtrl.text, model: "N/A", color: "N/A");
              bool success = await _controller.saveProfileChanges(p);
              if(success) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Guardado")));
            },
            child: Text("Guardar"),
          ),
        ],
      ),
    );
  }
}