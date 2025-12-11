import 'package:flutter/material.dart';
import 'package:manager/l10n/app_localizations.dart';
import '../models/device.dart';
import '../models/position.dart';
import '../utils/device_colors.dart';
import 'position_detail.dart';

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
  String _searchStatusQuery = '';

  @override
  Widget build(BuildContext context) {
    final devicesList = widget.devices.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    // Filter devices based on search query
    final filteredDevices = _searchQuery.isEmpty && _searchStatusQuery.isEmpty
        ? devicesList
        : devicesList
            .where((device) =>
                (_searchQuery.isEmpty || device.name.toLowerCase().contains(_searchQuery.toLowerCase())) &&
                (_searchStatusQuery.isEmpty || device.status?.toLowerCase() == _searchStatusQuery))
            .toList();

    // Calculate stats
    final totalDevices = devicesList.length;
    final onlineDevices = devicesList
        .where((d) => d.status?.toLowerCase() == 'online')
        .length;
    final offlineDevices = devicesList
        .where((d) => d.status?.toLowerCase() == 'offline')
        .length;
    final unknownDevices = devicesList
        .where((d) => d.status?.toLowerCase() == 'unknown')
        .length;

    if (devicesList.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
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
              l10n.noDevicesFound,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.waitingForData,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        // Summary Header
        Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 16,
            left: 10,
            right: 10,
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
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _searchStatusQuery = '';
                        });
                      },
                      child:
                      _StatCard(
                        icon: Icons.list_alt,
                        label: l10n.total,
                        value: totalDevices.toString(),
                        color: _searchStatusQuery.isEmpty ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.primary.withAlpha(75),
                      )
                    )
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _searchStatusQuery = 'online';
                        });
                      },
                      child:
                      _StatCard(
                        icon: Icons.check_circle,
                        label: l10n.online,
                        value: onlineDevices.toString(),
                        color: _searchStatusQuery == 'online' || _searchStatusQuery.isEmpty ? Theme.of(context).colorScheme.tertiary
                            : Theme.of(context).colorScheme.tertiary.withAlpha(75),
                      )
                    )
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _searchStatusQuery = 'offline';
                        });
                      },
                      child:
                      _StatCard(
                        icon: Icons.cancel,
                        label: l10n.offline,
                        value: offlineDevices.toString(),
                        color: _searchStatusQuery == 'offline' || _searchStatusQuery.isEmpty ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.error.withAlpha(75),
                      )
                    )
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _searchStatusQuery = 'Unknown';
                        });
                      },
                      child:
                      _StatCard(
                        icon: Icons.blur_circular,
                        label: l10n.unknown,
                        value: unknownDevices.toString(),
                        color: _searchStatusQuery == 'Unknown' || _searchStatusQuery.isEmpty ? Theme.of(context).colorScheme.outline
                            : Theme.of(context).colorScheme.outline.withAlpha(75),
                      )
                    )
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
                  hintText: l10n.searchDevices,
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
                        l10n.noDevicesFound,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.tryDifferentSearch,
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
                        key: ValueKey(device.id),
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
          overflow: TextOverflow.ellipsis,
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
    super.key,
    required this.device,
    this.position,
    this.onTap,
  });

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

  @override
  Widget build(BuildContext context) {
    final deviceColor = DeviceColors.getDeviceColor(device, position, context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: position != null ? () => onTap?.call(device.id) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: deviceColor.withValues(alpha: 0.2),
                    child: Icon(
                      _getDeviceIcon(),
                      color: deviceColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 8,
                              color: DeviceColors.getStatusColor(device, context),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              device.status?.toUpperCase() ?? 'UNKNOWN',
                              style: TextStyle(
                                fontSize: 12,
                                color: DeviceColors.getStatusColor(device, context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (device.disabled)
                    Icon(Icons.block, color: Theme.of(context).colorScheme.error)
                  else
                    const Icon(Icons.chevron_right),
                ],
              ),
              if (position != null) ...[
                const SizedBox(height: 12),
                PositionDetail(pos: position!, device: device, compact: true),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
