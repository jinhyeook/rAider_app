import 'package:yolo_realtime_plugin/yolo_realtime_plugin.dart';
import 'package:flutter/material.dart';
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

class _DrivingPageState extends State<DrivingPage> {
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
    _initializeTts();
    _initializeDriving();
    _loadUserInfo();
    _startDetectionTimer();
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

  // 객체 이름을 한국어로 번역하는 함수
  String translateToKorean(String objectName) {
    switch (objectName.toLowerCase()) {
      case 'pothole':
        return '포트홀';
      case 'car':
        return '자동차';
      case 'person':
        return '사람';
      case 'animal':
        return '동물';
      case 'manhole':
        return '맨홀';
      case 'speed_bump':
        return '과속방지턱';
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
            content: Text('로그인이 필요합니다.'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pop(); // 현재 페이지 닫기
        return;
      }
      
      print('현재 사용자: $_userId');
      
      // SharedPreferences에서 선택된 기기 코드 가져오기
      _deviceCode = prefs.getString('selected_device_code') ?? '';
      
      if (_deviceCode.isEmpty) {
        // 선택된 기기가 없으면 사용 가능한 기기 목록에서 첫 번째 선택
        final availableDevices = await DeviceRentalService.getAvailableDevices();
        if (availableDevices.isNotEmpty) {
          _deviceCode = availableDevices.first['device_id'];
          print('자동 선택된 기기: $_deviceCode');
        } else {
          // 사용 가능한 기기가 없으면 오류 표시
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('사용 가능한 기기가 없습니다.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      } else {
        print('선택된 기기: $_deviceCode');
      }
      
      // 페이지 진입 시 자동으로 대여 시작
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startRental();
      });
    } catch (e) {
      print('사용자 정보 로드 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('기기 정보 로드 실패: $e'),
          backgroundColor: Colors.red,
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
      print('주행 모드 초기화 오류: $e');
    }
  }

  Future<void> _startRental() async {
    try {
      // 서버 연결 테스트
      print('서버 연결 테스트 시작...');
      bool isServerConnected = await DeviceRentalService.testConnection();
      print('서버 연결 상태: $isServerConnected');
      
      // 현재 위치 가져오기
      final position = await DeviceRentalService.getCurrentLocation();
      
      // 기기 대여 시작 (재시도 로직 포함)
      Map<String, dynamic> result = {};
      int retryCount = 0;
      const maxRetries = 3;
      
      while (retryCount < maxRetries) {
        try {
          print('대여 시작 시도 ${retryCount + 1}/$maxRetries');
          result = await DeviceRentalService.startRental(
            userId: _userId,
            deviceCode: _deviceCode,
            latitude: position.latitude,
            longitude: position.longitude,
          );
          print('대여 시작 성공: $result');
          break;
        } catch (e) {
          retryCount++;
          print('대여 시작 실패 (시도 $retryCount/$maxRetries): $e');
          if (retryCount >= maxRetries) {
            throw Exception('서버 연결 실패: $e');
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
      
      String message = '기기 대여가 시작되었습니다!';
      if (result['offline_mode'] == true) {
        message = '오프라인 모드로 대여가 시작되었습니다!';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('대여 시작 실패: $e'),
          backgroundColor: Colors.red,
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
      
      print('대여 종료 결과: $result'); // 디버깅용
      
      // 대여 종료 결과 표시
      _showRentalResult(result);
      
    } catch (e) {
      print('대여 종료 오류: $e'); // 디버깅용
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('대여 종료 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRentalResult(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('대여 종료'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('사용 시간: ${result['usage_minutes']}분'),
            Text('이동 거리: ${result['moved_distance']}km'),
            Text('요금: ${result['fee']}원'),
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
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
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
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('주행 모드'),
          backgroundColor: const Color(0xFF0F5C31),
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('주행 모드를 초기화하는 중...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('주행 모드'),
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
                  Text('대여 중', style: TextStyle(color: Colors.green)),
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
                          String koreanName = translateToKorean(object);
                          announcement += '$koreanName ';
                        }
                        if (announcement.isNotEmpty) {
                          flutterTts.speak('$announcement 감지');
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
                    child: Text('카메라를 초기화할 수 없습니다'),
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
                    const Text(
                      '카메라를 전방으로 향하게해 위험 요소를 탐지하세요!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F5C31),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _endRental,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '대여 종료하기',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '대여를 시작하는 중입니다...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F5C31),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    CircularProgressIndicator(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
