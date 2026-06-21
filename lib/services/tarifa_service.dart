import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tarifa_config.dart';

// Servicio que guarda y lee la configuración de tarifas (RF-21).
class TarifaService {
  static const _key = 'sp_tarifa_config';

  Future<TarifaConfig> getConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return TarifaConfig(); // valores por defecto
    return TarifaConfig.fromJson(jsonDecode(raw));
  }

  Future<void> saveConfig(TarifaConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(config.toJson()));
  }
}