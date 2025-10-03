import 'package:flutter/material.dart';
import 'services/rag_chatbot_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final RAGChatbotService _ragChatbotService = RAGChatbotService();
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeChatbot();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  /// 챗봇 초기화 및 상태 확인
  Future<void> _initializeChatbot() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final status = await _ragChatbotService.getStatus();
      
      if (status['success'] && status['status'] == 'ready') {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
        _addWelcomeMessage();
      } else {
        setState(() {
          _isInitialized = false;
          _isLoading = false;
        });
        _addErrorMessage(status['message'] ?? '챗봇 초기화에 실패했습니다.');
      }
    } catch (e) {
      setState(() {
        _isInitialized = false;
        _isLoading = false;
      });
      _addErrorMessage('챗봇 서버에 연결할 수 없습니다.');
    }
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add(
        ChatMessage(
          text: '''안녕하세요! rAider 고객센터 챗봇입니다 :)
다음과 같은 질문에 답변해드릴 수 있습니다:

• 앱 제작 기관 및 제작 팀
• 앱 제작 배경
• 앱 주요 기능
• 문제 해결을 위한 연락처

궁금한 것이 있으시면 언제든지 질문해주세요!
          ''',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  void _addErrorMessage(String message) {
    setState(() {
      _messages.add(
        ChatMessage(
          text: '$message\n\n잠시 후 다시 시도해주세요.',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  Future<void> _sendMessage() async {
    if (!_isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('챗봇이 아직 초기화되지 않았습니다.'),
          backgroundColor: Colors.orange,
          duration: const Duration(milliseconds: 1500),
        ),
      );
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // 사용자 메시지 추가
    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _isLoading = true;
    });

    _messageController.clear();

    // RAG 챗봇 API 호출
    final response = await _ragChatbotService.sendMessage(text);

    setState(() {
      _isLoading = false;
      _messages.add(
        ChatMessage(
          text: response['success'] 
              ? response['message'] 
              : '죄송합니다. 일시적인 오류가 발생했습니다. 다시 시도해주세요.',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });

    // 오류가 발생한 경우 사용자에게 알림
    if (!response['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message']),
          backgroundColor: Colors.red,
          duration: const Duration(milliseconds: 1500),
          action: SnackBarAction(
            label: '재시도',
            textColor: Colors.white,
            onPressed: _initializeChatbot,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('rAider 고객센터 챗봇'),
        backgroundColor: const Color(0xFF0F5C31),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetChat,
            tooltip: '새 대화 시작',
          ),
        ],
      ),
      body: Column(
        children: [
          // 상태 표시 바
          if (!_isInitialized)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.orange[100],
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '챗봇 초기화 중...',
                      style: TextStyle(
                        color: Colors.orange[800],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _initializeChatbot,
                    child: const Text('재시도', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          
          // 채팅 메시지 리스트
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return _buildLoadingMessage();
                }
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          
          // 메시지 입력 영역
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: _isInitialized && !_isLoading,
                    decoration: InputDecoration(
                      hintText: _isInitialized 
                          ? '메시지를 입력하세요...' 
                          : '챗봇 초기화 중...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(color: Color(0xFF0F5C31)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F5C31),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: (_isInitialized && !_isLoading) ? _sendMessage : null,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(
                            Icons.send,
                            color: Colors.white,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: message.isUser 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF0F5C31),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser 
                    ? const Color(0xFF0F5C31)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(18).copyWith(
                  bottomLeft: message.isUser 
                      ? const Radius.circular(18)
                      : const Radius.circular(4),
                  bottomRight: message.isUser 
                      ? const Radius.circular(4)
                      : const Radius.circular(18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: message.isUser 
                          ? Colors.white70 
                          : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFF0F5C31),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.smart_toy,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(18).copyWith(
                bottomLeft: const Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F5C31)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '답변을 준비하고 있습니다...',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 새 대화 시작 (세션 초기화)
  Future<void> _resetChat() async {
    await _ragChatbotService.resetSession();
    setState(() {
      _messages.clear();
    });
    _addWelcomeMessage();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('새로운 대화를 시작합니다.'),
        backgroundColor: Color(0xFF0F5C31),
        duration: Duration(seconds: 1),
      ),
    );
  }


  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}시간 전';
    } else {
      return '${timestamp.month}/${timestamp.day} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}
