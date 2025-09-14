

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
  bool _isVerifying = false;
  Map<String, String>? _parsedOcrData;

  final double guideBoxRatio = 1.585; // 신분증 비율
  final double guideBoxWidthPercent = 0.8; // 가이드박스 가로 화면대비 비율

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    _controller = CameraController(
      _cameras![0], 
      ResolutionPreset.high,
      enableAudio: false,  // 오디오 비활성화
    );
    await _controller!.initialize();
    
    // 플래시를 명시적으로 끄기
    await _controller!.setFlashMode(FlashMode.off);
    
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
        // Uri.parse('http://192.168.173.229:5000/ocr'), // 로컬 서버 주소(핫스팟)
        Uri.parse('http://192.168.55.92:5000/ocr'), // 로컬 서버 주소(데스크탑)
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image': base64Image}),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        setState(() {
          _ocrResult = JsonEncoder.withIndent('  ').convert(jsonResponse);
          _parsedOcrData = _parseOcrResult(jsonResponse);
        });
      } else {
        setState(() {
          _ocrResult = 'server error: ${response.statusCode}';
          _parsedOcrData = null;
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

  // OCR 결과에서 운전면허증 번호, 이름, 주민번호 파싱
  Map<String, String>? _parseOcrResult(Map<String, dynamic> ocrResponse) {
    try {
      String? licenseNumber;
      String? name;
      String? idNumber;

      print('OCR 응답 전체 데이터: $ocrResponse');

      // OCR 응답에서 필요한 정보 추출
      if (ocrResponse.containsKey('번호')) {
        licenseNumber = ocrResponse['번호'].toString().trim();
        print('인식된 운전면허증 번호: $licenseNumber');
      }
      if (ocrResponse.containsKey('이름')) {
        name = ocrResponse['이름'].toString().trim();
        print('인식된 이름: $name');
      }
      if (ocrResponse.containsKey('주민번호')) {
        idNumber = ocrResponse['주민번호'].toString().trim();
        print('인식된 주민번호: $idNumber');
      }

      // 주민번호가 다른 키로 인식될 수 있으므로 추가 검색
      if (idNumber == null || idNumber.isEmpty) {
        for (String key in ocrResponse.keys) {
          String value = ocrResponse[key].toString().trim();
          // 주민번호 패턴 검사 (6자리-7자리 또는 13자리 숫자)
          RegExp ssnPattern = RegExp(r'^\d{6}[-]?\d{7}$|^\d{13}$');
          if (ssnPattern.hasMatch(value)) {
            idNumber = value;
            print('다른 키에서 주민번호 발견: $key = $value');
            break;
          }
        }
      }

      // 주민번호 형식 정규화 (하이픈 추가)
      if (idNumber != null && idNumber.isNotEmpty) {
        // 하이픈이 없고 13자리 숫자인 경우 하이픈 추가
        if (idNumber.length == 13 && !idNumber.contains('-')) {
          idNumber = '${idNumber.substring(0, 6)}-${idNumber.substring(6)}';
          print('주민번호 형식 정규화: $idNumber');
        }
      }

      // OCR 응답의 모든 키를 확인
      print('OCR 응답의 모든 키: ${ocrResponse.keys.toList()}');

      // 주민번호와 이름이 모두 있어야 인증 가능
      if (licenseNumber != null && name != null && idNumber != null && idNumber.isNotEmpty) {
        print('모든 정보가 인식됨 - 인증 가능');
        return {
          'license_number': licenseNumber,
          'name': name,
          'id_number': idNumber,
        };
      } else {
        print('인식되지 않은 정보: licenseNumber=$licenseNumber, name=$name, idNumber=$idNumber');
      }
      return null;
    } catch (e) {
      print('OCR 파싱 오류: $e');
      return null;
    }
  }

  // DB에서 사용자 정보 확인 (주민번호 포함)
  Future<bool> _verifyUserInfo() async {
    if (_parsedOcrData == null) return false;

    setState(() { _isVerifying = true; });

    try {
      // 전송할 데이터 확인
      final ssnValue = _parsedOcrData!['id_number'];
      final requestData = {
        'name': _parsedOcrData!['name'],
        'driver_license': _parsedOcrData!['license_number'],
        'ssn': ssnValue, // 주민번호 추가
      };
      
      print('서버로 전송할 데이터: $requestData');
      print('_parsedOcrData 전체: $_parsedOcrData');
      print('주민번호 값: $ssnValue');
      print('주민번호 타입: ${ssnValue.runtimeType}');
      print('주민번호가 null인가?: ${ssnValue == null}');
      print('주민번호가 빈 문자열인가?: ${ssnValue == ""}');
      
      // 주민번호가 없으면 인증 불가
      if (ssnValue == null || ssnValue.isEmpty) {
        print('주민번호가 없어서 인증 불가');
        return false;
      }

      final response = await http.post(
        Uri.parse('http://192.168.55.92:5000/api/auth/verify-user-license'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      );

      print('응답 상태 코드: ${response.statusCode}');
      print('응답 본문: ${response.body}');
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['verified'] == true;
      } else {
        // 에러 응답도 파싱해서 로그 출력
        try {
          final errorResult = jsonDecode(response.body);
          print('에러 응답: $errorResult');
        } catch (e) {
          print('에러 응답 파싱 실패: $e');
        }
      }
      return false;
    } catch (e) {
      print('사용자 정보 확인 오류: $e');
      return false;
    } finally {
      setState(() { _isVerifying = false; });
    }
  }

  // 인증 성공 시 빈 페이지로 이동
  void _navigateToEmptyPage() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const EmptyPage(),
      ),
    );
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
                  // 첫 번째 행: 사진촬영, 서버전송, 다시촬영
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
                            _parsedOcrData = null;
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
                  // 두 번째 행: 인증하기 버튼 (OCR 결과가 있을 때만 표시)
                  if (_parsedOcrData != null) ...[
                    SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: _isVerifying 
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Icon(Icons.verified_user),
                        label: Text(_isVerifying ? '인증 중...' : '인증하기'),
                        onPressed: _isVerifying ? null : () async {
                          final isVerified = await _verifyUserInfo();
                          if (isVerified) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('인증이 완료되었습니다!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _navigateToEmptyPage();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('인증에 실패했습니다. 정보를 다시 확인해주세요.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isVerifying ? Colors.grey[400] : Color(0xFF0F5C31),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                      ),
                    ),
                  ],
                  // OCR 결과가 있지만 주민번호가 인식되지 않은 경우 안내 메시지
                  if (_ocrResult.isNotEmpty && _parsedOcrData == null) ...[
                    SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange[700], size: 24),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '주민번호가 인식되지 않았습니다.\n운전면허증을 다시 촬영해주세요.',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 빈 페이지 클래스
class EmptyPage extends StatelessWidget {
  const EmptyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('인증 완료'),
        centerTitle: true,
        backgroundColor: const Color(0xFF0F5C31),
        foregroundColor: Colors.white,
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
              '인증이 완료되었습니다!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F5C31),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '운전면허증 인증이 성공적으로 완료되었습니다.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F5C31),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
  }
}