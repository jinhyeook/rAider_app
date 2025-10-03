
// 무시: prefer_const_constructors

import 'package:yolo_realtime_plugin/yolo_realtime_plugin.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/server_config.dart';

// import 'package:flutter_tts/flutter_tts.dart';


class YoloRealTimeViewReport extends StatefulWidget {
  const YoloRealTimeViewReport({Key? key}) : super(key: key);

  @override
  State<YoloRealTimeViewReport> createState() =>
      _YoloRealTimeViewReportState();
}

class _YoloRealTimeViewReportState extends State<YoloRealTimeViewReport> {
  YoloRealtimeController? yoloController;
  // 참고: 'flutter pub get' 실행 후, 다음 줄들의 주석을 해제하세요:
  // late FlutterTts flutterTts;
  DateTime lastAnnouncementTime = DateTime.now();
  Set<String> lastAnnouncedObjects = {};
  
  // 수동 신고 시스템을 위한 변수들
  String? _currentUserId;
  Uint8List? _capturedImageData;
  // ServerConfig를 통해 서버 주소 관리
  bool _isProcessing = false; // 신고 처리 중 상태
  bool _shouldCaptureImage = false; // 수동 촬영 시에만 이미지 캡처

  @override
  void initState() {
    super.initState();

    // // 텍스트 음성 변환 초기화
    // flutterTts = FlutterTts();
    // flutterTts.setLanguage("ko-KR"); // 한국어
    // flutterTts.setSpeechRate(0.5); // 명확성을 위한 느린 발화 속도
    // flutterTts.setVolume(1.0); // 최대 볼륨

    _loadUserInfo();
    yoloInit();
  }

  Future<void> _loadUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 모든 SharedPreferences 키 확인
      final keys = prefs.getKeys();
      print('SharedPreferences 키들: $keys');
      
      _currentUserId = prefs.getString('user_id') ?? '';
      print('user_id 값: "$_currentUserId"');
      
      // 다른 방법으로도 시도해보기
      if (_currentUserId!.isEmpty) {
        // AuthService에서 저장한 user_data에서 USER_ID 추출 시도
        final userDataString = prefs.getString('user_data');
        if (userDataString != null) {
          try {
            final userData = jsonDecode(userDataString);
            _currentUserId = userData['USER_ID'] ?? '';
            print('user_data에서 추출한 USER_ID: "$_currentUserId"');
          } catch (e) {
            print('user_data 파싱 오류: $e');
          }
        }
      }
      
