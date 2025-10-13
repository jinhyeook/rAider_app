import 'package:yolo_realtime_plugin/yolo_realtime_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'services/device_rental_service.dart';
import 'services/location_service.dart';
import 'home.dart';

// 주행 페이지 (기기 대여 기능 포함)
class DrivingPage extends StatefulWidget {
  const DrivingPage({Key? key}) : super(key: key);

  @override
  State<DrivingPage> createState() => _DrivingPageState();
}

class _DrivingPageState extends State<DrivingPage> with WidgetsBindingObserver {
  YoloRealtimeController? yoloController;
  bool _isRentalStarted = false;
  bool _isInitialized = false;
  String? _rentalId;
  String _userId = '';
  String _deviceCode = '';
  
  // 음성 피드백을 위한 변수들
  late FlutterTts flutterTts;
  Timer? _detectionTimer;
  bool _isDetectionEnabled = true;
  
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeTts();
    _initializeDriving();
    _loadUserInfo();
    _startDetectionTimer();
    _setupBackButtonHandler();
  }

  // FlutterTts 초기화
  Future<void> _initializeTts() async {
    flutterTts = FlutterTts();
    await flutterTts.setLanguage("ko-KR"); // 한국어
    await flutterTts.setSpeechRate(0.5); // 명확성을 위한 느린 발화 속도
    await flutterTts.setVolume(1.0); // 최대 볼륨
  }

 
  void _startDetectionTimer() {
    _detectionTimer = Timer.periodic(const Duration(seconds: 3), (timer) { // 초 설정
      setState(() {
        _isDetectionEnabled = true;
      });
    });
  }

  // 객체 이름을 영어로 표시하는 함수
  String translateToEnglish(String objectName) {
    switch (objectName.toLowerCase()) {
      case 'pothole':
        return 'Pothole';
      case 'car':
        return 'Car';
      case 'person':
        return 'Person';
      case 'animal':
        return 'Animal';
      case 'manhole':
        return 'Manhole';
      case 'speed_bump':
        return 'Speed Bump';
      default:
        return objectName;
    }
  }

  Future<void> _loadUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('user_id') ?? '';
      
      // 사용자 ID가 없으면 로그인 페이지로 이동
      if (_userId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login required.'),
            backgroundColor: Colors.red,
            duration: Duration(milliseconds: 1500),
          ),
        );
        Navigator.of(context).pop(); // 현재 페이지 닫기
        return;
      }
      
      print('Current user: $_userId');
      
      // SharedPreferences에서 선택된 기기 코드 가져오기
      _deviceCode = prefs.getString('selected_device_code') ?? '';
      
      if (_deviceCode.isEmpty) {
        // 선택된 기기가 없으면 사용 가능한 기기 목록에서 첫 번째 선택
        final availableDevices = await DeviceRentalService.getAvailableDevices();
        if (availableDevices.isNotEmpty) {
          _deviceCode = availableDevices.first['device_id'];
          print('Auto-selected device: $_deviceCode');
        } else {
          // 사용 가능한 기기가 없으면 오류 표시
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No available devices.'),
              backgroundColor: Colors.red,
              duration: Duration(milliseconds: 1500),
            ),
          );
          return;
        }
      } else {
        print('Selected device: $_deviceCode');
      }
      
      // 페이지 진입 시 자동으로 대여 시작
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startRental();
      });
    } catch (e) {
      print('User info load error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Device info load failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }
  }

  Future<void> _initializeDriving() async {
    yoloController = YoloRealtimeController(
      fullClasses: ["pothole", "car", "person", "animal", "manhole", "speed_bump"],
      activeClasses: ["pothole", "car", "person", "animal", "manhole", "speed_bump"],
      androidModelPath: 'assets/yolov5s_320_detect.pt',
      //androidModelPath: 'assets/yolov5s_320_drive.pt',
      androidModelWidth: 320,
      androidModelHeight: 320,
      androidConfThreshold: 0.7,
      androidIouThreshold: 0.3,
      iOSModelPath: 'assets/yolov5s_320_detect.pt',
      iOSConfThreshold: 0.5,
    );

    try {
      await yoloController?.initialize();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Driving mode initialization error: $e');
    }
  }

  Future<void> _startRental() async {
    try {
      // 서버 연결 테스트
      print('Starting server connection test...');
      bool isServerConnected = await DeviceRentalService.testConnection();
      print('Server connection status: $isServerConnected');
      
      // 현재 위치 가져오기
      final position = await DeviceRentalService.getCurrentLocation();
      
      // 기기 대여 시작 (재시도 로직 포함)
      Map<String, dynamic> result = {};
      int retryCount = 0;
      const maxRetries = 3;
      
      while (retryCount < maxRetries) {
        try {
          print('Rental start attempt ${retryCount + 1}/$maxRetries');
          result = await DeviceRentalService.startRental(
            userId: _userId,
            deviceCode: _deviceCode,
            latitude: position.latitude,
            longitude: position.longitude,
          );
          print('Rental start success: $result');
          break;
        } catch (e) {
          retryCount++;
          print('Rental start failed (attempt $retryCount/$maxRetries): $e');
          if (retryCount >= maxRetries) {
            throw Exception('Server connection failed: $e');
          }
          await Future.delayed(const Duration(seconds: 2)); // 2초 대기 후 재시도
        }
      }
      
      setState(() {
        _isRentalStarted = true;
        _rentalId = result['rental_id'];
      });
      
      // 실시간 위치 추적 시작 (항상 시작 - 오프라인 모드여도 위치 추적은 필요)
      LocationService.startLocationTracking(
        userId: _userId,
        deviceCode: _deviceCode,
      );
      
      String message = 'Device rental has started!';
      if (result['offline_mode'] == true) {
        message = 'Rental started in offline mode!';
      }
      
      // 기존 SnackBar 제거 후 성공 메시지 표시
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rental start failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }
  }

  Future<void> _endRental() async {
    try {
      // 현재 위치 가져오기
      final position = await DeviceRentalService.getCurrentLocation();
      
      // 기기 대여 종료
      final result = await DeviceRentalService.endRental(
        userId: _userId,
        deviceCode: _deviceCode,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      
      // 실시간 위치 추적 중지
      LocationService.stopLocationTracking();
      
      setState(() {
        _isRentalStarted = false;
        _rentalId = null;
      });
      
      print('Rental end result: $result'); // 디버깅용
      
      // 대여 종료 결과 표시
      _showRentalResult(result);
      
    } catch (e) {
      print('Rental end error: $e'); // 디버깅용
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rental end failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }
  }

  void _showRentalResult(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rental End'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Usage time: ${result['usage_minutes']} minutes'),
            Text('Distance: ${result['moved_distance']} km'),
            Text('Fee: ${result['fee']} won'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // 다이얼로그 닫기
              
              // 모든 페이지를 제거하고 홈 화면으로 이동
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false, // 모든 이전 라우트 제거
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // 뒤로가기 버튼 처리 설정
  void _setupBackButtonHandler() {
    // WillPopScope를 사용하므로 여기서는 빈 구현
  }

  // 뒤로가기 버튼 처리
  Future<bool> _handleBackButton() async {
    if (_isRentalStarted) {
      // 대여가 진행 중이면 종료 확인 다이얼로그 표시
      final shouldEnd = await _showExitConfirmationDialog();
      if (shouldEnd == true) {
        await _endRental();
        return true; // 뒤로가기 허용
      }
      return false; // 뒤로가기 차단
    } else {
      // 대여가 시작되지 않았으면 그냥 종료 허용
      return true;
    }
  }

  // 종료 확인 다이얼로그
  Future<bool?> _showExitConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('End Device Rental'),
          content: const Text('Do you want to end the device rental?\nFees will be calculated upon exit.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );
  }

  // 앱 상태 변경 감지 (홈버튼 등)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused && _isRentalStarted) {
      // 앱이 백그라운드로 갈 때 (홈버튼 등)
      _showAppPausedDialog();
    }
  }

  // 앱 일시정지 다이얼로그
  void _showAppPausedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('App Paused'),
          content: const Text('You cannot exit the app during device rental.\nPlease return to the app.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // 앱을 다시 포그라운드로 가져오기
                SystemChannels.platform.invokeMethod('SystemNavigator.pop');
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    // 페이지를 벗어날 때 위치 추적 중지
    if (_isRentalStarted) {
      LocationService.stopLocationTracking();
    }
    // 타이머 정리
    _detectionTimer?.cancel();
    // FlutterTts 정리
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Driving Mode',
            style: TextStyle(
              fontSize: isSmallScreen ? 18 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color(0xFF0F5C31),
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                SizedBox(height: isSmallScreen ? 16 : 20),
                Text(
                  'Initializing driving mode...',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: _handleBackButton,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Driving Mode',
            style: TextStyle(
              fontSize: isSmallScreen ? 18 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color(0xFF0F5C31),
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          actions: [
            if (_isRentalStarted)
              Container(
                margin: const EdgeInsets.only(right: 16),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on, color: Colors.green),
                    SizedBox(width: 4),
                    Text('Renting', style: TextStyle(color: Colors.green)),
                  ],
                ),
              ),
          ],
        ),
      body: Stack(
        children: [
          // 카메라 뷰 (전체 화면)
          Positioned.fill(
            child: yoloController != null
                ? YoloRealTimeView(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                    controller: yoloController!,
                    drawBox: true,
                    captureBox: (boxes) {
                      if (boxes.isNotEmpty && _isDetectionEnabled) {
                        // 박스에서 객체 이름 추출
                        final Set<String> detectedObjects = boxes
                            .map((box) => box.label)
                            .toSet();

                        // 안내 텍스트 생성
                        String announcement = '';

                        // 감지된 객체를 안내에 추가
                        for (final object in detectedObjects) {
                          String englishName = translateToEnglish(object);
                          announcement += '$englishName ';
                        }
                        if (announcement.isNotEmpty) {
                          flutterTts.speak('$announcement detected');
                          // 탐지 후 비활성화 (10초 후 다시 활성화됨)
                          setState(() {
                            _isDetectionEnabled = false;
                          });
                        }
                      }
                    },
                    captureImage: null, // 메모리 절약을 위해 비활성화
                  )
                : const Center(
                    child: Text('Cannot initialize camera'),
                  ),
          ),
          
          // 대여 종료 버튼 (하단 팝업)
          if (_isRentalStarted)
            Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Point the camera forward to detect hazards!',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F5C31),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: isSmallScreen ? 12 : 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _endRental,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: isSmallScreen ? 12 : 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'End Rental',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 16 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // 대여 시작 중일 때 로딩 표시
          if (!_isRentalStarted)
            Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Starting rental...',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F5C31),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: isSmallScreen ? 12 : 16),
                    const CircularProgressIndicator(),
                  ],
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }
}
