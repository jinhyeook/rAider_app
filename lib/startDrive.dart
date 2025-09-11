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
  DateTime lastAnnouncementTime = DateTime.now();
  Set<String> lastAnnouncedObjects = {};

  @override
  void initState() {
    super.initState();

    // // 텍스트 음성 변환 초기화
    flutterTts = FlutterTts();
    flutterTts.setLanguage("ko-KR"); // 한국어
    flutterTts.setSpeechRate(0.5); // 명확성을 위한 느린 발화 속도
    flutterTts.setVolume(1.0); // 최대 볼륨

    yoloInit();
  }

  Future<void> yoloInit() async {
    yoloController = YoloRealtimeController(
      // 공통
      fullClasses: fullClasses,
      activeClasses: activeClasses,

      // 안드로이드
      androidModelPath: 'assets/detect.pt',
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
        title: const Text('Drive Mode'),
        backgroundColor: Colors.green,
      ),
      body: YoloRealTimeView(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height - AppBar().preferredSize.height,
        controller: yoloController!,
        drawBox: true,
        captureBox: (boxes) {
          if (boxes.isNotEmpty) {
            // 디바운싱을 위한 현재 시간 가져오기
            final now = DateTime.now();

            // 마지막 안내 이후 최소 3초가 지났을 때만 안내
            if (now.difference(lastAnnouncementTime).inSeconds >= 3) {
              // 박스에서 객체 이름 추출
              final Set<String> detectedObjects = boxes
                  .map((box) => box.label)
                  .toSet();

              // 마지막 안내와 다른 객체가 감지되었을 때만 안내
              if (detectedObjects.difference(lastAnnouncedObjects).isNotEmpty) {
                // 안내 텍스트 생성
                String announcement = '';

                // 감지된 객체를 안내에 추가
                for (final object in detectedObjects) {
                  // 필요한 경우 객체 이름을 한국어로 번역
                  String koreanName = translateToKorean(object);
                  announcement += '$koreanName, ';
                }

                // 끝에 있는 쉼표와 공백 제거
                if (announcement.isNotEmpty) {
                  announcement = announcement.substring(0, announcement.length - 2);

                  flutterTts.speak(announcement);

                  // 현재는 안내 내용만 출력
                  print('감지된 객체: $announcement');

                  // 마지막 안내 시간과 객체 업데이트
                  lastAnnouncementTime = now;
                  lastAnnouncedObjects = detectedObjects;
                }
              }
            }
          }
        },
        captureImage: (data) async {
          // print('이진 이미지: $data');

          /// 원하는 대로 이진 이미지를 처리하고 사용하세요.
          // imageToFile(data);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context);
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.home, color: Colors.white),
        tooltip: '홈으로 돌아가기',
      ),
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
      default:
        return objectName;
    }
  }
}
