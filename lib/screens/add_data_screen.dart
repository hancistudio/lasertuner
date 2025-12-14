import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:lasertuner/config/app_config.dart';
import 'dart:typed_data';
import '../models/experiment_model.dart';
import '../services/firestore_service.dart';
import '../widgets/custom_button.dart';

class AddDataScreen extends StatefulWidget {
  final String userId;

  const AddDataScreen({super.key, required this.userId});

  @override
  State<AddDataScreen> createState() => _AddDataScreenState();
}

class _AddDataScreenState extends State<AddDataScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _imagePicker = ImagePicker();

  // Seçili değerler
  String? _selectedMachine;
  double? _selectedPower;
  String? _selectedMaterial;
  double? _selectedThickness;

  // Fotoğraflar
  XFile? _selectedImageFile;
  Uint8List? _webImage;
  XFile? _selectedImageFile2;
  Uint8List? _webImage2;

  bool _isLoading = false;

  final Map<String, bool> _selectedProcesses = {
    'cutting': false,
    'engraving': false,
    'scoring': false,
  };

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
      _showSnackBar('Resim seçme hatası: $e');
    }
  }

  bool _validateInputs() {
    if (_selectedMachine == null) {
      _showSnackBar('⚠️ Lütfen makine seçin');
      return false;
    }
    if (_selectedPower == null) {
      _showSnackBar('⚠️ Lütfen lazer gücü seçin');
      return false;
    }
    if (_selectedMaterial == null) {
      _showSnackBar('⚠️ Lütfen malzeme seçin');
      return false;
    }
    if (_selectedThickness == null) {
      _showSnackBar('⚠️ Lütfen kalınlık seçin');
      return false;
    }

    if (!_selectedProcesses.containsValue(true)) {
      _showSnackBar('⚠️ En az bir işlem tipi seçin');
      return false;
    }

    if (_selectedImageFile == null) {
      _showSnackBar('⚠️ Lütfen en az bir fotoğraf yükleyin');
      return false;
    }

    // Process parametreleri kontrolü
    for (var entry in _selectedProcesses.entries) {
      if (entry.value) {
        final controllers = _processControllers[entry.key]!;
        if (controllers['power']!.text.isEmpty ||
            controllers['speed']!.text.isEmpty ||
            controllers['passes']!.text.isEmpty) {
          _showSnackBar(
            '⚠️ ${_getProcessName(entry.key)} için tüm parametreleri girin',
          );
          return false;
        }
      }
    }

    return true;
  }

  Future<void> _submitData() async {
    if (!_validateInputs()) return;

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
        machineBrand: _selectedMachine!,
        laserPower: _selectedPower!,
        materialType: AppConfig.getMaterialDisplayName(_selectedMaterial!),
        materialThickness: _selectedThickness!,
        processes: processes,
        photoUrl: '',
        photoUrl2: '',
        qualityScores: qualityScores,
        dataSource: 'user',
        verificationStatus: 'pending',
        createdAt: DateTime.now(),
      );

      await _firestoreService.addExperiment(
        experiment,
        _selectedImageFile!,
        imageFile2: _selectedImageFile2,
      );

      _showSnackBar('✅ Veri başarıyla eklendi!');

      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnackBar('❌ Hata: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
        return 'Kazıma';
      case 'scoring':
        return 'Çizme';
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Veri Ekle', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Bilgilendirme kartı
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Deneyimlediğiniz başarılı kesim parametrelerini topluluğa ekleyin. Veriler onaylandıktan sonra tahmin sisteminde kullanılacak.',
                            style: TextStyle(
                              color: Colors.blue.shade900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Makine seçimi
                _buildMachineSection(isDark, isMobile),
                const SizedBox(height: 16),

                // Malzeme seçimi
                _buildMaterialSection(isDark, isMobile),
                const SizedBox(height: 16),

                // İşlem tipleri
                _buildProcessSection(isDark, isMobile),
                const SizedBox(height: 16),

                // Fotoğraflar
                _buildPhotoSection(isDark, isMobile),
                const SizedBox(height: 24),

                // Gönder butonu
                CustomButton(
                  text: 'Veriyi Gönder',
                  onPressed: _submitData,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMachineSection(bool isDark, bool isMobile) {
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

            // Makine seçimi
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

              // Güç seçimi
              Text(
                'Lazer Gücü',
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

  Widget _buildMaterialSection(bool isDark, bool isMobile) {
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
                          return FilterChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(material['icon'] as String),
                                const SizedBox(width: 4),
                                Text(material['name'] as String),
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

              // Kalınlık seçimi
              Row(
                children: [
                  Text(
                    'Kalınlık (mm)',
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

  Widget _buildProcessSection(bool isDark, bool isMobile) {
    return Card(
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
                  'İşlem Parametreleri',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Kullandığınız parametreleri girin',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),

            _buildProcessInputs(
              'cutting',
              'Kesme',
              Icons.content_cut,
              Colors.red,
            ),
            const SizedBox(height: 12),
            _buildProcessInputs('engraving', 'Kazıma', Icons.draw, Colors.blue),
            const SizedBox(height: 12),
            _buildProcessInputs(
              'scoring',
              'Çizme',
              Icons.border_style,
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessInputs(
    String key,
    String name,
    IconData icon,
    Color color,
  ) {
    final controllers = _processControllers[key]!;
    final isSelected = _selectedProcesses[key]!;

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? color : Colors.grey.shade300),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            title: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Text(name, style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            value: isSelected,
            onChanged: (value) {
              setState(() => _selectedProcesses[key] = value ?? false);
            },
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
                          controller: controllers['power']!,
                          decoration: InputDecoration(
                            labelText: 'Güç (%)',
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
                          controller: controllers['speed']!,
                          decoration: InputDecoration(
                            labelText: 'Hız (mm/s)',
                            hintText: '0-500',
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
                          controller: controllers['passes']!,
                          decoration: InputDecoration(
                            labelText: 'Geçiş',
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
                      Text('Kalite: ${_qualityScores[key]!.toInt()}/10'),
                      Expanded(
                        child: Slider(
                          value: _qualityScores[key]!,
                          min: 0,
                          max: 10,
                          divisions: 10,
                          label: _qualityScores[key]!.toInt().toString(),
                          onChanged:
                              (value) =>
                                  setState(() => _qualityScores[key] = value),
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
    );
  }

  Widget _buildPhotoSection(bool isDark, bool isMobile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.photo_library, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Fotoğraflar',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'En az 1, en fazla 2 fotoğraf ekleyebilirsiniz.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 16),

            _buildPhotoUpload(
              title: '1. Fotoğraf (Zorunlu)',
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

            _buildPhotoUpload(
              title: '2. Fotoğraf (İsteğe Bağlı)',
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
    );
  }

  Widget _buildPhotoUpload({
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
                      decoration: BoxDecoration(
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
              label: const Text('Değiştir'),
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
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Fotoğraf Ekle',
                        style: TextStyle(
                          color: Colors.blue,
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
