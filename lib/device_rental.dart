import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'camera.dart';
import 'home.dart';
import 'ocr.dart';

class NaverMapApp extends StatefulWidget {
  const NaverMapApp({super.key});

  @override
  State<NaverMapApp> createState() => _NaverMapAppState();
}

class _NaverMapAppState extends State<NaverMapApp> {
  final Completer<NaverMapController> _mapControllerCompleter = Completer();
  bool _showRentButton = false;
  String? _selectedMarkerId;

  final List<NLatLng> _hardcodedLocations = [
    NLatLng(37.334792, 126.800192),
    NLatLng(37.335000, 126.799800),
    NLatLng(37.334500, 126.800500),
    NLatLng(37.335200, 126.800100),
    NLatLng(37.334600, 126.799900),
  ];

  @override
  void initState() {
    super.initState();
    _checkAndRequestLocationPermission();
  }

  Future<void> _checkAndRequestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      log("Location permissions are permanently denied.", name: "LocationPermission");
      return;
    }

    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      _showCurrentLocation();
    }
  }

  Future<void> _showCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    final NLatLng currentLatLng = NLatLng(position.latitude, position.longitude);

    final controller = await _mapControllerCompleter.future;

    // 현재 위치 마커
    final currentMarker = NMarker(
      id: 'current_location_marker',
      position: currentLatLng,
      caption: NOverlayCaption(text: 'You'),
    );
    controller.addOverlay(currentMarker);

    // 카메라 이동
    await controller.updateCamera(NCameraUpdate.withParams(
      target: currentLatLng,
      zoom: 14,
    ));

    // 하드코딩된 마커
    for (int i = 0; i < _hardcodedLocations.length; i++) {
      final marker = NMarker(
        id: 'hardcoded_marker_$i',
        position: _hardcodedLocations[i],
        caption: NOverlayCaption(text: 'device ${i + 1}'),
      );

      marker.setOnTapListener((overlay) {
        setState(() {
          if (_selectedMarkerId == marker.info.id) {
            // 같은 마커 클릭 시 해제
            _selectedMarkerId = null;
            _showRentButton = false;
          } else {
            _selectedMarkerId = marker.info.id;
            _showRentButton = true;
          }
        });
      });

      controller.addOverlay(marker);
    }

    log("Added your location and device marker");
  }

  // 신분증 인증 페이지로 이동
  void _navigateToHomeScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => IdCardOcrPage()),
      //MaterialPageRoute(builder: (context) => CameraTestPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Rent Map'),
        centerTitle: true,
        backgroundColor: const Color(0xFF0F5C31),
      ),
      body: Stack(
        children: [
          NaverMap(
            options: const NaverMapViewOptions(
              indoorEnable: true,
              locationButtonEnable: true,
              consumeSymbolTapEvents: false,
            ),
            onMapReady: (controller) async {
              _mapControllerCompleter.complete(controller);
              log("NaverMap is ready!", name: "NaverMapApp");
            },
          ),
          if (_showRentButton)
            Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: ElevatedButton(
                onPressed: _navigateToHomeScreen,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const Text('Rent'),
              ),
            ),
        ],
      ),
    );
  }
}
