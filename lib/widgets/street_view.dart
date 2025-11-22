import 'package:flutter/material.dart';
import 'package:manager/models/position.dart';
import 'package:manager/utils/constants.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/mapillary_service.dart';

class StreetView extends StatefulWidget {
  final Position position;

  const StreetView({super.key, required this.position});

  @override
  State<StreetView> createState() => _StreetViewState();
}

class _StreetViewState extends State<StreetView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasImage = false;
  bool _pageLoaded = false;
  String? _pendingImageId;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            _pageLoaded = true;
            // If we already have an image ID, load it now
            if (_pendingImageId != null && mounted) {
              final parts = _pendingImageId!.split('|');
              final imageId = parts[0];
              final bearingDiff = double.parse(parts[1]);
              _loadImage(imageId, bearingDiff);
            }
          },
        ),
      )
      ..loadHtmlString(_buildHtml());

    // Fetch image ID immediately (in parallel with page load)
    _fetchImageId();
  }

  @override
  void didUpdateWidget(StreetView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if position has changed significantly
    if (_hasPositionChanged(oldWidget.position, widget.position)) {
      _fetchImageId();
    }
  }

  bool _hasPositionChanged(Position oldPos, Position newPos) {
    // Consider position changed if lat/lon/course differ
    const double latLonThreshold = 0.0001; // ~11 meters
    const double courseThreshold = 10.0; // 10 degrees

    return (oldPos.latitude - newPos.latitude).abs() > latLonThreshold ||
           (oldPos.longitude - newPos.longitude).abs() > latLonThreshold ||
           (oldPos.course - newPos.course).abs() > courseThreshold;
  }

  String _buildHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <title>Mapillary Viewer</title>
  <style>
    html, body {
      margin: 0;
      padding: 0;
      height: 100%;
      overflow: hidden;
      background-color: #000;
    }
    #mly {
      width: 100vw;
      height: 100vh;
    }
  </style>
  <link
    rel="stylesheet"
    href="https://unpkg.com/mapillary-js@4.1.2/dist/mapillary.css"
  />
</head>
<body>
  <div id="mly"></div>

  <script src="https://unpkg.com/mapillary-js@4.1.2/dist/mapillary.js"></script>
  <script>
    let viewer = null;
    const accessToken = '$mapillaryToken';

    function updateImage(imageId, bearingDiff) {
      if (viewer === null) {
        viewer = new mapillary.Viewer({
          accessToken: accessToken,
          container: 'mly',
          imageId: imageId,
          component: {
            cover: false,
            zoom: false,
            direction: false,
            sequence: false
          }
        });

        // Pan to the vehicle's bearing after image loads
        if (bearingDiff !== undefined && bearingDiff !== 0) {
          viewer.on('image', function() {
            // Convert bearing difference to pan amount (normalized 0-1)
            // bearingDiff is in degrees, normalize to 0-1 range for panning
            var panAmount = bearingDiff / 360;
            viewer.getCenter().then(function(center) {
              viewer.setCenter([center[0] + panAmount, center[1]]);
            });
          });
        }
      } else {
        viewer.moveTo(imageId).then(function() {
          // Pan after moving to new image
          if (bearingDiff !== undefined && bearingDiff !== 0) {
            var panAmount = bearingDiff / 360;
            viewer.getCenter().then(function(center) {
              viewer.setCenter([center[0] + panAmount, center[1]]);
            });
          }
        }).catch(function(error) {
          console.error('Error moving to image:', error);
        });
      }
    }
  </script>
</body>
</html>
''';
  }

  Future<void> _fetchImageId() async {
    try {
      // Use local Mapillary service to get image data
      final imageData = await MapillaryService.getImageData(
        latitude: widget.position.latitude,
        longitude: widget.position.longitude,
        course: widget.position.course,
      );

      if (imageData != null && mounted) {
        // Calculate bearing difference (how much to pan)
        // Only rotate if the image is panoramic
        double bearingDiff = 0;
        if (imageData.isPano) {
          bearingDiff = widget.position.course - imageData.compassAngle;

          // Normalize to -180 to 180 range
          while (bearingDiff > 180) {
            bearingDiff -= 360;
          }
          while (bearingDiff < -180) {
            bearingDiff += 360;
          }
        }

        if (_pageLoaded) {
          // Page is ready, load the image immediately
          _loadImage(imageData.id, bearingDiff);
        } else {
          // Page not ready yet, store for later
          _pendingImageId = '${imageData.id}|$bearingDiff';
          setState(() {
            _hasImage = true;
          });
        }
      } else {
        // No image ID available
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasImage = false;
          });
        }
      }
    } catch (e) {
      // Error
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasImage = false;
        });
      }
    }
  }

  Future<void> _loadImage(String imageId, double bearingDiff) async {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasImage = true;
      });
      await _controller.runJavaScript('updateImage("$imageId", $bearingDiff);');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: _isLoading
          ? Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            )
          : _hasImage
              ? WebViewWidget(controller: _controller)
              : Container(
                  color: colors.surfaceContainerHighest,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.streetview,
                          size: 48,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Street View unavailable',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
