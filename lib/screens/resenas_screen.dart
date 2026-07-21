import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/resena_service.dart';
import '../services/auth_service.dart';
import '../theme.dart';

class ResenasScreen extends StatefulWidget {
  const ResenasScreen({super.key});

  @override
  State<ResenasScreen> createState() => _ResenasScreenState();
}

class _ResenasScreenState extends State<ResenasScreen> {
  final _resenaService = ResenaService();
  final _authService = AuthService();

  bool _esDueno = false;
  bool _cargandoRol = true;

  @override
  void initState() {
    super.initState();
    _verificarRol();
  }

  Future<void> _verificarRol() async {
    try {
      final rol = await _authService.obtenerRol();
      if (mounted) {
        setState(() {
          _esDueno = (rol == 'dueno');
          _cargandoRol = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _cargandoRol = false);
      }
    }
  }

  void _abrirFormularioModal(BuildContext context) {
    if (_authService.uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para publicar una reseña.')),
      );
      return;
    }

    final comentarioController = TextEditingController();
    double calificacionSeleccionada = 5.0;
    String? parqueaderoSeleccionadoId;
    String? parqueaderoSeleccionadoNombre;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 20,
                left: 24,
                right: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Escribir una Reseña', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                  const SizedBox(height: 16),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('parqueaderos').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const LinearProgressIndicator();
                      final docs = snapshot.data!.docs;

                      return DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Selecciona el Parqueadero',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(data['nombre'] ?? 'Parqueadero'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          final pDoc = docs.firstWhere((element) => element.id == val);
                          final data = pDoc.data() as Map<String, dynamic>;
                          setModalState(() {
                            parqueaderoSeleccionadoId = val;
                            parqueaderoSeleccionadoNombre = data['nombre'];
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  const Text('Puntuación:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final estrellaVal = index + 1;
                      return IconButton(
                        icon: Icon(
                          index < calificacionSeleccionada ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () {
                          setModalState(() => calificacionSeleccionada = estrellaVal.toDouble());
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: comentarioController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Cuéntanos tu experiencia sobre la atención, seguridad y espacios...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      label: const Text('Publicar Reseña', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        if (parqueaderoSeleccionadoId == null || comentarioController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Selecciona un parqueadero y escribe un comentario.')),
                          );
                          return;
                        }

                        try {
                          await _resenaService.crearResena(
                            parqueaderoId: parqueaderoSeleccionadoId!,
                            parqueaderoNombre: parqueaderoSeleccionadoNombre!,
                            calificacion: calificacionSeleccionada,
                            comentario: comentarioController.text.trim(),
                          );
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('¡Reseña publicada con éxito!'), backgroundColor: Colors.green),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: Text(_esDueno ? 'Opiniones de Clientes' : 'Reseñas y Experiencias'),
      ),
      // 🔐 OCULTAR BOTÓN FLOTANTE SI ES DUENO O SI AÚN ESTÁ CARGANDO EL ROL
      floatingActionButton: (_esDueno || _cargandoRol)
          ? null
          : FloatingActionButton.extended(
        backgroundColor: Colors.amber.shade800,
        icon: const Icon(Icons.rate_review_rounded, color: Colors.white),
        label: const Text('Calificar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _abrirFormularioModal(context),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _resenaService.escucharResenas(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'Aún no hay opiniones registradas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final String usuario = data['usuarioNombre'] ?? 'Conductor Anónimo';
              final String parqueadero = data['parqueaderoNombre'] ?? 'Parqueadero';
              final String comentario = data['comentario'] ?? '';
              final double calificacion = (data['calificacion'] ?? 5.0).toDouble();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(parqueadero, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kPrimary)),
                          Row(
                            children: List.generate(5, (i) {
                              return Icon(
                                i < calificacion ? Icons.star_rounded : Icons.star_outline_rounded,
                                color: Colors.amber,
                                size: 18,
                              );
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(comentario, style: const TextStyle(fontSize: 13.5, color: Color(0xFF374151))),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.person, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(usuario, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                        ],
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
}