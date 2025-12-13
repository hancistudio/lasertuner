class AppConfig {
  // Admin şifresi
  static const String ADMIN_PASSWORD = 'laser2025';

  // ML API URL
  static const String ML_API_URL = 'https://lasertuner-ml-api.onrender.com';

  // Firebase Storage
  static const String STORAGE_BUCKET = 'gs://your-project-id.appspot.com';

  // DIODE LASER LIMITS
  static const int MAX_IMAGE_SIZE_MB = 5;
  static const double MIN_LASER_POWER = 2.0;
  static const double MAX_LASER_POWER = 40.0;
  static const double MIN_THICKNESS = 1.0;
  static const double MAX_THICKNESS = 10.0;

  // Reputation kuralları
  static const int REPUTATION_ADD_DATA = 5;
  static const int REPUTATION_UPVOTE = 2;
  static const int REPUTATION_DOWNVOTE = -1;
  static const int REPUTATION_GOLD_STANDARD = 20;

  // ===== DESTEKLENMEYEcek MALZEMELER (Uyarı için) =====
  static const List<String> UNSUPPORTED_MATERIALS = [
    'Metal',
    'Çelik',
    'Paslanmaz Çelik',
    'Bakır',
    'Pirinç',
    'Cam',
    'Seramik',
    'Taş',
    'Mermer',
    'Granit',
  ];

  // ===== DESTEKLENEN MALZEMELER =====
  static const List<String> SUPPORTED_MATERIALS = [
    'Ahşap',
    'MDF',
    'Kontrplak',
    'Karton',
    'Deri',
    'Keçe',
    'Kumaş',
    'Kağıt',
    'Köpük',
    'Mantar',
    'Bambu',
  ];

  // ===== DESTEKLENEN MAKİNE MODELLERİ =====
  static const List<Map<String, dynamic>> SUPPORTED_MACHINES = [
    {
      'name': 'xTool D1 Pro',
      'brand': 'xTool',
      'defaultPower': 20.0,
      'powerRange': [5.0, 10.0, 20.0, 40.0],
      'icon': '🔥',
      'maxThickness': 8.0,
    },
    {
      'name': 'Sculpfun SF-A9',
      'brand': 'Sculpfun',
      'defaultPower': 33.0,
      'powerRange': [10.0, 20.0, 33.0],
      'icon': '⚡',
      'maxThickness': 8.0,
    },
    {
      'name': 'xTool S1',
      'brand': 'xTool',
      'defaultPower': 40.0,
      'powerRange': [10.0, 20.0, 40.0],
      'icon': '💎',
      'maxThickness': 10.0,
    },
    {
      'name': 'Ortur Laser Master 3',
      'brand': 'Ortur',
      'defaultPower': 10.0,
      'powerRange': [5.0, 10.0, 20.0],
      'icon': '🎯',
      'maxThickness': 6.0,
    },
    {
      'name': 'Atomstack S20 Pro',
      'brand': 'Atomstack',
      'defaultPower': 20.0,
      'powerRange': [5.0, 10.0, 20.0],
      'icon': '🚀',
      'maxThickness': 8.0,
    },
    {
      'name': 'Sculpfun S30 Pro Max',
      'brand': 'Sculpfun',
      'defaultPower': 33.0,
      'powerRange': [10.0, 20.0, 33.0],
      'icon': '💪',
      'maxThickness': 8.0,
    },
    {
      'name': 'LaserPecker 3',
      'brand': 'LaserPecker',
      'defaultPower': 10.0,
      'powerRange': [2.0, 5.0, 10.0],
      'icon': '🌟',
      'maxThickness': 5.0,
    },
    {
      'name': 'Longer Laser B1',
      'brand': 'Longer',
      'defaultPower': 40.0,
      'powerRange': [10.0, 20.0, 40.0],
      'icon': '🦅',
      'maxThickness': 10.0,
    },
    {
      'name': 'xTool F1',
      'brand': 'xTool',
      'defaultPower': 20.0,
      'powerRange': [5.0, 10.0, 20.0],
      'icon': '✨',
      'maxThickness': 6.0,
    },
    {
      'name': 'TwoTrees TTS Series',
      'brand': 'TwoTrees',
      'defaultPower': 20.0,
      'powerRange': [5.0, 10.0, 20.0, 40.0],
      'icon': '🌲',
      'maxThickness': 8.0,
    },
    {
      'name': 'Diğer',
      'brand': 'Custom',
      'defaultPower': 20.0,
      'powerRange': [2.0, 5.0, 10.0, 15.0, 20.0, 25.0, 30.0, 33.0, 35.0, 40.0],
      'icon': '🔧',
      'maxThickness': 10.0,
    },
  ];

  // ===== STANDART GÜÇ DEĞERLERİ (2-40W) =====
  static const List<double> STANDARD_POWER_VALUES = [
    2.0, 3.0, 5.0, 7.0, 10.0, 15.0, 20.0, 25.0, 30.0, 33.0, 35.0, 40.0,
  ];

  // ===== KALINLIK DEĞERLERİ (1-10mm) =====
  static const List<double> THICKNESS_VALUES = [
    1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5,
    6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0,
  ];

  // ===== MALZEME KATEGORİLERİ =====
  static const Map<String, List<Map<String, dynamic>>> MATERIAL_CATEGORIES = {
    'Ahşap Ürünleri': [
      {
        'name': 'Ahşap',
        'key': 'ahsap',
        'icon': '🪵',
        'maxThickness': 8.0,
        'difficulty': 'Orta',
      },
      {
        'name': 'Kontrplak',
        'key': 'kontrplak',
        'icon': '🪵',
        'maxThickness': 10.0,
        'difficulty': 'Orta',
      },
      {
        'name': 'MDF',
        'key': 'mdf',
        'icon': '📦',
        'maxThickness': 8.0,
        'difficulty': 'Orta',
      },
      {
        'name': 'Balsa Ağacı',
        'key': 'balsa',
        'icon': '🌳',
        'maxThickness': 10.0,
        'difficulty': 'Kolay',
      },
      {
        'name': 'Bambu',
        'key': 'bambu',
        'icon': '🎋',
        'maxThickness': 8.0,
        'difficulty': 'Orta',
      },
      {
        'name': 'Kayın',
        'key': 'kayin',
        'icon': '🌲',
        'maxThickness': 6.0,
        'difficulty': 'Zor',
      },
      {
        'name': 'Meşe',
        'key': 'mese',
        'icon': '🌳',
        'maxThickness': 5.0,
        'difficulty': 'Zor',
      },
      {
        'name': 'Ceviz',
        'key': 'ceviz',
        'icon': '🌰',
        'maxThickness': 5.0,
        'difficulty': 'Zor',
      },
      {
        'name': 'Akçaağaç',
        'key': 'akcaagac',
        'icon': '🍁',
        'maxThickness': 5.0,
        'difficulty': 'Zor',
      },
      {
        'name': 'Huş Ağacı',
        'key': 'hus',
        'icon': '🌲',
        'maxThickness': 6.0,
        'difficulty': 'Orta',
      },
      {
        'name': 'Çam',
        'key': 'cam',
        'icon': '🌲',
        'maxThickness': 6.0,
        'difficulty': 'Orta',
      },
    ],
    'Organik Malzemeler': [
      {
        'name': 'Deri',
        'key': 'deri',
        'icon': '🧥',
        'maxThickness': 5.0,
        'difficulty': 'Kolay',
      },
      {
        'name': 'Karton',
        'key': 'karton',
        'icon': '📦',
        'maxThickness': 5.0,
        'difficulty': 'Çok Kolay',
      },
      {
        'name': 'Kağıt',
        'key': 'kagit',
        'icon': '📄',
        'maxThickness': 2.0,
        'difficulty': 'Çok Kolay',
      },
      {
        'name': 'Kumaş',
        'key': 'kumas',
        'icon': '🧵',
        'maxThickness': 3.0,
        'difficulty': 'Çok Kolay',
      },
      {
        'name': 'Keçe',
        'key': 'kece',
        'icon': '🧶',
        'maxThickness': 4.0,
        'difficulty': 'Çok Kolay',
      },
      {
        'name': 'Mantar',
        'key': 'mantar',
        'icon': '🍄',
        'maxThickness': 6.0,
        'difficulty': 'Kolay',
      },
    ],
    'Sentetik Malzemeler': [
      {
        'name': 'Akrilik',
        'key': 'akrilik',
        'icon': '💎',
        'maxThickness': 3.0,
        'difficulty': 'Orta',
        'warning': 'Sadece bazı diode lazerler destekler',
      },
      {
        'name': 'Lastik',
        'key': 'lastik',
        'icon': '⚫',
        'maxThickness': 5.0,
        'difficulty': 'Orta',
      },
      {
        'name': 'Köpük',
        'key': 'kopuk',
        'icon': '🧽',
        'maxThickness': 10.0,
        'difficulty': 'Çok Kolay',
      },
    ],
    'Metal (Sınırlı)': [
      {
        'name': 'Anodize Alüminyum',
        'key': 'anodize_aluminyum',
        'icon': '⚙️',
        'maxThickness': 1.0,
        'difficulty': 'Çok Zor',
        'warning': 'Sadece markalama için, kesim değil',
      },
    ],
    'Diğer': [
      {
        'name': 'Diğer Malzeme',
        'key': 'diger',
        'icon': '❓',
        'maxThickness': 10.0,
        'difficulty': 'Bilinmiyor',
      },
    ],
  };

  // ===== HELPER METHODS =====

  static String getMaterialKeyFromDisplayName(String displayName) {
    final normalized = displayName.toLowerCase().trim();
    // Tüm kategorilerde ara
    for (var category in MATERIAL_CATEGORIES.values) {
      for (var material in category) {
        final materialName = (material['name'] as String).toLowerCase();
        final materialKey = material['key'] as String;
        if (normalized == materialName || normalized == materialKey) {
          return materialKey;
        }
      }
    }
    // Bulunamazsa, normalize edilmiş versiyonu döndür
    return _normalizeForBackend(normalized);
  }

  static String _normalizeForBackend(String text) {
    return text
        .toLowerCase()
        .replaceAll('ş', 's')
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ı', 'i')
        .replaceAll(' ', '_')
        .trim();
  }

  /// ✅ YENİ: Material key'den backend-safe key'e çevirme
  static String getMaterialBackendKey(String materialKey) {
    return _normalizeForBackend(materialKey);
  }

  /// Makine adından güç aralığını al
  static List<double> getPowerRangeForMachine(String machineName) {
    final machine = SUPPORTED_MACHINES.firstWhere(
      (m) => m['name'] == machineName,
      orElse: () => SUPPORTED_MACHINES.last, // Diğer
    );
    return List<double>.from(machine['powerRange']);
  }

  /// Makine adından varsayılan gücü al
  static double getDefaultPowerForMachine(String machineName) {
    final machine = SUPPORTED_MACHINES.firstWhere(
      (m) => m['name'] == machineName,
      orElse: () => SUPPORTED_MACHINES.last,
    );
    return machine['defaultPower'].toDouble();
  }

  /// Makine adından max kalınlık al
  static double getMaxThicknessForMachine(String machineName) {
    final machine = SUPPORTED_MACHINES.firstWhere(
      (m) => m['name'] == machineName,
      orElse: () => SUPPORTED_MACHINES.last,
    );
    return machine['maxThickness']?.toDouble() ?? MAX_THICKNESS;
  }

  /// Malzeme için maksimum kalınlık
  static double getMaxThicknessForMaterial(String materialKey) {
    for (var category in MATERIAL_CATEGORIES.values) {
      final material = category.firstWhere(
        (m) => m['key'] == materialKey,
        orElse: () => {},
      );
      if (material.isNotEmpty) {
        return material['maxThickness']?.toDouble() ?? MAX_THICKNESS;
      }
    }
    return MAX_THICKNESS;
  }

  /// Tüm malzemeleri düz liste olarak al
  static List<Map<String, dynamic>> getAllMaterials() {
    List<Map<String, dynamic>> allMaterials = [];
    MATERIAL_CATEGORIES.forEach((category, materials) {
      allMaterials.addAll(materials);
    });
    return allMaterials;
  }

  /// Malzeme key'inden görünen adı al
  static String getMaterialDisplayName(String materialKey) {
    for (var category in MATERIAL_CATEGORIES.values) {
      final material = category.firstWhere(
        (m) => m['key'] == materialKey,
        orElse: () => {},
      );
      if (material.isNotEmpty) {
        return material['name'];
      }
    }
    return materialKey;
  }

  /// Malzeme key'inden kategori al
  static String getMaterialCategory(String materialKey) {
    for (var entry in MATERIAL_CATEGORIES.entries) {
      final material = entry.value.firstWhere(
        (m) => m['key'] == materialKey,
        orElse: () => {},
      );
      if (material.isNotEmpty) {
        return entry.key;
      }
    }
    return 'Diğer';
  }

  /// Malzeme key'inden ikon al
  static String getMaterialIcon(String materialKey) {
    for (var category in MATERIAL_CATEGORIES.values) {
      final material = category.firstWhere(
        (m) => m['key'] == materialKey,
        orElse: () => {},
      );
      if (material.isNotEmpty) {
        return material['icon'] ?? '❓';
      }
    }
    return '❓';
  }

  /// Malzeme key'inden zorluk al
  static String getMaterialDifficulty(String materialKey) {
    for (var category in MATERIAL_CATEGORIES.values) {
      final material = category.firstWhere(
        (m) => m['key'] == materialKey,
        orElse: () => {},
      );
      if (material.isNotEmpty) {
        return material['difficulty'] ?? 'Bilinmiyor';
      }
    }
    return 'Bilinmiyor';
  }

  /// Malzeme key'inden uyarı al
  static String? getMaterialWarning(String materialKey) {
    for (var category in MATERIAL_CATEGORIES.values) {
      final material = category.firstWhere(
        (m) => m['key'] == materialKey,
        orElse: () => {},
      );
      if (material.isNotEmpty) {
        return material['warning'];
      }
    }
    return null;
  }

  /// Kalınlık değeri için en yakın standart değeri bul
  static double getNearestThickness(double value) {
    return THICKNESS_VALUES.reduce((a, b) {
      return (a - value).abs() < (b - value).abs() ? a : b;
    });
  }

  /// Güç değeri için en yakın standart değeri bul
  static double getNearestPower(double value) {
    return STANDARD_POWER_VALUES.reduce((a, b) {
      return (a - value).abs() < (b - value).abs() ? a : b;
    });
  }

  /// Makine için önerilen malzemeleri al
  static List<String> getRecommendedMaterialsForMachine(String machineName) {
    final maxThickness = getMaxThicknessForMachine(machineName);
    final allMaterials = getAllMaterials();
    return allMaterials
        .where((m) => (m['maxThickness'] ?? 10.0) <= maxThickness)
        .map((m) => m['key'] as String)
        .toList();
  }

  /// Malzeme için önerilen makineleri al
  static List<String> getRecommendedMachinesForMaterial(String materialKey) {
    final materialMaxThickness = getMaxThicknessForMaterial(materialKey);
    return SUPPORTED_MACHINES
        .where((m) => (m['maxThickness'] ?? 10.0) >= materialMaxThickness)
        .map((m) => m['name'] as String)
        .toList();
  }
}