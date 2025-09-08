

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class IdCardOcrPage extends StatefulWidget {
  @override
  State<IdCardOcrPage> createState() => _IdCardOcrPageState();
}

class _IdCardOcrPageState extends State<IdCardOcrPage> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  XFile? _capturedFile;
  File? _croppedImageFile;
  String _ocrResult = '';
  bool _isProcessing = false;

  final double guideBoxRatio = 1.585; // 신분증 비율
  final double guideBoxWidthPercent = 0.8; // 가이드박스 가로 화면대비 비율

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    _controller = CameraController(_cameras![0], ResolutionPreset.high);
    await _controller!.initialize();
    setState(() {});
  }

  // 사진 촬영
  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final file = await _controller!.takePicture();
    setState(() {
      _capturedFile = file;
      _ocrResult = '';
      _croppedImageFile = null;
    });
  }

  Future<void> _cropAndSendToServer({
    required double previewW,
    required double previewH,
    required double guideLeft,
    required double guideTop,
    required double guideW,
    required double guideH,
  }) async {
    if (_capturedFile == null) return;
    setState(() { _isProcessing = true; });

    try {
      File imageFile = File(_capturedFile!.path);
      final bytes = await imageFile.readAsBytes();
      img.Image? capturedImg = img.decodeImage(bytes);
      if (capturedImg == null) throw Exception('image decoding failed');

      int imgW = capturedImg.width;
      int imgH = capturedImg.height;

      // 화면 픽셀 대비 실제 이미지 픽셀로 변환 비율
      double scaleX = imgW / previewW;
      double scaleY = imgH / previewH;

      int cropX = (guideLeft * scaleX).round();
      int cropY = (guideTop * scaleY).round();
      int cropWidth = (guideW * scaleX).round();
      int cropHeight = (guideH * scaleY).round();

      // 크롭 경계 보정
      if (cropX < 0) cropX = 0;
      if (cropY < 0) cropY = 0;
      if (cropX + cropWidth > imgW) cropWidth = imgW - cropX;
      if (cropY + cropHeight > imgH) cropHeight = imgH - cropY;

      img.Image croppedImg = img.copyCrop(
        capturedImg,  // 회전 X
        x: cropX+25,
        y: cropY+25,
        width: cropWidth+25,
        height: cropHeight+30,
      );

      final croppedBytes = img.encodeJpg(croppedImg);
      final tempDir = await getTemporaryDirectory();
      final croppedFile = await File('${tempDir.path}/cropped_temp.jpg').writeAsBytes(croppedBytes);

      setState(() { _croppedImageFile = croppedFile; });

      // 포트 번호 꼭 붙이기
      final base64Image = base64Encode(croppedBytes);
      final response = await http.post(
        // Uri.parse('http://3.34.48.22:5001/ocr'), // AWS 서버 주소
        // Uri.parse('http://192.168.45.90:5000/ocr'), // 로컬 서버 주소(노트북)
        Uri.parse('http://192.168.55.92:5000/ocr'), // 로컬 서버 주소(데스크탑)
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image': base64Image}),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        setState(() {
          _ocrResult = JsonEncoder.withIndent('  ').convert(jsonResponse);
        });
      } else {
        setState(() {
          _ocrResult = 'server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _ocrResult = 'error : $e';
      });
    } finally {
      setState(() { _isProcessing = false; });
    }
  }


  // 실제 은행앱 스타일 오버레이+가이드박스
  Widget _buildGuideOverlay(double screenW, double screenH) {
    final boxW = (screenW * guideBoxWidthPercent) + 27;
    final boxH = boxW / guideBoxRatio;
    final boxLeft = (screenW - boxW) / 2;
    final boxTop = ((screenH - boxH) / 2)-20;

    return Stack(
      children: [
        // 반투명 어두운 영역(위)
        Positioned(
          left: 0, top: 0, right: 0, height: boxTop,
          child: Container(color: Colors.black.withOpacity(0.6)),
        ),
        // 반투명 어두운 영역(아래)
        Positioned(
          left: 0, right: 0, top: boxTop + boxH, bottom: 0,
          child: Container(color: Colors.black.withOpacity(0.6)),
        ),
        // 반투명 어두운 영역(왼쪽)
        Positioned(
          left: 0, top: boxTop, width: boxLeft, height: boxH,
          child: Container(color: Colors.black.withOpacity(0.6)),
        ),
        // 반투명 어두운 영역(오른쪽)
        Positioned(
          left: boxLeft + boxW, right: 0, top: boxTop, height: boxH,
          child: Container(color: Colors.black.withOpacity(0.6)),
        ),
        // 밝은 가이드박스 테두리
        Positioned(
          left: boxLeft, top: boxTop, width: boxW, height: boxH,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.lightBlueAccent, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                'Please fit your license here',
                style: TextStyle(
                  color: Colors.white,
                  backgroundColor: Colors.black38,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {

    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final boxW = screenW * guideBoxWidthPercent;
    final boxH = boxW / guideBoxRatio;
    final boxLeft = (screenW - boxW) / 2;
    final boxTop = (screenH - boxH) / 2;


    return Scaffold(
      appBar: AppBar(
        title: Text("Driver License Verification "),
        leading: BackButton(),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 카메라 프리뷰 or 촬영 이미지 (BoxFit.cover로 꽉 채움)
          Positioned.fill(
            child: _capturedFile == null
                ? (_controller != null && _controller!.value.isInitialized
                ? CameraPreview(_controller!)
                : Center(child: CircularProgressIndicator()))
                : Image.file(File(_capturedFile!.path), fit: BoxFit.cover),
          ),

          // ★★ 촬영 전: 가이드 오버레이
          if (_capturedFile == null)
            _buildGuideOverlay(screenW, screenH),

          // 안내문구 & 버튼
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              color: Colors.white.withOpacity(0.95),
              padding: EdgeInsets.symmetric(vertical: 18, horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // OCR 결과 표시 (촬영 후에만)
                  if (_isProcessing)
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ),
                  if (_ocrResult.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, spreadRadius: 2)],
                      ),
                      child: Text(
                        _ocrResult,
                        style: TextStyle(fontSize: 14, fontFamily: 'monospace'),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 사진촬영
                      ElevatedButton.icon(
                        icon: Icon(Icons.camera_alt),
                        label: Text('picture'),
                        onPressed: _capturedFile == null ? _capture : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _capturedFile == null ? Colors.blue[700] : Colors.grey[300],
                          foregroundColor: _capturedFile == null ? Colors.white : Colors.black45,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        ),
                      ),
                      // 서버전송
                      ElevatedButton.icon(
                        icon: Icon(Icons.send),
                        label: Text('Verification'),
                        onPressed: (_capturedFile != null && !_isProcessing)
                            ? () => _cropAndSendToServer(
                          previewW: screenW,
                          previewH: screenH,
                          guideLeft: boxLeft,
                          guideTop: boxTop,
                          guideW: boxW,
                          guideH: boxH,
                        )
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (_capturedFile != null && !_isProcessing) ? Colors.green : Colors.grey[300],
                          foregroundColor: (_capturedFile != null && !_isProcessing) ? Colors.white : Colors.black45,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        ),
                      ),
                      // 다시촬영
                      ElevatedButton.icon(
                        icon: Icon(Icons.refresh),
                        label: Text('Retake photo'),
                        onPressed: _capturedFile != null
                            ? () {
                          setState(() {
                            _capturedFile = null;
                            _croppedImageFile = null;
                            _ocrResult = '';
                          });
                        }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _capturedFile != null ? Colors.red[400] : Colors.grey[300],
                          foregroundColor: _capturedFile != null ? Colors.white : Colors.black45,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        ),
                      ),
                    ],
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