import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home.dart';
import 'qr.dart';
import 'device_service.dart';
import 'config/server_config.dart';

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
  List<Map<String, dynamic>> _groupedDevices = [];
  bool _showDeviceListPopup = false;

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
    if (_isLoadingDevices) {
      log("이미 로딩 중이므로 건너뜀", name: "DeviceRental");
      return;
    }
    
    log("기기 로드 시작", name: "DeviceRental");
    setState(() {
      _isLoadingDevices = true;
    });

    try {
      final result = await _deviceService.getAvailableDevices();
      
      if (result['success'] == true) {
        final devicesList = result['devices'];
        
        if (devicesList == null || devicesList.isEmpty) {
          setState(() {
            _devices = [];
          });
          return;
        }
        
        setState(() {
          _devices = List<Map<String, dynamic>>.from(devicesList);
        });
        
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
      return;
    }
    
    final controller = await _mapControllerCompleter.future;
    
    // 기존 기기 마커들 제거
    for (var device in _devices) {
      final markerId = 'device_${device['device_id']}';
      try {
        await controller.deleteOverlay(NOverlayInfo(type: NOverlayType.marker, id: markerId));
      } catch (e) {
        // 마커가 없을 수 있음
      }
    }

    // 새로운 마커들 추가
    int addedMarkers = 0;
    
    for (int i = 0; i < _devices.length; i++) {
      var device = _devices[i];
      
      // 좌표 데이터 타입 변환
      double? latitude;
      double? longitude;
      
      try {
        // DB에서 latitude와 longitude가 뒤바뀌어 있으므로 수정
        if (device['latitude'] is String) {
          longitude = double.parse(device['latitude'] as String);
        } else {
          longitude = device['latitude'] as double?;
        }
        
        if (device['longitude'] is String) {
          latitude = double.parse(device['longitude'] as String);
        } else {
          latitude = device['longitude'] as double?;
        }
      } catch (e) {
        continue;
      }
      
      final deviceType = device['device_type'] as String?;
      final deviceId = device['device_id'] as String?;
      
      if (latitude != null && longitude != null && deviceId != null) {
        // 좌표 유효성 검사
        if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
          continue;
        }
        
        final position = NLatLng(latitude, longitude);
        final iconData = _getDeviceIcon(deviceType);
        
        // 디버깅을 위한 로그
        log("Creating marker for device: $deviceId, type: '$deviceType', icon: $iconData", name: "DeviceRental");
        
        try {
          final marker = NMarker(
            id: 'device_$deviceId',
            position: position,
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
            // 해당 위치의 모든 기기 찾기
            final deviceGroup = _findDevicesAtLocation(device);
            
            if (deviceGroup.length > 1) {
              // 여러 기기가 있는 경우 팝업 표시
              setState(() {
                _groupedDevices = deviceGroup;
                _selectedMarkerId = null;
                _showRentButton = false;
                _selectedDevice = null;
              });
              _showDeviceSelectionPopup();
            } else {
              // 단일 기기인 경우 기존 로직
              setState(() {
                if (_selectedMarkerId == marker.info.id) {
                  _selectedMarkerId = null;
                  _showRentButton = false;
                  _selectedDevice = null;
                } else {
                  _selectedMarkerId = marker.info.id;
                  _showRentButton = true;
                  _selectedDevice = device;
                }
              });
            }
          });

          await controller.addOverlay(marker);
          addedMarkers++;
          log("Marker added successfully: $deviceId", name: "DeviceRental");
        } catch (e) {
          log("Failed to add marker for device $deviceId: $e", name: "DeviceRental");
        }
      }
    }
    
    log("Marker update completed. Added $addedMarkers markers out of ${_devices.length} devices", name: "DeviceRental");
  }

  /// 좌표를 소수점 4자리까지 반올림하여 그룹화 키 생성
  String _getGroupKey(double latitude, double longitude) {
    final latRounded = (latitude * 10000).round() / 10000;
    final lngRounded = (longitude * 10000).round() / 10000;
    return '${latRounded.toStringAsFixed(4)},${lngRounded.toStringAsFixed(4)}';
  }

  /// 기기들을 좌표 기반으로 그룹화
  Map<String, List<Map<String, dynamic>>> _groupDevicesByLocation(List<Map<String, dynamic>> devices) {
    final Map<String, List<Map<String, dynamic>>> groupedDevices = {};
    
    for (var device in devices) {
      double? latitude;
      double? longitude;
      
      try {
        // DB에서 latitude와 longitude가 뒤바뀌어 있으므로 수정
        if (device['latitude'] is String) {
          longitude = double.parse(device['latitude'] as String);
        } else {
          longitude = device['latitude'] as double?;
        }
        
        if (device['longitude'] is String) {
          latitude = double.parse(device['longitude'] as String);
        } else {
          latitude = device['longitude'] as double?;
        }
      } catch (e) {
        continue;
      }
      
      if (latitude != null && longitude != null) {
        final groupKey = _getGroupKey(latitude, longitude);
        if (!groupedDevices.containsKey(groupKey)) {
          groupedDevices[groupKey] = [];
        }
        groupedDevices[groupKey]!.add(device);
      }
    }
    
    return groupedDevices;
  }

  /// 특정 위치의 모든 기기 찾기
  List<Map<String, dynamic>> _findDevicesAtLocation(Map<String, dynamic> targetDevice) {
    double? targetLatitude;
    double? targetLongitude;
    
    try {
      // DB에서 latitude와 longitude가 뒤바뀌어 있으므로 수정
      if (targetDevice['latitude'] is String) {
        targetLongitude = double.parse(targetDevice['latitude'] as String);
      } else {
        targetLongitude = targetDevice['latitude'] as double?;
      }
      
      if (targetDevice['longitude'] is String) {
        targetLatitude = double.parse(targetDevice['longitude'] as String);
      } else {
        targetLatitude = targetDevice['longitude'] as double?;
      }
    } catch (e) {
      return [targetDevice];
    }
    
    if (targetLatitude == null || targetLongitude == null) {
      return [targetDevice];
    }
    
    final targetGroupKey = _getGroupKey(targetLatitude, targetLongitude);
    final groupedDevices = _groupDevicesByLocation(_devices);
    
    return groupedDevices[targetGroupKey] ?? [targetDevice];
  }

  /// 기기 타입에 따른 아이콘 반환
  IconData _getDeviceIcon(String? deviceType) {
    if (deviceType == null) return Icons.location_on;
    
    final type = deviceType.toLowerCase().trim();
    
    // 자전거 관련 키워드
    if (type.contains('bicycle') || type.contains('bike') || type.contains('자전거')) {
      return Icons.directions_bike;
    }
    // 킥보드/스쿠터 관련 키워드
    else if (type.contains('kickboard') || type.contains('scooter') || type.contains('킥보드') || type.contains('스쿠터')) {
      return Icons.electric_scooter;
    }
    // 전동차 관련 키워드
    else if (type.contains('electric') || type.contains('전동')) {
      return Icons.electric_car;
    }
    // 기본값
    else {
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


  /// 기기 선택 팝업 표시
  void _showDeviceSelectionPopup() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Device Selection (${_groupedDevices.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F5C31),
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _groupedDevices.length,
              itemBuilder: (context, index) {
                final device = _groupedDevices[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF0F5C31), width: 2),
                      ),
                      child: Icon(
                        _getDeviceIcon(device['device_type']),
                        color: _getBatteryColor(device['battery_level']),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      '${device['device_type'] ?? 'Device'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ID: ${device['device_id'] ?? 'N/A'}'),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.battery_std,
                              color: _getBatteryColor(device['battery_level']),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${device['battery_level'] ?? 0}%',
                              style: TextStyle(
                                color: _getBatteryColor(device['battery_level']),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      setState(() {
                        _selectedDevice = device;
                        _showRentButton = true;
                        _showDeviceListPopup = false;
                      });
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _showDeviceListPopup = false;
                });
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // QR코드 스캔 페이지로 이동
  void _navigateToHomeScreen() async {
    if (_selectedDevice != null) {
      // 선택된 기기 정보를 SharedPreferences에 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_device_id', _selectedDevice!['device_id']);
      print('Selected device saved: ${_selectedDevice!['device_id']}');
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
    return WillPopScope(
      onWillPop: () async {
        // 뒤로가기 버튼이 눌렸을 때 확인 다이얼로그 표시
        final shouldPop = await _showExitConfirmationDialog();
        return shouldPop ?? false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Device Rental Map',
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width < 600 ? 18 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
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
                target: NLatLng(37.3125, 126.8083),
                zoom: 14,
              ),
            ),
            onMapReady: (controller) async {
              _mapControllerCompleter.complete(controller);
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
                'Available Devices: ${_devices.length}',
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
                              '${_selectedDevice!['device_type'] ?? 'Device'}',
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
      ),
    );
  }

  // 종료 확인 다이얼로그
  Future<bool?> _showExitConfirmationDialog() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Exit Device Rental Map',
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Do you want to exit the device rental map?',
            style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Exit',
                style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
              ),
            ),
          ],
        );
      },
    );
  }
}
