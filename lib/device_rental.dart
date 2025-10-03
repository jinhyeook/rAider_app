import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home.dart';
import 'qr.dart';
import 'device_service.dart';

class NaverMapApp extends StatefulWidget {
  const NaverMapApp({super.key});

  @override
  State<NaverMapApp> createState() => _NaverMapAppState();
}

class _NaverMapAppState extends State<NaverMapApp> {
  final Completer<NaverMapController> _mapControllerCompleter = Completer();
  final DeviceService _deviceService = DeviceService();
  bool _showRentButton = false;
  String? _selectedMarkerId;
  List<Map<String, dynamic>> _devices = [];
  bool _isLoadingDevices = false;
  Timer? _refreshTimer;
  Map<String, dynamic>? _selectedDevice;

  @override
  void initState() {
    super.initState();
    _checkAndRequestLocationPermission();
    _startPeriodicRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// 주기적으로 기기 정보 새로고침 (30초마다)
  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadDevices();
    });
  }

  /// DB에서 사용 가능한 기기 목록 로드
  Future<void> _loadDevices() async {
    if (_isLoadingDevices) return;
    
    setState(() {
      _isLoadingDevices = true;
    });

    try {
      final result = await _deviceService.getAvailableDevices();
      
      log("기기 로드 결과: $result", name: "DeviceRental");
      
      if (result['success']) {
        setState(() {
          _devices = List<Map<String, dynamic>>.from(result['devices']);
        });
        log("로드된 기기 수: ${_devices.length}", name: "DeviceRental");
        _updateMapMarkers();
      } else {
        log("기기 로드 실패: ${result['message']}", name: "DeviceRental");
      }
    } catch (e) {
      log("기기 로드 오류: $e", name: "DeviceRental");
    } finally {
      setState(() {
        _isLoadingDevices = false;
      });
    }
  }

  /// 강제 새로고침 (모든 마커 제거 후 다시 로드)
  Future<void> _forceRefreshDevices() async {
    log("강제 새로고침 시작", name: "DeviceRental");
    
    // 기존 마커들 강제 제거 (알려진 ID들로)
    if (_mapControllerCompleter.isCompleted) {
      try {
        final controller = await _mapControllerCompleter.future;
        
        // 현재 _devices에 있는 마커들 제거
        for (var device in _devices) {
          final markerId = 'device_${device['device_id']}';
          try {
            await controller.deleteOverlay(NOverlayInfo(type: NOverlayType.marker, id: markerId));
            log("강제 마커 제거: $markerId", name: "DeviceRental");
          } catch (e) {
            log("강제 마커 제거 실패: $markerId", name: "DeviceRental");
          }
        }
        
        // 추가로 가능한 기기 ID들도 시도
        for (int i = 1; i <= 50; i++) {
          final possibleIds = [
            'device_025090400$i',
            'device_025091400$i', 
            'device_125090400$i',
            'device_125091400$i',
            'device_BUSAN_00$i',
            'device_DEVICE_00$i',
          ];
          
          for (var id in possibleIds) {
            try {
              await controller.deleteOverlay(NOverlayInfo(type: NOverlayType.marker, id: id));
              log("추가 마커 제거: $id", name: "DeviceRental");
            } catch (e) {
              // 마커가 없으면 무시
            }
          }
        }
      } catch (e) {
        log("강제 마커 제거 오류: $e", name: "DeviceRental");
      }
    }
    
    // 기기 목록 초기화
    setState(() {
      _devices = [];
      _selectedMarkerId = null;
      _showRentButton = false;
      _selectedDevice = null;
    });
    
    // 잠시 대기 후 새로 로드
    await Future.delayed(const Duration(milliseconds: 100));
    
    // 사용자 위치 업데이트
    await _showCurrentLocation();
  }

  /// 지도에 마커 업데이트
  Future<void> _updateMapMarkers() async {
    if (!_mapControllerCompleter.isCompleted) {
      log("지도 컨트롤러가 아직 준비되지 않음", name: "DeviceRental");
      return;
    }
    
    final controller = await _mapControllerCompleter.future;
    log("마커 업데이트 시작: ${_devices.length}개 기기", name: "DeviceRental");
    
    // 기존 기기 마커들 제거 (알려진 ID들로)
    for (var device in _devices) {
      final markerId = 'device_${device['device_id']}';
      try {
        await controller.deleteOverlay(NOverlayInfo(type: NOverlayType.marker, id: markerId));
        log("기존 마커 제거: $markerId", name: "DeviceRental");
      } catch (e) {
        log("마커 제거 실패 (없을 수 있음): $markerId", name: "DeviceRental");
      }
    }

    // 새로운 마커들 추가
    int addedMarkers = 0;
    for (var device in _devices) {
      final latitude = device['latitude'] as double?;
      final longitude = device['longitude'] as double?;
      final deviceType = device['device_type'] as String?;
      final deviceId = device['device_id'] as String?;
      
      log("기기 처리 중: $deviceId, lat: $latitude, lng: $longitude, type: $deviceType", name: "DeviceRental");
      
      if (latitude != null && longitude != null && deviceId != null) {
        // 좌표가 뒤바뀌어 있으므로 수정
        final position = NLatLng(longitude, latitude);
        
        // 기기 타입에 따른 아이콘 선택
        final iconData = _getDeviceIcon(deviceType);
        
        try {
          // 기기 타입에 따른 아이콘이 있는 마커
          final marker = NMarker(
            id: 'device_$deviceId',
            position: position,
            caption: NOverlayCaption(text: deviceType ?? 'Device'),
            icon: await NOverlayImage.fromWidget(
              context: context,
              widget: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0F5C31), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  iconData,
                  color: _getBatteryColor(device['battery_level']),
                  size: 24,
                ),
              ),
              size: const Size(40, 40),
            ),
          );

          marker.setOnTapListener((overlay) {
            log("마커 클릭: $deviceId", name: "DeviceRental");
            setState(() {
              if (_selectedMarkerId == marker.info.id) {
                // 같은 마커 클릭 시 해제
                _selectedMarkerId = null;
                _showRentButton = false;
                _selectedDevice = null;
              } else {
                _selectedMarkerId = marker.info.id;
                _showRentButton = true;
                // 선택된 기기 정보 저장
                _selectedDevice = device;
              }
            });
          });

          await controller.addOverlay(marker);
          addedMarkers++;
          log("마커 추가 성공: $deviceId at ($latitude, $longitude)", name: "DeviceRental");
        } catch (e) {
          log("마커 추가 실패: $deviceId, 오류: $e", name: "DeviceRental");
        }
      } else {
        log("기기 데이터 누락: $deviceId, lat: $latitude, lng: $longitude", name: "DeviceRental");
      }
    }
    
    log("마커 업데이트 완료: $addedMarkers개 마커 추가됨", name: "DeviceRental");
  }

  /// 기기 타입에 따른 아이콘 반환
  IconData _getDeviceIcon(String? deviceType) {
    switch (deviceType?.toLowerCase()) {
      case '자전거':
        return Icons.directions_bike;
      case '킥보드':
        return Icons.electric_scooter;
      default:
        return Icons.location_on;
    }
  }

  /// 배터리 레벨에 따른 색상 반환
  Color _getBatteryColor(dynamic batteryLevel) {
    final level = batteryLevel is int ? batteryLevel : 0;
    
    if (level >= 50) {
      return Colors.green; // 50% 이상: 녹색
    } else if (level >= 20) {
      return Colors.orange; // 20-49%: 주황색
    } else {
      return Colors.red; // 20% 미만: 빨간색
    }
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

    // 기존 현재 위치 마커 제거
    try {
      await controller.deleteOverlay(NOverlayInfo(type: NOverlayType.marker, id: 'current_location_marker'));
      log("기존 사용자 위치 마커 제거", name: "DeviceRental");
    } catch (e) {
      log("기존 사용자 위치 마커 제거 실패 (없을 수 있음)", name: "DeviceRental");
    }

    // 현재 위치 마커 (아이콘 포함)
    final currentMarker = NMarker(
      id: 'current_location_marker',
      position: currentLatLng,
      caption: NOverlayCaption(text: 'You'),
      icon: await NOverlayImage.fromWidget(
        context: context,
        widget: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.person,
            color: Colors.white,
            size: 24,
          ),
        ),
        size: const Size(40, 40),
      ),
    );
    controller.addOverlay(currentMarker);

    // 카메라 이동
    await controller.updateCamera(NCameraUpdate.withParams(
      target: currentLatLng,
      zoom: 14,
    ));

    // DB에서 기기 정보 로드
    await _loadDevices();

    log("사용자 위치 마커 추가 및 기기 마커 로드 완료", name: "DeviceRental");
  }

  // QR코드 스캔 페이지로 이동
  void _navigateToHomeScreen() async {
    if (_selectedDevice != null) {
      // 선택된 기기 정보를 SharedPreferences에 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_device_id', _selectedDevice!['device_id']);
      print('선택된 기기 저장: ${_selectedDevice!['device_id']}');
    }
    
    // QR화면으로 이동 (지도 상태 유지)
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QrScanPage()),
    );
    
    // QR화면에서 돌아왔을 때 지도 상태 복원
    if (result == 'back_from_qr') {
      // 선택된 기기 상태 초기화
      setState(() {
        _selectedMarkerId = null;
        _showRentButton = false;
        _selectedDevice = null;
      });
      
      // 기기 목록 새로고침
      await _loadDevices();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('기기 대여 지도'),
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
              initialCameraPosition: NCameraPosition(
                target: NLatLng(37.3125, 126.8083), // 안산시 단원구 선부광장
                zoom: 14,
              ),
            ),
            onMapReady: (controller) async {
              _mapControllerCompleter.complete(controller);
              log("NaverMap is ready!", name: "NaverMapApp");
              
              // 지도 준비 후 잠시 대기 후 기기 로드
              await Future.delayed(const Duration(milliseconds: 500));
              await _loadDevices();
            },
          ),
          // 새로고침 버튼
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              onPressed: _forceRefreshDevices,
              backgroundColor: const Color(0xFF0F5C31),
              child: _isLoadingDevices
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.refresh, color: Colors.white),
            ),
          ),
          // 기기 개수 표시
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '사용 가능한 기기: ${_devices.length}개',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F5C31),
                ),
              ),
            ),
          ),
          if (_showRentButton && _selectedDevice != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 기기 정보 표시
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_selectedDevice!['device_type'] ?? '기기'}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F5C31),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: ${_selectedDevice!['device_id'] ?? 'N/A'}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        // 배터리 정보 표시
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getBatteryColor(_selectedDevice!['battery_level']),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.battery_std,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_selectedDevice!['battery_level'] ?? 0}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Rent 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _navigateToHomeScreen,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F5C31),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                        child: const Text('Rent'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
