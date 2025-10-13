import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'login.dart';
import 'signup.dart';
import 'home.dart';
import 'auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // FlutterNaverMap 초기화
  final naverMapSdk = FlutterNaverMap();
  await naverMapSdk.init(
    clientId: 'by4fsilwbn',
    onAuthFailed: (error) {
      // 네이버맵 인증 실패 처리
    },
  );

  // 사용자 인증 상태 로드
  await AuthService().loadUserData();
  
  // 인증 상태 검증은 백그라운드에서만 수행 (자동 로그아웃 방지)
  if (AuthService().isLoggedIn) {
    print('사용자 로그인 상태 확인됨 - 백그라운드에서 인증 상태 검증 중...');
    // 백그라운드에서 인증 상태 검증 (앱 시작 속도에 영향 없도록)
    AuthService().validateAuthState().then((isValid) {
      if (!isValid) {
        print('인증 상태 검증 실패 (로그아웃하지 않음)');
      } else {
        print('인증 상태 검증 성공');
      }
    });
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('앱 생명주기 상태 변경: $state');
    
    switch (state) {
      case AppLifecycleState.resumed:
        // 앱이 포그라운드로 돌아올 때 사용자 데이터 다시 로드
        print('앱이 포그라운드로 복원됨 - 사용자 데이터 재로드');
        AuthService().loadUserData();
        
        // 인증 상태 재검증은 앱 시작 시에만 수행 (자동 로그아웃 방지)
        // 기기 대여 중이거나 일반적인 앱 전환에서는 검증하지 않음
        break;
      case AppLifecycleState.paused:
        // 앱이 백그라운드로 갈 때
        print('앱이 백그라운드로 이동');
        break;
      case AppLifecycleState.detached:
        // 앱이 완전히 종료될 때 정리 작업
        print('앱이 완전히 종료됨 - 정리 작업 수행');
        _cleanupResources();
        break;
      case AppLifecycleState.inactive:
        // 앱이 비활성 상태일 때
        print('앱이 비활성 상태');
        break;
      case AppLifecycleState.hidden:
        // 앱이 숨겨진 상태일 때
        print('앱이 숨겨진 상태');
        break;
    }
  }

  void _cleanupResources() {
    // Flutter 엔진 정리
    WidgetsBinding.instance.removeObserver(this);
  }

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

  /// 앱 종료 확인 다이얼로그
  void _showExitDialog(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Exit App',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F5C31),
              fontSize: isSmallScreen ? 18 : 20,
            ),
          ),
          content: Text(
            'Are you sure you want to exit the app?',
            style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 다이얼로그 닫기
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: isSmallScreen ? 14 : 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // 다이얼로그 닫기
                SystemNavigator.pop(); // 앱 종료
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 16 : 20,
                  vertical: isSmallScreen ? 8 : 12,
                ),
              ),
              child: Text(
                'Exit',
                style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
              ),
            ),
          ],
        );
      },
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
              children: <Widget>[
                Text(
                  'rAider',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 28 : (isTablet ? 32 : 36),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F5C31),
                  ),
                ),
                SizedBox(height: isSmallScreen ? 20 : 30),
                Divider(
                  color: Colors.grey,
                  thickness: 1.5,
                  indent: isSmallScreen ? 30 : 50,
                  endIndent: isSmallScreen ? 30 : 50,
                  height: isSmallScreen ? 20 : 30,
                ),
                SizedBox(height: isSmallScreen ? 20 : 30),
                Text(
                  'Personal Mobility Safety Support',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : (isTablet ? 20 : 24),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 40 : 50),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
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
                      'Login',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: isSmallScreen ? 16 : 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SignupScreen()),
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
                      'Sign Up',
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showExitDialog(context);
        },
        backgroundColor: Colors.red[600],
        foregroundColor: Colors.white,
        mini: isSmallScreen,
        tooltip: 'Exit App',
        child: Icon(
          Icons.power_settings_new,
          size: isSmallScreen ? 18 : 20,
        ),
      ),
    );
  }
}