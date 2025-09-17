import 'dart:convert';
import 'package:http/http.dart' as http;

class DeviceService {
  static const String _baseUrl = 'http://192.168.55.92:5000'; // 서버 주소 복원

  // 싱글톤 패턴
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  /// 사용 가능한 기기 목록 조회
  /// is_used = 0인 기기들만 가져옵니다
  Future<Map<String, dynamic>> getAvailableDevices() async {
    try {
      print('기기 목록 요청 시작: $_baseUrl/api/devices/available');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/api/devices/available'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('서버 응답: ${response.statusCode}');
      print('응답 본문: ${response.body}');

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        print('기기 목록 조회 성공: ${responseData.length}개');
        return {
          'success': true,
          'devices': responseData,
        };
      } else {
        print('서버 오류: ${response.statusCode}');
        return {
          'success': false,
          'message': responseData['error'] ?? '기기 정보를 가져오는데 실패했습니다.',
        };
      }
    } catch (e) {
      print('네트워크 오류 상세: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다. 다시 시도해주세요.\n오류: $e',
      };
    }
  }

  /// 특정 기기 정보 조회
  Future<Map<String, dynamic>> getDeviceInfo(String deviceId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/devices/$deviceId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'device': responseData,
        };
      } else {
        return {
          'success': false,
          'message': responseData['error'] ?? '기기 정보를 가져오는데 실패했습니다.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다. 다시 시도해주세요.',
      };
    }
  }

  /// 기기 사용 상태 업데이트
  Future<Map<String, dynamic>> updateDeviceStatus(String deviceId, bool isUsed) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/devices/$deviceId/status'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'is_used': isUsed ? 1 : 0,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? '기기 상태가 업데이트되었습니다.',
        };
      } else {
        return {
          'success': false,
          'message': responseData['error'] ?? '기기 상태 업데이트에 실패했습니다.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다. 다시 시도해주세요.',
      };
    }
  }
}
