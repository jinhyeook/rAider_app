import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'device_rental_service.dart';

class LocationService {
  static Timer? _locationTimer;
  static String? _currentUserId;
  static String? _currentDeviceCode;
  static bool _isTracking = false;
  
  // 위치 추적 시작 (10초마다)
  static void startLocationTracking({
    required String userId,
    required String deviceCode,
  }) {
    if (_isTracking) return;
    
    _currentUserId = userId;
    _currentDeviceCode = deviceCode;
    _isTracking = true;
    
    
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        final position = await DeviceRentalService.getCurrentLocation();
        final now = DateTime.now();
        
        // 서버 연결 상태와 관계없이 항상 로그 전송 시도
        await DeviceRentalService.sendRealtimeLog(
          userId: userId,
          deviceCode: deviceCode,
          latitude: position.latitude,
          longitude: position.longitude,
        );
      } catch (e) {
        // 위치 추적은 계속 진행 (서버 연결 실패와 무관하게)
      }
    });
  }
  
  // 위치 추적 중지
  static void stopLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _isTracking = false;
    _currentUserId = null;
    _currentDeviceCode = null;
  }
  
  // 추적 상태 확인
  static bool get isTracking => _isTracking;
  
}
