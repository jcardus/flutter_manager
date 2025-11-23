import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../models/device.dart';
import '../models/position.dart';
import 'device_detail.dart';
import 'device_route.dart';

class _MeasureSize extends SingleChildRenderObjectWidget {
  final ValueChanged<Size> onChange;

  const _MeasureSize({
    required this.onChange,
    required Widget child,
  }) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _MeasureSizeRenderObject(onChange);
  }

  @override
  void updateRenderObject(BuildContext context, _MeasureSizeRenderObject renderObject) {
    renderObject.onChange = onChange;
  }
}

class _MeasureSizeRenderObject extends RenderProxyBox {
  ValueChanged<Size> onChange;
  Size? _oldSize;

  _MeasureSizeRenderObject(this.onChange);

  @override
  void performLayout() {
    super.performLayout();

    Size newSize = child!.size;
    if (_oldSize == newSize) return;

    _oldSize = newSize;
    onChange(newSize);
  }
}

class DeviceBottomSheet extends StatefulWidget {
  final Device device;
  final Position? position;
  final VoidCallback? onClose;
  final ValueChanged<bool>? onRouteToggle;

  const DeviceBottomSheet({
    super.key,
    required this.device,
    this.position,
    this.onClose,
    this.onRouteToggle,
  });

  @override
  State<DeviceBottomSheet> createState() => _DeviceBottomSheetState();
}

class _DeviceBottomSheetState extends State<DeviceBottomSheet> {
  static const double _minChildSize = 0.15;
  static const double _maxChildSizeLimit = 0.95;

  bool _showingRoute = false;
  double _maxChildSize = 0.5;
  String? _lastMeasuredView;
  final DraggableScrollableController _draggableController = DraggableScrollableController();

  @override
  void dispose() {
    _draggableController.dispose();
    super.dispose();
  }

  void _toggleRoute() {
    setState(() {
      _showingRoute = !_showingRoute;
    });
    widget.onRouteToggle?.call(_showingRoute);
  }

  void _onContentSizeChanged(Size size) {
    final currentView = _showingRoute ? 'route' : 'detail';

    // Only measure size when opening drawer
    if (_lastMeasuredView != null) return;
    final screenHeight = MediaQuery.of(context).size.height;
    final contentHeight = size.height;

    final ratio = (contentHeight / screenHeight).clamp(_minChildSize, _maxChildSizeLimit);

    // Ensure minimum reasonable size
    final adjustedRatio = ratio.clamp(0.5, _maxChildSizeLimit);

    dev.log('New calculated size: $adjustedRatio (was $_maxChildSize)');
    _lastMeasuredView = currentView;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _maxChildSize = adjustedRatio;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.position;
    return DraggableScrollableSheet(
      controller: _draggableController,
      maxChildSize: _maxChildSize,
      minChildSize: _minChildSize,
      initialChildSize: _maxChildSize,
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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _MeasureSize(
                  onChange: _onContentSizeChanged,
                  child: _showingRoute
                      ? DeviceRoute(
                          key: const ValueKey('route'),
                          position: position,
                          device: widget.device,
                          onBack: _toggleRoute,
                        )
                      : DeviceDetail(
                          key: const ValueKey('detail'),
                          position: position,
                          device: widget.device,
                          onClose: widget.onClose,
                          onShowRoute: _toggleRoute,
                        ),
                ),
              ),
            ));
      },
    );
  }
}
