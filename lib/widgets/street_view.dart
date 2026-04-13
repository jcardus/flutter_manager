import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:manager/models/position.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/mapillary_service.dart';
import '../utils/constants.dart';
import '../utils/google_url_signer.dart';

class StreetView extends StatefulWidget {
  final Position? position;
  final double width;

  const StreetView({super.key, required this.position, required this.width});

  @override
  State<StreetView> createState() => _StreetViewState();
}

class _StreetViewState extends State<StreetView> {
  bool _googleAvailable = true;
  bool _googleChecked = false;
  MapillaryImage? _mapillaryImage;
  bool _mapillaryFetched = false;

  @override
  void initState() {
    super.initState();
    _checkGoogleAvailability();
  }

  Future<void> _checkGoogleAvailability() async {
    final pos = widget.position;
    if (pos == null) return;
    try {
      final metadataUrl = GoogleUrlSigner.signUrl(
        'https://maps.googleapis.com/maps/api/streetview/metadata'
        '?location=${pos.latitude},${pos.longitude}',
        googleMapsSigningSecret,
        clientId: googleMapsClientId,
      );
      final resp = await http.get(Uri.parse(metadataUrl));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final available = data['status'] == 'OK';
        if (mounted) {
          setState(() {
            _googleAvailable = available;
            _googleChecked = true;
          });
          if (!available) _fetchMapillary();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _googleChecked = true);
        _fetchMapillary();
      }
    }
  }

  String _getStreetViewUrl(double latitude, double longitude, double heading) {
    final size = '${widget.width.toInt()}x200';
    const fov = '90';
    const pitch = '0';

    final baseUrl =
        'https://maps.googleapis.com/maps/api/streetview'
        '?size=$size'
        '&location=$latitude,$longitude'
        '&heading=${heading.toStringAsFixed(0)}'
        '&fov=$fov'
        '&pitch=$pitch';

    return GoogleUrlSigner.signUrl(
      baseUrl,
      googleMapsSigningSecret,
      clientId: googleMapsClientId,
    );
  }

  Future<void> _fetchMapillary() async {
    if (_mapillaryFetched || widget.position == null) return;
    _mapillaryFetched = true;
    final image = await MapillaryService.getImageData(
      latitude: widget.position!.latitude,
      longitude: widget.position!.longitude,
      course: widget.position!.course,
    );
    if (mounted) setState(() => _mapillaryImage = image);
  }

  Future<void> _openStreetView(double latitude, double longitude, double heading) async {
    final h = heading.toStringAsFixed(0);
    final svUri = Uri.parse('google.streetview://cbll=$latitude,$longitude&cbp=12,$h,0,0,0');
    if (await canLaunchUrl(svUri)) {
      await launchUrl(svUri, mode: LaunchMode.externalApplication);
      return;
    }
    final mapsUri = Uri.parse('comgooglemaps://?center=$latitude,$longitude&mapmode=streetview');
    if (await canLaunchUrl(mapsUri)) {
      await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
      return;
    }
    final webUri = Uri.parse('https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=$latitude,$longitude&heading=$h');
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openMapillary(String imageId) async {
    final uri = Uri.parse('https://www.mapillary.com/app/?focus=photo&pKey=$imageId');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildPlaceholder({String? message}) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.streetview, size: 48),
            const SizedBox(height: 8),
            Text(message ?? 'Street View unavailable'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pos = widget.position;
    if (pos == null) return const SizedBox.shrink();

    return SizedBox(
      height: 200,
      child: GestureDetector(
        onTap: () {
          if (!_googleAvailable && _mapillaryImage != null) {
            _openMapillary(_mapillaryImage!.id);
          } else if (_googleAvailable) {
            _openStreetView(pos.latitude, pos.longitude, pos.course);
          }
        },
        child: !_googleChecked
            ? _buildPlaceholder(message: 'Loading...')
            : _googleAvailable
                ? Image.network(
                    _getStreetViewUrl(pos.latitude, pos.longitude, pos.course),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Theme.of(context).primaryColor,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => _buildPlaceholder(),
                  )
                : _mapillaryImage?.thumbUrl != null
                    ? Image.network(
                        _mapillaryImage!.thumbUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                      )
                    : _mapillaryFetched
                        ? _buildPlaceholder()
                        : _buildPlaceholder(message: 'Loading...'),
      ),
    );
  }
}
