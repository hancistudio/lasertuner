import 'package:flutter/material.dart';
import '../models/prediction_model.dart';
import '../models/experiment_model.dart';
import '../services/ml_service.dart';
import '../widgets/custom_button.dart';

class GetPredictionScreen extends StatefulWidget {
  const GetPredictionScreen({super.key});

  @override
  State<GetPredictionScreen> createState() => _GetPredictionScreenState();
}

class _GetPredictionScreenState extends State<GetPredictionScreen>
    with SingleTickerProviderStateMixin {
  // ✅ RENDER.COM API URL
  static const String API_URL = 'https://lasertuner-ml-api.onrender.com';

  final MLService _mlService = MLService();
  final TextEditingController _machineBrandController = TextEditingController();
  final TextEditingController _laserPowerController = TextEditingController();
  final TextEditingController _materialTypeController = TextEditingController();
  final TextEditingController _thicknessController = TextEditingController();

  bool _isLoading = false;
  bool _apiHealthy = false;
  bool _isCheckingHealth = true;
  PredictionResponse? _predictionResult;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final Map<String, bool> _selectedProcesses = {
    'cutting': false,
    'engraving': false,
    'scoring': false,
  };

  // Popüler seçenekler
  final List<String> popularMachines = [
    'Epilog Laser Fusion Pro',
    'Trotec Speedy 400',
    'Universal Laser Systems',
    'Thunder Laser',
    'Diğer',
  ];

  final List<String> popularMaterials = [
    'Ahşap',
    'MDF',
    'Plexiglass',
    'Karton',
    'Deri',
    'Diğer',
  ];

  final List<double> popularPowers = [40, 60, 80, 100, 130];
  final List<double> popularThickness = [3, 4, 5, 6, 8, 10];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _checkApiHealth();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _machineBrandController.dispose();
    _laserPowerController.dispose();
    _materialTypeController.dispose();
    _thicknessController.dispose();
    super.dispose();
  }

  Future<void> _checkApiHealth() async {
    setState(() => _isCheckingHealth = true);

    try {
      print('🔍 Checking API health...');
      final isHealthy = await _mlService.checkHealth();

      if (mounted) {
        setState(() {
          _apiHealthy = isHealthy;
          _isCheckingHealth = false;
        });

        if (isHealthy) {
          _showSnackBar(
            '✅ ML servisi aktif ve hazır!',
            backgroundColor: Colors.green,
          );
        } else {
          _showSnackBar(
            '⚠️ ML servisi yanıt vermiyor. Fallback mode aktif.',
            backgroundColor: Colors.orange,
          );
        }
      }
    } catch (e) {
      print('❌ Health check error: $e');
      if (mounted) {
        setState(() {
          _apiHealthy = false;
          _isCheckingHealth = false;
        });
        _showSnackBar(
          '⚠️ API bağlantısı kurulamadı. Yerel tahmin kullanılacak.',
          backgroundColor: Colors.orange,
        );
      }
    }
  }

  void _getPrediction() {
    // Validasyon
    if (_machineBrandController.text.isEmpty ||
        _laserPowerController.text.isEmpty ||
        _materialTypeController.text.isEmpty ||
        _thicknessController.text.isEmpty) {
      _showSnackBar('Lütfen tüm alanları doldurun');
      return;
    }

    if (!_selectedProcesses.containsValue(true)) {
      _showSnackBar('En az bir işlem tipi seçin');
      return;
    }

    setState(() => _isLoading = true);

    // Async işlemleri buradan başlat
    _performPrediction();
  }

  Future<void> _performPrediction() async {
    try {
      List<String> selectedProcessList =
          _selectedProcesses.entries
              .where((entry) => entry.value)
              .map((entry) => entry.key)
              .toList();

      final request = PredictionRequest(
        machineBrand: _machineBrandController.text,
        laserPower: double.parse(_laserPowerController.text),
        materialType: _materialTypeController.text,
        materialThickness: double.parse(_thicknessController.text),
        processes: selectedProcessList,
      );

      PredictionResponse response;

      // API'yi dene, başarısız olursa fallback kullan
      try {
        print('📤 Sending request to API...');
        response = await _mlService.getPrediction(request);
        print('✅ Prediction received from API');

        setState(() {
          _predictionResult = response;
        });

        _animationController.forward(from: 0);
        _showSnackBar(
          '✅ Tahmin başarıyla alındı!',
          backgroundColor: Colors.green,
        );
      } catch (apiError) {
        print('❌ API error, using fallback: $apiError');

        // Fallback kullan
        response = _mlService.generateFallbackPrediction(request);

        setState(() {
          _predictionResult = response;
        });

        _animationController.forward(from: 0);
        _showSnackBar(
          '⚠️ API kullanılamadı, yerel tahmin kullanıldı',
          backgroundColor: Colors.orange,
        );
      }
    } catch (e) {
      print('❌ Prediction error: $e');
      _showSnackBar('Hata: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Parametre Tahmini',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // API Status Indicator
          if (_isCheckingHealth)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: Icon(
                  _apiHealthy ? Icons.cloud_done : Icons.cloud_off,
                  color: _apiHealthy ? Colors.white : Colors.orange,
                ),
                onPressed: _checkApiHealth,
                tooltip:
                    _apiHealthy
                        ? 'ML Servisi Aktif\n$API_URL'
                        : 'ML Servisi Bağlantı Yok\nTekrar dene',
              ),
            ),
          // Info button
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () => _showInfoDialog(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // API Status Card
                if (!_apiHealthy && !_isCheckingHealth)
                  Card(
                    color: Colors.orange.shade50,
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange.shade700,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'API Bağlantısı Yok',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Yerel tahmin algoritması kullanılacak. '
                                  'İnternet bağlantınızı kontrol edin.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: _checkApiHealth,
                            child: const Text('Tekrar Dene'),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Bilgilendirme kartı
                Card(
                  color: Colors.green.shade50,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: Colors.green.shade700,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Akıllı Tahmin Sistemi',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.green.shade900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Topluluk verilerinden öğrenen ML modeli ile '
                                'en uygun parametreleri tahmin ediyoruz.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Makine bilgileri
                _buildSectionCard(
                  title: '🔧 Makine Bilgileri',
                  isDark: isDark,
                  isLarge: isLargeScreen,
                  children: [
                    _buildDropdownField(
                      label: 'Makine Marka/Model',
                      controller: _machineBrandController,
                      options: popularMachines,
                      icon: Icons.precision_manufacturing,
                    ),
                    const SizedBox(height: 16),
                    _buildChipSelector(
                      label: 'Lazer Gücü (W)',
                      controller: _laserPowerController,
                      options: popularPowers,
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Malzeme bilgileri
                _buildSectionCard(
                  title: '📦 Malzeme Bilgileri',
                  isDark: isDark,
                  isLarge: isLargeScreen,
                  children: [
                    _buildDropdownField(
                      label: 'Malzeme Türü',
                      controller: _materialTypeController,
                      options: popularMaterials,
                      icon: Icons.category,
                    ),
                    const SizedBox(height: 16),
                    _buildChipSelector(
                      label: 'Kalınlık (mm)',
                      controller: _thicknessController,
                      options: popularThickness,
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // İşlem tipleri
                _buildSectionCard(
                  title: '⚙️ İşlem Tipleri',
                  isDark: isDark,
                  isLarge: isLargeScreen,
                  children: [
                    _buildProcessCheckbox(
                      'Kesme',
                      'cutting',
                      Icons.content_cut,
                    ),
                    _buildProcessCheckbox('Kazıma', 'engraving', Icons.draw),
                    _buildProcessCheckbox(
                      'Çizme',
                      'scoring',
                      Icons.border_style,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Tahmin butonu
                CustomButton(
                  text: '🎯 Tahmini Getir',
                  onPressed: _isLoading ? null : _getPrediction,
                  isLoading: _isLoading,
                ),

                // Sonuçlar
                if (_predictionResult != null) ...[
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildPredictionResults(isDark, isLargeScreen),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.green),
                SizedBox(width: 12),
                Text('API Bilgisi'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bu uygulama Render.com üzerinde barındırılan bir ML API kullanır.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'API URL:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SelectableText(
                  API_URL,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 12),
                const Text('Özellikler:'),
                const Text('• Cloud-based ML tahminleri'),
                const Text('• Offline fallback desteği'),
                const Text('• Gerçek zamanlı sağlık kontrolü'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'İlk istek 30-60 saniye sürebilir (cold start)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tamam'),
              ),
            ],
          ),
    );
  }

  // ... (Diğer widget metodları aynı kalacak, sadece ekranın geri kalanı)
  // _buildSectionCard, _buildDropdownField, _buildChipSelector, vs.

  Widget _buildSectionCard({
    required String title,
    required bool isDark,
    required bool isLarge,
    required List<Widget> children,
  }) {
    return Card(
      elevation: isDark ? 2 : 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isLarge ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: isLarge ? 18 : 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required TextEditingController controller,
    required List<String> options,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        suffixIcon: PopupMenuButton<String>(
          icon: const Icon(Icons.arrow_drop_down, color: Colors.green),
          onSelected: (value) {
            if (value == 'Diğer') {
              controller.clear();
            } else {
              controller.text = value;
            }
          },
          itemBuilder: (context) {
            return options.map((option) {
              return PopupMenuItem<String>(
                value: option,
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(option),
                  ],
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  Widget _buildChipSelector({
    required String label,
    required TextEditingController controller,
    required List<double> options,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              options.map((value) {
                final isSelected = controller.text == value.toString();
                return ChoiceChip(
                  label: Text('$value'),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      controller.text = selected ? value.toString() : '';
                    });
                  },
                  selectedColor: Colors.green,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : null,
                    fontWeight: isSelected ? FontWeight.bold : null,
                  ),
                );
              }).toList(),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'veya manuel girin',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _buildProcessCheckbox(String title, String key, IconData icon) {
    return CheckboxListTile(
      title: Row(
        children: [
          Icon(icon, size: 20, color: Colors.green),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      value: _selectedProcesses[key],
      onChanged: (value) {
        setState(() => _selectedProcesses[key] = value ?? false);
      },
      activeColor: Colors.green,
    );
  }

  Widget _buildPredictionResults(bool isDark, bool isLarge) {
    return Card(
      elevation: 4,
      color: isDark ? Colors.grey.shade900 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.green.shade300, width: 2),
      ),
      child: Padding(
        padding: EdgeInsets.all(isLarge ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tahmin Sonuçları',
                        style: TextStyle(
                          fontSize: isLarge ? 20 : 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        '${_predictionResult!.predictions.length} işlem için parametre',
                        style: TextStyle(
                          fontSize: 13,
                          color:
                              isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Güven skoru
            _buildConfidenceScore(isDark, isLarge),
            const SizedBox(height: 20),

            // Her işlem için parametreler
            ..._predictionResult!.predictions.entries.map((entry) {
              return _buildProcessResult(entry, isDark, isLarge);
            }).toList(),

            // Notlar
            if (_predictionResult!.notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      _predictionResult!.confidenceScore >= 0.7
                          ? Colors.blue.shade50
                          : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        _predictionResult!.confidenceScore >= 0.7
                            ? Colors.blue.shade200
                            : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color:
                          _predictionResult!.confidenceScore >= 0.7
                              ? Colors.blue
                              : Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _predictionResult!.notes,
                        style: TextStyle(
                          color:
                              _predictionResult!.confidenceScore >= 0.7
                                  ? Colors.blue.shade900
                                  : Colors.orange.shade900,
                          fontSize: 13,
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
    );
  }

  Widget _buildConfidenceScore(bool isDark, bool isLarge) {
    final confidence = _predictionResult!.confidenceScore;
    final percentage = (confidence * 100).toInt();

    Color getColor() {
      if (confidence >= 0.8) return Colors.green;
      if (confidence >= 0.6) return Colors.orange;
      return Colors.red;
    }

    return Container(
      padding: EdgeInsets.all(isLarge ? 16 : 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [getColor().withOpacity(0.1), getColor().withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: getColor().withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.analytics, color: getColor(), size: isLarge ? 28 : 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Güven Skoru',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '%$percentage',
                  style: TextStyle(
                    fontSize: isLarge ? 24 : 20,
                    fontWeight: FontWeight.bold,
                    color: getColor(),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: isLarge ? 80 : 60,
            height: isLarge ? 80 : 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: confidence,
                  strokeWidth: 6,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(getColor()),
                ),
                Text(
                  percentage >= 80
                      ? '✓'
                      : percentage >= 60
                      ? '!'
                      : '?',
                  style: TextStyle(
                    fontSize: isLarge ? 28 : 24,
                    color: getColor(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessResult(
    MapEntry<String, ProcessParams> entry,
    bool isDark,
    bool isLarge,
  ) {
    String processName =
        entry.key == 'cutting'
            ? 'Kesme'
            : entry.key == 'engraving'
            ? 'Kazıma'
            : 'Çizme';
    ProcessParams params = entry.value;

    IconData icon =
        entry.key == 'cutting'
            ? Icons.content_cut
            : entry.key == 'engraving'
            ? Icons.draw
            : Icons.border_style;

    return Container(
      margin: EdgeInsets.only(bottom: isLarge ? 16 : 12),
      padding: EdgeInsets.all(isLarge ? 16 : 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.green.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.green, size: isLarge ? 24 : 20),
              const SizedBox(width: 8),
              Text(
                processName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isLarge ? 18 : 16,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: isLarge ? 16 : 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildParamChip(
                'Güç',
                '${params.power.toStringAsFixed(1)}%',
                isDark,
              ),
              _buildParamChip(
                'Hız',
                '${params.speed.toStringAsFixed(0)} mm/s',
                isDark,
              ),
              _buildParamChip('Geçiş', '${params.passes}', isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParamChip(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
