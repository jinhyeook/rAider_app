import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'config/server_config.dart';

class MyPageService {
  // ServerConfig를 통해 서버 주소 관리

  // 싱글톤 패턴
  static final MyPageService _instance = MyPageService._internal();
  factory MyPageService() => _instance;
  MyPageService._internal();

  /// 사용자 정보 조회
  /// 현재 로그인된 사용자의 상세 정보를 가져옵니다
  Future<Map<String, dynamic>> getUserInfo() async {
    try {
      // 현재 로그인된 사용자 정보 가져오기
      final authService = AuthService();
      final currentUser = authService.currentUser;
      
      if (currentUser == null) {
        return {
          'success': false,
          'message': '로그인이 필요합니다.',
        };
      }

      final userId = currentUser['user_id'];
      
      final response = await http.get(
        Uri.parse(ServerConfig.getUserUrl('/user-info/$userId')),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'user_info': responseData,
        };
      } else {
        return {
          'success': false,
          'message': responseData['error'] ?? '사용자 정보를 가져오는데 실패했습니다.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다. 다시 시도해주세요.',
      };
    }
  }

  /// 사용자 정보 업데이트
  /// 사용자의 정보를 수정합니다
  Future<Map<String, dynamic>> updateUserInfo(Map<String, dynamic> userData) async {
    try {
      final authService = AuthService();
      final currentUser = authService.currentUser;
      
      if (currentUser == null) {
        return {
          'success': false,
          'message': '로그인이 필요합니다.',
        };
      }

      final userId = currentUser['user_id'];
      
      final response = await http.put(
        Uri.parse(ServerConfig.getUserUrl('/user-info/$userId')),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(userData),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? '정보가 성공적으로 업데이트되었습니다.',
        };
      } else {
        return {
          'success': false,
          'message': responseData['error'] ?? '정보 업데이트에 실패했습니다.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다. 다시 시도해주세요.',
      };
    }
  }

  /// 디바이스 사용 로그 조회
  /// 현재 로그인된 사용자의 최근 디바이스 사용 내역을 가져옵니다
  Future<Map<String, dynamic>> getDeviceLogs() async {
    try {
      print('=== Device Logs API 호출 시작 ===');
      
      // 현재 로그인된 사용자 정보 가져오기
      final authService = AuthService();
      final currentUser = authService.currentUser;
      
      print('Current user: $currentUser');
      
      if (currentUser == null) {
        print('사용자가 로그인되지 않음');
        return {
          'success': false,
          'message': 'Login required.',
        };
      }

      final userId = currentUser['user_id'];
      print('User ID: $userId');
      
      final apiUrl = ServerConfig.getUserUrl('/device-logs/$userId');
      print('API URL: $apiUrl');
      
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        print('API 호출 성공');
        print('Device logs: ${responseData['device_logs']}');
        return {
          'success': true,
          'device_logs': responseData['device_logs'] ?? [],
        };
      } else {
        print('API 호출 실패: ${response.statusCode}');
        return {
          'success': false,
          'message': responseData['error'] ?? 'Failed to load device logs.',
        };
      }
    } catch (e) {
      print('Device logs API 호출 중 오류: $e');
      return {
        'success': false,
        'message': 'Network error occurred. Please try again.',
      };
    }
  }
}
