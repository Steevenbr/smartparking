// Configuración de tarifas y horarios del parqueadero (RF-21).
class TarifaConfig {
  double tarifaHora;      // costo por hora completa
  double tarifaFraccion;  // costo por fracción (ej. cada 15 min)
  int minutosFraccion;    // duración de la fracción en minutos
  String horaApertura;    // ej. "08:00"
  String horaCierre;      // ej. "20:00"

  TarifaConfig({
    this.tarifaHora = 0,
    this.tarifaFraccion = 0,
    this.minutosFraccion = 15,
    this.horaApertura = '08:00',
    this.horaCierre = '20:00',
  });

  Map<String, dynamic> toJson() => {
        'tarifaHora': tarifaHora,
        'tarifaFraccion': tarifaFraccion,
        'minutosFraccion': minutosFraccion,
        'horaApertura': horaApertura,
        'horaCierre': horaCierre,
      };

  factory TarifaConfig.fromJson(Map<String, dynamic> json) => TarifaConfig(
        tarifaHora: (json['tarifaHora'] ?? 0).toDouble(),
        tarifaFraccion: (json['tarifaFraccion'] ?? 0).toDouble(),
        minutosFraccion: json['minutosFraccion'] ?? 15,
        horaApertura: json['horaApertura'] ?? '08:00',
        horaCierre: json['horaCierre'] ?? '20:00',
      );
}