import 'package:flutter/material.dart';
import 'package:manager/l10n/app_localizations.dart';
import '../../map/styles.dart';

class MapStyleSelector extends StatefulWidget {
  final int selectedStyleIndex;
  final bool mapReady;
  final Function(int) onStyleSelected;
  final bool geofencesLayer;
  final Function() onLayerSelected;
  final Function() onZoomIn;
  final Function() onZoomOut;

  const MapStyleSelector({
    super.key,
    required this.selectedStyleIndex,
    required this.mapReady,
    required this.onStyleSelected,
    required this.geofencesLayer,
    required this.onLayerSelected,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  State<MapStyleSelector> createState() => _MapStyleSelectorState();
}

class _MapStyleSelectorState extends State<MapStyleSelector> {
  bool _menuExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Positioned(
      top: 0,
      right: 0,
      child: SafeArea(
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: IntrinsicWidth(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: 30,
                maxWidth: _menuExpanded ? 250 : 30,
              ),
              child: Material(
                elevation: 3,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          _menuExpanded = !_menuExpanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          _menuExpanded ? Icons.chevron_right : Icons.chevron_left,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    if (_menuExpanded) ...[
                      const Divider(height: 1),

                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            InkWell(
                              onTap: widget.onZoomIn,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                                ),
                                child: Icon(
                                  Icons.add,
                                  size: 20,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            InkWell(
                              onTap: widget.onZoomOut,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                                ),
                                child: Icon(
                                  Icons.remove,
                                  size: 20,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 1),

                      ...List.generate(MapStyles.configs.length, (index) {
                        final config = MapStyles.configs[index];
                        final isSelected = widget.selectedStyleIndex == index;
                        return InkWell(
                          onTap: () => widget.onStyleSelected(index),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                  size: 20,
                                  color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    widget.mapReady || !isSelected ? config.getLocalizedName(context) : l10n.loading,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                      const Divider(height: 1),

                      InkWell(
                        onTap: () => widget.onLayerSelected(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                widget.geofencesLayer ? Icons.check_box_outlined : Icons.check_box_outline_blank,
                                size: 20,
                                color: widget.geofencesLayer
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "Geofences",
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: widget.geofencesLayer
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                    fontWeight: widget.geofencesLayer ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
