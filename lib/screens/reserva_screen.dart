import 'package:flutter/material.dart';
import '../models/parqueadero.dart';
import '../services/parqueadero_service.dart';
import '../services/reserva_service.dart';

// RF-04: reserva de estacionamientos.
class ReservaScreen extends StatefulWidget {
  const ReservaScreen({super.key});

  @override
  State<ReservaScreen> createState() => _ReservaScreenState();
}

class _ReservaScreenState extends State<ReservaScreen> {
  final _parqueaderos = ParqueaderoService();
  final _reservas = ReservaService();
  final _duracionCtrl = TextEditingController(text: '2');

  // Guardamos solo el id (texto) para evitar el error del Dropdown.
  String? _seleccionadoId;
  List<Parqueadero> _lista = [];
  DateTime _fecha = DateTime.now();
  TimeOfDay _hora = TimeOfDay.now();
  bool _guardando = false;

  String _fechaTexto() =>
      '${_fecha.day.toString().padLeft(2, '0')}/${_fecha.month.toString().padLeft(2, '0')}/${_fecha.year}';

  String _horaTexto() =>
      '${_hora.hour.toString().padLeft(2, '0')}:${_hora.minute.toString().padLeft(2, '0')}';

  Future<void> _guardar() async {
    if (_seleccionadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un parqueadero.')),
      );
      return;
    }
    final p = _lista.firstWhere((x) => x.id == _seleccionadoId);

    // Validación previa en pantalla (RF-04)
    if (p.espaciosLibres <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ese parqueadero no tiene espacios disponibles.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      await _reservas.crearReserva(
        parqueaderoId: p.id,
        parqueaderoNombre: p.nombre,
        fecha: _fechaTexto(),
        hora: _horaTexto(),
        duracionHoras: int.tryParse(_duracionCtrl.text) ?? 1,
      );
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Reserva creada con éxito.'),
            backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      // Si el parqueadero se llenó justo antes, mostramos el error.
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
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
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Parqueadero',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _seleccionadoId,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(border: OutlineInputBorder()),
                  hint: const Text('Selecciona un parqueadero'),
                  // Mostramos los espacios libres de cada parqueadero (RF-04)
                  items: _lista
                      .map((p) => DropdownMenuItem<String>(
                            value: p.id,
                            child: Text(
                              '${p.nombre} (${p.espaciosLibres} libres)',
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
                  decoration: const InputDecoration(
                    labelText: 'Duración estimada (horas)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.hourglass_bottom),
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _guardando ? null : _guardar,
                  child:
                      Text(_guardando ? 'Guardando...' : 'Confirmar reserva'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}