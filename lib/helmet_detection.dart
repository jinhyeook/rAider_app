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
  String _detectionStatus = '헬멧을 착용해주세요';
  Color _statusColor = Colors.orange;
  
  // 탐지 정확도 개선을 위한 변수들
  Timer? _detectionTimer;
  List<bool> _recentDetections = [];
  static const int _detectionHistorySize = 5; // 히스토리 크기 증가
  static const double _stableDetectionThreshold = 0.8; // 80% 이상 일치해야 안정적 탐지로 간주

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
      
      // 탐지 안정화를 위한 타이머 시작
      _startDetectionStabilization();
    } catch (e) {
      print('헬멧 검사 모델 초기화 오류: $e');
      setState(() {
        _detectionStatus = '모델 초기화 실패';
        _statusColor = Colors.red;
      });
    }
  }

  // 탐지 안정화를 위한 타이머 시작
  void _startDetectionStabilization() {
    _detectionTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      // 최근 탐지 결과를 기반으로 안정적인 상태 판단
      _updateStableDetection();
    });
  }

  // 안정적인 탐지 상태 업데이트 (단순화)
  void _updateStableDetection() {
    if (_recentDetections.length >= _detectionHistorySize) {
      final trueCount = _recentDetections.where((detection) => detection).length;
      final stabilityRatio = trueCount / _recentDetections.length;
      
      print('탐지 안정성: $stabilityRatio (${trueCount}/${_recentDetections.length})'); // 디버깅
      
      if (stabilityRatio >= _stableDetectionThreshold) {
        // 안정적으로 헬멧 착용 감지
        if (!_isHelmetDetected) {
          setState(() {
            _isHelmetDetected = true;
            _detectionStatus = '헬멧 착용 확인됨!';
            _statusColor = Colors.green;
          });
          print('헬멧 착용 안정적 탐지 완료!');
        }
      } else if (stabilityRatio <= (1 - _stableDetectionThreshold)) {
        // 안정적으로 헬멧 미착용 감지
        if (_isHelmetDetected) {
          setState(() {
            _isHelmetDetected = false;
            _detectionStatus = '헬멧을 착용해주세요';
            _statusColor = Colors.red;
          });
          print('헬멧 미착용 안정적 탐지 완료!');
        }
      }
    }
  }

  void _onDetectionResult(dynamic boxes) {
    bool currentDetection = false;
    
    if (boxes.isNotEmpty) {
      print('탐지된 박스 개수: ${boxes.length}'); // 디버깅
      
      // 헬멧 착용 여부 확인 - 단순화된 로직
      bool helmetFound = false;
      bool noHelmetFound = false;
      double maxConfidence = 0.0;
      String detectedLabel = '';

      for (final box in boxes) {
        print('박스 정보: label=${box.label}, confidence=${box.confidence}'); // 디버깅
        
        // 신뢰도가 높은 감지만 고려 (임계값 상향)
        if (box.confidence > 0.7) {
          // 바운딩 박스 크기 검증 (Rect 속성 사용)
          final boxWidth = box.rect.right - box.rect.left;
          final boxHeight = box.rect.bottom - box.rect.top;
          final boxSize = (boxWidth + boxHeight) / 2;
          
          print('박스 크기: width=$boxWidth, height=$boxHeight, size=$boxSize'); // 디버깅
          
          // 박스가 너무 작거나 크면 무시 (엄격한 크기 제한)
          if (boxSize < 0.15 || boxSize > 0.6) {
            print('박스 크기가 부적절함: $boxSize');
            continue;
          }
          
          // 박스가 화면 중앙에 있는지 확인
          final centerX = (box.rect.left + box.rect.right) / 2;
          final centerY = (box.rect.top + box.rect.bottom) / 2;
          
          print('박스 중심: centerX=$centerX, centerY=$centerY'); // 디버깅
          
          // 박스가 화면 중앙에서 너무 멀리 떨어져 있으면 무시
          final distanceFromCenter = ((centerX - 0.5).abs() + (centerY - 0.5).abs()) / 2;
          if (distanceFromCenter > 0.3) {
            print('박스가 중앙에서 너무 멀리 떨어져 있음: $distanceFromCenter');
            continue;
          }
          
          // 박스가 화면 하단에 있는지 확인 (얼굴은 보통 하단에 위치)
          if (centerY < 0.4) {
            print('박스가 화면 상단에 있음 (얼굴이 아님): $centerY');
            continue;
          }
          
          // 박스의 가로세로 비율 확인 (얼굴은 대략 정사각형에 가움)
          final aspectRatio = boxWidth / boxHeight;
          if (aspectRatio < 0.5 || aspectRatio > 2.0) {
            print('박스 비율이 부적절함 (얼굴이 아님): $aspectRatio');
            continue;
          }
          
          if (box.label == 'helmet') {
            helmetFound = true;
            if (box.confidence > maxConfidence) {
              maxConfidence = box.confidence;
              detectedLabel = 'helmet';
            }
            print('헬멧 탐지됨: confidence=${box.confidence}');
          } else if (box.label == 'nohelmet') {
            noHelmetFound = true;
            if (box.confidence > maxConfidence) {
              maxConfidence = box.confidence;
              detectedLabel = 'nohelmet';
            }
            print('헬멧 미착용 탐지됨: confidence=${box.confidence}');
          }
        } else {
          print('신뢰도가 너무 낮음: ${box.confidence}');
        }
      }

      // 탐지 결과 결정 (엄격한 검증)
      if (helmetFound && !noHelmetFound) {
        currentDetection = true;
        _detectionStatus = '헬멧 착용 감지 중...';
        _statusColor = Colors.blue;
        print('헬멧 착용 탐지됨');
      } else if (noHelmetFound && !helmetFound) {
        currentDetection = false;
        _detectionStatus = '헬멧 미착용 감지 중...';
        _statusColor = Colors.red;
        print('헬멧 미착용 탐지됨');
      } else if (helmetFound && noHelmetFound) {
        // 둘 다 감지된 경우 - 신뢰도가 높은 것으로 판단
        currentDetection = (detectedLabel == 'helmet');
        _detectionStatus = currentDetection ? '헬멧 착용 감지 중...' : '헬멧 미착용 감지 중...';
        _statusColor = currentDetection ? Colors.blue : Colors.red;
        print('혼재 탐지: ${detectedLabel} 선택됨');
      } else {
        // 불명확한 감지
        currentDetection = false;
        _detectionStatus = '얼굴을 카메라 중앙에 맞춰주세요';
        _statusColor = Colors.orange;
        print('유효한 탐지 없음');
      }
    } else {
      currentDetection = false;
      _detectionStatus = '얼굴을 카메라 중앙에 맞춰주세요';
      _statusColor = Colors.orange;
      print('탐지된 박스 없음');
    }
    
    // 최근 탐지 결과에 추가 (안정화를 위해)
    _recentDetections.add(currentDetection);
    if (_recentDetections.length > _detectionHistorySize) {
      _recentDetections.removeAt(0);
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
          title: const Text('헬멧 검사 종료'),
          content: const Text('헬멧 검사를 종료하시겠습니까?\n안전한 주행을 위해 헬멧 착용이 필요합니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('종료'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
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

    return WillPopScope(
      onWillPop: _handleBackButton,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 전면 카메라 - 1:1 비율로 모델 입력과 일치
            Positioned.fill(
              child: yoloController != null
                  ? Center(
                      child: AspectRatio(
                        aspectRatio: 1, // 1:1 비율로 모델 입력과 일치
                        child: Container(
                          width: MediaQuery.of(context).size.width,
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
                    )
                  : const Center(
                      child: Text(
                        '카메라를 초기화할 수 없습니다',
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
                  '얼굴을 가이드라인 중앙에 맞춰주세요\n카메라를 정면으로 향하게 하세요',
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
    return WillPopScope(
      onWillPop: _handleBackButton,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('헬멧 검사 완료'),
          backgroundColor: const Color(0xFF0F5C31),
          foregroundColor: Colors.white,
          centerTitle: true,
          automaticallyImplyLeading: false, // 뒤로가기 버튼 비활성화
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
      ),
    );
  }
}

