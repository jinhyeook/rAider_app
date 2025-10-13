import 'package:yolo_realtime_plugin/yolo_realtime_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/device_rental_service.dart';
import 'services/location_service.dart';
import 'home.dart';
import 'driving_page.dart';

class HelmetDetectionPage extends StatefulWidget {
  const HelmetDetectionPage({Key? key}) : super(key: key);

  @override
  State<HelmetDetectionPage> createState() => _HelmetDetectionPageState();
}

class _HelmetDetectionPageState extends State<HelmetDetectionPage> {
  YoloRealtimeController? yoloController;
  bool _isHelmetDetected = false;
  bool _isInitialized = false;
  String _detectionStatus = 'Please wear a helmet';
  Color _statusColor = Colors.orange;
  
  // 탐지 간격 제어
  DateTime? _lastDetectionTime;
  final Duration _detectionInterval = const Duration(seconds: 5);
  
  

  @override
  void initState() {
    super.initState();
    _initializeHelmetDetection();
  }

  Future<void> _initializeHelmetDetection() async {
    yoloController = YoloRealtimeController(
      // 헬멧 검사용 클래스만 활성화
      fullClasses: ['nohelmet', 'helmet'],
      activeClasses: ['nohelmet', 'helmet'],

      // 안드로이드 설정 - 모델 입력 사이즈에 맞춤
      androidModelPath: 'assets/yolov5s_320_helmet.pt',
      androidModelWidth: 320, // 모델 입력 사이즈에 맞춤
      androidModelHeight: 320,
      androidConfThreshold: 0.6, // 신뢰도 임계값
      androidIouThreshold: 0.4, // IoU 임계값 조정

      // iOS 설정
      iOSModelPath: 'assets/yolov5s_320_helmet.pt',
      iOSConfThreshold: 0.7,
    );

    try {
      await yoloController?.initialize();
      setState(() {
        _isInitialized = true;
      });
      
    } catch (e) {
      print('Helmet detection model initialization error: $e');
      setState(() {
        _detectionStatus = 'Model initialization failed';
        _statusColor = Colors.red;
      });
    }
  }


  void _onDetectionResult(dynamic boxes) {
    // 5초 간격으로만 탐지 결과 처리
    final now = DateTime.now();
    if (_lastDetectionTime != null && 
        now.difference(_lastDetectionTime!) < _detectionInterval) {
      return; // 5초가 지나지 않았으면 처리하지 않음
    }
    _lastDetectionTime = now;
    
    print('Helmet detection performed (5-second interval)');
    
    bool currentDetection = false;
    
    if (boxes.isNotEmpty) {
      print('Number of detected boxes: ${boxes.length}'); // 디버깅
      
      // 헬멧 착용 여부 확인 - 단순화된 로직
      bool helmetFound = false;
      bool noHelmetFound = false;
      double maxConfidence = 0.0;
      String detectedLabel = '';

      for (final box in boxes) {
        print('Box info: label=${box.label}, confidence=${box.confidence}'); // 디버깅
        
        // 신뢰도가 높은 감지만 고려 (임계값 상향)
        if (box.confidence > 0.7) {
          
          if (box.label == 'helmet') {
            helmetFound = true;
            if (box.confidence > maxConfidence) {
              maxConfidence = box.confidence;
              detectedLabel = 'helmet';
            }
            print('Helmet detected: confidence=${box.confidence}');
          } else if (box.label == 'nohelmet') {
            noHelmetFound = true;
            if (box.confidence > maxConfidence) {
              maxConfidence = box.confidence;
              detectedLabel = 'nohelmet';
            }
            print('No helmet detected: confidence=${box.confidence}');
          }
        } else {
          print('Confidence too low: ${box.confidence}');
        }
      }

      // 탐지 결과 결정 (엄격한 검증)
      if (helmetFound && !noHelmetFound) {
        currentDetection = true;
        _detectionStatus = 'Helmet wearing detected...';
        _statusColor = Colors.blue;
        print('Helmet wearing detected');
      } else if (noHelmetFound && !helmetFound) {
        currentDetection = false;
        _detectionStatus = 'No helmet detected...';
        _statusColor = Colors.red;
        print('No helmet detected');
      } else if (helmetFound && noHelmetFound) {
        // 둘 다 감지된 경우 - 신뢰도가 높은 것으로 판단
        currentDetection = (detectedLabel == 'helmet');
        _detectionStatus = currentDetection ? 'Helmet wearing detected...' : 'No helmet detected...';
        _statusColor = currentDetection ? Colors.blue : Colors.red;
        print('Mixed detection: ${detectedLabel} selected');
      } else {
        // 불명확한 감지
        currentDetection = false;
        _detectionStatus = 'Please center your face in the camera';
        _statusColor = Colors.orange;
        print('No valid detection');
      }
    } else {
      currentDetection = false;
      _detectionStatus = 'Please center your face in the camera';
      _statusColor = Colors.orange;
      print('No boxes detected');
    }
    
    // 즉시 탐지 결과 반영
    setState(() {
      _isHelmetDetected = currentDetection;
      if (currentDetection) {
        _detectionStatus = 'Helmet wearing confirmed!';
        _statusColor = Colors.green;
      } else {
        _detectionStatus = 'Please wear a helmet';
        _statusColor = Colors.red;
      }
    });
  }


