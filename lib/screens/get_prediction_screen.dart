import 'package:flutter/material.dart';
import 'package:lasertuner/config/app_config.dart';
import '../models/prediction_model.dart';
import '../models/experiment_model.dart';
import '../services/ml_service.dart';
import '../services/gemini_ai_service.dart';
import '../widgets/custom_button.dart';

class GetPredictionScreen extends StatefulWidget {
  const GetPredictionScreen({super.key});

  @override
  State<GetPredictionScreen> createState() => _GetPredictionScreenState();
}

class _GetPredictionScreenState extends State<GetPredictionScreen>
    with SingleTickerProviderStateMixin {
  // ✅ Services
  final MLService _mlService = MLService();
  final GeminiAIService _geminiService = GeminiAIService();

  // ✅ Controllers
  final TextEditingController _machineBrandController = TextEditingController();
  final TextEditingController _laserPowerController = TextEditingController();
  final TextEditingController _materialTypeController = TextEditingController();
  final TextEditingController _thicknessController = TextEditingController();

  // ✅ State
  bool _isLoading = false;
  bool _apiHealthy = false;
  bool _isCheckingHealth = true;
  PredictionResponse? _mlPrediction;
  PredictionResponse? _geminiPrediction;
  String? _selectedPredictionSource; // 'ml' veya 'gemini'
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final Map<String, bool> _selectedProcesses = {
    'cutting': false,
    'engraving': false,
    'scoring': false,
  };

  // ✅ Popüler seçenekler
  final List<String> popularMachines = [
    'xTool D1 Pro',
    'Atomstack A5',
    'Ortur Laser Master 3',
    'Sculpfun S9',
    'Creality Falcon',
    'TwoTrees',
    'Diğer',
  ];

  final List<String> popularMaterials = [
    'Ahşap',
    'MDF',
    'Karton',
    'Deri',
    'Keçe',
    'Kumaş',
    'Kağıt',
    'Köpük',
    'Mantar',
    'Diğer',
  ];

  final List<double> popularPowers = [5, 10, 15, 20, 30, 40];
  final List<double> popularThickness = [1, 2, 3, 4, 5, 6, 8];

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
            '⚠️ ML servisi yanıt vermiyor. Gemini AI kullanılabilir.',
            backgroundColor: Colors.orange,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _apiHealthy = false;
          _isCheckingHealth = false;
        });
        _showSnackBar(
          '⚠️ API bağlantısı kurulamadı. Gemini AI kullanın.',
          backgroundColor: Colors.orange,
        );
      }
    }
  }

  bool _validateInputs() {
    if (_machineBrandController.text.isEmpty ||
        _laserPowerController.text.isEmpty ||
        _materialTypeController.text.isEmpty ||
        _thicknessController.text.isEmpty) {
      _showSnackBar('❌ Lütfen tüm alanları doldurun');
      return false;
    }

    // Malzeme kontrolü
    for (String unsupported in AppConfig.UNSUPPORTED_MATERIALS) {
      if (_materialTypeController.text.toLowerCase().contains(
        unsupported.toLowerCase(),
      )) {
        _showSnackBar(
          '⚠️ ${_materialTypeController.text} diode lazer için uygun değil! CO2 lazer gerektirir.',
          backgroundColor: Colors.red,
        );
        return false;
      }
    }

    // Güç ve kalınlık kontrolü
    final power = double.tryParse(_laserPowerController.text) ?? 0;
    final thickness = double.tryParse(_thicknessController.text) ?? 0;

    if (power < AppConfig.MIN_LASER_POWER ||
        power > AppConfig.MAX_LASER_POWER) {
      _showSnackBar(
        '⚠️ Lazer gücü ${AppConfig.MIN_LASER_POWER}W - ${AppConfig.MAX_LASER_POWER}W arasında olmalı!',
        backgroundColor: Colors.red,
      );
      return false;
    }

    if (thickness > AppConfig.MAX_THICKNESS) {
      _showSnackBar(
        '⚠️ Diode lazerler max ${AppConfig.MAX_THICKNESS}mm kesebilir!',
        backgroundColor: Colors.orange,
      );
      return false;
    }

    if (!_selectedProcesses.containsValue(true)) {
      _showSnackBar('❌ En az bir işlem tipi seçin');
      return false;
    }

    return true;
  }

  // 🤖 ML API ile tahmin al
  Future<void> _getPredictionFromML() async {
    if (!_validateInputs()) return;

    setState(() {
      _isLoading = true;
      _mlPrediction = null;
      _selectedPredictionSource = 'ml';
    });

    try {
      final request = _buildPredictionRequest();
      final response = await _mlService.getPrediction(request);

      setState(() {
        _mlPrediction = response;
      });

      _animationController.forward(from: 0);
      _showSnackBar(
        '✅ ML tahmini başarıyla alındı!',
        backgroundColor: Colors.green,
      );
    } catch (e) {
      print('❌ ML prediction error: $e');
      _showSnackBar('❌ ML tahmini alınamadı: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 🧠 Gemini AI ile tahmin al
  Future<void> _getPredictionFromGemini() async {
    if (!_validateInputs()) return;

    setState(() {
      _isLoading = true;
      _geminiPrediction = null;
      _selectedPredictionSource = 'gemini';
    });

    try {
      final request = _buildPredictionRequest();
      final response = await _geminiService.getPredictionWithGemini(request);

      setState(() {
        _geminiPrediction = response;
      });

      _animationController.forward(from: 0);
      _showSnackBar(
        '✅ Gemini AI tahmini başarıyla alındı!',
        backgroundColor: Colors.purple,
      );
    } catch (e) {
      print('❌ Gemini prediction error: $e');
      _showSnackBar('❌ Gemini AI tahmini alınamadı: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 🔀 Her iki tahmini karşılaştır
  Future<void> _getComparativePredictions() async {
    if (!_validateInputs()) return;

    setState(() {
      _isLoading = true;
      _mlPrediction = null;
      _geminiPrediction = null;
      _selectedPredictionSource = 'both';
    });

    try {
      final request = _buildPredictionRequest();

      // Paralel olarak her iki tahmini al
      final results = await Future.wait([
        _mlService.getPrediction(request).catchError((e) {
          print('ML error: $e');
          return _mlService.generateFallbackPrediction(request);
        }),
        _geminiService.getPredictionWithGemini(request),
      ]);

      setState(() {
        _mlPrediction = results[0];
        _geminiPrediction = results[1];
      });

      _animationController.forward(from: 0);
      _showSnackBar(
        '✅ Her iki tahmin de alındı! Karşılaştırabilirsiniz.',
        backgroundColor: Colors.blue,
      );
    } catch (e) {
      print('❌ Comparative prediction error: $e');
      _showSnackBar('❌ Tahminler alınamadı: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  PredictionRequest _buildPredictionRequest() {
    List<String> selectedProcessList =
        _selectedProcesses.entries
            .where((entry) => entry.value)
            .map((entry) => entry.key)
            .toList();

    return PredictionRequest(
      machineBrand: _machineBrandController.text,
      laserPower: double.parse(_laserPowerController.text),
      materialType: _materialTypeController.text,
      materialThickness: double.parse(_thicknessController.text),
      processes: selectedProcessList,
    );
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
          // API Status
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
            IconButton(
              icon: Icon(
                _apiHealthy ? Icons.cloud_done : Icons.cloud_off,
                color: _apiHealthy ? Colors.white : Colors.orange,
              ),
              onPressed: _checkApiHealth,
              tooltip:
                  _apiHealthy ? 'ML Servisi Aktif' : 'ML Servisi Bağlantı Yok',
            ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: _showInfoDialog,
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
                if (!_apiHealthy && !_isCheckingHealth) _buildApiStatusCard(),

                // Info Card
                _buildInfoCard(isDark),
                const SizedBox(height: 24),

                // Makine Bilgileri
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

                // Malzeme Bilgileri
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

                // İşlem Tipleri
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

                // 🎯 TAHMİN BUTONLARI
                _buildPredictionButtons(isLargeScreen),

                // Sonuçlar
                if (_mlPrediction != null || _geminiPrediction != null) ...[
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

  // 🎯 TAHMİN BUTONLARI
  Widget _buildPredictionButtons(bool isLargeScreen) {
    return Column(
      children: [
        // ML API Butonu
        CustomButton(
          text: '🤖 ML API ile Tahmin Al',
          onPressed: _isLoading ? null : _getPredictionFromML,
          isLoading: _isLoading && _selectedPredictionSource == 'ml',
          backgroundColor: Colors.green,
        ),
        const SizedBox(height: 12),

        // Gemini AI Butonu
        CustomButton(
          text: '🧠 Gemini AI ile Tahmin Al',
          onPressed: _isLoading ? null : _getPredictionFromGemini,
          isLoading: _isLoading && _selectedPredictionSource == 'gemini',
          backgroundColor: Colors.purple,
        ),
        const SizedBox(height: 12),

        // Karşılaştırmalı Tahmin Butonu
        CustomButton(
          text: '🔀 Her İkisini Karşılaştır',
          onPressed: _isLoading ? null : _getComparativePredictions,
          isLoading: _isLoading && _selectedPredictionSource == 'both',
          backgroundColor: Colors.blue,
        ),
      ],
    );
  }

  // API Status Card
  Widget _buildApiStatusCard() {
    return Card(
      color: Colors.orange.shade50,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    'ML API Bağlantısı Yok',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gemini AI kullanabilir veya bağlantıyı tekrar deneyebilirsiniz.',
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
    );
  }

  // Info Card
  Widget _buildInfoCard(bool isDark) {
    return Card(
      color: Colors.green.shade50,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    'ML API (topluluk verisi) veya Gemini AI (yapay zeka) ile tahmin alın.',
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
    );
  }

  // Info Dialog
  void _showInfoDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 12),
                Text('Tahmin Kaynakları'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoSection(
                    '🤖 ML API',
                    'Topluluk deneylerinden öğrenen makine öğrenmesi modeli. '
                        'Gerçek kullanıcı verilerine dayalı tahminler.',
                  ),
                  const SizedBox(height: 16),
                  _buildInfoSection(
                    '🧠 Gemini AI',
                    'Google\'ın yapay zeka modeli. Geniş bilgi tabanından '
                        'akıllı öneriler sunar.',
                  ),
                  const SizedBox(height: 16),
                  _buildInfoSection(
                    '🔀 Karşılaştırma',
                    'Her iki kaynaktan da tahmin alıp karşılaştırabilirsiniz. '
                        'En uygun parametreleri seçin.',
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    '✅ Desteklenen Malzemeler:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...AppConfig.SUPPORTED_MATERIALS
                      .map((m) => Text('  • $m'))
                      .toList(),
                  const SizedBox(height: 12),
                  const Text(
                    '❌ Desteklenmeyen:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  ...AppConfig.UNSUPPORTED_MATERIALS
                      .map(
                        (m) => Text(
                          '  • $m (CO2 gerektirir)',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      )
                      .toList(),
                ],
              ),
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

  Widget _buildInfoSection(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 4),
        Text(description, style: const TextStyle(fontSize: 13, height: 1.4)),
      ],
    );
  }

  // Section Card
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

  // Dropdown Field
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

  // Chip Selector
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

  // Process Checkbox
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

  // 📊 SONUÇLAR
  Widget _buildPredictionResults(bool isDark, bool isLargeScreen) {
    if (_selectedPredictionSource == 'both') {
      // Karşılaştırmalı görünüm
      return Column(
        children: [
          if (_mlPrediction != null)
            _buildSinglePredictionCard(
              _mlPrediction!,
              '🤖 ML API Tahmini',
              Colors.green,
              isDark,
              isLargeScreen,
            ),
          const SizedBox(height: 16),
          if (_geminiPrediction != null)
            _buildSinglePredictionCard(
              _geminiPrediction!,
              '🧠 Gemini AI Tahmini',
              Colors.purple,
              isDark,
              isLargeScreen,
            ),
        ],
      );
    } else if (_selectedPredictionSource == 'ml' && _mlPrediction != null) {
      return _buildSinglePredictionCard(
        _mlPrediction!,
        '🤖 ML API Tahmini',
        Colors.green,
        isDark,
        isLargeScreen,
      );
    } else if (_selectedPredictionSource == 'gemini' &&
        _geminiPrediction != null) {
      return _buildSinglePredictionCard(
        _geminiPrediction!,
        '🧠 Gemini AI Tahmini',
        Colors.purple,
        isDark,
        isLargeScreen,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildSinglePredictionCard(
    PredictionResponse result,
    String title,
    Color accentColor,
    bool isDark,
    bool isLarge,
  ) {
    return Card(
      elevation: 4,
      color: isDark ? Colors.grey.shade900 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accentColor.withOpacity(0.5), width: 2),
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
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.check_circle, color: accentColor, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: isLarge ? 20 : 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result.dataSource == 'gemini_ai'
                            ? 'Yapay Zeka Önerisi'
                            : 'Topluluk Verisi',
                        style: TextStyle(
                          fontSize: 12,
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

            // Güven Skoru
            _buildConfidenceScore(result, accentColor, isDark, isLarge),
            const SizedBox(height: 20),

            // Parametreler
            ...result.predictions.entries.map((entry) {
              return _buildProcessResult(entry, accentColor, isDark, isLarge);
            }).toList(),

            // Notlar
            if (result.notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: accentColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        result.notes,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
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

  Widget _buildConfidenceScore(
    PredictionResponse result,
    Color accentColor,
    bool isDark,
    bool isLarge,
  ) {
    final confidence = result.confidenceScore;
    final percentage = (confidence * 100).toInt();

    return Container(
      padding: EdgeInsets.all(isLarge ? 16 : 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accentColor.withOpacity(0.1), accentColor.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.analytics, color: accentColor, size: isLarge ? 28 : 24),
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
                    color: accentColor,
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
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
                Text(
                  percentage >= 80
                      ? '✓'
                      : percentage >= 60
                      ? '!'
                      : '?',
                  style: TextStyle(
                    fontSize: isLarge ? 28 : 24,
                    color: accentColor,
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
    Color accentColor,
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
        color: accentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: isLarge ? 24 : 20),
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
                accentColor,
              ),
              _buildParamChip(
                'Hız',
                '${params.speed.toStringAsFixed(0)} mm/s',
                accentColor,
              ),
              _buildParamChip('Geçiş', '${params.passes}', accentColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParamChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
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
