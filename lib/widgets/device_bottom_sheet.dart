import 'package:flutter/material.dart';
import '../models/device.dart';
import '../models/position.dart';
import 'device_detail.dart';

class DeviceBottomSheet extends StatefulWidget {
  final Device device;
  final Position? position;
  final VoidCallback? onClose;

  const DeviceBottomSheet({
    super.key,
    required this.device,
    this.position,
    this.onClose,
  });

  @override
  State<DeviceBottomSheet> createState() => _DeviceBottomSheetState();
}

class _DeviceBottomSheetState extends State<DeviceBottomSheet> {
  // DraggableScrollableSheet configuration
  final double _sheetPosition = 0.5;

  @override
  Widget build(BuildContext context) {
    final position = widget.position;
    return DraggableScrollableSheet(
      maxChildSize: 0.9,
      initialChildSize: _sheetPosition,
      builder: (BuildContext context, ScrollController scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: DeviceDetail(
              position: position,
              device: widget.device)
        );
      },
    );
  }
}
