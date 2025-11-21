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

  @override
  Widget build(BuildContext context) {
    final position = widget.position;
    return DraggableScrollableSheet(
      maxChildSize: 0.6,
      minChildSize: 0.15,
      initialChildSize: 0.6,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: ClampingScrollPhysics(),
              controller: scrollController,
              child: DeviceDetail(
                position: position,
                device: widget.device, onClose: widget.onClose
            ))
        );
      },
    );
  }
}
