import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:lasertuner/config/app_config.dart';
import 'dart:convert';
import '../models/experiment_model.dart';
import '../services/firestore_service.dart';
import '../widgets/custom_button.dart';

class ResearcherPanelScreen extends StatefulWidget {
  final String userId;

  const ResearcherPanelScreen({super.key, required this.userId});

  @override
  State<ResearcherPanelScreen> createState() => _ResearcherPanelScreenState();
}

class _ResearcherPanelScreenState extends State<ResearcherPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AraÅŸtÄ±rmacÄ± Paneli',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.orange,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.science), text: 'Veri Ekle'),
            Tab(icon: Icon(Icons.upload_file), text: 'Ä°Ã§e Aktar'),
            Tab(icon: Icon(Icons.list_alt), text: 'Verilerim'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ExperimentDataTab(userId: widget.userId),
          _ExternalDataTab(userId: widget.userId),
          _MyDataTab(userId: widget.userId),
        ],
      ),
    );
  }
}

// ========== TAB 1: DENEY VERÄ°SÄ° EKLE ==========
class _ExperimentDataTab extends StatefulWidget {
  final String userId;
  const _ExperimentDataTab({required this.userId});

  @override
  State<_ExperimentDataTab> createState() => _ExperimentDataTabState();
}

// ========== _ExperimentDataTab Ä°Ã‡Ä°N TAM KOD ==========
// Bu kodu researcher_panel_screen.dart iÃ§indeki _ExperimentDataTab ve _ExperimentDataTabState ile deÄŸiÅŸtirin

class _ExperimentDataTabState extends State<_ExperimentDataTab> {
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _imagePicker = ImagePicker();

  // âœ… AppConfig entegrasyonu - Dropdown/Chip seÃ§imleri
  String? _selectedMachine;
  double? _selectedPower;
  String? _selectedMaterial;
  double? _selectedThickness;

  // FotoÄŸraf deÄŸiÅŸkenleri
  XFile? _selectedImageFile;
  Uint8List? _webImage;
  XFile? _selectedImageFile2;
  Uint8List? _webImage2;
  bool _isLoading = false;

  // Ä°ÅŸlem seÃ§imleri
  final Map<String, bool> _selectedProcesses = {
    'cutting': false,
    'engraving': false,
    'scoring': false,
  };

  // Ä°ÅŸlem parametreleri
  final Map<String, Map<String, TextEditingController>> _processControllers = {
    'cutting': {
      'power': TextEditingController(),
      'speed': TextEditingController(),
      'passes': TextEditingController(text: '1'),
    },
    'engraving': {
      'power': TextEditingController(),
      'speed': TextEditingController(),
      'passes': TextEditingController(text: '1'),
    },
    'scoring': {
      'power': TextEditingController(),
      'speed': TextEditingController(),
      'passes': TextEditingController(text: '1'),
    },
  };

  // Kalite skorlarÄ±
  final Map<String, double> _qualityScores = {
    'cutting': 5,
    'engraving': 5,
    'scoring': 5,
  };

