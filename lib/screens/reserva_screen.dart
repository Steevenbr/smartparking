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

  Parqueadero? _seleccionado;
  DateTime _fecha = DateTime.now();
  TimeOfDay _hora = TimeOfDay.now();
  bool _guardando = false;

  String _fechaTexto() =>
      '${_fecha.day.toString().padLeft(2, '0')}/${_fecha.month.toString().padLeft(2, '0')}/${_fecha.year}';

  String _horaTexto() =>
      '${_hora.hour.toString().padLeft(2, '0')}:${_hora.minute.toString().padLeft(2, '0')}';

  Future<void> _guardar() async {
    if (_seleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un parqueadero.')),
      );
      return;
    }
    setState(() => _guardando = true);
    await _reservas.crearReserva(
      parqueaderoId: _seleccionado!.id,
      parqueaderoNombre: _seleccionado!.nombre,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reservar Lugar')),
      body: StreamBuilder<List<Parqueadero>>(
        stream: _parqueaderos.escucharParqueaderos(),
        builder: (context, snapshot) {
          final lista = snapshot.data ?? [];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Parqueadero',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<Parqueadero>(
                  value: _seleccionado,
                  isExpanded: true,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  hint: const Text('Selecciona un parqueadero'),
                  items: lista
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(p.nombre, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _seleccionado = v),
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
                  child: Text(_guardando ? 'Guardando...' : 'Confirmar reserva'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
