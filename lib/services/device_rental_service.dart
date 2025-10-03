import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../config/server_config.dart';

class DeviceRentalService {
  // ServerConfig를 통해 서버 주소 관리
  
  // 기기 대여 시작
  static Future<Map<String, dynamic>> startRental({
    required String userId,
    required String deviceCode,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ServerConfig.deviceRentalUrl + '/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'device_code': deviceCode,
          'start_latitude': latitude,
          'start_longitude': longitude,
        }),
      );
      
      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('대여 시작 실패: ${response.body}');
      }
    } catch (e) {
      // 서버 연결 실패 시 오프라인 모드로 동작
      return {
        'message': '오프라인 모드로 대여가 시작되었습니다.',
        'rental_id': 'offline_${DateTime.now().millisecondsSinceEpoch}',
        'offline_mode': true
      };
    }
  }
  
  // 실시간 로그 전송
  static Future<void> sendRealtimeLog({
    required String userId,
    required String deviceCode,
    required double latitude,
    required double longitude,
  }) async {
    try {
      
      final response = await http.post(
        Uri.parse(ServerConfig.deviceRentalUrl + '/realtime-log'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'device_code': deviceCode,
          'latitude': latitude,
          'longitude': longitude,
        }),
      ).timeout(const Duration(seconds: 10));
      
    } catch (e) {
      // 오류가 발생해도 예외를 다시 던지지 않음 (위치 추적은 계속 진행)
    }
  }
  
  // 기기 대여 종료
  static Future<Map<String, dynamic>> endRental({
    required String userId,
    required String deviceCode,
    required double latitude,
    required double longitude,
  }) async {
    try {
      
      final response = await http.post(
        Uri.parse(ServerConfig.deviceRentalUrl + '/end'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'device_code': deviceCode,
          'end_latitude': latitude,
          'end_longitude': longitude,
        }),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result;
      } else {
        throw Exception('대여 종료 실패: ${response.body}');
      }
    } catch (e) {
      // 서버 연결 실패 시 오프라인 모드로 동작
      return {
        'message': '오프라인 모드로 대여가 종료되었습니다.',
        'usage_minutes': 5, // 기본값
        'fee': 500, // 기본값
        'moved_distance': 1.0, // 기본값
        'offline_mode': true
      };
    }
  }
  
  // 기기 대여 상태 확인
  static Future<Map<String, dynamic>> getRentalStatus(String deviceCode) async {
    try {
      final response = await http.get(
        Uri.parse(ServerConfig.deviceRentalUrl + '/status/$deviceCode'),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('상태 확인 실패: ${response.body}');
      }
    } catch (e) {
      throw Exception('상태 확인 중 오류: $e');
    }
  }
  
  // 현재 위치 가져오기
  static Future<Position> getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('위치 권한이 거부되었습니다.');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('위치 권한이 영구적으로 거부되었습니다.');
      }
      
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      throw Exception('위치 정보를 가져올 수 없습니다: $e');
    }
  }
  
  // 사용 가능한 기기 목록 조회
  static Future<List<Map<String, dynamic>>> getAvailableDevices() async {
    try {
      final response = await http.get(
        Uri.parse(ServerConfig.getDeviceUrl('/available')),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final List<dynamic> devices = jsonDecode(response.body);
        return devices.cast<Map<String, dynamic>>();
      } else {
        throw Exception('기기 목록 조회 실패: ${response.body}');
      }
    } catch (e) {
      return [];
    }
  }
  
  // 서버 연결 테스트
  static Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse(ServerConfig.deviceRentalUrl + '/status/TEST'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200 || response.statusCode == 404; // 404도 서버가 응답했다는 의미
    } catch (e) {
      return false;
    }
  }
}
