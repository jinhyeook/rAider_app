import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'login.dart';
import 'signup.dart';
import 'home.dart';
import 'auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // FlutterNaverMap 초기화 (인스턴스로)
  final naverMapSdk = FlutterNaverMap();
  await naverMapSdk.init(
    clientId: 'by4fsilwbn',
    onAuthFailed: (error) {
      print('네이버맵 인증 실패: $error');
    },
  );

  // 사용자 인증 상태 로드
  await AuthService().loadUserData();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'rAider App',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: AuthService().isLoggedIn ? const HomeScreen() : const WelcomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('rAider'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'rAider',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F5C31),
              ),
            ),
            const Divider(
              color: Colors.grey,
              thickness: 1.5,
              indent: 50,
              endIndent: 50,
              height: 30,
            ),
            const Text(
              'Personal Mobility Safety Support',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 50),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                backgroundColor: Color(0xFF0F5C31),
                foregroundColor: Colors.white,
              ),
              child: const Text('Login', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SignupScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                backgroundColor: Color(0xFF0F5C31),
                foregroundColor: Colors.white,
              ),
              child: const Text('Sign Up', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}