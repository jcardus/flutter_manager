import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'screens/login_page.dart';
import 'services/traccar_auth_service.dart';
import 'services/traccar_socket_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.grey),
        useMaterial3: true,
      ),
      routes: {
        '/login': (_) => const LoginPage(),
      },
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = TraccarAuthService();
    return FutureBuilder<bool>(
      future: auth.sessionExists(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final loggedIn = snapshot.data == true;
        if (loggedIn) {
          return const HomePage(title: 'Manager');
        } else {
          return const LoginPage();
        }
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  MapLibreMapController? mapController;
  int _selectedIndex = 0;
  String? _mapStyle;
  final TraccarSocketService _socketService = TraccarSocketService();
  StreamSubscription? _wsSub;

  // Default location (San Francisco)
  final LatLng _center = const LatLng(37.7749, -122.4194);

  // Icons for bottom navigation
  final List<IconData> _iconList = [
    Icons.map_outlined,
    Icons.search_outlined,
    Icons.favorite_outline,
    Icons.person_outline,
  ];

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
    _connectSocket();
  }

  Future<void> _connectSocket() async {
    final ok = await _socketService.connect();
    if (!mounted) return;
    if (ok && _socketService.stream != null) {
      _wsSub = _socketService.stream!.listen(
        (event) {
          dev.log('[WS] Message: ${event is String ? event : event.toString()}', name: 'TraccarWS');
        },
        onError: (e) => dev.log('[WS] Stream error: $e', name: 'TraccarWS'),
        onDone: () => dev.log('[WS] Closed', name: 'TraccarWS'),
      );
    } else {
      dev.log('[WS] Failed to connect', name: 'TraccarWS');
    }
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _socketService.close();
    super.dispose();
  }

  Future<void> _loadMapStyle() async {
    final style = await rootBundle.loadString('assets/google_maps_style.json');
    setState(() {
      _mapStyle = style;
    });
  }

  void _onMapCreated(MapLibreMapController controller) {
    mapController = controller;
  }

  void _onMenuItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Handle menu item selection here
    switch (index) {
      case 0:
        print('Map selected');
        break;
      case 1:
        print('Search selected');
        break;
      case 2:
        print('Saved selected');
        break;
      case 3:
        print('Profile selected');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _mapStyle == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          // MapLibre Map (full screen)
          MapLibreMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: 11.0,
            ),
            styleString: _mapStyle!,
            myLocationEnabled: true,
            myLocationTrackingMode: MyLocationTrackingMode.tracking,
          ),

          // Curved Navigation Bar Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CurvedNavigationBar(
              index: _selectedIndex,
              height: 60,
              items: <Widget>[
                Icon(_iconList[0], size: 30, color: Colors.white),
                Icon(_iconList[1], size: 30, color: Colors.white),
                Icon(_iconList[2], size: 30, color: Colors.white),
                Icon(_iconList[3], size: 30, color: Colors.white),
              ],
              color: Theme.of(context).colorScheme.primary,
              buttonBackgroundColor: Theme.of(context).colorScheme.primary,
              backgroundColor: Colors.transparent,
              animationCurve: Curves.easeInOut,
              animationDuration: const Duration(milliseconds: 300),
              onTap: _onMenuItemTapped,
            ),
          ),

          // SpeedDial Menu
          Positioned(
            bottom: 80,
            right: 16,
            child: SpeedDial(
              icon: Icons.add,
              activeIcon: Icons.close,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              activeBackgroundColor: Theme.of(context).colorScheme.primary,
              activeForegroundColor: Colors.white,
              buttonSize: const Size(56, 56),
              visible: true,
              closeManually: false,
              elevation: 8.0,
              animationCurve: Curves.elasticInOut,
              isOpenOnStart: false,
              shape: const CircleBorder(),
              children: [
                SpeedDialChild(
                  child: const Icon(Icons.add_location_alt),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  label: 'Add Location',
                  labelStyle: const TextStyle(fontSize: 14),
                  onTap: () => print('Add Location'),
                ),
                SpeedDialChild(
                  child: const Icon(Icons.route),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  label: 'Add Route',
                  labelStyle: const TextStyle(fontSize: 14),
                  onTap: () => print('Add Route'),
                ),
                SpeedDialChild(
                  child: const Icon(Icons.local_shipping),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  label: 'Add Vehicle',
                  labelStyle: const TextStyle(fontSize: 14),
                  onTap: () => print('Add Vehicle'),
                ),
                SpeedDialChild(
                  child: const Icon(Icons.camera_alt),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  label: 'Take Photo',
                  labelStyle: const TextStyle(fontSize: 14),
                  onTap: () => print('Take Photo'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
