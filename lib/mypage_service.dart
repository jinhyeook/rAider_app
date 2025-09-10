import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class MyPageService {
  static const String _baseUrl = 'http://192.168.55.92:5000'; // AuthService와 동일한 서버 주소

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
        Uri.parse('$_baseUrl/api/user-info/$userId'),
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
        Uri.parse('$_baseUrl/api/user-info/$userId'),
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
}
