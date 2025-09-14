import 'package:yolo_realtime_plugin/yolo_realtime_plugin.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class HelmetDetectionPage extends StatefulWidget {
  const HelmetDetectionPage({Key? key}) : super(key: key);

  @override
  State<HelmetDetectionPage> createState() => _HelmetDetectionPageState();
}

class _HelmetDetectionPageState extends State<HelmetDetectionPage> {
  YoloRealtimeController? yoloController;
  bool _isHelmetDetected = false;
  bool _isInitialized = false;
  String _detectionStatus = '헬멧을 착용해주세요';
  Color _statusColor = Colors.orange;

  @override
  void initState() {
    super.initState();
    _initializeHelmetDetection();
  }

  Future<void> _initializeHelmetDetection() async {
    yoloController = YoloRealtimeController(
      // 헬멧 검사용 클래스만 활성화
      fullClasses: ['no_helmet', 'helmet'],
      activeClasses: ['no_helmet', 'helmet'],

      // 안드로이드 설정
      androidModelPath: 'assets/helmet_yolov5s_320_1.pt',
      androidModelWidth: 320,
      androidModelHeight: 320,
      androidConfThreshold: 0.5,
      androidIouThreshold: 0.5,

      // iOS 설정
      iOSModelPath: 'helmet_yolov5s_320_1',
      iOSConfThreshold: 0.5,
    );

    try {
      await yoloController?.initialize();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('헬멧 검사 모델 초기화 오류: $e');
      setState(() {
        _detectionStatus = '모델 초기화 실패';
        _statusColor = Colors.red;
      });
    }
  }

  void _onDetectionResult(dynamic boxes) {
    if (boxes.isNotEmpty) {
      // 헬멧 착용 여부 확인
      bool helmetFound = false;
      bool noHelmetFound = false;

      for (final box in boxes) {
        if (box.label == 'helmet') {
          helmetFound = true;
        } else if (box.label == 'no_helmet') {
          noHelmetFound = true;
        }
      }

      setState(() {
        if (helmetFound && !noHelmetFound) {
          // 헬멧 착용 감지
          _isHelmetDetected = true;
          _detectionStatus = '헬멧 착용 확인됨!';
          _statusColor = Colors.green;
        } else if (noHelmetFound) {
          // 헬멧 미착용 감지
          _isHelmetDetected = false;
          _detectionStatus = '헬멧을 착용해주세요';
          _statusColor = Colors.red;
        } else {
          // 불명확한 감지
          _isHelmetDetected = false;
          _detectionStatus = '얼굴을 카메라에 비춰주세요';
          _statusColor = Colors.orange;
        }
      });
    } else {
      setState(() {
        _isHelmetDetected = false;
        _detectionStatus = '얼굴을 카메라에 비춰주세요';
        _statusColor = Colors.orange;
      });
    }
  }

  void _proceedToNextPage() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const HelmetSuccessPage(),
      ),
    );
  }

  @override
  void dispose() {
    // YoloRealtimeController에는 dispose 메서드가 없으므로 제거
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('헬멧 검사'),
          backgroundColor: const Color(0xFF0F5C31),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                '헬멧 검사 모델을 초기화하는 중...',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('헬멧 검사'),
        backgroundColor: const Color(0xFF0F5C31),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 카메라 뷰
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              child: yoloController != null
                  ? YoloRealTimeView(
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height * 0.5, // 높이 조정
                      controller: yoloController!,
                      drawBox: true,  // 바운딩 박스 그리기 활성화
                      captureBox: (boxes) {
                        _onDetectionResult(boxes);
                      },
                    )
                  : const Center(
                      child: Text('카메라를 초기화할 수 없습니다'),
                    ),
            ),
          ),
          
          // 상태 표시 영역
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16), // 패딩 줄임
              color: Colors.grey[100],
              child: SingleChildScrollView( // 스크롤 가능하게 수정
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isHelmetDetected ? Icons.check_circle : Icons.warning,
                      size: 50, // 아이콘 크기 줄임
                      color: _statusColor,
                    ),
                    const SizedBox(height: 12), // 간격 줄임
                    Text(
                      _detectionStatus,
                      style: TextStyle(
                        fontSize: 18, // 폰트 크기 줄임
                        fontWeight: FontWeight.bold,
                        color: _statusColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16), // 간격 줄임
                  
                    // 다음 단계 버튼 (헬멧 착용 시에만 활성화)
                    if (_isHelmetDetected)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _proceedToNextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F5C31),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12), // 패딩 줄임
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '다음 단계로 진행',
                            style: TextStyle(
                              fontSize: 16, // 폰트 크기 줄임
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12), // 패딩 줄임
                        decoration: BoxDecoration(
                          color: _statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _statusColor),
                        ),
                        child: Text(
                          '헬멧을 착용하고 얼굴을 카메라에 비춰주세요',
                          style: TextStyle(
                            color: _statusColor,
                            fontSize: 14, // 폰트 크기 줄임
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 헬멧 검사 성공 페이지
class HelmetSuccessPage extends StatelessWidget {
  const HelmetSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('헬멧 검사 완료'),
        backgroundColor: const Color(0xFF0F5C31),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: 100,
              color: Colors.green,
            ),
            const SizedBox(height: 20),
            const Text(
              '헬멧 착용이 확인되었습니다!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F5C31),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '안전한 주행을 위해 헬멧을 착용해주셔서 감사합니다.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // 여기서 다음 페이지로 이동 (예: 주행 시작 페이지)
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const YoloRealTimeViewExample(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F5C31),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: const Text('주행 시작'),
            ),
          ],
        ),
      ),
    );
  }
}

// startDrive_new.dart에서 사용하는 클래스 import
class YoloRealTimeViewExample extends StatefulWidget {
  const YoloRealTimeViewExample({Key? key}) : super(key: key);

  @override
  State<YoloRealTimeViewExample> createState() => _YoloRealTimeViewExampleState();
}

class _YoloRealTimeViewExampleState extends State<YoloRealTimeViewExample> {
  YoloRealtimeController? yoloController;

  @override
  void initState() {
    super.initState();
    _yoloInit();
  }

  Future<void> _yoloInit() async {
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
    } catch (e) {
      print('ERROR: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (yoloController == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('주행 모드'),
        backgroundColor: Colors.green,
      ),
      body: YoloRealTimeView(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height - AppBar().preferredSize.height,
        controller: yoloController!,
        drawBox: true,
        captureBox: (boxes) {
          // 기존 주행 모드 로직
        },
        captureImage: (data) async {
          // 기존 주행 모드 로직
        },
      ),
    );
  }
}
