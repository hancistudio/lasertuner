import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  late FirebaseRemoteConfig _remoteConfig;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    _remoteConfig = FirebaseRemoteConfig.instance;

    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ),
    );

    // Default değerler
    await _remoteConfig.setDefaults({
      'admin_password': 'laser2025',
      'ml_api_url': 'http://localhost:8000',
      'max_image_size_mb': 5,
    });

    try {
      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      print('Remote Config fetch error: $e');
    }

    _initialized = true;
  }

  String get adminPassword => _remoteConfig.getString('admin_password');
  String get mlApiUrl => _remoteConfig.getString('ml_api_url');
  int get maxImageSizeMb => _remoteConfig.getInt('max_image_size_mb');
}
