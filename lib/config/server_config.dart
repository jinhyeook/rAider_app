/// 서버 설정을 중앙에서 관리하는 클래스
class ServerConfig {
  // 서버 기본 URL
  static const String baseUrl = 'http://192.168.55.92:5000'; // 로컬 서버 주소(데스크탑)
  // static const String _baseUrl = 'http://3.34.48.22:5000'; // AWS 서버 주소
  //static const String _baseUrl = 'http://192.168.45.193:5000'; // 로컬 서버 주소(노트북)
  //static const String _baseUrl = 'http://192.168.173.229:5000'; // 로컬 서버 주소(핫스팟)
  
  
  // API 엔드포인트들
  static const String authEndpoint = '/api/auth';
  static const String deviceEndpoint = '/api/device';
  static const String deviceRentalEndpoint = '/api/device-rental';
  static const String ocrEndpoint = '/ocr';
  static const String reportEndpoint = '/api/report';
  static const String userEndpoint = '/api/user';
  
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
  
  // 서버 주소 변경 시 사용할 메서드 (필요시)
  static void updateBaseUrl(String newBaseUrl) {
    // 현재는 const로 정의되어 있어 런타임에 변경 불가
    // 필요시 const를 제거하고 setter를 추가할 수 있음
  }
}
