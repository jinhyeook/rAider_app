import 'package:flutter/material.dart';
import 'package:untitled/report_mode.dart';
import 'device_rental.dart';
import 'startDrive.dart';
import 'auth_service.dart';
import 'main.dart';
import 'mypage.dart';
import 'device_service.dart';

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

  // 기기 대여 페이지로 이동 (DB에서 기기 정보 먼저 가져오기)
  Future<void> _navigateToDeviceRental(BuildContext context) async {
    try {
      print('기기 대여 페이지 이동 시작');
      
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
      
      print('기기 목록 조회 결과: $result');
      
      // 로딩 다이얼로그 닫기
      Navigator.of(context).pop();
      
      if (result['success']) {
        final devices = List<Map<String, dynamic>>.from(result['devices']);
        print('조회된 기기 수: ${devices.length}');
        
        if (devices.isNotEmpty) {
          // 기기가 있으면 지도 페이지로 이동
          print('지도 페이지로 이동');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NaverMapApp(),
            ),
          );
        } else {
          // 사용 가능한 기기가 없을 때
          print('사용 가능한 기기 없음');
          _showNoDevicesDialog(context);
        }
      } else {
        // DB 연결 실패 시
        print('DB 연결 실패: ${result['message']}');
        _showErrorDialog(context, result['message'] ?? '기기 정보를 가져오는데 실패했습니다.');
      }
    } catch (e) {
      print('오류 발생: $e');
      
      // 로딩 다이얼로그 닫기
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      // 오류 발생 시
      _showErrorDialog(context, '네트워크 오류가 발생했습니다. 다시 시도해주세요.\n오류: $e');
    }
  }

  // 사용 가능한 기기가 없을 때 다이얼로그
  void _showNoDevicesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사용 가능한 기기 없음'),
        content: const Text('현재 사용 가능한 기기가 없습니다.\n잠시 후 다시 시도해주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  // 오류 다이얼로그
  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('오류'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('rAider'),
        centerTitle: true,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.logout, color: Color(0xFF0F5C31)),
            label: const Text(
              'logout',
              style: TextStyle(color: Color(0xFF0F5C31)),
            ),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'HOME',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 50),
            // 첫 번째 기능 버튼 - 주행 시작
            ElevatedButton(
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
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                backgroundColor: Color(0xFF0F5C31),
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 50),
              ),
              child: const Text('Use personal device', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 20),
            // 두 번째 기능 버튼 - 기기 대여
            ElevatedButton(
              onPressed: () => _navigateToDeviceRental(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                backgroundColor: Color(0xFF0F5C31),
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 50),
              ),
              child: const Text('Rent a device', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 20),
            // 세 번째 기능 버튼
            ElevatedButton(
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
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                backgroundColor: Color(0xFF0F5C31),
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 50),
              ),
              child: const Text('Report', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 20),
            // 네 번째 기능 버튼 - 마이페이지
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyPageScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                backgroundColor: Color(0xFF0F5C31),
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 50),
              ),
              child: const Text('My Page', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
