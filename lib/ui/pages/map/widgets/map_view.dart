import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_application_2/ui/pages/map/widgets/custom_marker.dart';
import 'package:flutter_application_2/ui/pages/map/map_controller.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:flutter_application_2/core/constants/text_strings.dart';

class MapView extends StatelessWidget {
  final MapPageController controller;
  final VoidCallback? onTap;

  const MapView({
    super.key,
    required this.controller,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return FlutterMap(
          mapController: controller.mapController,
          options: MapOptions(
            initialCenter: const LatLng(0, 0),
            initialZoom: 4,
            minZoom: 2,
            maxZoom: 18,
            cameraConstraint: CameraConstraint.contain(
              bounds: controller.mapBounds,
            ),
            onTap: (tapPosition, latLng) {
              // First dismiss keyboard
              if (onTap != null) onTap!();

              // Then handle map functionality
              if (!controller.showRoute) return;

              controller.destination = latLng;
              controller.fetchRoute();

              // Show feedback that destination was set
              ResponsiveSnackBar.showInfo(
                context: context,
                message: TextStrings.destinationSet,
              );
            },
          ),
          children: [
            TileLayer(
              urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
              tileProvider: kIsWeb
                  ? CancellableNetworkTileProvider()
                  : NetworkTileProvider(),
            ),
            if (controller.showMarkersAndRoute &&
                controller.currentLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: controller.currentLocation!,
                    width: 50,
                    height: 50,
                    child: CustomMarker(
                      location: controller.currentLocation!,
                      icon: Icons.home,
                      description: 'Current Location',
                      timestamp: DateTime.now(),
                      withCircle: true,
                      circleSize: 35,
                      iconSize: 30,
                    ),
                  ),
                ],
              ),
            if (controller.showMarkersAndRoute &&
                controller.destination != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: controller.destination!,
                    width: 50,
                    height: 50,
                    child: CustomMarker(
                      location: controller.destination!,
                      icon: Icons.location_on,
                      description: 'Destination',
                      timestamp: DateTime.now(),
                      withCircle: true,
                      circleSize: 35,
                      iconSize: 30,
                    ),
                  ),
                ],
              ),
            if (controller.showMarkersAndRoute &&
                controller.currentLocation != null &&
                controller.destination != null &&
                controller.route.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: controller.route,
                    strokeWidth: 5,
                    color: Colors.red,
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}
