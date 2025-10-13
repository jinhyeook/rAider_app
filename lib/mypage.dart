import 'package:flutter/material.dart';
import 'mypage_service.dart';
import 'auth_service.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  final MyPageService _myPageService = MyPageService();
  Map<String, dynamic>? _userInfo;
  List<Map<String, dynamic>> _deviceLogs = [];
  bool _isLoading = true;
  bool _isLoadingLogs = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadDeviceLogs();
  }

  /// 사용자 정보 로드
  Future<void> _loadUserInfo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _myPageService.getUserInfo();
      
      if (result['success']) {
        setState(() {
          _userInfo = result['user_info'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e';
        _isLoading = false;
      });
    }
  }

  /// 디바이스 사용 로그 로드
  Future<void> _loadDeviceLogs() async {
    print('=== _loadDeviceLogs 시작 ===');
    setState(() {
      _isLoadingLogs = true;
    });

    try {
      print('MyPageService.getDeviceLogs() 호출 중...');
      final result = await _myPageService.getDeviceLogs();
      print('getDeviceLogs 결과: $result');
      
      if (result['success']) {
        final logs = List<Map<String, dynamic>>.from(result['device_logs'] ?? []);
        print('로드된 디바이스 로그 개수: ${logs.length}');
        print('디바이스 로그 내용: $logs');
        
        setState(() {
          _deviceLogs = logs;
          _isLoadingLogs = false;
        });
        print('디바이스 로그 상태 업데이트 완료');
      } else {
        setState(() {
          _isLoadingLogs = false;
        });
        print('Device logs load failed: ${result['message']}');
      }
    } catch (e) {
      setState(() {
        _isLoadingLogs = false;
      });
      print('Device logs load error: $e');
    }
  }

  /// 통합 정보 카드 위젯 (사용자 정보 + 디바이스 로그)
  Widget _buildIntegratedInfoCard() {
    if (_userInfo == null) return const SizedBox.shrink();
    
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Card(
      margin: EdgeInsets.all(isSmallScreen ? 12 : 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Icon(
                  Icons.person,
                  color: const Color(0xFF0F5C31),
                  size: isSmallScreen ? 24 : 28,
                ),
                SizedBox(width: isSmallScreen ? 8 : 12),
                Text(
                  'My Information',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F5C31),
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 16 : 20),
            
            // 사용자 정보 항목들
            _buildInfoRow('User ID', _userInfo!['USER_ID'] ?? 'N/A'),
            _buildInfoRow('Name', _userInfo!['name'] ?? 'N/A'),
            _buildInfoRow('Email', _userInfo!['email'] ?? 'N/A'),
            _buildInfoRow('Phone', _userInfo!['phone'] ?? 'N/A'),
            _buildInfoRow('Birth Date', _userInfo!['birth'] ?? 'N/A'),
            _buildInfoRow('Age', '${_userInfo!['age'] ?? 'N/A'} years old'),
            _buildInfoRow('Report Count', '${_userInfo!['report_count'] ?? 0} times'),
            
            // 구분선
            SizedBox(height: isSmallScreen ? 20 : 24),
            Divider(
              color: Colors.grey[300],
              thickness: 1,
            ),
            SizedBox(height: isSmallScreen ? 16 : 20),
            
            // 디바이스 사용 로그 섹션
            Row(
              children: [
                Icon(
                  Icons.history,
                  color: const Color(0xFF0F5C31),
                  size: isSmallScreen ? 20 : 22,
                ),
                SizedBox(width: isSmallScreen ? 6 : 8),
                Text(
                  'Recent Device Usage',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F5C31),
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            
            // 로딩 상태
            if (_isLoadingLogs)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F5C31)),
                  ),
                ),
              )
            else if (_deviceLogs.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No device usage history found.',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              )
            else
              // 디바이스 로그 목록
              ...(_deviceLogs.map((log) => _buildLogItem(log)).toList()),
          ],
        ),
      ),
    );
  }

  /// 로그 항목 위젯
  Widget _buildLogItem(Map<String, dynamic> log) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    // 시간 포맷팅
    String formatDateTime(String? dateTimeStr) {
      if (dateTimeStr == null) return 'N/A';
      try {
        final dateTime = DateTime.parse(dateTimeStr);
        return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        return 'Invalid Date';
      }
    }

    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 디바이스 코드
          Row(
            children: [
              Icon(
                Icons.device_hub,
                size: isSmallScreen ? 16 : 18,
                color: const Color(0xFF0F5C31),
              ),
              SizedBox(width: isSmallScreen ? 6 : 8),
              Text(
                'Device: ${log['DEVICE_CODE'] ?? 'N/A'}',
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F5C31),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 8 : 10),
          
          // 시작 시간
          _buildLogRow('Start Time', formatDateTime(log['start_time']), Icons.play_arrow),
          SizedBox(height: isSmallScreen ? 4 : 6),
          
          // 종료 시간
          _buildLogRow('End Time', formatDateTime(log['end_time']), Icons.stop),
          SizedBox(height: isSmallScreen ? 4 : 6),
          
          // 요금
          _buildLogRow('Fee', '${log['fee'] ?? 0} won', Icons.payment),
        ],
      ),
    );
  }

  /// 로그 행 위젯
  Widget _buildLogRow(String label, String value, IconData icon) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Row(
      children: [
        Icon(
          icon,
          size: isSmallScreen ? 14 : 16,
          color: Colors.grey[600],
        ),
        SizedBox(width: isSmallScreen ? 6 : 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: isSmallScreen ? 12 : 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 14,
              color: Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  /// 정보 행 위젯
  Widget _buildInfoRow(String label, String value) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 6 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isSmallScreen ? 70 : 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          SizedBox(width: isSmallScreen ? 12 : 16),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 로딩 위젯
  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F5C31)),
          ),
          SizedBox(height: 16),
          Text(
            'Loading user information...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  /// 에러 위젯
  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'An unknown error occurred.',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadUserInfo,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF0F5C31),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final isDesktop = screenSize.width >= 1200;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Page',
          style: TextStyle(
            fontSize: isSmallScreen ? 20 : 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingWidget()
            : _errorMessage != null
                ? _buildErrorWidget()
                : SingleChildScrollView(
                    child: Center(
                      child: Container(
                        constraints: isDesktop
                            ? const BoxConstraints(maxWidth: 600)
                            : null,
                        child: Column(
                          children: [
                            SizedBox(height: isSmallScreen ? 16 : 20),
                            _buildIntegratedInfoCard(),
                            SizedBox(height: isSmallScreen ? 16 : 20),
                            // 새로고침 버튼
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 12 : 16,
                              ),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    _loadUserInfo();
                                    _loadDeviceLogs();
                                  },
                                  icon: Icon(
                                    Icons.refresh,
                                    size: isSmallScreen ? 18 : 20,
                                  ),
                                  label: Text(
                                    'Refresh',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 14 : 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F5C31),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                      vertical: isSmallScreen ? 12 : 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 16 : 20),
                          ],
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }
}
