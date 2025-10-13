import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config/server_config.dart';

class AuthService {
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
  
  // 인증 상태 검증 (네트워크 상태 확인)
  Future<bool> validateAuthState() async {
    if (_currentUser == null) {
      return false;
    }
    
    try {
      // 서버에 현재 사용자 상태 확인 요청
      final response = await http.get(
        Uri.parse(ServerConfig.getAuthUrl('/validate-session')),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['valid'] == true;
      } else {
        // 서버에서 세션이 유효하지 않다고 응답
        print('서버에서 세션 무효화 응답');
        await logout();
        return false;
      }
    } catch (e) {
      print('인증 상태 검증 오류: $e');
      // 네트워크 오류 시 로컬 상태 유지 (오프라인 모드)
      return true;
    }
  }

  // 로그인 함수
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse(ServerConfig.getAuthUrl('/login')),
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
        
        try {
          await _saveUserData(_currentUser!);
          return {
            'success': true,
            'message': responseData['message'],
            'user': _currentUser,
          };
        } catch (saveError) {
          print('사용자 데이터 저장 실패: $saveError');
          // 저장 실패해도 로그인은 성공으로 처리하되 경고 메시지 추가
          return {
            'success': true,
            'message': '${responseData['message']} (Warning: Local data save failed)',
            'user': _currentUser,
          };
        }
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
        Uri.parse(ServerConfig.getAuthUrl('/register')),
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
      
      if (userDataString != null && userDataString.isNotEmpty) {
        try {
          final decodedUser = jsonDecode(userDataString);
          // 사용자 데이터 유효성 검사
          if (decodedUser is Map<String, dynamic> && 
              (decodedUser.containsKey('USER_ID') || 
               decodedUser.containsKey('user_id') || 
               decodedUser.containsKey('id') || 
               decodedUser.containsKey('ID'))) {
            _currentUser = decodedUser;
            print('사용자 데이터 로드 성공: ${_currentUser?['USER_ID'] ?? _currentUser?['user_id'] ?? _currentUser?['id'] ?? _currentUser?['ID']}');
          } else {
            print('사용자 데이터 형식이 올바르지 않음');
            _currentUser = null;
            await _clearUserData(); // 손상된 데이터 정리
          }
        } catch (jsonError) {
          print('JSON 파싱 오류: $jsonError');
          _currentUser = null;
          await _clearUserData(); // 손상된 데이터 정리
        }
      } else {
        _currentUser = null;
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
      final userDataJson = jsonEncode(userData);
      
      // 데이터 저장 시도
      final success = await prefs.setString(_userKey, userDataJson);
      if (!success) {
        throw Exception('Failed to save user data to SharedPreferences');
      }
      
      // report_mode.dart에서 사용할 수 있도록 user_id도 별도로 저장
      String? userId;
      if (userData['USER_ID'] != null) {
        userId = userData['USER_ID'].toString();
      } else if (userData['user_id'] != null) {
        userId = userData['user_id'].toString();
      } else if (userData['id'] != null) {
        userId = userData['id'].toString();
      } else if (userData['ID'] != null) {
        userId = userData['ID'].toString();
      }
      
      if (userId != null && userId.isNotEmpty) {
        final userIdSuccess = await prefs.setString('user_id', userId);
        if (!userIdSuccess) {
          print('Warning: Failed to save user_id to SharedPreferences');
        }
      }
      
      print('사용자 데이터 저장 성공: $userId');
    } catch (e) {
      print('사용자 데이터 저장 오류: $e');
      // 저장 실패 시 현재 사용자 정보도 null로 설정
      _currentUser = null;
      rethrow; // 상위에서 처리할 수 있도록 예외 재발생
    }
  }

  // 로컬 사용자 데이터 삭제
  Future<void> _clearUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 각 키를 개별적으로 제거하고 결과 확인
      final keysToRemove = [_userKey, _tokenKey, 'user_id', 'selected_device_code'];
      for (final key in keysToRemove) {
        try {
          final removed = await prefs.remove(key);
          if (removed) {
            print('키 제거 성공: $key');
          } else {
            print('키 제거 실패: $key');
          }
        } catch (keyError) {
          print('키 $key 제거 중 오류: $keyError');
        }
      }
      
      print('사용자 데이터 정리 완료');
    } catch (e) {
      print('사용자 데이터 정리 오류: $e');
      rethrow;
    }
  }

  // 이메일 중복 확인
  Future<Map<String, dynamic>> checkEmail(String email) async {
    try {
      final response = await http.post(
        Uri.parse(ServerConfig.getAuthUrl('/check-email')),
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
        Uri.parse(ServerConfig.getAuthUrl('/verify-license')),
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
