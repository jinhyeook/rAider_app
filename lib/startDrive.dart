
// 무시: prefer_const_constructors

import 'package:yolo_realtime_plugin/yolo_realtime_plugin.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

class YoloRealTimeViewExample extends StatefulWidget {
  const YoloRealTimeViewExample({Key? key}) : super(key: key);

  @override
  State<YoloRealTimeViewExample> createState() =>
      _YoloRealTimeViewExampleState();
}

class _YoloRealTimeViewExampleState extends State<YoloRealTimeViewExample> {
  YoloRealtimeController? yoloController;
  // 참고: 'flutter pub get' 실행 후, 다음 줄들의 주석을 해제하세요:
  late FlutterTts flutterTts;
  Timer? _detectionTimer;
  bool _isDetectionEnabled = true;

  @override
  void initState() {
    super.initState();

    // // 텍스트 음성 변환 초기화
    flutterTts = FlutterTts();
    flutterTts.setLanguage("ko-KR"); // 한국어
    flutterTts.setSpeechRate(0.5); // 명확성을 위한 느린 발화 속도
    flutterTts.setVolume(1.0); // 최대 볼륨

    yoloInit();
    _startDetectionTimer();
  }

  Future<void> yoloInit() async {
    yoloController = YoloRealtimeController(
      // 공통
      fullClasses: fullClasses,
      activeClasses: activeClasses,

      // 안드로이드
      androidModelPath: 'assets/yolov5s_320_detect.pt',
      // androidModelPath: 'assets/yolov5s_320_drive.pt',
      androidModelWidth: 320,
      androidModelHeight: 320,
      androidConfThreshold: 0.7,
      androidIouThreshold: 0.3,
      iOSModelPath: 'assets/yolov5s_320_detect.pt',
      iOSConfThreshold: 0.5,
    );

    try {
      await yoloController?.initialize();
    } catch (e) {
      print('ERROR: $e');
    }
  }

  void _startDetectionTimer() {
    _detectionTimer = Timer.periodic(const Duration(seconds:3), (timer) { // 초 설정
      setState(() {
        _isDetectionEnabled = true;
      }); 
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    if (yoloController == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                SizedBox(height: isSmallScreen ? 16 : 20),
                Text(
                  'Initializing camera...',
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
      onWillPop: () async {
        // 뒤로가기 버튼이 눌렸을 때 확인 다이얼로그 표시
        final shouldPop = await _showExitConfirmationDialog();
        return shouldPop ?? false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Personal Driving Mode',
            style: TextStyle(
              fontSize: isSmallScreen ? 18 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.green,
          automaticallyImplyLeading: false,
        ),
      body: Stack(
        children: [
          // 카메라 뷰 (전체 화면)
          YoloRealTimeView(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height - AppBar().preferredSize.height,
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
              // 필요한 경우 객체 이름을 한국어로 번역
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
        captureImage: (data) async {
          // print('이진 이미지: $data');

          /// 원하는 대로 이진 이미지를 처리하고 사용하세요.
          // imageToFile(data);
        },
          ),
          // 팝업 스타일 안내 문구
          Positioned(
            bottom: 100, // 홈 버튼 위쪽에 위치
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                '카메라를 전방으로 향하게해 위험 요소를 탐지하세요!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context);
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.home, color: Colors.white),
        tooltip: '홈으로 돌아가기',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  // 종료 확인 다이얼로그
  Future<bool?> _showExitConfirmationDialog() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Exit Personal Driving Mode',
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Do you want to exit personal driving mode?',
            style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
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


  List<String> activeClasses = [
    "pothole",
    "car",
    "person",
    "animal",
    "manhole",
    "speed_bump"
  ];

  List<String> fullClasses = [
    "pothole",
    "car",
    "person",
    "animal",
    "manhole",
    "speed_bump"
  ];

  // 객체 이름을 영어로 번역하는 함수
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

  @override
  void dispose() {
    // 타이머 정리
    _detectionTimer?.cancel();
    // FlutterTts 정리
    flutterTts.stop();
    super.dispose();
  }
}
