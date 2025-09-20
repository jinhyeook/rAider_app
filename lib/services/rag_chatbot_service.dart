import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/server_config.dart';

class RAGChatbotService {
  
  // 싱글톤 패턴
  static final RAGChatbotService _instance = RAGChatbotService._internal();
  factory RAGChatbotService() => _instance;
  RAGChatbotService._internal();

  String? _sessionId;

  /// 세션 ID 생성 또는 가져오기
  Future<String> _getSessionId() async {
    if (_sessionId != null) return _sessionId!;
    
    final prefs = await SharedPreferences.getInstance();
    _sessionId = prefs.getString('chatbot_session_id');
    
    if (_sessionId == null) {
      _sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('chatbot_session_id', _sessionId!);
    }
    
    return _sessionId!;
  }

  /// RAG 챗봇 API를 통해 메시지 전송
  Future<Map<String, dynamic>> sendMessage(String userMessage) async {
    try {
      final sessionId = await _getSessionId();
      
      final response = await http.post(
        Uri.parse(ServerConfig.getUserUrl('/RAG_Chatbot')),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'question': userMessage,
          'session_id': sessionId,
        }),
      ).timeout(const Duration(seconds: 30));

      print('RAG 챗봇 응답: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        return {
          'success': true,
          'message': data['response'] ?? '답변을 받지 못했습니다.',
          'session_id': data['session_id'],
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['error'] ?? '서버 오류가 발생했습니다.',
        };
      }
    } catch (e) {
      print('RAG 챗봇 오류: $e');
      return {
        'success': false,
        'message': '네트워크 오류가 발생했습니다. 다시 시도해주세요.',
      };
    }
  }

  /// 세션 초기화 (새로운 대화 시작)
  Future<void> resetSession() async {
    try {
      final sessionId = await _getSessionId();
      
      final response = await http.post(
        Uri.parse(ServerConfig.getUserUrl('/RAG_Chatbot/reset')),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'session_id': sessionId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('chatbot_session_id');
        _sessionId = null;
        print('세션 초기화 완료');
      } else {
        print('세션 초기화 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('세션 초기화 오류: $e');
      // 로컬에서라도 세션 초기화
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('chatbot_session_id');
      _sessionId = null;
    }
  }

  /// 챗봇 상태 확인
  Future<Map<String, dynamic>> getStatus() async {
    try {
      final response = await http.get(
        Uri.parse(ServerConfig.getUserUrl('/RAG_Chatbot/status')),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'status': data['status'],
          'message': data['message'],
          'document_count': data['document_count'],
          'active_sessions': data['active_sessions'],
        };
      } else {
        return {
          'success': false,
          'message': '상태 확인 실패',
        };
      }
    } catch (e) {
      print('상태 확인 오류: $e');
      return {
        'success': false,
        'message': '상태 확인 중 오류가 발생했습니다.',
      };
    }
  }

}