      if (_currentUserId!.isEmpty) {
        print('사용자 ID를 찾을 수 없습니다. 로그인이 필요합니다.');
      } else {
        print('현재 신고자: $_currentUserId');
      }
    } catch (e) {
      print('사용자 정보 로드 오류: $e');
    }
  }

  Future<void> yoloInit() async {
    yoloController = YoloRealtimeController(
      // 공통
      fullClasses: fullClasses,
      activeClasses: activeClasses,

      // 안드로이드
      androidModelPath: 'assets/yolov5s_320_report.pt',
      androidModelWidth: 320,
      androidModelHeight: 320,
      androidConfThreshold: 0.5,
      androidIouThreshold: 0.5,

      // iOS
      iOSModelPath: 'yolov5s',
      iOSConfThreshold: 0.5,
    );

    try {
      await yoloController?.initialize();
    } catch (e) {
      print('ERROR: $e');
    }
  }

  // 수동 촬영 및 신고 처리 함수
  Future<void> _handleManualCapture() async {
    try {
      if (_isProcessing) return; // 이미 처리 중이면 무시
      
      setState(() {
        _isProcessing = true;
      });

      // 사용자 ID 확인
      if (_currentUserId == null || _currentUserId!.isEmpty) {
        print('사용자 ID가 없어서 신고를 건너뜁니다.');
        _showErrorSnackBar('로그인이 필요합니다.');
        return;
      }

      print('수동 촬영 시작');
      
      // 1. 현재 위치 가져오기
      final position = await _getCurrentLocation();
      
      // 2. 수동 촬영 플래그 설정 및 화면 캡처
      _shouldCaptureImage = true;
      
      // 이미지 캡처를 위한 대기 시간 추가
      await Future.delayed(const Duration(milliseconds: 500));
      
      // YOLO 컨트롤러에서 직접 이미지 캡처 시도
      if (yoloController != null) {
        try {
          // YOLO 컨트롤러의 captureImage 메서드가 있다면 사용
          // 또는 다른 방법으로 이미지 캡처
          print('YOLO 컨트롤러를 통한 이미지 캡처 시도');
        } catch (e) {
          print('YOLO 컨트롤러 이미지 캡처 오류: $e');
        }
      }
      
      // 추가 대기 시간
      await Future.delayed(const Duration(milliseconds: 1000));
      
      if (_capturedImageData == null) {
        print('이미지 캡처 실패 - _capturedImageData가 null');
        _showErrorSnackBar('이미지 캡처에 실패했습니다. 다시 시도해주세요.');
        return;
      }
      
      // 3. CNN 분류로 위반 유형 판단
      final violationType = await _classifyImage(_capturedImageData!);
      
      if (violationType == null) {
        _showErrorSnackBar('헬멧 미착용 위반이 감지되지 않았습니다.');
        return;
      }
      
      // 4. 신고 데이터 구성
      final now = DateTime.now();
      final reportData = {
        'reporter_user_id': _currentUserId,
        'violation_type': violationType,
        'reporter_location': {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
        'report_time': now.toIso8601String(),
        'image_data': base64Encode(_capturedImageData!),
      };
      
      // 5. 서버로 전송
      await _sendReportToServer(reportData);
      
      // 6. 사용자에게 알림
      final koreanClassName = _getKoreanClassName(violationType);
      _showSuccessSnackBar('$koreanClassName 유형으로 신고되었습니다.');
      
    } catch (e) {
      print('수동 신고 처리 오류: $e');
      
      _showErrorSnackBar('신고에 실패했습니다.');
    } finally {
      setState(() {
        _isProcessing = false;
        _shouldCaptureImage = false; // 촬영 플래그 리셋
      });
    }
  }

  // 최근 감지된 객체들을 저장할 변수
  List<BoxModel> _lastDetectedBoxes = [];
  
  // YOLO 모델을 사용한 이미지 분류 함수 (실시간 감지 결과 기반)
  Future<String?> _classifyImage(Uint8List imageData) async {
    try {
      print('YOLO 모델로 이미지 분류 시작');
      
      if (_lastDetectedBoxes.isEmpty) {
        print('감지된 객체가 없음');
        return null;
      }

      print('YOLO 감지 결과: ${_lastDetectedBoxes.length}개 객체');
      
      // 감지된 객체들 중에서 헬멧 미착용 위반 찾기
      bool hasMultiViolation = false;
      bool hasSingleViolation = false;
      
      for (final detection in _lastDetectedBoxes) {
        print('감지된 객체: ${detection.label}, 신뢰도: ${detection.confidence}');
        
        if (detection.label == 'total_nohelmet_multi') {
          hasMultiViolation = true;
        } else if (detection.label == 'total_nohelmet_single') {
          hasSingleViolation = true;
        }
      }
      
      // 위반 유형 결정 (multi가 우선순위)
      if (hasMultiViolation) {
        print('다중 헬멧 미착용 위반 감지');
        return 'total_nohelmet_multi';
      } else if (hasSingleViolation) {
        print('단일 헬멧 미착용 위반 감지');
        return 'total_nohelmet_single';
      } else {
        print('헬멧 미착용 위반이 감지되지 않음');
        return null;
      }
      
    } catch (e) {
      print('YOLO 이미지 분류 오류: $e');
      return null;
    }
  }

  // 현재 위치 가져오기
  Future<Position> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('위치 권한이 거부되었습니다.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('위치 권한이 영구적으로 거부되었습니다.');
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('위치 가져오기 오류: $e');
      rethrow;
    }
  }

  // 현재 화면 캡처 (실제로는 이미지 데이터가 이미 captureImage 콜백에서 받아짐)
  Future<void> _captureCurrentScreen() async {
    try {
      print('화면 캡처 요청');
      
      // YOLO 컨트롤러가 있는지 확인
      if (yoloController == null) {
        print('YOLO 컨트롤러가 초기화되지 않음');
        return;
      }
      
      // YOLO의 captureImage 콜백에서 이미 _capturedImageData에 저장되므로
      // 여기서는 추가 작업이 필요하지 않음
      // 하지만 YOLO 컨트롤러가 활성화되어 있는지 확인
      print('YOLO 컨트롤러 상태 확인 완료');
      
    } catch (e) {
      print('화면 캡처 오류: $e');
    }
  }

  // 성공 스낵바 표시
  void _showSuccessSnackBar(String message) {
    if (mounted) {
      // 기존 SnackBar 제거 후 성공 메시지 표시
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // 클래스 유형을 한국어로 변환
  String _getKoreanClassName(String violationType) {
    switch (violationType) {
      case 'total_nohelmet_multi':
        return '다중 헬멧 미착용';
      case 'total_nohelmet_single':
        return '단일 헬멧 미착용';
      default:
        return '헬멧 미착용';
    }
  }

  // 에러 스낵바 표시
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }
  }

  // 안내 메시지 표시 함수
  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '신고 안내',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F5C31),
          ),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '• 5분 이내로 신고되어야 합니다.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              '• 본인을 신고할 수 없습니다.',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              '확인',
              style: TextStyle(
                color: Color(0xFF0F5C31),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 서버로 신고 데이터 전송
  Future<void> _sendReportToServer(Map<String, dynamic> reportData) async {
    try {
      print('신고 데이터 전송 시작: $reportData');
      
      final response = await http.post(
        Uri.parse(ServerConfig.getUserUrl('/report/manual-submit')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(reportData),
      ).timeout(const Duration(seconds: 10));
      
      print('서버 응답: ${response.statusCode} - ${response.body}');
      
      if (response.statusCode == 200) {
        print('수동 신고 전송 성공');
      } else {
        throw Exception('서버 응답 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('신고 전송 오류: $e');
      rethrow;
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
        title: const Text('신고 모드'),
        backgroundColor: const Color(0xFF0F5C31),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // 카메라 뷰 (전체 화면)
          Positioned.fill(
            child: YoloRealTimeView(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              controller: yoloController!,
              drawBox: true,
              captureBox: (boxes) {
                // YOLO 감지 결과는 화면에만 표시 (자동 신고 안함)
                // 실시간으로 감지된 객체들을 화면에 표시하고 저장
                print('감지된 객체들: ${boxes.map((box) => box.label).toList()}');
                
                // 최근 감지된 객체들을 저장 (분류에 사용)
                _lastDetectedBoxes = boxes;
              },
              captureImage: (data) async {
                // 수동 촬영 시에만 이미지 캡처
                if (_shouldCaptureImage && data != null) {
                  _capturedImageData = data;
                  print('수동 이미지 캡처 완료: ${data.length} bytes');
                } else if (_shouldCaptureImage && data == null) {
                  print('이미지 캡처 실패 - data가 null');
                }
              },
            ),
          ),
          
          // 수동 신고 모드 상태 표시 (상단)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '수동 신고 모드 - 촬영 버튼을 눌러 신고하세요',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 수동 촬영 버튼 (하단 중앙)
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: FloatingActionButton(
                  onPressed: _isProcessing ? null : _handleManualCapture,
                  backgroundColor: _isProcessing ? Colors.grey : const Color(0xFF0F5C31),
                  foregroundColor: Colors.white,
                  child: _isProcessing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.camera_alt, size: 28),
                ),
              ),
            ),
          ),
          
          // 안내 버튼 (우하단)
          Positioned(
            bottom: 50,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: FloatingActionButton(
                onPressed: _showInfoDialog,
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                mini: true,
                child: const Icon(Icons.info_outline, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }


  List<String> activeClasses = [
    "person",
    "kickboard",
    "no_helmet",
    "helmet",
    "total_nohelmet_multi",
    "total_nohelmet_single",
    "total_helmet_single"
  ];

  List<String> fullClasses = [
    "person",
    "kickboard",
    "no_helmet",
    "helmet",
    "total_nohelmet_multi",
    "total_nohelmet_single",
    "total_helmet_single"
  ];

  // 객체 이름을 한국어로 번역하는 함수
  // String translateToKorean(String objectName) {
  //   switch (objectName.toLowerCase()) {
  //     case 'pothole':
  //       return '포트홀';
  //     case 'car':
  //       return '자동차';
  //     case 'person':
  //       return '사람';
  //     case 'animal':
  //       return '동물';
  //     default:
  //       return objectName;
  //   }
  // }
}
