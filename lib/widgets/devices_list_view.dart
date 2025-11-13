import 'package:flutter/material.dart';
import '../models/device.dart';
import '../models/position.dart';

class DevicesListView extends StatefulWidget {
  final Map<int, Device> devices;
  final Map<int, Position> positions;
  final VoidCallback? onRefresh;
  final void Function(int deviceId)? onDeviceTap;

  const DevicesListView({
    super.key,
    required this.devices,
    required this.positions,
    this.onRefresh,
    this.onDeviceTap,
  });

  @override
  State<DevicesListView> createState() => _DevicesListViewState();
}

class _DevicesListViewState extends State<DevicesListView> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final devicesList = widget.devices.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    // Filter devices based on search query
    final filteredDevices = _searchQuery.isEmpty
        ? devicesList
        : devicesList
            .where((device) =>
                device.name.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    // Calculate stats
    final totalDevices = devicesList.length;
    final onlineDevices = devicesList
        .where((d) => d.status?.toLowerCase() == 'online')
        .length;
    final offlineDevices = devicesList
        .where((d) => d.status?.toLowerCase() == 'offline')
        .length;

    if (devicesList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.devices_other,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No devices found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Waiting for data...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Summary Header
        Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            bottom: 16,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatCard(
                    icon: Icons.devices,
                    label: 'Total',
                    value: totalDevices.toString(),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  _StatCard(
                    icon: Icons.check_circle,
                    label: 'Online',
                    value: onlineDevices.toString(),
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  _StatCard(
                    icon: Icons.cancel,
                    label: 'Offline',
                    value: offlineDevices.toString(),
                    color: Theme.of(context).colorScheme.error,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Search Bar
              TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search devices...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Devices List
        Expanded(
          child: filteredDevices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No devices found',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try a different search term',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    widget.onRefresh?.call();
                  },
                  child: ListView.builder(
                    itemCount: filteredDevices.length,
                    padding: const EdgeInsets.only(bottom: 80, top: 8),
                    itemBuilder: (context, index) {
                      final device = filteredDevices[index];
                      final position = widget.positions[device.id];
                      return _DeviceListItem(
                        device: device,
                        position: position,
                        onTap: widget.onDeviceTap,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _DeviceListItem extends StatelessWidget {
  final Device device;
  final Position? position;
  final void Function(int deviceId)? onTap;

  const _DeviceListItem({
    required this.device,
    this.position,
    this.onTap,
  });

  Color _getStatusColor(BuildContext context) {
    switch (device.status?.toLowerCase()) {
      case 'online':
        return Theme.of(context).colorScheme.tertiary;
      case 'offline':
        return Theme.of(context).colorScheme.error;
      case 'unknown':
        return Theme.of(context).colorScheme.outline;
      default:
        return Theme.of(context).colorScheme.outline;
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
    final statusColor = _getStatusColor(context);
    final subtitleColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(
            _getDeviceIcon(),
            color: statusColor,
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
                  color: statusColor,
                ),
                const SizedBox(width: 6),
                Text(
                  device.status?.toUpperCase() ?? 'UNKNOWN',
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 12, color: subtitleColor),
                const SizedBox(width: 4),
                Text(
                  _formatLastUpdate(device.lastUpdate),
                  style: TextStyle(
                    fontSize: 12,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
            if (position != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.speed, size: 12, color: subtitleColor),
                  const SizedBox(width: 4),
                  Text(
                    _formatSpeed(position?.speed),
                    style: TextStyle(
                      fontSize: 12,
                      color: subtitleColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.navigation, size: 12, color: subtitleColor),
                  const SizedBox(width: 4),
                  Text(
                    '${position?.course.toStringAsFixed(0)}°',
                    style: TextStyle(
                      fontSize: 12,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: device.disabled
            ? Icon(Icons.block, color: Theme.of(context).colorScheme.error)
            : const Icon(Icons.chevron_right),
        onTap: () {
          onTap?.call(device.id);
        },
      ),
    );
  }
}
