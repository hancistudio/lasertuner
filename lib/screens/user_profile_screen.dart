import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/experiment_model.dart';
import '../models/user_model.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  UserModel? _user;
  bool _isLoading = true;
  List<ExperimentModel> _userExperiments = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .get();
      if (userDoc.exists) {
        _user = UserModel.fromMap(userDoc.data()!);
      }

      final experimentsSnapshot =
          await FirebaseFirestore.instance
              .collection('experiments')
              .where('userId', isEqualTo: widget.userId)
              .orderBy('createdAt', descending: true)
              .get();

      _userExperiments =
          experimentsSnapshot.docs
              .map((doc) => ExperimentModel.fromFirestore(doc))
              .toList();

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profil'),
          backgroundColor: Colors.deepPurple,
        ),
        body: Center(
          child: CircularProgressIndicator(
            color: isDark ? Colors.white : Colors.deepPurple,
          ),
        ),
      );
    }

    if (_user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profil'),
          backgroundColor: Colors.deepPurple,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Kullanıcı bulunamadı',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    final verifiedCount =
        _userExperiments
            .where((e) => e.verificationStatus == 'verified')
            .length;
    final pendingCount =
        _userExperiments.where((e) => e.verificationStatus == 'pending').length;
    final rejectedCount =
        _userExperiments
            .where((e) => e.verificationStatus == 'rejected')
            .length;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Kullanıcı Profili',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profil Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isLargeScreen ? 32 : 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple, Colors.deepPurple.shade700],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: isLargeScreen ? 120 : 100,
                    height: isLargeScreen ? 120 : 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _user!.email.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontSize: isLargeScreen ? 48 : 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isLargeScreen ? 20 : 16),
                  Text(
                    _user!.email.split('@')[0],
                    style: TextStyle(
                      fontSize: isLargeScreen ? 28 : 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _user!.email,
                    style: TextStyle(
                      fontSize: isLargeScreen ? 16 : 14,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(height: isLargeScreen ? 20 : 16),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isLargeScreen ? 24 : 20,
                      vertical: isLargeScreen ? 12 : 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: isLargeScreen ? 28 : 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_user!.reputation} Puan',
                          style: TextStyle(
                            fontSize: isLargeScreen ? 20 : 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'İstatistikler',
                        style: TextStyle(
                          fontSize: isLargeScreen ? 24 : 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      SizedBox(height: isLargeScreen ? 20 : 16),

                      LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount =
                              constraints.maxWidth > 900 ? 4 : 2;
                          return GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: isLargeScreen ? 16 : 12,
                            crossAxisSpacing: isLargeScreen ? 16 : 12,
                            childAspectRatio: isLargeScreen ? 1.5 : 1.3,
                            children: [
                              _StatCard(
                                icon: Icons.upload_file,
                                label: 'Toplam Veri',
                                value: _userExperiments.length.toString(),
                                color: Colors.blue,
                                isDark: isDark,
                                isLarge: isLargeScreen,
                              ),
                              _StatCard(
                                icon: Icons.verified,
                                label: 'Onaylanmış',
                                value: verifiedCount.toString(),
                                color: Colors.green,
                                isDark: isDark,
                                isLarge: isLargeScreen,
                              ),
                              _StatCard(
                                icon: Icons.pending,
                                label: 'Bekleyen',
                                value: pendingCount.toString(),
                                color: Colors.orange,
                                isDark: isDark,
                                isLarge: isLargeScreen,
                              ),
                              _StatCard(
                                icon: Icons.cancel,
                                label: 'Reddedilen',
                                value: rejectedCount.toString(),
                                color: Colors.red,
                                isDark: isDark,
                                isLarge: isLargeScreen,
                              ),
                            ],
                          );
                        },
                      ),

                      SizedBox(height: isLargeScreen ? 32 : 24),

                      Row(
                        children: [
                          Text(
                            'Paylaşılan Veriler',
                            style: TextStyle(
                              fontSize: isLargeScreen ? 24 : 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_userExperiments.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isLargeScreen ? 20 : 16),

                      if (_userExperiments.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.inbox,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Henüz veri paylaşılmamış',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _userExperiments.length,
                          itemBuilder: (context, index) {
                            return _DetailedExperimentCard(
                              experiment: _userExperiments[index],
                              isDark: isDark,
                              isLarge: isLargeScreen,
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  final bool isLarge;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
    required this.isLarge,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isDark ? 2 : 3,
      color: isDark ? Colors.grey.shade900 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isLarge ? 20 : 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isLarge ? 12 : 10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: isLarge ? 32 : 28),
            ),
            SizedBox(height: isLarge ? 12 : 8),
            Text(
              value,
              style: TextStyle(
                fontSize: isLarge ? 28 : 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: isLarge ? 13 : 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailedExperimentCard extends StatefulWidget {
  final ExperimentModel experiment;
  final bool isDark;
  final bool isLarge;

  const _DetailedExperimentCard({
    required this.experiment,
    required this.isDark,
    required this.isLarge,
  });

  @override
  State<_DetailedExperimentCard> createState() =>
      _DetailedExperimentCardState();
}

class _DetailedExperimentCardState extends State<_DetailedExperimentCard> {
  bool _isExpanded = false;
  int _currentPhotoIndex = 0;

  @override
  Widget build(BuildContext context) {
    final exp = widget.experiment;
    final isVerified = exp.verificationStatus == 'verified';
    final isPending = exp.verificationStatus == 'pending';

    final photos = <String>[];
    if (exp.photoUrl.isNotEmpty) photos.add(exp.photoUrl);
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
                  isVerified
                      ? (widget.isDark
                          ? Colors.green.shade900.withOpacity(0.3)
                          : Colors.green.shade50)
                      : isPending
                      ? (widget.isDark
                          ? Colors.orange.shade900.withOpacity(0.3)
                          : Colors.orange.shade50)
                      : (widget.isDark
                          ? Colors.red.shade900.withOpacity(0.3)
                          : Colors.red.shade50),
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
                    color:
                        isVerified
                            ? Colors.green.withOpacity(0.2)
                            : isPending
                            ? Colors.orange.withOpacity(0.2)
                            : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isVerified
                        ? Icons.verified
                        : isPending
                        ? Icons.pending
                        : Icons.cancel,
                    color:
                        isVerified
                            ? Colors.green
                            : isPending
                            ? Colors.orange
                            : Colors.red,
                    size: widget.isLarge ? 28 : 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exp.machineBrand,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: widget.isLarge ? 18 : 16,
                          color: widget.isDark ? Colors.white : Colors.black87,
                        ),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isVerified
                          ? 'Onaylandı'
                          : isPending
                          ? 'Beklemede'
                          : 'Reddedildi',
                      style: TextStyle(
                        color:
                            isVerified
                                ? Colors.green
                                : isPending
                                ? Colors.orange
                                : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: widget.isLarge ? 14 : 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${exp.createdAt.day}/${exp.createdAt.month}/${exp.createdAt.year}',
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            widget.isDark
                                ? Colors.grey.shade500
                                : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Fotoğraflar
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
                // Fotoğraf sayısı göstergesi
                if (photos.length > 1)
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
                                      ? Colors.blue
                                      : Colors.white.withOpacity(0.5),
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                // Sol/Sağ oklar
                if (photos.length > 1) ...[
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
          ],

          // İçerik
          Padding(
            padding: EdgeInsets.all(widget.isLarge ? 16 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Özet bilgi
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
                      label: '${exp.processes.length} işlem',
                      isDark: widget.isDark,
                    ),
                    if (photos.length > 1)
                      _InfoChip(
                        icon: Icons.photo_library,
                        label: '${photos.length} fotoğraf',
                        isDark: widget.isDark,
                      ),
                  ],
                ),

                if (_isExpanded) ...[
                  const Divider(height: 24),

                  // Detaylı parametreler
                  ...exp.processes.entries.map((entry) {
                    String processName =
                        entry.key == 'cutting'
                            ? 'Kesme'
                            : entry.key == 'engraving'
                            ? 'Kazıma'
                            : 'Çizme';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            widget.isDark
                                ? Colors.blue.shade900.withOpacity(0.3)
                                : Colors.blue.shade50,
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
                                'Güç',
                                '${entry.value.power.toStringAsFixed(1)}%',
                                widget.isDark,
                              ),
                              _ParamItem(
                                'Hız',
                                '${entry.value.speed.toStringAsFixed(0)} mm/s',
                                widget.isDark,
                              ),
                              _ParamItem(
                                'Geçiş',
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

                  // Oylama bilgisi
                  if (exp.approveCount > 0 || exp.rejectCount > 0)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            widget.isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.thumb_up, size: 16, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(
                            '${exp.approveCount}',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.thumb_down, size: 16, color: Colors.red),
                          const SizedBox(width: 4),
                          Text(
                            '${exp.rejectCount}',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],

                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                    icon: Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.blue,
                    ),
                    label: Text(
                      _isExpanded ? 'Daha Az' : 'Detayları Gör',
                      style: TextStyle(color: Colors.blue),
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
