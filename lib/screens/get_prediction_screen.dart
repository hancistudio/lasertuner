import 'package:flutter/material.dart';
import 'package:lasertuner/config/app_config.dart';
import '../models/prediction_model.dart';
import '../models/experiment_model.dart';
import '../services/ml_service.dart';
import '../services/gemini_ai_service.dart';

class GetPredictionScreen extends StatefulWidget {
  const GetPredictionScreen({super.key});

  @override
  State<GetPredictionScreen> createState() => _GetPredictionScreenState();
}

class _GetPredictionScreenState extends State<GetPredictionScreen>
    with SingleTickerProviderStateMixin {
  // Services
  final MLService _mlService = MLService();
  final GeminiAIService _geminiService = GeminiAIService();

  // State
  bool _isLoading = false;
  bool _apiHealthy = false;
  bool _isCheckingHealth = true;
  PredictionResponse? _mlPrediction;
  PredictionResponse? _geminiPrediction;
  String? _selectedPredictionSource;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // SeÃ§ili deÄŸerler
  String? _selectedMachine;
  double? _selectedPower;
  String? _selectedMaterial;
  double? _selectedThickness;

  final Map<String, bool> _selectedProcesses = {
    'cutting': false,
    'engraving': false,
    'scoring': false,
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _checkApiHealth();
  }

  @override
  void dispose() {
    _animationController.dispose();
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
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _apiHealthy = false;
          _isCheckingHealth = false;
        });
      }
    }
  }

  bool _validateInputs() {
    if (_selectedMachine == null) {
      _showSnackBar('âš ï¸ LÃ¼tfen makine seÃ§in', isError: true);
      return false;
    }
    if (_selectedPower == null) {
      _showSnackBar('âš ï¸ LÃ¼tfen lazer gÃ¼cÃ¼ seÃ§in', isError: true);
      return false;
    }
    if (_selectedMaterial == null) {
      _showSnackBar('âš ï¸ LÃ¼tfen malzeme seÃ§in', isError: true);
      return false;
    }
    if (_selectedThickness == null) {
      _showSnackBar('âš ï¸ LÃ¼tfen kalÄ±nlÄ±k seÃ§in', isError: true);
      return false;
    }
    if (!_selectedProcesses.containsValue(true)) {
      _showSnackBar('âš ï¸ En az bir iÅŸlem tipi seÃ§in', isError: true);
      return false;
    }

    // Makine-Malzeme uyumluluÄŸu kontrolÃ¼
    final machineMaxThickness = AppConfig.getMaxThicknessForMachine(
      _selectedMachine!,
    );
    final materialMaxThickness = AppConfig.getMaxThicknessForMaterial(
      _selectedMaterial!,
    );

    if (_selectedThickness! > machineMaxThickness) {
      _showSnackBar(
        'âš ï¸ $_selectedMachine maksimum $machineMaxThickness mm kesebilir!',
        isError: true,
      );
      return false;
    }

    if (_selectedThickness! > materialMaxThickness) {
      _showSnackBar(
        'âš ï¸ ${AppConfig.getMaterialDisplayName(_selectedMaterial!)} iÃ§in maksimum kalÄ±nlÄ±k $materialMaxThickness mm!',
        isError: true,
      );
      return false;
    }

    return true;
  }

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

      setState(() => _mlPrediction = response);
      _animationController.forward(from: 0);
      _showSnackBar('âœ… ML tahmini baÅŸarÄ±yla alÄ±ndÄ±!');
    } catch (e) {
      _showSnackBar('âŒ ML tahmini alÄ±namadÄ±: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

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

      setState(() => _geminiPrediction = response);
      _animationController.forward(from: 0);
      _showSnackBar('âœ… Gemini AI tahmini baÅŸarÄ±yla alÄ±ndÄ±!');
    } catch (e) {
      _showSnackBar('âŒ Gemini AI tahmini alÄ±namadÄ±: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

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

      final results = await Future.wait([
        _mlService.getPrediction(request).catchError((e) {
          return _mlService.generateFallbackPrediction(request);
        }),
        _geminiService.getPredictionWithGemini(request),
      ]);

      setState(() {
        _mlPrediction = results[0];
        _geminiPrediction = results[1];
      });

      _animationController.forward(from: 0);
      _showSnackBar('âœ… Her iki tahmin de alÄ±ndÄ±!');
    } catch (e) {
      _showSnackBar('âŒ Tahminler alÄ±namadÄ±: $e', isError: true);
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
      machineBrand: _selectedMachine!,
      laserPower: _selectedPower!,
      materialType: AppConfig.getMaterialDisplayName(_selectedMaterial!),
      materialThickness: _selectedThickness!,
      processes: selectedProcessList,
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    final isMobile = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 900;
    final isDesktop = size.width >= 900;

    final horizontalPadding =
        isMobile
            ? 16.0
            : isTablet
            ? 32.0
            : 48.0;
    final cardPadding = isMobile ? 16.0 : 24.0;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Parametre Tahmini',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade700, Colors.green.shade500],
            ),
          ),
        ),
        actions: [
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
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _apiHealthy
                            ? Colors.white.withOpacity(0.2)
                            : Colors.orange.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _apiHealthy ? Icons.cloud_done : Icons.cloud_off,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _apiHealthy ? 'Online' : 'Offline',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
            tooltip: 'Bilgi',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 1200 : double.infinity,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: isMobile ? 16 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeroBanner(isDark, isMobile),
                SizedBox(height: isMobile ? 20 : 32),

                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildFormSection(isDark, cardPadding, isMobile),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            _buildActionButtons(isMobile),
                            const SizedBox(height: 16),
                            _buildQuickTipsCard(isDark, cardPadding),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildFormSection(isDark, cardPadding, isMobile),
                      SizedBox(height: isMobile ? 20 : 24),
                      _buildActionButtons(isMobile),
                      const SizedBox(height: 16),
                      _buildQuickTipsCard(isDark, cardPadding),
                    ],
                  ),

                if (_mlPrediction != null || _geminiPrediction != null) ...[
                  SizedBox(height: isMobile ? 24 : 32),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildPredictionResults(isDark, isMobile, isDesktop),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner(bool isDark, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade600, Colors.green.shade400],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.auto_awesome,
            size: isMobile ? 48 : 64,
            color: Colors.white,
          ),
          SizedBox(height: isMobile ? 12 : 16),
          Text(
            'AkÄ±llÄ± Parametre Tahmini',
            style: TextStyle(
              fontSize: isMobile ? 24 : 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isMobile ? 8 : 12),
          Text(
            'Makinenizi ve malzemenizi seÃ§in, AI en uygun ayarlarÄ± Ã¶nersin',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
          FutureBuilder<Map<String, dynamic>?>(
            future: _mlService.getModelStatus(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                final data = snapshot.data!;
                final isTrained = data['transfer_learning_trained'] == true;
                final totalExperiments = data['total_experiments'] ?? 0;

                return Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isTrained ? Icons.check_circle : Icons.pending,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              isTrained
                                  ? 'ðŸ¤– Transfer Learning Modeli Aktif'
                                  : 'âš™ï¸ Statik Algoritma KullanÄ±lÄ±yor',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isMobile ? 13 : 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Veri tabanÄ±nda $totalExperiments doÄŸrulanmÄ±ÅŸ deney',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: isMobile ? 11 : 12,
                        ),
                      ),
                      if (!isTrained && totalExperiments < 50)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '50+ deney gerekli (ÅŸu an: $totalExperiments)',
                            style: TextStyle(
                              color: Colors.orange.shade200,
                              fontSize: isMobile ? 10 : 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          if (!_apiHealthy && !_isCheckingHealth) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'ML API Ã§evrimdÄ±ÅŸÄ± - Gemini AI kullanÄ±labilir',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 12 : 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormSection(bool isDark, double padding, bool isMobile) {
    return Column(
      children: [
        _buildMachineCard(isDark, padding, isMobile),
        SizedBox(height: isMobile ? 16 : 20),
        _buildMaterialCard(isDark, padding, isMobile),
        SizedBox(height: isMobile ? 16 : 20),
        _buildProcessCard(isDark, padding, isMobile),
      ],
    );
  }

  Widget _buildMachineCard(bool isDark, double padding, bool isMobile) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.precision_manufacturing,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Makine SeÃ§imi',
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'KullandÄ±ÄŸÄ±nÄ±z lazer kesim makinesini seÃ§in',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Makine Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isMobile ? 2 : 3,
                childAspectRatio: 2.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: AppConfig.SUPPORTED_MACHINES.length,
              itemBuilder: (context, index) {
                final machine = AppConfig.SUPPORTED_MACHINES[index];
                final machineName = machine['name'] as String;
                final isSelected = _selectedMachine == machineName;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedMachine = machineName;
                      _selectedPower = machine['defaultPower'] as double;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? Colors.green.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.green : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          machine['icon'] as String,
                          style: TextStyle(fontSize: isMobile ? 20 : 24),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          machineName,
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 12,
                            fontWeight:
                                isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                            color: isSelected ? Colors.green : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            if (_selectedMachine != null) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),

              // Lazer GÃ¼cÃ¼ SeÃ§imi
              Text(
                'Lazer GÃ¼cÃ¼',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    AppConfig.getPowerRangeForMachine(_selectedMachine!).map((
                      power,
                    ) {
                      final isSelected = _selectedPower == power;
                      return ChoiceChip(
                        label: Text('${power.toInt()}W'),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(
                            () => _selectedPower = selected ? power : null,
                          );
                        },
                        selectedColor: Colors.green,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      );
                    }).toList(),
              ),

              if (_selectedPower != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'SeÃ§ili: $_selectedMachine - ${_selectedPower!.toInt()}W',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialCard(bool isDark, double padding, bool isMobile) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.category, color: Colors.orange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Malzeme SeÃ§imi',
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Kesim yapacaÄŸÄ±nÄ±z malzemeyi seÃ§in',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Malzeme Kategorileri
            ...AppConfig.MATERIAL_CATEGORIES.entries.map((category) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      category.key,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        category.value.map((material) {
                          final materialKey = material['key'] as String;
                          final isSelected = _selectedMaterial == materialKey;
                          final hasWarning = material['warning'] != null;

                          return ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(material['icon'] as String),
                                const SizedBox(width: 4),
                                Text(material['name'] as String),
                                if (hasWarning) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.warning_amber,
                                    size: 14,
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : Colors.orange,
                                  ),
                                ],
                              ],
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedMaterial =
                                    selected ? materialKey : null;
                                // SeÃ§ilen malzemeye uygun kalÄ±nlÄ±k sÄ±fÄ±rla
                                if (selected) {
                                  final maxThickness =
                                      AppConfig.getMaxThicknessForMaterial(
                                        materialKey,
                                      );
                                  if (_selectedThickness != null &&
                                      _selectedThickness! > maxThickness) {
                                    _selectedThickness = null;
                                  }
                                }
                              });
                            },
                            selectedColor: Colors.orange,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                              fontSize: 13,
                            ),
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            }).toList(),

            if (_selectedMaterial != null) ...[
              const Divider(),
              const SizedBox(height: 16),

              // KalÄ±nlÄ±k SeÃ§imi
              Row(
                children: [
                  Text(
                    'KalÄ±nlÄ±k (mm)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Max: ${AppConfig.getMaxThicknessForMaterial(_selectedMaterial!).toInt()}mm',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    AppConfig.THICKNESS_VALUES
                        .where(
                          (t) =>
                              t <=
                              AppConfig.getMaxThicknessForMaterial(
                                _selectedMaterial!,
                              ),
                        )
                        .map((thickness) {
                          final isSelected = _selectedThickness == thickness;
                          return ChoiceChip(
                            label: Text('${thickness.toString()} mm'),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(
                                () =>
                                    _selectedThickness =
                                        selected ? thickness : null,
                              );
                            },
                            selectedColor: Colors.blue,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          );
                        })
                        .toList(),
              ),

              if (_selectedThickness != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'SeÃ§ili: ${AppConfig.getMaterialDisplayName(_selectedMaterial!)} - $_selectedThickness mm (${AppConfig.getMaterialDifficulty(_selectedMaterial!)})',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.green.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProcessCard(bool isDark, double padding, bool isMobile) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.settings, color: Colors.purple),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ä°ÅŸlem Tipleri',
                        style: TextStyle(
                          // get_prediction_screen.dart devamÄ±...
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'YapÄ±lacak iÅŸlemleri seÃ§in',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildProcessTile(
              'Kesme',
              'cutting',
              Icons.content_cut,
              Colors.red,
            ),
            _buildProcessTile('KazÄ±ma', 'engraving', Icons.draw, Colors.blue),
            _buildProcessTile(
              'Ã‡izme',
              'scoring',
              Icons.border_style,
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessTile(
    String title,
    String key,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:
            _selectedProcesses[key]!
                ? color.withOpacity(0.1)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedProcesses[key]! ? color : Colors.grey.shade300,
        ),
      ),
      child: CheckboxListTile(
        title: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight:
                    _selectedProcesses[key]!
                        ? FontWeight.bold
                        : FontWeight.normal,
              ),
            ),
          ],
        ),
        value: _selectedProcesses[key],
        onChanged: (value) {
          setState(() => _selectedProcesses[key] = value ?? false);
        },
        activeColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildActionButtons(bool isMobile) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tahmin KaynaÄŸÄ± SeÃ§in',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            _buildPredictionButton(
              icon: Icons.smart_toy,
              label: 'ML API',
              subtitle: 'Topluluk verisi',
              color: Colors.green,
              isLoading: _isLoading && _selectedPredictionSource == 'ml',
              onPressed: _getPredictionFromML,
            ),
            const SizedBox(height: 12),

            _buildPredictionButton(
              icon: Icons.psychology,
              label: 'Gemini AI',
              subtitle: 'Yapay zeka',
              color: Colors.purple,
              isLoading: _isLoading && _selectedPredictionSource == 'gemini',
              onPressed: _getPredictionFromGemini,
            ),
            const SizedBox(height: 12),

            _buildPredictionButton(
              icon: Icons.compare_arrows,
              label: 'KarÅŸÄ±laÅŸtÄ±r',
              subtitle: 'Her ikisini gÃ¶r',
              color: Colors.blue,
              isLoading: _isLoading && _selectedPredictionSource == 'both',
              onPressed: _getComparativePredictions,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: _isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      child:
          isLoading
              ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
              : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 24),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
    );
  }

  Widget _buildQuickTipsCard(bool isDark, double padding) {
    return Card(
      elevation: 2,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tips_and_updates, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'HÄ±zlÄ± Ä°puÃ§larÄ±',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTipItem(
              'âœ“ Her makine iÃ§in Ã¶nerilen gÃ¼Ã§ deÄŸerlerini kullanÄ±n',
            ),
            _buildTipItem('âœ“ Malzeme kalÄ±nlÄ±ÄŸÄ±nÄ± doÄŸru seÃ§in'),
            _buildTipItem('âœ“ Ä°lk denemede dÃ¼ÅŸÃ¼k gÃ¼Ã§le baÅŸlayÄ±n'),
            _buildTipItem('âœ“ AhÅŸap iÃ§in 2-5mm kalÄ±nlÄ±k idealdir'),
            _buildTipItem('âš  Metal ve cam kesimi desteklenmez'),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text.substring(0, 1),
            style: TextStyle(fontSize: 16, color: Colors.blue.shade700),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text.substring(2),
              style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionResults(bool isDark, bool isMobile, bool isDesktop) {
    if (_selectedPredictionSource == 'both') {
      return isDesktop
          ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_mlPrediction != null)
                Expanded(
                  child: _buildSinglePredictionCard(
                    _mlPrediction!,
                    'ðŸ¤– ML API',
                    Colors.green,
                    isDark,
                    isMobile,
                  ),
                ),
              const SizedBox(width: 16),
              if (_geminiPrediction != null)
                Expanded(
                  child: _buildSinglePredictionCard(
                    _geminiPrediction!,
                    'ðŸ§  Gemini AI',
                    Colors.purple,
                    isDark,
                    isMobile,
                  ),
                ),
            ],
          )
          : Column(
            children: [
              if (_mlPrediction != null)
                _buildSinglePredictionCard(
                  _mlPrediction!,
                  'ðŸ¤– ML API',
                  Colors.green,
                  isDark,
                  isMobile,
                ),
              const SizedBox(height: 16),
              if (_geminiPrediction != null)
                _buildSinglePredictionCard(
                  _geminiPrediction!,
                  'ðŸ§  Gemini AI',
                  Colors.purple,
                  isDark,
                  isMobile,
                ),
            ],
          );
    } else if (_selectedPredictionSource == 'ml' && _mlPrediction != null) {
      return _buildSinglePredictionCard(
        _mlPrediction!,
        'ðŸ¤– ML API Tahmini',
        Colors.green,
        isDark,
        isMobile,
      );
    } else if (_selectedPredictionSource == 'gemini' &&
        _geminiPrediction != null) {
      return _buildSinglePredictionCard(
        _geminiPrediction!,
        'ðŸ§  Gemini AI Tahmini',
        Colors.purple,
        isDark,
        isMobile,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildSinglePredictionCard(
    PredictionResponse result,
    String title,
    Color accentColor,
    bool isDark,
    bool isMobile,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: accentColor.withOpacity(0.5), width: 2),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accentColor.withOpacity(0.05), Colors.white],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 20 : 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: accentColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          result
                              .getDataSourceDescription(), // âœ… Yeni metod kullanÄ±lÄ±yor
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _buildConfidenceIndicator(result, accentColor, isMobile),
              const SizedBox(height: 24),
              if (result.hasWarnings()) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber,
                            color: Colors.orange,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Ã–nemli UyarÄ±lar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...result.warnings.map((warning) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.arrow_right,
                                color: Colors.orange,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  warning,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              ...result.predictions.entries.map((entry) {
                return _buildProcessResult(entry, accentColor, isMobile);
              }),

              if (result.notes.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accentColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: accentColor, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          result.notes,
                          style: const TextStyle(fontSize: 14, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfidenceIndicator(
    PredictionResponse result,
    Color color,
    bool isMobile,
  ) {
    final confidence = result.confidenceScore;
    final percentage = (confidence * 100).toInt();

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GÃ¼ven Skoru',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    percentage >= 80
                        ? 'YÃ¼ksek GÃ¼venilirlik'
                        : percentage >= 60
                        ? 'Orta GÃ¼venilirlik'
                        : 'DÃ¼ÅŸÃ¼k GÃ¼venilirlik',
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  '$percentage%',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: confidence,
              minHeight: 8,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          if (result.dataPointsUsed > 0) ...[
            const SizedBox(height: 8),
            Text(
              '${result.dataPointsUsed} benzer deney kullanÄ±ldÄ±',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProcessResult(
    MapEntry<String, ProcessParams> entry,
    Color color,
    bool isMobile,
  ) {
    String processName =
        entry.key == 'cutting'
            ? 'Kesme'
            : entry.key == 'engraving'
            ? 'KazÄ±ma'
            : 'Ã‡izme';
    ProcessParams params = entry.value;

    IconData icon =
        entry.key == 'cutting'
            ? Icons.content_cut
            : entry.key == 'engraving'
            ? Icons.draw
            : Icons.border_style;

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: isMobile ? 22 : 26),
              const SizedBox(width: 12),
              Text(
                processName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 18 : 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildParamBadge(
                'GÃ¼Ã§',
                '${params.power.toStringAsFixed(1)}%',
                color,
                Icons.bolt,
              ),
              _buildParamBadge(
                'HÄ±z',
                '${params.speed.toStringAsFixed(0)}',
                color,
                Icons.speed,
              ),
              _buildParamBadge(
                'GeÃ§iÅŸ',
                '${params.passes}',
                color,
                Icons.repeat,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParamBadge(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.info_outline, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                const Text('NasÄ±l Ã‡alÄ±ÅŸÄ±r?'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoSection(
                    '1ï¸âƒ£ Makine SeÃ§in',
                    'KullandÄ±ÄŸÄ±nÄ±z diode lazer makinesini seÃ§in. Her makine iÃ§in uygun gÃ¼Ã§ deÄŸerleri gÃ¶sterilir.',
                  ),
                  const SizedBox(height: 16),
                  _buildInfoSection(
                    '2ï¸âƒ£ Malzeme SeÃ§in',
                    'Kesim yapacaÄŸÄ±nÄ±z malzemeyi seÃ§in. Her malzeme iÃ§in maksimum kalÄ±nlÄ±k bilgisi verilir.',
                  ),
                  const SizedBox(height: 16),
                  _buildInfoSection(
                    '3ï¸âƒ£ Ä°ÅŸlem SeÃ§in',
                    'Kesme, kazÄ±ma veya Ã§izme iÅŸlemlerinden birini veya birkaÃ§Ä±nÄ± seÃ§in.',
                  ),
                  const SizedBox(height: 16),
                  _buildInfoSection(
                    '4ï¸âƒ£ Tahmin AlÄ±n',
                    'ML API topluluk verilerinden, Gemini AI yapay zekadan Ã¶nerileri alÄ±r. KarÅŸÄ±laÅŸtÄ±rma ile her ikisini gÃ¶rÃ¼rsÃ¼nÃ¼z.',
                  ),
                  const Divider(height: 32),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber,
                              color: Colors.orange.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Ã–nemli UyarÄ±lar',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'â€¢ Ä°lk denemede dÃ¼ÅŸÃ¼k gÃ¼Ã§le baÅŸlayÄ±n\n'
                          'â€¢ Metal ve cam kesimi desteklenmez\n'
                          'â€¢ 8mm Ã¼zeri kalÄ±nlÄ±klar zordur\n'
                          'â€¢ Her zaman test kesimi yapÄ±n',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('AnladÄ±m', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
    );
  }

  Widget _buildInfoSection(String title, String description) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}
