import 'package:flutter/material.dart';
import 'package:manager/models/position.dart';

import '../utils/constants.dart';
import '../utils/google_url_signer.dart';

class StreetView extends StatelessWidget {
  final Position? position;
  final double width;

  const StreetView({super.key, required this.position, required this.width});
  String _getStreetViewUrl(double latitude, double longitude, double heading) {
    final size = '${width.toInt()}x200';
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Image.network(
        _getStreetViewUrl(
          position!.latitude,
          position!.longitude,
          position!.course,
        ),
        fit: BoxFit.cover,
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
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.streetview,
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Street View unavailable',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
