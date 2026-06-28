// lib/views/cost_view.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/cost_controller.dart';
import '../models/parking_rate_model.dart';

class CostView extends StatefulWidget {
  final ParkingRateModel model;
  const CostView({super.key, required this.model});

  @override
  _CostViewState createState() => _CostViewState();
}

class _CostViewState extends State<CostView> {
  final CostController _controller = CostController();
  Timer? _timer;
  double _currentCost = 0.0;

  @override
  void initState() {
    super.initState();
    // Actualización dinámica cada segundo para el RF-15
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() => _currentCost = _controller.calculateCost(widget.model));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text("Costo en tiempo real"),
        trailing: Text("\$ ${_currentCost.toStringAsFixed(2)}", 
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }
}