  void _proceedToNextPage() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const HelmetSuccessPage(),
      ),
    );
  }

  // 뒤로가기 버튼 처리
  Future<bool> _handleBackButton() async {
    final shouldPop = await _showExitConfirmationDialog();
    return shouldPop ?? false;
  }

  // 종료 확인 다이얼로그
  Future<bool?> _showExitConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Exit Helmet Check'),
          content: const Text('Do you want to exit the helmet check?\nHelmet wearing is required for safe driving.'),
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

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                SizedBox(height: isSmallScreen ? 16 : 20),
                Text(
                  'Initializing helmet detection model...',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    color: Colors.white,
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
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 전면 카메라 - 1:1 비율로 모델 입력과 일치, -90도 회전
            Positioned.fill(
              child: yoloController != null
                  ? Center(
                      child: AspectRatio(
                        aspectRatio: 1, // 1:1 비율로 모델 입력과 일치
                        child: Container(
                          width: MediaQuery.of(context).size.width,
                          child: Transform.rotate(
                            angle: 0.0, // 헬멧 모델은 회전 없음
                            child: YoloRealTimeView(
                              width: MediaQuery.of(context).size.width,
                              height: MediaQuery.of(context).size.width, // 1:1 비율 유지
                              controller: yoloController!,
                              drawBox: true, // 바운딩 박스 출력 활성화
                              captureBox: (boxes) {
                                _onDetectionResult(boxes);
                              },
                            ),
                          ),
                        ),
                      ),
                    )
                  : const Center(
                      child: Text(
                        'Cannot initialize camera',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
            ),
          
            // 얼굴 가이드라인 오버레이 - 1:1 비율로 모델과 일치
            Positioned.fill(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1, // 1:1 비율로 모델과 일치
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withOpacity(0.8),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        // 상단 가이드라인
                        Container(
                          height: 1,
                          color: Colors.white.withOpacity(0.6),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              // 좌측 가이드라인
                              Container(
                                width: 1,
                                color: Colors.white.withOpacity(0.6),
                              ),
                              Expanded(child: Container()),
                              // 우측 가이드라인
                              Container(
                                width: 1,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ],
                          ),
                        ),
                        // 하단 가이드라인
                        Container(
                          height: 1,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          
            // 상단 안내 텍스트
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Please center your face in the guideline\nPoint the camera straight ahead',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          
          // 하단 상태 표시 (팝업식)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 드래그 핸들
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // 상태 표시
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          _isHelmetDetected ? Icons.check_circle : Icons.warning,
                          size: 40,
                          color: _statusColor,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _detectionStatus,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _statusColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Detection interval: 5 seconds',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        
                        // 다음 단계 버튼 (헬멧 착용 시에만 활성화)
                        if (_isHelmetDetected)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _proceedToNextPage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F5C31),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Proceed to Next Step',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _statusColor),
                            ),
                            child: Text(
                              'Please wear a helmet and point your face at the camera',
                              style: TextStyle(
                                color: _statusColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
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
}

// 헬멧 검사 성공 페이지
class HelmetSuccessPage extends StatelessWidget {
  const HelmetSuccessPage({super.key});

  // 뒤로가기 버튼 처리
  Future<bool> _handleBackButton() async {
    // 성공 페이지에서는 뒤로가기를 허용하지 않음
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    return WillPopScope(
      onWillPop: _handleBackButton,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Helmet Check Complete',
            style: TextStyle(
              fontSize: isSmallScreen ? 18 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color(0xFF0F5C31),
          foregroundColor: Colors.white,
          centerTitle: true,
          automaticallyImplyLeading: false, // 뒤로가기 버튼 비활성화
        ),
        body: SafeArea(
          child: Center(
            child: Container(
              constraints: screenSize.width >= 1200
                  ? const BoxConstraints(maxWidth: 600)
                  : null,
              padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: isSmallScreen ? 80 : 100,
                    color: Colors.green,
                  ),
                  SizedBox(height: isSmallScreen ? 16 : 20),
                  Text(
                    'Helmet wearing confirmed!',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F5C31),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isSmallScreen ? 8 : 10),
                  Text(
                    'Thank you for wearing a helmet for safe driving.',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isSmallScreen ? 24 : 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        // 헬멧 인증 완료 후 바로 주행 모드로 이동 (대여 시작 포함)
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DrivingPage(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F5C31),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 24 : 30,
                          vertical: isSmallScreen ? 12 : 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Start Driving',
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
      ),
    );
  }
}