  Future<void> _pickImage({bool isSecond = false}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null) {
        if (isSecond) {
          setState(() => _selectedImageFile2 = image);
          if (kIsWeb) {
            final bytes = await image.readAsBytes();
            setState(() => _webImage2 = bytes);
          }
        } else {
          setState(() => _selectedImageFile = image);
          if (kIsWeb) {
            final bytes = await image.readAsBytes();
            setState(() => _webImage = bytes);
          }
        }
      }
    } catch (e) {
      _showSnackBar('Resim seÃ§me hatasÄ±: $e');
    }
  }

  Future<void> _submitData() async {
    // âœ… Validasyonlar
    if (_selectedMachine == null) {
      _showSnackBar('âš ï¸ LÃ¼tfen makine seÃ§in');
      return;
    }
    if (_selectedPower == null) {
      _showSnackBar('âš ï¸ LÃ¼tfen lazer gÃ¼cÃ¼ seÃ§in');
      return;
    }
    if (_selectedMaterial == null) {
      _showSnackBar('âš ï¸ LÃ¼tfen malzeme seÃ§in');
      return;
    }
    if (_selectedThickness == null) {
      _showSnackBar('âš ï¸ LÃ¼tfen kalÄ±nlÄ±k seÃ§in');
      return;
    }
    if (!_selectedProcesses.containsValue(true)) {
      _showSnackBar('En az bir iÅŸlem tipi seÃ§in');
      return;
    }
    if (_selectedImageFile == null) {
      _showSnackBar('LÃ¼tfen en az bir fotoÄŸraf yÃ¼kleyin');
      return;
    }

    // Process parametreleri kontrolÃ¼
    for (var entry in _selectedProcesses.entries) {
      if (entry.value) {
        final controllers = _processControllers[entry.key]!;
        if (controllers['power']!.text.isEmpty ||
            controllers['speed']!.text.isEmpty ||
            controllers['passes']!.text.isEmpty) {
          _showSnackBar(
            'âš ï¸ ${_getProcessName(entry.key)} iÃ§in tÃ¼m parametreleri girin',
          );
          return;
        }
      }
    }

    setState(() => _isLoading = true);

    try {
      Map<String, ProcessParams> processes = {};
      Map<String, int> qualityScores = {};

      _selectedProcesses.forEach((processType, isSelected) {
        if (isSelected) {
          final controllers = _processControllers[processType]!;
          processes[processType] = ProcessParams(
            power: double.parse(controllers['power']!.text),
            speed: double.parse(controllers['speed']!.text),
            passes: int.parse(controllers['passes']!.text),
          );
          qualityScores[processType] = _qualityScores[processType]!.toInt();
        }
      });

      ExperimentModel experiment = ExperimentModel(
        id: '',
        userId: widget.userId,
        machineBrand: _selectedMachine!, // âœ… Dropdown'dan
        laserPower: _selectedPower!, // âœ… Chip'den
        materialType: AppConfig.getMaterialDisplayName(
          _selectedMaterial!,
        ), // âœ… Display name
        materialThickness: _selectedThickness!, // âœ… Chip'den
        processes: processes,
        photoUrl: '',
        photoUrl2: '',
        qualityScores: qualityScores,
        dataSource: 'researcher',
        verificationStatus: 'verified',
        createdAt: DateTime.now(),
      );

      await _firestoreService.addExperiment(
        experiment,
        _selectedImageFile!,
        imageFile2: _selectedImageFile2,
      );
      _showSnackBar('âœ… Gold Standard veri baÅŸarÄ±yla eklendi!');
      _clearForm();
    } catch (e) {
      _showSnackBar('âŒ Hata: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _processControllers.values.forEach(
      (c) => c.values.forEach((ctrl) {
        if (ctrl == c['passes'])
          ctrl.text = '1';
        else
          ctrl.clear();
      }),
    );
    setState(() {
      _selectedMachine = null;
      _selectedPower = null;
      _selectedMaterial = null;
      _selectedThickness = null;
      _selectedProcesses.updateAll((key, value) => false);
      _qualityScores.updateAll((key, value) => 5);
      _selectedImageFile = null;
      _webImage = null;
      _selectedImageFile2 = null;
      _webImage2 = null;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _getProcessName(String key) {
    switch (key) {
      case 'cutting':
        return 'Kesme';
      case 'engraving':
        return 'KazÄ±ma';
      case 'scoring':
        return 'Ã‡izme';
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'DoÄŸrulanmÄ±ÅŸ laboratuvar verilerini ekleyin. Veriler "Gold Standard" olarak iÅŸaretlenecektir.',
                          style: TextStyle(color: Colors.orange.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // âœ… Makine seÃ§imi (AppConfig entegrasyonu)
              _buildMachineSection(isDark),
              const SizedBox(height: 16),

              // âœ… Malzeme seÃ§imi (AppConfig entegrasyonu)
              _buildMaterialSection(isDark),
              const SizedBox(height: 16),

              // Ä°ÅŸlem tipleri
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.settings, color: Colors.purple),
                          const SizedBox(width: 8),
                          Text(
                            'Ä°ÅŸlem Tipleri',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ..._buildProcessSelections(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // FotoÄŸraflar
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.photo_library, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            'FotoÄŸraflar',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'En az 1, en fazla 2 fotoÄŸraf ekleyebilirsiniz.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildPhotoSection(
                        title: '1. FotoÄŸraf (Zorunlu)',
                        imageFile: _selectedImageFile,
                        webImage: _webImage,
                        onPick: () => _pickImage(isSecond: false),
                        onRemove:
                            () => setState(() {
                              _selectedImageFile = null;
                              _webImage = null;
                            }),
                        isRequired: true,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),
                      _buildPhotoSection(
                        title: '2. FotoÄŸraf (Ä°steÄŸe BaÄŸlÄ±)',
                        imageFile: _selectedImageFile2,
                        webImage: _webImage2,
                        onPick: () => _pickImage(isSecond: true),
                        onRemove:
                            () => setState(() {
                              _selectedImageFile2 = null;
                              _webImage2 = null;
                            }),
                        isRequired: false,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              CustomButton(
                text: 'Gold Standard Veri Ekle',
                onPressed: _submitData,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== MAKINE SEÃ‡Ä°MÄ° (AppConfig) ==========
  Widget _buildMachineSection(bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.precision_manufacturing, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Makine Bilgileri',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Makine Modeli',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  AppConfig.SUPPORTED_MACHINES.map((machine) {
                    final machineName = machine['name'] as String;
                    final isSelected = _selectedMachine == machineName;
                    return FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(machine['icon'] as String),
                          const SizedBox(width: 4),
                          Text(machineName),
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedMachine = selected ? machineName : null;
                          if (selected) {
                            _selectedPower = machine['defaultPower'] as double;
                          }
                        });
                      },
                      selectedColor: Colors.green,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    );
                  }).toList(),
            ),

            if (_selectedMachine != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Lazer GÃ¼cÃ¼',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
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
                        selectedColor: Colors.blue,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      );
                    }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ========== MALZEME SEÃ‡Ä°MÄ° (AppConfig) ==========
  Widget _buildMaterialSection(bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.category, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Malzeme Bilgileri',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Malzeme kategorileri
            ...AppConfig.MATERIAL_CATEGORIES.entries.map((category) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      category.key,
                      style: TextStyle(
                        fontSize: 13,
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
                          return FilterChip(
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
                              fontSize: 12,
                            ),
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            }).toList(),

            if (_selectedMaterial != null) ...[
              const Divider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'KalÄ±nlÄ±k (mm)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
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
                        fontSize: 10,
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
                            label: Text('$thickness mm'),
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
            ],
          ],
        ),
      ),
    );
  }

  // ========== Ä°ÅžLEM PARAMETRELERÄ° ==========
  List<Widget> _buildProcessSelections() {
    List<Widget> widgets = [];
    _selectedProcesses.forEach((processType, isSelected) {
      String processName = _getProcessName(processType);
      IconData icon =
          processType == 'cutting'
              ? Icons.content_cut
              : processType == 'engraving'
              ? Icons.draw
              : Icons.border_style;
      Color color =
          processType == 'cutting'
              ? Colors.red
              : processType == 'engraving'
              ? Colors.blue
              : Colors.orange;

      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
            ),
          ),
          child: Column(
            children: [
              CheckboxListTile(
                title: Row(
                  children: [
                    Icon(icon, size: 20, color: color),
                    const SizedBox(width: 8),
                    Text(
                      processName,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                value: isSelected,
                onChanged:
                    (v) => setState(
                      () => _selectedProcesses[processType] = v ?? false,
                    ),
                activeColor: color,
              ),
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller:
                                  _processControllers[processType]!['power']!,
                              decoration: InputDecoration(
                                labelText: 'GÃ¼Ã§ (%)',
                                hintText: '0-100',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller:
                                  _processControllers[processType]!['speed']!,
                              decoration: InputDecoration(
                                labelText: 'HÄ±z (mm/s)',
                                hintText: '50-500',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller:
                                  _processControllers[processType]!['passes']!,
                              decoration: InputDecoration(
                                labelText: 'GeÃ§iÅŸ',
                                hintText: '1-20',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            'Kalite: ${_qualityScores[processType]!.toInt()}/10',
                          ),
                          Expanded(
                            child: Slider(
                              value: _qualityScores[processType]!,
                              min: 0,
                              max: 10,
                              divisions: 10,
                              label:
                                  _qualityScores[processType]!
                                      .toInt()
                                      .toString(),
                              onChanged:
                                  (value) => setState(
                                    () => _qualityScores[processType] = value,
                                  ),
                              activeColor: color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    });
    return widgets;
  }

  // ========== FOTOÄžRAF YÃœKLENMESÄ° ==========
  Widget _buildPhotoSection({
    required String title,
    required XFile? imageFile,
    required Uint8List? webImage,
    required VoidCallback onPick,
    required VoidCallback onRemove,
    required bool isRequired,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isRequired && imageFile == null
                  ? Colors.orange.shade300
                  : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              if (isRequired)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Zorunlu',
                    style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (imageFile != null) ...[
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child:
                      kIsWeb && webImage != null
                          ? Image.memory(
                            webImage,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.contain,
                          )
                          : Image.network(
                            imageFile.path,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder:
                                (c, e, s) => Container(
                                  height: 150,
                                  color: Colors.grey.shade300,
                                  child: const Center(child: Icon(Icons.image)),
                                ),
                          ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.refresh),
              label: const Text('DeÄŸiÅŸtir'),
            ),
          ] else
            GestureDetector(
              onTap: onPick,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate,
                        size: 40,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'FotoÄŸraf Ekle',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _processControllers.values.forEach(
      (c) => c.values.forEach((ctrl) => ctrl.dispose()),
    );
    super.dispose();
  }
}

// ========== TAB 2: HARÄ°CÄ° VERÄ° Ä°Ã‡E AKTAR ==========
class _ExternalDataTab extends StatefulWidget {
  final String userId;
  const _ExternalDataTab({required this.userId});

  @override
  State<_ExternalDataTab> createState() => _ExternalDataTabState();
}

class _ExternalDataTabState extends State<_ExternalDataTab> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;
  String? _fileName;
  List<Map<String, dynamic>>? _parsedData;

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'csv'],
      );
      if (result != null) {
        setState(() => _fileName = result.files.single.name);
        if (kIsWeb) {
          final bytes = result.files.single.bytes;
          if (bytes != null)
            _parseFile(bytes, result.files.single.extension ?? '');
        } else {
          final file = File(result.files.single.path!);
          final bytes = await file.readAsBytes();
          _parseFile(bytes, result.files.single.extension ?? '');
        }
      }
    } catch (e) {
      _showSnackBar('Dosya seÃ§me hatasÄ±: $e');
    }
  }

  void _parseFile(Uint8List bytes, String extension) {
    try {
      String content = utf8.decode(bytes);
      if (extension == 'json') {
        final jsonData = jsonDecode(content);
        if (jsonData is List)
          setState(
            () => _parsedData = List<Map<String, dynamic>>.from(jsonData),
          );
        else
          setState(() => _parsedData = [Map<String, dynamic>.from(jsonData)]);
        _showSnackBar('${_parsedData!.length} kayÄ±t bulundu');
      } else if (extension == 'csv') {
        List<String> lines = content.split('\n');
        if (lines.length > 1) {
          List<String> headers =
              lines[0].split(',').map((e) => e.trim()).toList();
          List<Map<String, dynamic>> data = [];
          for (int i = 1; i < lines.length; i++) {
            if (lines[i].trim().isEmpty) continue;
            List<String> values =
                lines[i].split(',').map((e) => e.trim()).toList();
            Map<String, dynamic> row = {};
            for (int j = 0; j < headers.length && j < values.length; j++)
              row[headers[j]] = values[j];
            data.add(row);
          }
          setState(() => _parsedData = data);
          _showSnackBar('${_parsedData!.length} kayÄ±t bulundu');
        }
      }
    } catch (e) {
      _showSnackBar('Dosya parse hatasÄ±: $e');
    }
  }

  Future<void> _importData() async {
    if (_parsedData == null || _parsedData!.isEmpty) {
      _showSnackBar('Ä°Ã§e aktarÄ±lacak veri bulunamadÄ±');
      return;
    }

    setState(() => _isLoading = true);
    int successCount = 0, errorCount = 0;

    try {
      for (var data in _parsedData!) {
        try {
          Map<String, ProcessParams> processes = {};
          Map<String, int> qualityScores = {};

          if (data.containsKey('cutting_power')) {
            processes['cutting'] = ProcessParams(
              power: double.parse(data['cutting_power'].toString()),
              speed: double.parse(data['cutting_speed'].toString()),
              passes: int.parse(data['cutting_passes'].toString()),
            );
            qualityScores['cutting'] = int.parse(
              data['cutting_quality']?.toString() ?? '5',
            );
          }
          if (data.containsKey('engraving_power')) {
            processes['engraving'] = ProcessParams(
              power: double.parse(data['engraving_power'].toString()),
              speed: double.parse(data['engraving_speed'].toString()),
              passes: int.parse(data['engraving_passes'].toString()),
            );
            qualityScores['engraving'] = int.parse(
              data['engraving_quality']?.toString() ?? '5',
            );
          }
          if (data.containsKey('scoring_power')) {
            processes['scoring'] = ProcessParams(
              power: double.parse(data['scoring_power'].toString()),
              speed: double.parse(data['scoring_speed'].toString()),
              passes: int.parse(data['scoring_passes'].toString()),
            );
            qualityScores['scoring'] = int.parse(
              data['scoring_quality']?.toString() ?? '5',
            );
          }

          ExperimentModel experiment = ExperimentModel(
            id: '',
            userId: widget.userId,
            machineBrand: data['machineBrand']?.toString() ?? 'Unknown',
            laserPower: double.parse(data['laserPower']?.toString() ?? '0'),
            materialType: data['materialType']?.toString() ?? 'Unknown',
            materialThickness: double.parse(
              data['materialThickness']?.toString() ?? '0',
            ),
            processes: processes,
            photoUrl:
                data['photoUrl']?.toString() ??
                'https://via.placeholder.com/400x300.png?text=No+Image',
            photoUrl2: data['photoUrl2']?.toString() ?? '',
            qualityScores: qualityScores,
            dataSource: 'researcher_import',
            verificationStatus: 'verified',
            createdAt: DateTime.now(),
          );

          await _firestoreService.addExperimentWithoutImage(experiment);
          successCount++;
        } catch (e) {
          errorCount++;
        }
      }

      _showSnackBar('âœ… $successCount kayÄ±t eklendi, âŒ $errorCount hata');
      setState(() {
        _parsedData = null;
        _fileName = null;
      });
    } catch (e) {
      _showSnackBar('Import hatasÄ±: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'JSON veya CSV FormatÄ±nda Toplu Veri Ä°Ã§e Aktarma',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Beklenen JSON formatÄ±:\n[\n  {\n    "machineBrand": "Epilog Laser",\n    "laserPower": 100,\n    "materialType": "AhÅŸap",\n    "materialThickness": 3,\n    "cutting_power": 80,\n    "cutting_speed": 250,\n    "cutting_passes": 1,\n    "cutting_quality": 8\n  }\n]',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.cloud_upload,
                        size: 64,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Dosya YÃ¼kle',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 24),
                      if (_fileName != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text('Dosya: $_fileName')),
                              if (_parsedData != null)
                                Chip(
                                  label: Text('${_parsedData!.length} kayÄ±t'),
                                  backgroundColor: Colors.green.shade100,
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('JSON/CSV DosyasÄ± SeÃ§'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                      ),
                      if (_parsedData != null) ...[
                        const SizedBox(height: 24),
                        CustomButton(
                          text:
                              'Verileri Ä°Ã§e Aktar (${_parsedData!.length} kayÄ±t)',
                          onPressed: _importData,
                          isLoading: _isLoading,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== TAB 3: EKLEDÄ°ÄžÄ°M VERÄ°LER ==========
class _MyDataTab extends StatelessWidget {
  final String userId;
  const _MyDataTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;

    return StreamBuilder<List<ExperimentModel>>(
      stream: FirestoreService().getResearcherExperiments(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Colors.orange));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.science_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'HenÃ¼z veri eklemediniz',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ä°lk sekmeden yeni veri ekleyebilirsiniz.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            return Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 900),
                child: _ResearcherDataCard(
                  experiment: snapshot.data![index],
                  isDark: isDark,
                  isLarge: isLargeScreen,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ResearcherDataCard extends StatefulWidget {
  final ExperimentModel experiment;
  final bool isDark;
  final bool isLarge;

  const _ResearcherDataCard({
    required this.experiment,
    required this.isDark,
    required this.isLarge,
  });

  @override
  State<_ResearcherDataCard> createState() => _ResearcherDataCardState();
}

class _ResearcherDataCardState extends State<_ResearcherDataCard> {
  bool _isExpanded = false;
  int _currentPhotoIndex = 0;

  @override
  Widget build(BuildContext context) {
    final exp = widget.experiment;
    final isImported = exp.dataSource == 'researcher_import';

    final photos = <String>[];
    if (exp.photoUrl.isNotEmpty && !exp.photoUrl.contains('placeholder'))
      photos.add(exp.photoUrl);
    if (exp.photoUrl2.isNotEmpty) photos.add(exp.photoUrl2);

    return Card(
      margin: EdgeInsets.only(bottom: widget.isLarge ? 20 : 16),
      elevation: widget.isDark ? 2 : 3,
      color: widget.isDark ? Colors.grey.shade900 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(widget.isLarge ? 16 : 12),
            decoration: BoxDecoration(
              color:
                  widget.isDark
                      ? Colors.orange.shade900.withOpacity(0.3)
                      : Colors.orange.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isImported ? Icons.upload_file : Icons.science,
                    color: Colors.orange,
                    size: widget.isLarge ? 28 : 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              exp.machineBrand,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: widget.isLarge ? 18 : 16,
                                color:
                                    widget.isDark
                                        ? Colors.white
                                        : Colors.black87,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Gold Standard',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${exp.materialType} - ${exp.materialThickness}mm',
                        style: TextStyle(
                          color:
                              widget.isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade700,
                          fontSize: widget.isLarge ? 14 : 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // FotoÄŸraflar
          if (photos.isNotEmpty) ...[
            Stack(
              children: [
                InteractiveViewer(
                  child: Image.network(
                    photos[_currentPhotoIndex],
                    height: widget.isLarge ? 250 : 180,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder:
                        (c, e, s) => Container(
                          height: widget.isLarge ? 250 : 180,
                          color:
                              widget.isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                          child: const Center(
                            child: Icon(Icons.image_not_supported),
                          ),
                        ),
                  ),
                ),
                if (photos.length > 1) ...[
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(photos.length, (index) {
                        return GestureDetector(
                          onTap:
                              () => setState(() => _currentPhotoIndex = index),
                          child: Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  _currentPhotoIndex == index
                                      ? Colors.orange
                                      : Colors.white.withOpacity(0.5),
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconButton(
                        onPressed:
                            _currentPhotoIndex > 0
                                ? () => setState(() => _currentPhotoIndex--)
                                : null,
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.chevron_left, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconButton(
                        onPressed:
                            _currentPhotoIndex < photos.length - 1
                                ? () => setState(() => _currentPhotoIndex++)
                                : null,
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.chevron_right, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ] else
            Container(
              height: 100,
              color:
                  widget.isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'FotoÄŸraf yok (Ä°Ã§e aktarÄ±lan veri)',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Ä°Ã§erik
          Padding(
            padding: EdgeInsets.all(widget.isLarge ? 16 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                      icon: Icons.flash_on,
                      label: '${exp.laserPower}W',
                      isDark: widget.isDark,
                    ),
                    _InfoChip(
                      icon: Icons.layers,
                      label: '${exp.processes.length} iÅŸlem',
                      isDark: widget.isDark,
                    ),
                    _InfoChip(
                      icon: Icons.calendar_today,
                      label:
                          '${exp.createdAt.day}/${exp.createdAt.month}/${exp.createdAt.year}',
                      isDark: widget.isDark,
                    ),
                    if (photos.length > 1)
                      _InfoChip(
                        icon: Icons.photo_library,
                        label: '${photos.length} fotoÄŸraf',
                        isDark: widget.isDark,
                      ),
                    if (isImported)
                      _InfoChip(
                        icon: Icons.upload_file,
                        label: 'Ä°Ã§e aktarÄ±ldÄ±',
                        isDark: widget.isDark,
                      ),
                  ],
                ),

                if (_isExpanded) ...[
                  const Divider(height: 24),
                  ...exp.processes.entries.map((entry) {
                    String processName =
                        entry.key == 'cutting'
                            ? 'Kesme'
                            : entry.key == 'engraving'
                            ? 'KazÄ±ma'
                            : 'Ã‡izme';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            widget.isDark
                                ? Colors.orange.shade900.withOpacity(0.3)
                                : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            processName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color:
                                  widget.isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _ParamItem(
                                'GÃ¼Ã§',
                                '${entry.value.power.toStringAsFixed(1)}%',
                                widget.isDark,
                              ),
                              _ParamItem(
                                'HÄ±z',
                                '${entry.value.speed.toStringAsFixed(0)} mm/s',
                                widget.isDark,
                              ),
                              _ParamItem(
                                'GeÃ§iÅŸ',
                                '${entry.value.passes}',
                                widget.isDark,
                              ),
                              _ParamItem(
                                'Kalite',
                                '${exp.qualityScores[entry.key] ?? "-"}/10',
                                widget.isDark,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],

                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                    icon: Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.orange,
                    ),
                    label: Text(
                      _isExpanded ? 'Daha Az' : 'DetaylarÄ± GÃ¶r',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParamItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _ParamItem(this.label, this.value, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }
}
