import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/prediction_model.dart';
import '../models/experiment_model.dart';
import '../widgets/custom_button.dart';

class GetPredictionScreen extends StatefulWidget {
  const GetPredictionScreen({Key? key}) : super(key: key);

  @override
  State<GetPredictionScreen> createState() => _GetPredictionScreenState();
}

class _GetPredictionScreenState extends State<GetPredictionScreen>
    with SingleTickerProviderStateMixin {
  // API URL - Render deploy sonrası buraya gerçek URL'i koy
  static const String API_URL = 'https://YOUR-RENDER-APP.onrender.com';

  final TextEditingController _machineBrandController = TextEditingController();
  final TextEditingController _laserPowerController = TextEditingController();
  final TextEditingController _materialTypeController = TextEditingController();
  final TextEditingController _thicknessController = TextEditingController();

  bool _isLoading = false;
  bool _apiHealthy = false;
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
    try {
      final response = await http
          .get(Uri.parse('$API_URL/health'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        setState(() => _apiHealthy = true);
      }
    } catch (e) {
      setState(() => _apiHealthy = false);
      _showSnackBar(
        '⚠️ ML servisi bağlantı hatası. Fallback mode kullanılacak.',
      );
    }
  }

  Future<void> _getPrediction() async {
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

    try {
      List<String> selectedProcessList =
          _selectedProcesses.entries
              .where((entry) => entry.value)
              .map((entry) => entry.key)
              .toList();

      final requestBody = {
        'machineBrand': _machineBrandController.text,
        'laserPower': double.parse(_laserPowerController.text),
        'materialType': _materialTypeController.text,
        'materialThickness': double.parse(_thicknessController.text),
        'processes': selectedProcessList,
      };

      // API'ye istek gönder
      final response = await http
          .post(
            Uri.parse('$API_URL/predict'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('İstek zaman aşımına uğradı');
            },
          );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        setState(() {
          _predictionResult = PredictionResponse.fromMap(data);
        });
        _animationController.forward(from: 0);
        _showSnackBar('✅ Tahmin başarıyla alındı!');
      } else {
        throw Exception('API Hatası: ${response.statusCode}');
      }
    } catch (e) {
      _showSnackBar('Hata: ${e.toString()}');
      // Fallback: Basit tahmin
      _generateFallbackPrediction();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _generateFallbackPrediction() {
    Map<String, ProcessParams> predictions = {};
    double thickness = double.parse(_thicknessController.text);

    _selectedProcesses.forEach((processType, isSelected) {
      if (isSelected) {
        if (processType == 'cutting') {
          predictions[processType] = ProcessParams(
            power: 70 + (thickness * 3),
            speed: 300 - (thickness * 20),
            passes: (thickness / 4).ceil(),
          );
        } else if (processType == 'engraving') {
          predictions[processType] = ProcessParams(
            power: 40 + (thickness * 2),
            speed: 500 - (thickness * 15),
            passes: 1,
          );
        } else if (processType == 'scoring') {
          predictions[processType] = ProcessParams(
            power: 55 + (thickness * 2.5),
            speed: 400 - (thickness * 18),
            passes: 1,
          );
        }
      }
    });

    setState(() {
      _predictionResult = PredictionResponse(
        predictions: predictions,
        confidenceScore: 0.5,
        notes:
            '⚠️ Bu tahmin basit bir algoritmaya dayanıyor. ML servisi bağlantısı kurulamadı.',
      );
    });
    _animationController.forward(from: 0);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          IconButton(
            icon: Icon(
              _apiHealthy ? Icons.cloud_done : Icons.cloud_off,
              color: _apiHealthy ? Colors.white : Colors.orange,
            ),
            onPressed: _checkApiHealth,
            tooltip:
                _apiHealthy ? 'ML Servisi Aktif' : 'ML Servisi Bağlantı Yok',
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
                                'Makine öğrenmesi ile topluluk verilerinden en uygun parametreleri tahmin ediyoruz.',
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
                  onPressed: _getPrediction,
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
    return CustomTextField(
      controller: controller,
      label: label,
      suffixIcon: PopupMenuButton<String>(
        icon: Icon(Icons.arrow_drop_down, color: Colors.green),
        onSelected: (value) {
          if (value == 'Diğer') {
            // Kullanıcı manuel girecek
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
        CustomTextField(
          controller: controller,
          label: 'veya manuel girin',
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
          Container(
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

// CustomTextField için suffix icon desteği ekle
class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType keyboardType;
  final Widget? suffixIcon;

  const CustomTextField({
    Key? key,
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.suffixIcon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
