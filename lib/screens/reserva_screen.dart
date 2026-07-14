import 'package:flutter/material.dart';
import '../models/parqueadero.dart';
import '../services/parqueadero_service.dart';
import 'pago_reserva_screen.dart';

// RF-04: reserva de estacionamientos (ahora con pago anticipado).
class ReservaScreen extends StatefulWidget {
  const ReservaScreen({super.key});

  @override
  State<ReservaScreen> createState() => _ReservaScreenState();
}

class _ReservaScreenState extends State<ReservaScreen> {
  final _parqueaderos = ParqueaderoService();
  final _duracionCtrl = TextEditingController(text: '2');

  // Guardamos solo el id (texto) para evitar el error del Dropdown.
  String? _seleccionadoId;
  List<Parqueadero> _lista = [];
  DateTime _fecha = DateTime.now();
  TimeOfDay _hora = TimeOfDay.now();

  String _fechaTexto() =>
      '${_fecha.day.toString().padLeft(2, '0')}/${_fecha.month.toString().padLeft(2, '0')}/${_fecha.year}';

  String _horaTexto() =>
      '${_hora.hour.toString().padLeft(2, '0')}:${_hora.minute.toString().padLeft(2, '0')}';

  // Muestra el costo estimado según el parqueadero elegido y la duración.
  double _montoEstimado() {
    if (_seleccionadoId == null) return 0;
    final p = _lista.firstWhere((x) => x.id == _seleccionadoId);
    final horas = int.tryParse(_duracionCtrl.text) ?? 0;
    return p.tarifaHora * horas;
  }

  Future<void> _continuarAlPago() async {
    if (_seleccionadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un parqueadero.')),
      );
      return;
    }

    final p = _lista.firstWhere((x) => x.id == _seleccionadoId);

    // Validación de disponibilidad (RF-04)
    if (p.espaciosLibres <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
        content: Text('Ese parqueadero no tiene espacios disponibles.'),
        backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final horas = int.tryParse(_duracionCtrl.text) ?? 0;
    if (horas <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa una duración válida (mínimo 1 hora).'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Vamos a la pantalla de pago anticipado.
    final pagado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PagoReservaScreen(
          parqueadero: p,
          fecha: _fechaTexto(),
          hora: _horaTexto(),
          duracionHoras: horas,
        ),
      ),
    );

    // Si el pago se completó, cerramos esta pantalla.
    if (pagado == true && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reservar Lugar')),
      body: StreamBuilder<List<Parqueadero>>(
        stream: _parqueaderos.escucharParqueaderos(),
        builder: (context, snapshot) {
          _lista = snapshot.data ?? [];
          // Si el id guardado ya no está en la lista, lo limpiamos.
          if (_seleccionadoId != null &&
              !_lista.any((p) => p.id == _seleccionadoId)) {
            _seleccionadoId = null;
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_lista.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aún no hay parqueaderos registrados.\n'
                  'El administrador debe crearlos primero desde el Panel Administrador.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final monto = _montoEstimado();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Parqueadero',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _seleccionadoId,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(border: OutlineInputBorder()),
                  hint: const Text('Selecciona un parqueadero'),
                  // Mostramos espacios libres y tarifa de cada parqueadero.
                  items: _lista
                      .map((p) => DropdownMenuItem<String>(
                            value: p.id,
                            child: Text(
                              '${p.nombre} · ${p.espaciosLibres} libres · \$${p.tarifaHora.toStringAsFixed(2)}/h',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _seleccionadoId = v),
                ),
                const SizedBox(height: 20),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Fecha'),
                  trailing: Text(_fechaTexto()),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _fecha,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 60)),
                    );
                    if (d != null) setState(() => _fecha = d);
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                  leading: const Icon(Icons.access_time),
                  title: const Text('Hora de llegada'),
                  trailing: Text(_horaTexto()),
                  onTap: () async {
                    final t = await showTimePicker(
                        context: context, initialTime: _hora);
                    if (t != null) setState(() => _hora = t);
                  },
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _duracionCtrl,
                  keyboardType: TextInputType.number,
                  // Al escribir, recalculamos el costo estimado.
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Duración estimada (horas)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.hourglass_bottom),
                  ),
                ),
                const SizedBox(height: 24),

                // Costo estimado del pago anticipado
                if (_seleccionadoId != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Costo estimado',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          '\$${monto.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),

                const Text(
                  'La reserva requiere pago anticipado para confirmarse.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: _continuarAlPago,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Continuar al pago'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}