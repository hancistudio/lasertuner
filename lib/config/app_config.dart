class AppConfig {
  // Admin şifresi
  static const String ADMIN_PASSWORD = 'laser2025';

  // ✨ DIODE LASER API URL
  static const String ML_API_URL = 'https://lasertuner-ml-api.onrender.com';

  // Firebase Storage
  static const String STORAGE_BUCKET = 'gs://your-project-id.appspot.com';

  // ✨ DIODE LASER LIMITS
  static const int MAX_IMAGE_SIZE_MB = 5;
  static const double MIN_LASER_POWER = 2.0; // 2W minimum
  static const double MAX_LASER_POWER = 40.0; // 40W maximum
  static const double MAX_THICKNESS = 10.0; // 10mm maximum

  // Reputation kuralları
  static const int REPUTATION_ADD_DATA = 5;
  static const int REPUTATION_UPVOTE = 2;
  static const int REPUTATION_DOWNVOTE = -1;
  static const int REPUTATION_GOLD_STANDARD = 20;

  // ✨ DIODE LASER SUPPORTED MATERIALS
  static const List<String> SUPPORTED_MATERIALS = [
    'Ahşap',
    'MDF',
    'Karton',
    'Deri',
    'Keçe',
    'Kumaş',
    'Kağıt',
    'Köpük',
    'Mantar',
  ];

  // ✨ NOT SUPPORTED MATERIALS (Warning)
  static const List<String> UNSUPPORTED_MATERIALS = [
    'Akrilik',
    'Plexiglass',
    'Metal',
    'Cam',
    'Seramik',
  ];
}
