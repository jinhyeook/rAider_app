import 'package:yolo_realtime_plugin/yolo_realtime_plugin.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
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
  
  @override
  void initState() {
    super.initState();
    _initializeDriving();
    _loadUserInfo();
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
      fullClasses: ["pothole", "car", "person", "animal"],
      activeClasses: ["pothole", "car", "person", "animal"],
      androidModelPath: 'assets/yolov5s_320_drive.pt',
      androidModelWidth: 320,
      androidModelHeight: 320,
      androidConfThreshold: 0.5,
      androidIouThreshold: 0.5,
      iOSModelPath: 'yolov5s',
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
      bool isServerConnected = await DeviceRentalService.testConnection();
      
      // 현재 위치 가져오기
      final position = await DeviceRentalService.getCurrentLocation();
      
      // 기기 대여 시작
      final result = await DeviceRentalService.startRental(
        userId: _userId,
        deviceCode: _deviceCode,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      
      setState(() {
        _isRentalStarted = true;
        _rentalId = result['rental_id'];
      });
      
      // 실시간 위치 추적 시작 (항상 시작 - 오프라인 모드여도 위치 추적은 필요)
      LocationService.startLocationTracking(
        userId: _userId,
        deviceCode: _deviceCode,
      );
      
      String message = result['offline_mode'] == true 
          ? '오프라인 모드로 대여가 시작되었습니다!'
          : '기기 대여가 시작되었습니다!';
      
      if (!isServerConnected) {
        message += '\n(서버 연결 실패 - 오프라인 모드)';
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
        title: Text(result['offline_mode'] == true ? '대여 종료 (오프라인)' : '대여 종료'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result['offline_mode'] == true) ...[
              const Text('오프라인 모드로 동작했습니다.', 
                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
            ],
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
                      // 전방 탐지 로직
                    },
                    captureImage: (data) async {
                      // 이미지 캡처 로직
                    },
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
                      '안전한 주행을 위해 전방을 주시하세요',
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
