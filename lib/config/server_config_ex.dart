/// 서버 설정 파일
class ServerConfig {

  // AWS 퍼블릭 IP로 변경경
  // 파일 이름을 server_config.dart로 변경
  static const String baseUrl = 'AWS_Public_IP:5000';
  // static const String baseUrl = 'AWS_Public_IP:80';

  // API 엔드포인트들
  static const String authEndpoint = '/api/auth';
  static const String deviceEndpoint = '/api/devices';
  static const String deviceRentalEndpoint = '/api/device-rental';
  static const String ocrEndpoint = '/ocr';
  static const String reportEndpoint = '/api/report';
  static const String userEndpoint = '/api';
  
  // 전체 URL 조합 메서드들
  static String get authUrl => baseUrl + authEndpoint;
  static String get deviceUrl => baseUrl + deviceEndpoint;
  static String get deviceRentalUrl => baseUrl + deviceRentalEndpoint;
  static String get ocrUrl => baseUrl + ocrEndpoint;
  static String get reportUrl => baseUrl + reportEndpoint;
  static String get userUrl => baseUrl + userEndpoint;
  
  // 특정 API URL 생성 메서드들
  static String getAuthUrl(String path) => baseUrl + authEndpoint + path;
  static String getDeviceUrl(String path) => baseUrl + deviceEndpoint + path;
  static String getDeviceRentalUrl(String path) => baseUrl + deviceRentalEndpoint + path;
  static String getUserUrl(String path) => baseUrl + userEndpoint + path;
}

