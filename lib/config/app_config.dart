class AppConfig {
  // Admin şifresi - Production'da environment variable'dan alınmalı
  static const String ADMIN_PASSWORD = 'laser2025';

  // API endpoint
  static const String ML_API_URL = 'http://localhost:8000';

  // Firebase Storage
  static const String STORAGE_BUCKET = 'gs://your-project-id.appspot.com';

  // Diğer config değerleri
  static const int MAX_IMAGE_SIZE_MB = 5;
  static const int MIN_REPUTATION = 0;
  static const int MAX_REPUTATION = 1000;

  // Reputation kazanma kuralları
  static const int REPUTATION_ADD_DATA = 5;
  static const int REPUTATION_UPVOTE = 2;
  static const int REPUTATION_DOWNVOTE = -1;
  static const int REPUTATION_GOLD_STANDARD = 20;
}
