// lib/widgets/parking_cost_monitor.dart
import 'dart:async';
import 'package:flutter/material.dart';

class ParkingCostMonitor extends StatefulWidget {
  final DateTime entryTime;
  final double rate;
  const ParkingCostMonitor({super.key, required this.entryTime, required this.rate});

  @override
  _ParkingCostMonitorState createState() => _ParkingCostMonitorState();
}

class _ParkingCostMonitorState extends State<ParkingCostMonitor> {
  Timer? _timer;
  String _cost = "0.00";

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 10), (t) {
      final hours = DateTime.now().difference(widget.entryTime).inSeconds / 3600;
      setState(() => _cost = (hours * widget.rate).toStringAsFixed(2));
    });
  }

  @override
  Widget build(BuildContext context) => Text("Costo actual: \$$_cost");
  
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }
}