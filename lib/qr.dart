import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ocr.dart';

class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  MobileScannerController controller = MobileScannerController();
  String? _scannedDeviceId;
  String? _selectedDeviceId;
  bool _isProcessing = false;
  Timer? _flashTimer;
  bool _isFlashOn = false;
  String _statusMessage = '';
  bool _showStatusCard = false;

  @override
  void initState() {
    super.initState();
    _startFlashAnimation();
    _loadSelectedDeviceId();
  }

  // 지도에서 선택한 기기 ID 로드
  Future<void> _loadSelectedDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedId = prefs.getString('selected_device_id');
    setState(() {
      _selectedDeviceId = selectedId;
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    _flashTimer?.cancel();
    super.dispose();
  }

  // 뒤로가기 처리
  void _handleBackButton() {
    Navigator.pop(context, 'back_from_qr');
  }

  // 플래시 애니메이션 효과
  void _startFlashAnimation() {
    _flashTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {
          _isFlashOn = !_isFlashOn;
        });
      }
    });
  }

  // QR코드 스캔 결과 처리
  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null && !_isProcessing) {
        _processQRCode(barcode.rawValue!);
        break; // 첫 번째 유효한 QR코드만 처리
      }
    }
  }

  // QR코드 데이터 처리
  Future<void> _processQRCode(String qrData) async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });

    log("QR code scanned: $qrData", name: "QRScan");
    print("=== QR code scanned: $qrData ===");

    try {
      // QR코드에서 기기 ID 추출 (예: "DEVICE_12345" 형태)
      String? deviceId = _extractDeviceId(qrData);
      
      log("Extracted device ID: $deviceId", name: "QRScan");
      print("=== Extracted device ID: $deviceId ===");
      
      if (deviceId != null) {
        // 지도에서 선택한 기기 ID와 비교
        final prefs = await SharedPreferences.getInstance();
        final selectedDeviceId = prefs.getString('selected_device_id');
        
        log("Selected device from map: $selectedDeviceId", name: "QRScan");
        log("Scanned device from QR: $deviceId", name: "QRScan");
        print("=== Selected device from map: $selectedDeviceId ===");
        print("=== Scanned device from QR: $deviceId ===");
        
        if (selectedDeviceId != null && selectedDeviceId == deviceId) {
          // 기기 ID가 일치하는 경우
          await prefs.setString('selected_device_code', deviceId);
          
          log("Device ID match confirmed: $deviceId", name: "QRScan");
          print("=== Device ID match confirmed: $deviceId ===");
          
          setState(() {
            _statusMessage = "✅ Device ID Match!\nProceeding with authentication...";
            _showStatusCard = true;
          });
          
          // 성공 피드백
          _showSuccessFeedback("Device ID matches! Proceeding with authentication.");
          
          // 잠시 후 OCR 페이지로 이동
          await Future.delayed(const Duration(milliseconds: 1500));
          
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => IdCardOcrPage()),
            );
          }
        } else {
          // 기기 ID가 일치하지 않는 경우
          print("=== Device ID mismatch: Selected device($selectedDeviceId) != Scanned device($deviceId) ===");
          
          setState(() {
            _statusMessage = "❌ Device ID Mismatch!\nSelected device: $selectedDeviceId\nScanned device: $deviceId";
            _showStatusCard = true;
          });
          
          _showErrorFeedback("The selected device and QR code do not match.\nPlease try again.");
        }
      } else {
        _showErrorFeedback("Invalid QR code.");
      }
    } catch (e) {
      log("QR code processing error: $e", name: "QRScan");
      _showErrorFeedback("An error occurred while processing the QR code.");
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // QR코드에서 기기 ID 추출
  String? _extractDeviceId(String qrData) {
    log("QR code original data: $qrData", name: "QRScan");
    print("=== QR code original data: $qrData ===");
    
    // 다양한 QR코드 형식 지원
    final patterns = [
      RegExp(r'DEVICE_(\w+)', caseSensitive: false),
      RegExp(r'device_(\w+)', caseSensitive: false),
      RegExp(r'기기_(\w+)', caseSensitive: false),
      RegExp(r'(\w{10,})', caseSensitive: false), // 10자 이상의 문자열
    ];

    log("Attempting pattern matching...", name: "QRScan");
    print("=== Attempting pattern matching... ===");
    
    for (int i = 0; i < patterns.length; i++) {
      final pattern = patterns[i];
      final match = pattern.firstMatch(qrData);
      if (match != null) {
        final extractedId = match.group(1) ?? match.group(0);
        log("Pattern $i match successful: $extractedId", name: "QRScan");
        print("=== Pattern $i match successful: $extractedId ===");
        return extractedId;
      }
    }

    // 패턴이 매치되지 않으면 전체 문자열을 기기 ID로 사용
    if (qrData.length >= 5) {
      log("Pattern matching failed, using full string: $qrData", name: "QRScan");
      print("=== Pattern matching failed, using full string: $qrData ===");
      return qrData;
    }

    log("Device ID extraction failed: string too short", name: "QRScan");
    print("=== Device ID extraction failed: string too short ===");
    return null;
  }

  // 성공 피드백 표시
  void _showSuccessFeedback(String message) {
    // 기존 SnackBar 제거
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // 에러 피드백 표시
  void _showErrorFeedback(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    return WillPopScope(
      onWillPop: () async {
        _handleBackButton();
        return false; // WillPopScope에서 직접 처리하므로 false 반환
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Device QR Code Scan',
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: const Color(0xFF0F5C31),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBackButton,
          ),
        actions: [],
      ),
      body: Stack(
        children: [
          // QR 스캐너
          MobileScanner(
            controller: controller,
            onDetect: _onDetect,
          ),
          
          // 가이드 오버레이
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 스캔 가이드 박스
                    Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _isFlashOn ? Colors.green : Colors.white,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Stack(
                        children: [
                          // 모서리 표시
                          ...List.generate(4, (index) {
                            return Positioned(
                              top: index < 2 ? 0 : null,
                              bottom: index >= 2 ? 0 : null,
                              left: index % 2 == 0 ? 0 : null,
                              right: index % 2 == 1 ? 0 : null,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: index < 2 ? BorderSide(color: _isFlashOn ? Colors.green : Colors.white, width: 4) : BorderSide.none,
                                    bottom: index >= 2 ? BorderSide(color: _isFlashOn ? Colors.green : Colors.white, width: 4) : BorderSide.none,
                                    left: index % 2 == 0 ? BorderSide(color: _isFlashOn ? Colors.green : Colors.white, width: 4) : BorderSide.none,
                                    right: index % 2 == 1 ? BorderSide(color: _isFlashOn ? Colors.green : Colors.white, width: 4) : BorderSide.none,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    // 안내 텍스트
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Scan the device QR code',
                        style: TextStyle(
                          color: _isFlashOn ? Colors.green : Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // 처리 중 표시
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.7),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Processing QR code...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // 상태 카드 (기기 ID 비교 결과 표시)
          if (_showStatusCard)
            Positioned(
              left: 20,
              right: 20,
              top: 100,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _statusMessage.contains('✅') ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _statusMessage.contains('✅') ? Colors.green : Colors.red,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _statusMessage.contains('✅') ? Icons.check_circle : Icons.error,
                      color: _statusMessage.contains('✅') ? Colors.green : Colors.red,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _statusMessage.contains('✅') ? Colors.green[700] : Colors.red[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    if (_selectedDeviceId != null)
                      Text(
                        'Selected device: $_selectedDeviceId',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
            ),

          // 하단 안내
          Positioned(
            left: 0,
            right: 0,
            bottom: 50,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.qr_code_scanner,
                    color: Color(0xFF0F5C31),
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Point the camera at the device QR code',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F5C31),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Make sure the QR code is clearly visible',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
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
