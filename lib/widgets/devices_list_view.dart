import 'package:flutter/material.dart';
import '../models/device.dart';
import '../models/position.dart';

class DevicesListView extends StatelessWidget {
  final Map<int, Device> devices;
  final Map<int, Position> positions;
  final VoidCallback? onRefresh;

  const DevicesListView({
    super.key,
    required this.devices,
    required this.positions,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final devicesList = devices.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (devicesList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.devices_other,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No devices found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Waiting for data...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        onRefresh?.call();
      },
      child: ListView.builder(
        itemCount: devicesList.length,
        padding: const EdgeInsets.only(bottom: 80),
        itemBuilder: (context, index) {
          final device = devicesList[index];
          final position = positions[device.id];
          return _DeviceListItem(
            device: device,
            position: position,
          );
        },
      ),
    );
  }
}

class _DeviceListItem extends StatelessWidget {
  final Device device;
  final Position? position;

  const _DeviceListItem({
    required this.device,
    this.position,
  });

  Color _getStatusColor() {
    switch (device.status?.toLowerCase()) {
      case 'online':
        return Colors.green;
      case 'offline':
        return Colors.red;
      case 'unknown':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getDeviceIcon() {
    switch (device.category?.toLowerCase()) {
      case 'car':
      case 'vehicle':
        return Icons.directions_car;
      case 'truck':
        return Icons.local_shipping;
      case 'bus':
        return Icons.directions_bus;
      case 'motorcycle':
        return Icons.two_wheeler;
      case 'bicycle':
        return Icons.pedal_bike;
      case 'person':
        return Icons.person;
      default:
        return Icons.navigation;
    }
  }

  String _formatSpeed(double? speed) {
    if (speed == null) return 'N/A';
    // Convert from knots to km/h (Traccar uses knots)
    final kmh = speed * 1.852;
    return '${kmh.toStringAsFixed(1)} km/h';
  }

  String _formatLastUpdate(DateTime? lastUpdate) {
    if (lastUpdate == null) return 'Never';

    final now = DateTime.now();
    final difference = now.difference(lastUpdate);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor().withValues(alpha: 0.2),
          child: Icon(
            _getDeviceIcon(),
            color: _getStatusColor(),
          ),
        ),
        title: Text(
          device.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: _getStatusColor(),
                ),
                const SizedBox(width: 6),
                Text(
                  device.status?.toUpperCase() ?? 'UNKNOWN',
                  style: TextStyle(
                    fontSize: 12,
                    color: _getStatusColor(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.access_time, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _formatLastUpdate(device.lastUpdate),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            if (position != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.speed, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    _formatSpeed(position?.speed),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.navigation, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${position?.course.toStringAsFixed(0)}°',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: device.disabled
            ? const Icon(Icons.block, color: Colors.red)
            : const Icon(Icons.chevron_right),
        onTap: () {
          // TODO: Navigate to device details
        },
      ),
    );
  }
}
