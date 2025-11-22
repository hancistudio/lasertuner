import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../models/experiment_model.dart';
import '../services/firestore_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';

class AddDataScreen extends StatefulWidget {
  final String userId;

  const AddDataScreen({super.key, required this.userId});

  @override
  State<AddDataScreen> createState() => _AddDataScreenState();
}

class _AddDataScreenState extends State<AddDataScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _machineBrandController = TextEditingController();
  final TextEditingController _laserPowerController = TextEditingController();
  final TextEditingController _materialTypeController = TextEditingController();
  final TextEditingController _thicknessController = TextEditingController();

  // İlk fotoğraf
  XFile? _selectedImageFile;
  Uint8List? _webImage;

  // İkinci fotoğraf
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

  Future<void> _submitData() async {
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

    if (_selectedImageFile == null) {
      _showSnackBar('Lütfen en az bir fotoğraf yükleyin');
      return;
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
        machineBrand: _machineBrandController.text,
        laserPower: double.parse(_laserPowerController.text),
        materialType: _materialTypeController.text,
        materialThickness: double.parse(_thicknessController.text),
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

      _showSnackBar('Veri başarıyla eklendi!');

      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Hata: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                // Makine bilgileri
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Makine Bilgileri',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _machineBrandController,
                          label: 'Makine Marka/Model',
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _laserPowerController,
                          label: 'Lazer Gücü (W)',
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Malzeme bilgileri
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Malzeme Bilgileri',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _materialTypeController,
                          label: 'Malzeme Türü',
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _thicknessController,
                          label: 'Kalınlık (mm)',
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // İşlem tipleri
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'İşlem Tipleri',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        ..._buildProcessSelections(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Fotoğraflar
                Card(
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
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // İlk fotoğraf
                        _buildPhotoSection(
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

                        // İkinci fotoğraf
                        _buildPhotoSection(
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
                ),
                const SizedBox(height: 24),

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
          ] else ...[
            GestureDetector(
              onTap: onPick,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                    style: BorderStyle.solid,
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
        ],
      ),
    );
  }

  List<Widget> _buildProcessSelections() {
    List<Widget> widgets = [];

    _selectedProcesses.forEach((processType, isSelected) {
      String processName =
          processType == 'cutting'
              ? 'Kesme'
              : processType == 'engraving'
              ? 'Kazıma'
              : 'Çizme';

      widgets.add(
        CheckboxListTile(
          title: Text(processName),
          value: isSelected,
          onChanged:
              (value) => setState(
                () => _selectedProcesses[processType] = value ?? false,
              ),
        ),
      );

      if (isSelected) {
        final controllers = _processControllers[processType]!;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 32, right: 16, bottom: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: controllers['power']!,
                        label: 'Güç (%)',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomTextField(
                        controller: controllers['speed']!,
                        label: 'Hız (mm/s)',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomTextField(
                        controller: controllers['passes']!,
                        label: 'Geçiş',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Kalite: ${_qualityScores[processType]!.toInt()}/10'),
                    Expanded(
                      child: Slider(
                        value: _qualityScores[processType]!,
                        min: 0,
                        max: 10,
                        divisions: 10,
                        label: _qualityScores[processType]!.toInt().toString(),
                        onChanged:
                            (value) => setState(
                              () => _qualityScores[processType] = value,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    });

    return widgets;
  }

  @override
  void dispose() {
    _machineBrandController.dispose();
    _laserPowerController.dispose();
    _materialTypeController.dispose();
    _thicknessController.dispose();
    _processControllers.values.forEach(
      (c) => c.values.forEach((ctrl) => ctrl.dispose()),
    );
    super.dispose();
  }
}
