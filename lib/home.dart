import 'package:flutter/material.dart';
import 'package:untitled/report_mode.dart';
import 'device_rental.dart';
import 'startDrive.dart';
import 'auth_service.dart';
import 'main.dart';
import 'mypage.dart';
import 'device_service.dart';
import 'chat_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // 로그아웃 함수
  Future<void> _logout(BuildContext context) async {
    final authService = AuthService();
    await authService.logout();
    
    // 로그인 화면으로 이동
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      (route) => false,
    );
  }

  // 기기 대여 페이지로 이동
  Future<void> _navigateToDeviceRental(BuildContext context) async {
    try {
      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // DB에서 사용 가능한 기기 정보 가져오기
      final deviceService = DeviceService();
      final result = await deviceService.getAvailableDevices();
      
      // 로딩 다이얼로그 닫기
      Navigator.of(context).pop();
      
      if (result['success']) {
        final devices = List<Map<String, dynamic>>.from(result['devices']);
        
        if (devices.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NaverMapApp(),
            ),
          );
        } else {
          _showNoDevicesDialog(context);
        }
      } else {
        // DB 연결 실패 시
        _showErrorDialog(context, result['message'] ?? 'Failed to retrieve device information.');
      }
    } catch (e) {
      
      // 로딩 다이얼로그 닫기
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      // 오류 발생 시
      _showErrorDialog(context, 'A network error occurred. Please try again.\nError: $e');
    }
  }

  // 사용 가능한 기기가 없을 때 다이얼로그
  void _showNoDevicesDialog(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'No Available Devices',
          style: TextStyle(
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'There are currently no available devices.\nPlease try again later.',
          style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
            ),
          ),
        ],
      ),
    );
  }

  // 오류 다이얼로그
  void _showErrorDialog(BuildContext context, String message) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Error',
          style: TextStyle(
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
            ),
          ),
        ],
      ),
    );
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
          'rAider',
          style: TextStyle(
            fontSize: isSmallScreen ? 20 : 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            icon: Icon(
              Icons.logout,
              color: const Color(0xFF0F5C31),
              size: isSmallScreen ? 18 : 20,
            ),
            label: Text(
              'Logout',
              style: TextStyle(
                color: const Color(0xFF0F5C31),
                fontSize: isSmallScreen ? 12 : 14,
              ),
            ),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: isDesktop
                ? const BoxConstraints(maxWidth: 600)
                : null,
            padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'HOME',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 20 : (isTablet ? 22 : 24),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 40 : 50),
                // 첫 번째 기능 버튼 - 주행 시작
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // startDrive.dart에서 YoloRealTimeViewExample로 이동
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const YoloRealTimeViewExample(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 40 : 50,
                        vertical: isSmallScreen ? 12 : 15,
                      ),
                      backgroundColor: const Color(0xFF0F5C31),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Use Personal Device',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: isSmallScreen ? 16 : 20),
                // 두 번째 기능 버튼 - 기기 대여
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _navigateToDeviceRental(context),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 40 : 50,
                        vertical: isSmallScreen ? 12 : 15,
                      ),
                      backgroundColor: const Color(0xFF0F5C31),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Rent a Device',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: isSmallScreen ? 16 : 20),
                // 세 번째 기능 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // 기능 3 기능은 나중에 구현될 예정
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const YoloRealTimeViewReport(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 40 : 50,
                        vertical: isSmallScreen ? 12 : 15,
                      ),
                      backgroundColor: const Color(0xFF0F5C31),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Report',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: isSmallScreen ? 16 : 20),
                // 네 번째 기능 버튼 - 마이페이지
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyPageScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 40 : 50,
                        vertical: isSmallScreen ? 12 : 15,
                      ),
                      backgroundColor: const Color(0xFF0F5C31),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'My Page',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // 고객센터 챗봇 - 우하단 작은 원형 버튼
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ChatScreen(),
            ),
          );
        },
        backgroundColor: const Color(0xFF0F5C31),
        foregroundColor: Colors.white,
        tooltip: 'Customer Service Chatbot',
        icon: Icon(
          Icons.chat,
          size: isSmallScreen ? 16 : 18,
        ),
        label: Text(
          'Customer Service',
          style: TextStyle(
            fontSize: isSmallScreen ? 10 : 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
