import 'package:flutter/material.dart';
import 'package:untitled/report_mode.dart';
import 'device_rental.dart';
import 'startDrive.dart';
import 'auth_service.dart';
import 'main.dart';
import 'mypage.dart';

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
            // 두 번째 기능 버튼
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NaverMapApp(),
                  ),
                );
              },
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
