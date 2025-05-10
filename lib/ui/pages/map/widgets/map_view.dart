import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_application_2/ui/pages/map/widgets/custom_marker.dart';
import 'package:flutter_application_2/ui/pages/map/widgets/custom_event_marker.dart';
import 'package:flutter_application_2/ui/pages/map/map_controller.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/category_utils.dart';

class MapView extends StatelessWidget {
  final MapPageController controller;
  final VoidCallback? onTap;
  final List<Marker>? markers; // Add custom markers parameter

  const MapView({
    super.key,
    required this.controller,
    this.onTap,
    this.markers,
  });

  @override
  Widget build(BuildContext context) {
    // Call setMapReady after the first frame (only once)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.setMapReady();
    });

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return ClipRRectMapContainer(
          child: MapWidget(
            mapController: controller,
            customMarkers: markers,
          ),
        );
      },
    );
  }
}

class MapWidget extends StatelessWidget {
  final MapPageController mapController;
  final List<Marker>? customMarkers;

  const MapWidget({
    super.key,
    required this.mapController,
    this.customMarkers,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController.mapController,
      options: MapOptions(
        initialCenter: mapController.currentLocation ?? const LatLng(0, 0),
        initialZoom: 10.0,
        minZoom: 3.0,
        maxZoom: 18.0,
        onMapReady: mapController.setMapReady,
        onTap: (_, __) => mapController.destination =
            null, // Clear destination when map is tapped
      ),
      children: [
        TileLayer(
          // Use a direct URL without subdomains to avoid the OSM warning
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          // Remove subdomains parameter
          tileProvider: CancellableNetworkTileProvider(),
          // Add user agent to identify your app to OSM - this is good practice
          additionalOptions: const {
            'User-Agent': 'Flutter Map App/1.0',
          },
        ),
        // Custom markers from the map page
        if (customMarkers != null && customMarkers!.isNotEmpty)
          MarkerLayer(markers: customMarkers!),
        // Standard markers from controller
        MarkerLayer(
          markers: [
            if (mapController.showMarkersAndRoute &&
                mapController.destination != null)
              Marker(
                point: mapController.destination!,
                child: mapController.markerEventType != null
                    ? CustomEventMarker.forEvent(
                        location: mapController.destination!,
                        eventType: mapController.markerEventType,
                        onTap: () {
                          // Show info about the marker when tapped
                          if (mapController.markerDescription != null) {
                            ResponsiveSnackBar.showInfo(
                              context: context,
                              message: mapController.markerDescription!,
                            );
                          }
                        },
                      )
                    : const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 30,
                      ),
              ),
            if (mapController.showMarkersAndRoute &&
                mapController.currentLocation != null)
              Marker(
                point: mapController.currentLocation!,
                child: Container(
                  height: 28,
                  width: 28,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade600, Colors.blue.shade300],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer ring
                      Container(
                        height: 20,
                        width: 20,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 1.5,
                          ),
                        ),
                      ),
                      // Inner dot
                      Container(
                        height: 6,
                        width: 6,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        PolylineLayer(
          polylines: [
            if (mapController.showMarkersAndRoute &&
                mapController.route.isNotEmpty)
              Polyline(
                points: mapController.route,
                color: Colors.blue,
                strokeWidth: 4.0,
              ),
          ],
        ),
      ],
    );
  }
}

class ClipRRectMapContainer extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;

  const ClipRRectMapContainer({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: child,
    );
  }
}
