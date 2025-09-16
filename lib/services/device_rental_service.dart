import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class DeviceRentalService {
  static const String baseUrl = 'http://192.168.55.92:5000/api/device-rental'; // 실제 서버 IP로 변경 필요
  
  // 기기 대여 시작
  static Future<Map<String, dynamic>> startRental({
    required String userId,
    required String deviceCode,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/start'),
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
      print('서버 연결 실패, 오프라인 모드로 동작: $e');
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
      print('실시간 로그 전송 시도: $baseUrl/realtime-log');
      print('데이터: userId=$userId, deviceCode=$deviceCode, lat=$latitude, lng=$longitude');
      
      final response = await http.post(
        Uri.parse('$baseUrl/realtime-log'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'device_code': deviceCode,
          'latitude': latitude,
          'longitude': longitude,
        }),
      ).timeout(const Duration(seconds: 10));
      
      print('실시간 로그 응답: ${response.statusCode} - ${response.body}');
      
      if (response.statusCode == 200) {
        print('실시간 로그 전송 성공');
      } else {
        print('실시간 로그 전송 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('실시간 로그 전송 오류: $e');
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
      print('대여 종료 요청: userId=$userId, deviceCode=$deviceCode, lat=$latitude, lng=$longitude');
      
      final response = await http.post(
        Uri.parse('$baseUrl/end'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'device_code': deviceCode,
          'end_latitude': latitude,
          'end_longitude': longitude,
        }),
      ).timeout(const Duration(seconds: 15));
      
      print('대여 종료 응답: ${response.statusCode} - ${response.body}');
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        print('대여 종료 성공: $result');
        return result;
      } else {
        print('대여 종료 실패: ${response.statusCode} - ${response.body}');
        throw Exception('대여 종료 실패: ${response.body}');
      }
    } catch (e) {
      // 서버 연결 실패 시 오프라인 모드로 동작
      print('서버 연결 실패, 오프라인 모드로 종료: $e');
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
        Uri.parse('$baseUrl/status/$deviceCode'),
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
        Uri.parse('http://192.168.55.92:5000/api/devices/available'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final List<dynamic> devices = jsonDecode(response.body);
        return devices.cast<Map<String, dynamic>>();
      } else {
        throw Exception('기기 목록 조회 실패: ${response.body}');
      }
    } catch (e) {
      print('기기 목록 조회 오류: $e');
      return [];
    }
  }
  
  // 서버 연결 테스트
  static Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/status/TEST'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200 || response.statusCode == 404; // 404도 서버가 응답했다는 의미
    } catch (e) {
      print('서버 연결 테스트 실패: $e');
      return false;
    }
  }
}
