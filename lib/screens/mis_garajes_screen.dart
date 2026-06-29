import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/parqueadero.dart';
import '../services/parqueadero_service.dart';
import '../services/auth_service.dart';

// RF-20 y RF-21: el dueño gestiona sus garajes (crear, editar tarifa/fracción/
// horario, activar/desactivar). Toda la configuración es POR garaje.
class MisGarajesScreen extends StatelessWidget {
  const MisGarajesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = ParqueaderoService();
    final ownerId = AuthService().uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Garajes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _dialogoGaraje(context, service, ownerId),
        icon: const Icon(Icons.add),
        label: const Text('Agregar garaje'),
      ),
      body: StreamBuilder<List<Parqueadero>>(
        stream: service.escucharMisGarajes(ownerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final lista = snapshot.data ?? [];
          if (lista.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aún no has registrado ningún garaje.\n'
                  'Toca "Agregar garaje" para crear el primero.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lista.length,
            itemBuilder: (context, i) {
              final p = lista[i];
              final activo = p.activo;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: activo ? Colors.white : Colors.grey.shade200,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: activo ? Colors.indigo : Colors.grey,
                    child: const Icon(Icons.store, color: Colors.white),
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(p.nombre,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      if (!activo) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('Inactivo',
                              style:
                                  TextStyle(fontSize: 11, color: Colors.white)),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    '${p.direccion}\n'
                    'Cap: ${p.espaciosTotales} · Libres: ${p.espaciosLibres} · \$${p.tarifaHora}/h · frac ${p.minutosFraccion}min',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            color: kPrimary),
                        tooltip: 'Editar',
                        onPressed: () => _dialogoGaraje(
                            context, service, ownerId,
                            existente: p),
                      ),
                      activo
                          ? IconButton(
                              icon: const Icon(Icons.toggle_on,
                                  color: Colors.green, size: 30),
                              tooltip: 'Desactivar',
                              onPressed: () =>
                                  service.desactivarParqueadero(p.id),
                            )
                          : IconButton(
                              icon: const Icon(Icons.toggle_off,
                                  color: Colors.grey, size: 30),
                              tooltip: 'Reactivar',
                              onPressed: () =>
                                  service.reactivarParqueadero(p.id),
                            ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Diálogo que sirve para CREAR (existente == null) o EDITAR un garaje.
  void _dialogoGaraje(
      BuildContext context, ParqueaderoService service, String ownerId,
      {Parqueadero? existente}) {
    final editando = existente != null;
    final nombreCtrl = TextEditingController(text: existente?.nombre ?? '');
    final dirCtrl = TextEditingController(text: existente?.direccion ?? '');
    final espaciosCtrl = TextEditingController(
        text: (existente?.espaciosTotales ?? 20).toString());
    final tarifaCtrl =
        TextEditingController(text: (existente?.tarifaHora ?? 1.0).toString());
    final fraccionCtrl = TextEditingController(
        text: (existente?.minutosFraccion ?? 15).toString());
    final aperturaCtrl =
        TextEditingController(text: existente?.horaApertura ?? '08:00');
    final cierreCtrl =
        TextEditingController(text: existente?.horaCierre ?? '20:00');
    final latCtrl = TextEditingController(
        text: (existente?.latitud ?? -0.9333).toString());
    final longCtrl = TextEditingController(
        text: (existente?.longitud ?? -78.6167).toString());

    Widget campo(String label, TextEditingController c, {TextInputType? tipo}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: c,
            keyboardType: tipo,
            decoration: const InputDecoration(isDense: true),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(editando ? 'Editar garaje' : 'Nuevo garaje',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                campo('Nombre del garaje', nombreCtrl),
                campo('Dirección', dirCtrl),
                Row(
                  children: [
                    Expanded(
                        child: campo('Capacidad', espaciosCtrl,
                            tipo: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: campo('Tarifa/hora (\$)', tarifaCtrl,
                            tipo: TextInputType.number)),
                  ],
                ),
                campo('Minutos por fracción', fraccionCtrl,
                    tipo: TextInputType.number),
                Row(
                  children: [
                    Expanded(child: campo('Hora apertura', aperturaCtrl)),
                    const SizedBox(width: 12),
                    Expanded(child: campo('Hora cierre', cierreCtrl)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                        child: campo('Latitud', latCtrl,
                            tipo: const TextInputType.numberWithOptions(
                                decimal: true, signed: true))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: campo('Longitud', longCtrl,
                            tipo: const TextInputType.numberWithOptions(
                                decimal: true, signed: true))),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kPrimarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: kPrimary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'La tarifa y la fracción son propias de este garaje.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final espacios = int.tryParse(espaciosCtrl.text) ?? 0;
              final datos = {
                'nombre': nombreCtrl.text.trim(),
                'direccion': dirCtrl.text.trim(),
                'latitud': double.tryParse(latCtrl.text) ?? -0.9333,
                'longitud': double.tryParse(longCtrl.text) ?? -78.6167,
                'espaciosTotales': espacios,
                'tarifaHora': double.tryParse(tarifaCtrl.text) ?? 1.0,
                'minutosFraccion': int.tryParse(fraccionCtrl.text) ?? 15,
                'horaApertura': aperturaCtrl.text.trim(),
                'horaCierre': cierreCtrl.text.trim(),
              };

              if (existente != null) {
                // Editar: no tocamos espaciosLibres para no descuadrar.
                await service.actualizarParqueadero(existente.id, datos);
              } else {
                final p = Parqueadero(
                  ownerId: ownerId,
                  nombre: datos['nombre'] as String,
                  direccion: datos['direccion'] as String,
                  latitud: datos['latitud'] as double,
                  longitud: datos['longitud'] as double,
                  espaciosTotales: espacios,
                  espaciosLibres: espacios,
                  tarifaHora: datos['tarifaHora'] as double,
                  minutosFraccion: datos['minutosFraccion'] as int,
                  horaApertura: datos['horaApertura'] as String,
                  horaCierre: datos['horaCierre'] as String,
                );
                await service.crearParqueadero(p);
              }

              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          editando ? 'Garaje actualizado.' : 'Garaje creado.')),
                );
              }
            },
            child: Text(editando ? 'Guardar' : 'Crear'),
          ),
        ],
      ),
    );
  }
}
