// Modelo de usuario de SmartParking.
// RF-01: nombre, correo, contraseña y rol.
// Los campos de vehículo quedan listos para el RF-11 (edición de perfil).
class AppUser {
  String name;
  String email;
  String password;
  String role; // 'conductor' o 'administrador'

  // Datos del vehículo (se editan en el RF-11)
  String placa;
  String modelo;
  String color;

  AppUser({
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    this.placa = '',
    this.modelo = '',
    this.color = '',
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'password': password,
        'role': role,
        'placa': placa,
        'modelo': modelo,
        'color': color,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        password: json['password'] ?? '',
        role: json['role'] ?? 'conductor',
        placa: json['placa'] ?? '',
        modelo: json['modelo'] ?? '',
        color: json['color'] ?? '',
      );
}