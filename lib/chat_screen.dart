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

  /// Initialize chatbot and check status
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
        _addErrorMessage(status['message'] ?? 'Failed to initialize chatbot.');
      }
    } catch (e) {
      setState(() {
        _isInitialized = false;
        _isLoading = false;
      });
      _addErrorMessage('Unable to connect to chatbot server.');
    }
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add(
        ChatMessage(
          text: '''Hello! I'm the rAider customer service chatbot :)
I can answer questions about the following topics:

• App development organization and team
• App development background
• Main app features
• Contact information for problem resolution

Feel free to ask me anything you're curious about!
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
          text: '$message\n\nPlease try again later.',
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
          content: Text('Chatbot is not yet initialized.'),
          backgroundColor: Colors.orange,
          duration: const Duration(milliseconds: 1500),
        ),
      );
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Add user message
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

    // Call RAG chatbot API
    final response = await _ragChatbotService.sendMessage(text);

    setState(() {
      _isLoading = false;
      _messages.add(
        ChatMessage(
          text: response['success'] 
              ? response['message'] 
              : 'Sorry, a temporary error occurred. Please try again.',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });

    // Notify user if error occurs
    if (!response['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message']),
          backgroundColor: Colors.red,
          duration: const Duration(milliseconds: 1500),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _initializeChatbot,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1200;
    final isDesktop = screenSize.width >= 1200;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'rAider Customer Service Chatbot',
          style: TextStyle(
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF0F5C31),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetChat,
            tooltip: 'Start new conversation',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status display bar
            if (!_isInitialized)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: isSmallScreen ? 6 : 8,
                  horizontal: isSmallScreen ? 12 : 16,
                ),
                color: Colors.orange[100],
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: Colors.orange,
                      size: isSmallScreen ? 14 : 16,
                    ),
                    SizedBox(width: isSmallScreen ? 6 : 8),
                    Expanded(
                      child: Text(
                        'Initializing chatbot...',
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontSize: isSmallScreen ? 12 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: _initializeChatbot,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 8 : 12,
                          vertical: isSmallScreen ? 4 : 8,
                        ),
                      ),
                      child: Text(
                        'Retry',
                        style: TextStyle(fontSize: isSmallScreen ? 10 : 12),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Chat message list
            Expanded(
              child: Container(
                constraints: isDesktop
                    ? BoxConstraints(
                        maxWidth: 800,
                        maxHeight: double.infinity,
                      )
                    : null,
                child: ListView.builder(
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                  itemCount: _messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length && _isLoading) {
                      return _buildLoadingMessage();
                    }
                    return _buildMessageBubble(_messages[index]);
                  },
                ),
              ),
            ),
            
            // Message input area
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
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
              child: Container(
                constraints: isDesktop
                    ? const BoxConstraints(maxWidth: 800)
                    : null,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        enabled: _isInitialized && !_isLoading,
                        decoration: InputDecoration(
                          hintText: _isInitialized 
                              ? 'Enter your message...' 
                              : 'Initializing chatbot...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              isSmallScreen ? 20 : 25,
                            ),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              isSmallScreen ? 20 : 25,
                            ),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              isSmallScreen ? 20 : 25,
                            ),
                            borderSide: const BorderSide(color: Color(0xFF0F5C31)),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 16 : 20,
                            vertical: isSmallScreen ? 10 : 12,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                        onSubmitted: (_) => _sendMessage(),
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                        ),
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 8 : 12),
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F5C31),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: (_isInitialized && !_isLoading) ? _sendMessage : null,
                        iconSize: isSmallScreen ? 20 : 24,
                        icon: _isLoading
                            ? SizedBox(
                                width: isSmallScreen ? 16 : 20,
                                height: isSmallScreen ? 16 : 20,
                                child: const CircularProgressIndicator(
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
      child: Row(
        mainAxisAlignment: message.isUser 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: isSmallScreen ? 28 : 32,
              height: isSmallScreen ? 28 : 32,
              decoration: const BoxDecoration(
                color: Color(0xFF0F5C31),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: isSmallScreen ? 18 : 20,
              ),
            ),
            SizedBox(width: isSmallScreen ? 6 : 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: screenSize.width * (isSmallScreen ? 0.75 : 0.7),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 12 : 16,
                vertical: isSmallScreen ? 10 : 12,
              ),
              decoration: BoxDecoration(
                color: message.isUser 
                    ? const Color(0xFF0F5C31)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 18).copyWith(
                  bottomLeft: message.isUser 
                      ? Radius.circular(isSmallScreen ? 16 : 18)
                      : const Radius.circular(4),
                  bottomRight: message.isUser 
                      ? const Radius.circular(4)
                      : Radius.circular(isSmallScreen ? 16 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : Colors.black87,
                      fontSize: isSmallScreen ? 14 : 16,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 3 : 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: message.isUser 
                          ? Colors.white70 
                          : Colors.grey[600],
                      fontSize: isSmallScreen ? 10 : 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            SizedBox(width: isSmallScreen ? 6 : 8),
            Container(
              width: isSmallScreen ? 28 : 32,
              height: isSmallScreen ? 28 : 32,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: isSmallScreen ? 18 : 20,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingMessage() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isSmallScreen ? 28 : 32,
            height: isSmallScreen ? 28 : 32,
            decoration: const BoxDecoration(
              color: Color(0xFF0F5C31),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.smart_toy,
              color: Colors.white,
              size: isSmallScreen ? 18 : 20,
            ),
          ),
          SizedBox(width: isSmallScreen ? 6 : 8),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12 : 16,
              vertical: isSmallScreen ? 10 : 12,
            ),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 18).copyWith(
                bottomLeft: const Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: isSmallScreen ? 16 : 20,
                  height: isSmallScreen ? 16 : 20,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F5C31)),
                  ),
                ),
                SizedBox(width: isSmallScreen ? 6 : 8),
                Text(
                  'Preparing response...',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: isSmallScreen ? 12 : 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Start new conversation (session reset)
  Future<void> _resetChat() async {
    await _ragChatbotService.resetSession();
    setState(() {
      _messages.clear();
    });
    _addWelcomeMessage();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Starting a new conversation.'),
        backgroundColor: Color(0xFF0F5C31),
        duration: Duration(seconds: 1),
      ),
    );
  }


  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
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
