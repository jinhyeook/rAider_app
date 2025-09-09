import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // static const String _baseUrl = 'http://3.34.48.22:5000'; // AWS 서버 주소
  // static const String _baseUrl = 'http://192.168.55.92:5000'; // 로컬 서버 주소(데스크탑)
  //static const String _baseUrl = 'http://192.168.45.193:5000'; // 로컬 서버 주소(노트북)
  static const String _baseUrl = 'http://192.168.173.229:5000'; // 로컬 서버 주소(핫스팟)
  
  static const String _userKey = 'user_data';
  static const String _tokenKey = 'auth_token';

  // 싱글톤 패턴
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // 현재 로그인된 사용자 정보
  Map<String, dynamic>? _currentUser;

  // 현재 사용자 정보 가져오기
  Map<String, dynamic>? get currentUser => _currentUser;

  // 로그인 상태 확인
  bool get isLoggedIn => _currentUser != null;

  // 로그인 함수
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // 로그인 성공 시 사용자 정보 저장
        _currentUser = responseData['user'];
        await _saveUserData(_currentUser!);
        
        return {
          'success': true,
          'message': responseData['message'],
          'user': _currentUser,
        };
      } else {
        return {
          'success': false,
          'message': responseData['error'] ?? '로그인에 실패했습니다.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다. 다시 시도해주세요.',
      };
    }
  }

  // 회원가입 함수
  Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/register'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(userData),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': responseData['message'],
          'user_id': responseData['user_id'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['error'] ?? '회원가입에 실패했습니다.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다. 다시 시도해주세요.',
      };
    }
  }

  // 로그아웃 함수
  Future<void> logout() async {
    _currentUser = null;
    await _clearUserData();
  }

  // 앱 시작 시 저장된 사용자 정보 로드
  Future<void> loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString(_userKey);
      
      if (userDataString != null) {
        _currentUser = jsonDecode(userDataString);
      }
    } catch (e) {
      print('사용자 데이터 로드 오류: $e');
      _currentUser = null;
    }
  }

  // 사용자 정보를 로컬에 저장
  Future<void> _saveUserData(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(userData));
    } catch (e) {
      print('사용자 데이터 저장 오류: $e');
    }
  }

  // 로컬 사용자 데이터 삭제
  Future<void> _clearUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      await prefs.remove(_tokenKey);
    } catch (e) {
      print('사용자 데이터 삭제 오류: $e');
    }
  }

  // 이메일 중복 확인
  Future<Map<String, dynamic>> checkEmail(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/check-email'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email': email}),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'available': responseData['available'],
          'message': responseData['message'],
        };
      } else {
        return {
          'success': false,
          'available': false,
          'message': responseData['message'],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'available': false,
        'message': '이메일 확인 중 오류가 발생했습니다.',
      };
    }
  }

  // 운전면허증 번호 확인
  Future<Map<String, dynamic>> checkDriverLicense(String license) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/verify-license'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'driver_license': license}),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'available': responseData['available'],
          'message': responseData['message'],
        };
      } else {
        return {
          'success': false,
          'available': false,
          'message': responseData['message'],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'available': false,
        'message': '운전면허증 확인 중 오류가 발생했습니다.',
      };
    }
  }
}
