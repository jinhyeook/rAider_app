import 'package:yolo_realtime_plugin/yolo_realtime_plugin.dart';
import 'package:flutter/material.dart';
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
      fullClasses: ['nohelmet', 'helmet'],
      activeClasses: ['nohelmet', 'helmet'],

      // 안드로이드 설정
      androidModelPath: 'assets/yolov5s_320_helmet.pt',
      androidModelWidth: 320,
      androidModelHeight: 320,
      androidConfThreshold: 0.5,
      androidIouThreshold: 0.5,

      // iOS 설정
      iOSModelPath: 'assets/yolov5s_320_helmet.pt',
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
      double maxConfidence = 0.0;
      String detectedLabel = '';

      for (final box in boxes) {
        // 신뢰도가 높은 감지만 고려
        if (box.confidence > 0.6) {
          if (box.label == 'helmet') {
            helmetFound = true;
            if (box.confidence > maxConfidence) {
              maxConfidence = box.confidence;
              detectedLabel = 'helmet';
            }
          } else if (box.label == 'nohelmet') {
            noHelmetFound = true;
            if (box.confidence > maxConfidence) {
              maxConfidence = box.confidence;
              detectedLabel = 'nohelmet';
            }
          }
        }
      }

      setState(() {
        if (helmetFound && !noHelmetFound) {
          // 헬멧 착용 감지
          _isHelmetDetected = true;
          _detectionStatus = '헬멧 착용 확인됨!';
          _statusColor = Colors.green;
        } else if (noHelmetFound && !helmetFound) {
          // 헬멧 미착용 감지
          _isHelmetDetected = false;
          _detectionStatus = '헬멧을 착용해주세요';
          _statusColor = Colors.red;
        } else if (helmetFound && noHelmetFound) {
          // 둘 다 감지된 경우 - 신뢰도가 높은 것으로 판단
          if (detectedLabel == 'helmet') {
            _isHelmetDetected = true;
            _detectionStatus = '헬멧 착용 확인됨!';
            _statusColor = Colors.green;
          } else {
            _isHelmetDetected = false;
            _detectionStatus = '헬멧을 착용해주세요';
            _statusColor = Colors.red;
          }
        } else {
          // 불명확한 감지
          _isHelmetDetected = false;
          _detectionStatus = '얼굴을 카메라 중앙에 맞춰주세요';
          _statusColor = Colors.orange;
        }
      });
    } else {
      setState(() {
        _isHelmetDetected = false;
        _detectionStatus = '얼굴을 카메라 중앙에 맞춰주세요';
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
        backgroundColor: Colors.black,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              SizedBox(height: 20),
              Text(
                '헬멧 검사 모델을 초기화하는 중...',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 전면 카메라 1x 비율 (세로 모드)
          Positioned.fill(
            child: yoloController != null
                ? YoloRealTimeView(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                    controller: yoloController!,
                    drawBox: true, // 바운딩 박스 출력 활성화
                    captureBox: (boxes) {
                      _onDetectionResult(boxes);
                    },
                  )
                : const Center(
                    child: Text(
                      '카메라를 초기화할 수 없습니다',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
          ),
          
          // 얼굴 가이드라인 오버레이 (세로 모드)
          Positioned.fill(
            child: Container(
              child: Column(
                children: [
                  // 상단 여백
                  Expanded(
                    flex: 1,
                    child: Container(),
                  ),
                  // 얼굴 영역 (중앙)
                  Expanded(
                    flex: 2,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withOpacity(0.8),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
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
                  // 하단 여백
                  Expanded(
                    flex: 1,
                    child: Container(),
                  ),
                ],
              ),
            ),
          ),
          
          // 상단 안내 텍스트 (세로 모드)
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
                '얼굴을 가이드라인 중앙에 맞춰주세요\n(세로 모드에서 촬영하세요)',
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
                                '다음 단계로 진행',
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
                              '헬멧을 착용하고 얼굴을 카메라에 비춰주세요',
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

