// 무시: prefer_const_constructors

import 'package:yolo_realtime_plugin/yolo_realtime_plugin.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  
  // 자동 신고 시스템을 위한 변수들
  DateTime? lastReportTime;
  String? _currentUserId;
  Uint8List? _capturedImageData;
  final String baseUrl = 'http://192.168.55.92:5000'; // Flask 서버 URL

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
      androidModelPath: 'assets/kick_report2.pt',
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

  // 자동 신고 처리 함수
  Future<void> _handleAutoReport(String violationType) async {
    try {
      // 사용자 ID 확인
      if (_currentUserId == null || _currentUserId!.isEmpty) {
        print('사용자 ID가 없어서 신고를 건너뜁니다.');
        return;
      }

      // 중복 신고 방지 (30초 내 중복 방지)
      final now = DateTime.now();
      if (lastReportTime != null && 
          now.difference(lastReportTime!).inSeconds < 30) {
        print('중복 신고 방지: ${now.difference(lastReportTime!).inSeconds}초 전에 신고됨');
        return;
      }

      print('헬멧 미착용 감지: $violationType');
      
      // 1. 현재 위치 가져오기
      final position = await _getCurrentLocation();
      
      // 2. 현재 화면 캡처
      await _captureCurrentScreen();
      
      // 3. 신고 데이터 구성
      final reportData = {
        'reporter_user_id': _currentUserId,
        'violation_type': violationType,
        'reporter_location': {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
        'report_time': now.toIso8601String(),
        'image_data': _capturedImageData != null ? base64Encode(_capturedImageData!) : null,
      };
      
      // 4. 서버로 전송
      await _sendReportToServer(reportData);
      
      // 5. 마지막 신고 시간 업데이트
      lastReportTime = now;
      
      // 6. 사용자에게 알림
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('헬멧 미착용 위반이 자동으로 신고되었습니다.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
    } catch (e) {
      print('자동 신고 처리 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('신고 처리 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
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

  // 현재 화면 캡처
  Future<void> _captureCurrentScreen() async {
    try {
      // YOLO 컨트롤러에서 현재 이미지 캡처 요청
      // captureImage 콜백에서 _capturedImageData에 저장됨
      print('화면 캡처 요청');
    } catch (e) {
      print('화면 캡처 오류: $e');
    }
  }

  // 서버로 신고 데이터 전송
  Future<void> _sendReportToServer(Map<String, dynamic> reportData) async {
    try {
      print('신고 데이터 전송 시작: $reportData');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/report/auto-submit'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(reportData),
      ).timeout(const Duration(seconds: 10));
      
      print('서버 응답: ${response.statusCode} - ${response.body}');
      
      if (response.statusCode == 200) {
        print('자동 신고 전송 성공');
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
                if (boxes.isNotEmpty) {
                  // 헬멧 미착용 감지 확인
                  bool hasViolation = false;
                  String violationType = '';
                  
                  for (final box in boxes) {
                    if (box.label == 'total_nohelmet_multi') {
                      hasViolation = true;
                      violationType = 'total_nohelmet_multi';
                      break;
                    } else if (box.label == 'total_nohelmet_single') {
                      hasViolation = true;
                      violationType = 'total_nohelmet_single';
                      break;
                    }
                  }
                  
                  // 위반 감지 시 자동 신고 처리
                  if (hasViolation) {
                    _handleAutoReport(violationType);
                  }
                }
              },
              captureImage: (data) async {
                // 자동 신고 시 이미지 캡처
                if (data != null) {
                  _capturedImageData = data;
                }
              },
            ),
          ),
          
          // 자동 신고 상태 표시 (상단)
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
                  Icon(Icons.security, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '자동 신고 모드 활성화',
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
