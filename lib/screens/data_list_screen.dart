import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lasertuner/config/app_config.dart';
import 'package:lasertuner/screens/user_profile_screen.dart';
import '../models/experiment_model.dart';
import '../services/firestore_service.dart';

class DataListScreen extends StatefulWidget {
  final String userId;

  const DataListScreen({super.key, required this.userId});

  @override
  State<DataListScreen> createState() => _DataListScreenState();
}

class _DataListScreenState extends State<DataListScreen>
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Topluluk Verileri',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.deepPurple,
        elevation: isLargeScreen ? 0 : 4,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: TextStyle(
            fontSize: isLargeScreen ? 14 : 12,
            fontWeight: FontWeight.bold,
          ),
          tabs: [
            Tab(
              icon: Icon(Icons.pending, size: isLargeScreen ? 24 : 20),
              text: isLargeScreen ? 'Onay Bekleyen' : 'Bekleyen',
            ),
            Tab(
              icon: Icon(Icons.verified, size: isLargeScreen ? 24 : 20),
              text: isLargeScreen ? 'DoÄŸrulanmÄ±ÅŸ' : 'OnaylÄ±',
            ),
            Tab(
              icon: Icon(Icons.star, size: isLargeScreen ? 24 : 20),
              text: 'Gold Standard',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DataListTab(
            userId: widget.userId,
            verificationStatus: 'pending',
            dataSource: 'user',
            showVoting: true,
          ),
          _DataListTab(
            userId: widget.userId,
            verificationStatus: 'verified',
            dataSource: 'user',
            showVoting: false,
          ),
          _DataListTab(
            userId: widget.userId,
            dataSource: 'researcher',
            showVoting: false,
          ),
        ],
      ),
    );
  }
}

class _DataListTab extends StatelessWidget {
  final String userId;
  final String? verificationStatus;
  final String? dataSource;
  final bool showVoting;

  const _DataListTab({
    required this.userId,
    this.verificationStatus,
    this.dataSource,
    required this.showVoting,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return StreamBuilder<List<ExperimentModel>>(
      stream: _getExperimentsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: isDark ? Colors.white : Colors.deepPurple,
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox,
                  size: screenWidth > 600 ? 80 : 64,
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'HenÃ¼z veri yok',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontSize: screenWidth > 600 ? 18 : 16,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(screenWidth > 600 ? 24 : 16),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            return Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 900),
                child: _ExperimentCard(
                  experiment: snapshot.data![index],
                  currentUserId: userId,
                  showVoting: showVoting,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Stream<List<ExperimentModel>> _getExperimentsStream() {
    final service = FirestoreService();

    if (dataSource == 'researcher') {
      return service.getExperimentsByDataSource('researcher');
    }

    if (verificationStatus == 'pending' && dataSource == 'user') {
      return service.getExperimentsByStatusAndSource('pending', 'user');
    }

    if (verificationStatus == 'verified' && dataSource == 'user') {
      return service.getExperimentsByStatusAndSource('verified', 'user');
    }

    return service.getExperiments();
  }
}

class _ExperimentCard extends StatefulWidget {
  final ExperimentModel experiment;
  final String currentUserId;
  final bool showVoting;

  const _ExperimentCard({
    required this.experiment,
    required this.currentUserId,
    required this.showVoting,
  });

  @override
  State<_ExperimentCard> createState() => _ExperimentCardState();
}

class _ExperimentCardState extends State<_ExperimentCard> {
  bool _isExpanded = false;
  Map<String, dynamic>? _userData;

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
              .doc(widget.experiment.userId)
              .get();

      if (userDoc.exists && mounted) {
        setState(() {
          _userData = userDoc.data();
        });
      }
    } catch (e) {
      print('KullanÄ±cÄ± bilgisi yÃ¼kleme hatasÄ±: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;

    final isGoldStandard =
        widget.experiment.dataSource == 'researcher' ||
        widget.experiment.dataSource == 'researcher_import';
    final isPending = widget.experiment.verificationStatus == 'pending';
    final isRejected = widget.experiment.verificationStatus == 'rejected';

    final totalVotes =
        widget.experiment.qualityScores.values.isEmpty
            ? 0
            : widget.experiment.qualityScores.values.reduce((a, b) => a + b);
    final avgQuality =
        widget.experiment.qualityScores.values.isEmpty
            ? 0.0
            : totalVotes / widget.experiment.qualityScores.length;

    return Card(
      margin: EdgeInsets.only(bottom: isLargeScreen ? 24 : 16),
      elevation: isDark ? 2 : 3,
      color: isDark ? Colors.grey.shade900 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.grey.shade800 : Colors.transparent,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(isLargeScreen ? 20 : 16),
            decoration: BoxDecoration(
              color: _getHeaderColor(
                isGoldStandard,
                isRejected,
                isPending,
                isDark,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Ä°kon
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _getIconBgColor(
                          isGoldStandard,
                          isRejected,
                          isPending,
                          isDark,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getStatusIcon(isGoldStandard, isRejected, isPending),
                        color: _getStatusColor(
                          isGoldStandard,
                          isRejected,
                          isPending,
                        ),
                        size: isLargeScreen ? 28 : 24,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // BaÅŸlÄ±k bilgileri
                    // BaÅŸlÄ±k bilgileri
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.experiment.machineBrand,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isLargeScreen ? 18 : 16,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            // â¬‡ï¸ BURADA DEÄžÄ°ÅžTÄ°R
                            '${AppConfig.getMaterialDisplayName(widget.experiment.materialType)} - ${widget.experiment.materialThickness}mm',
                            style: TextStyle(
                              color:
                                  isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade700,
                              fontSize: isLargeScreen ? 14 : 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Kalite badge
                    if (avgQuality > 0)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isLargeScreen ? 14 : 12,
                          vertical: isLargeScreen ? 8 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getQualityColor(avgQuality),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              avgQuality.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Onay/Red sayÄ±larÄ±
                    if (isPending &&
                        (widget.experiment.approveCount > 0 ||
                            widget.experiment.rejectCount > 0))
                      const SizedBox(width: 8),
                    if (isPending &&
                        (widget.experiment.approveCount > 0 ||
                            widget.experiment.rejectCount > 0))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade800 : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                isDark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.thumb_up, size: 12, color: Colors.green),
                            const SizedBox(width: 2),
                            Text(
                              '${widget.experiment.approveCount}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.thumb_down, size: 12, color: Colors.red),
                            const SizedBox(width: 2),
                            Text(
                              '${widget.experiment.rejectCount}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                // KullanÄ±cÄ± bilgisi
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => UserProfileScreen(
                              userId: widget.experiment.userId,
                            ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? Colors.grey.shade800.withOpacity(0.5)
                              : Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: isLargeScreen ? 16 : 14,
                          backgroundColor: Colors.deepPurple,
                          child: Text(
                            _userData?['email']
                                    ?.substring(0, 1)
                                    .toUpperCase() ??
                                'U',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isLargeScreen ? 14 : 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _userData?['email']?.split('@')[0] ??
                                  'YÃ¼kleniyor...',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isLargeScreen ? 13 : 12,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            if (_userData?['reputation'] != null)
                              Row(
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: isLargeScreen ? 12 : 10,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_userData!['reputation']} puan',
                                    style: TextStyle(
                                      fontSize: isLargeScreen ? 11 : 10,
                                      color:
                                          isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color:
                              isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade600,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.experiment.photoUrl.isNotEmpty)
            Container(
              height: isLargeScreen ? 300 : 200,
              child: Builder(
                builder: (context) {
                  // FotoÄŸraflarÄ± topla
                  final photoUrls = <String>[];
                  if (widget.experiment.photoUrl.isNotEmpty) {
                    photoUrls.add(widget.experiment.photoUrl);
                  }
                  if (widget.experiment.photoUrl2.isNotEmpty) {
                    photoUrls.add(widget.experiment.photoUrl2);
                  }

                  if (photoUrls.isEmpty) {
                    return Container(
                      color:
                          isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      child: Center(
                        child: Icon(
                          Icons.image_not_supported,
                          color:
                              isDark
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade400,
                        ),
                      ),
                    );
                  }

                  return _PhotoCarousel(
                    photoUrls: photoUrls,
                    isDark: isDark,
                    isLarge: isLargeScreen,
                  );
                },
              ),
            ),
          // Ä°Ã§erik
          Padding(
            padding: EdgeInsets.all(isLargeScreen ? 20 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ã–zet bilgi
                Wrap(
                  spacing: isLargeScreen ? 12 : 8,
                  runSpacing: isLargeScreen ? 12 : 8,
                  children: [
                    _InfoChip(
                      icon: Icons.flash_on,
                      label: '${widget.experiment.laserPower}W',
                      isDark: isDark,
                      isLarge: isLargeScreen,
                    ),
                    _InfoChip(
                      icon: Icons.layers,
                      label: '${widget.experiment.processes.length} iÅŸlem',
                      isDark: isDark,
                      isLarge: isLargeScreen,
                    ),
                    _InfoChip(
                      icon: Icons.calendar_today,
                      label: _formatDate(widget.experiment.createdAt),
                      isDark: isDark,
                      isLarge: isLargeScreen,
                    ),
                  ],
                ),

                if (_isExpanded) ...[
                  const Divider(height: 32),

                  // DetaylÄ± parametreler
                  ...widget.experiment.processes.entries.map((entry) {
                    return _ProcessDetails(
                      processName: _getProcessName(entry.key),
                      params: entry.value,
                      quality: widget.experiment.qualityScores[entry.key] ?? 5,
                      isDark: isDark,
                      isLarge: isLargeScreen,
                    );
                  }).toList(),
                ],

                // GeniÅŸlet/Daralt butonu
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                    icon: Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: isDark ? Colors.blue.shade300 : Colors.blue,
                    ),
                    label: Text(
                      _isExpanded ? 'Daha Az' : 'DetaylarÄ± GÃ¶r',
                      style: TextStyle(
                        color: isDark ? Colors.blue.shade300 : Colors.blue,
                      ),
                    ),
                  ),
                ),

                // Oylama bÃ¶lÃ¼mÃ¼
                if (widget.showVoting && isPending) ...[
                  const Divider(),
                  _VotingSection(
                    experimentId: widget.experiment.id,
                    currentUserId: widget.currentUserId,
                    isDark: isDark,
                    isLarge: isLargeScreen,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getHeaderColor(
    bool isGold,
    bool isRejected,
    bool isPending,
    bool isDark,
  ) {
    if (isGold) {
      return isDark
          ? Colors.orange.shade900.withOpacity(0.3)
          : Colors.orange.shade50;
    }
    if (isRejected) {
      return isDark ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade50;
    }
    if (isPending) {
      return isDark
          ? Colors.blue.shade900.withOpacity(0.3)
          : Colors.blue.shade50;
    }
    return isDark
        ? Colors.green.shade900.withOpacity(0.3)
        : Colors.green.shade50;
  }

  Color _getIconBgColor(
    bool isGold,
    bool isRejected,
    bool isPending,
    bool isDark,
  ) {
    if (isGold) {
      return isDark ? Colors.orange.shade800 : Colors.orange.shade100;
    }
    if (isRejected) {
      return isDark ? Colors.red.shade800 : Colors.red.shade100;
    }
    if (isPending) {
      return isDark ? Colors.blue.shade800 : Colors.blue.shade100;
    }
    return isDark ? Colors.green.shade800 : Colors.green.shade100;
  }

  IconData _getStatusIcon(bool isGold, bool isRejected, bool isPending) {
    if (isGold) return Icons.star;
    if (isRejected) return Icons.cancel;
    if (isPending) return Icons.pending;
    return Icons.verified;
  }

  Color _getStatusColor(bool isGold, bool isRejected, bool isPending) {
    if (isGold) return Colors.orange;
    if (isRejected) return Colors.red;
    if (isPending) return Colors.blue;
    return Colors.green;
  }

  Color _getQualityColor(double quality) {
    if (quality >= 8) return Colors.green;
    if (quality >= 6) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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
}

// _PhotoCarousel widget'Ä±nÄ± _VotingSection'dan Ã¶nce ekleyin

class _PhotoCarousel extends StatefulWidget {
  final List<String> photoUrls;
  final bool isDark;
  final bool isLarge;

  const _PhotoCarousel({
    required this.photoUrls,
    required this.isDark,
    required this.isLarge,
  });

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: widget.photoUrls.length,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
            });
          },
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => _FullScreenImageViewer(
                          photoUrls: widget.photoUrls,
                          initialIndex: index,
                        ),
                  ),
                );
              },
              child: Container(
                color:
                    widget.isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                child: Image.network(
                  widget.photoUrls[index],
                  width: double.infinity,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value:
                            loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                        color: widget.isDark ? Colors.white : Colors.deepPurple,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Icon(
                        Icons.image_not_supported,
                        color:
                            widget.isDark
                                ? Colors.grey.shade600
                                : Colors.grey.shade400,
                        size: 48,
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),

        // FotoÄŸraf sayÄ±sÄ± gÃ¶stergesi (birden fazla varsa)
        if (widget.photoUrls.length > 1)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    '${_currentPage + 1}/${widget.photoUrls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Nokta gÃ¶stergeleri (birden fazla varsa)
        if (widget.photoUrls.length > 1)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.photoUrls.length,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        _currentPage == index
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Sol ok (birden fazla fotoÄŸraf varsa)
        if (widget.photoUrls.length > 1 && _currentPage > 0)
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_left,
                    color: Colors.white,
                    size: widget.isLarge ? 32 : 28,
                  ),
                ),
              ),
            ),
          ),

        // SaÄŸ ok (birden fazla fotoÄŸraf varsa)
        if (widget.photoUrls.length > 1 &&
            _currentPage < widget.photoUrls.length - 1)
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                    size: widget.isLarge ? 32 : 28,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FullScreenImageViewer extends StatefulWidget {
  final List<String> photoUrls;
  final int initialIndex;

  const _FullScreenImageViewer({
    required this.photoUrls,
    required this.initialIndex,
  });

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${widget.photoUrls.length}',
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.photoUrls.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                widget.photoUrls[index],
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value:
                          loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                      color: Colors.white,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      color: Colors.white,
                      size: 64,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final bool isLarge;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.isLarge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge ? 14 : 12,
        vertical: isLarge ? 10 : 8,
      ),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isLarge ? 18 : 16,
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              fontSize: isLarge ? 14 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessDetails extends StatelessWidget {
  final String processName;
  final ProcessParams params;
  final int quality;
  final bool isDark;
  final bool isLarge;

  const _ProcessDetails({
    required this.processName,
    required this.params,
    required this.quality,
    required this.isDark,
    required this.isLarge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: isLarge ? 16 : 12),
      padding: EdgeInsets.all(isLarge ? 16 : 12),
      decoration: BoxDecoration(
        color:
            isDark
                ? Colors.blue.shade900.withOpacity(0.3)
                : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.blue.shade700 : Colors.blue.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            processName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isLarge ? 18 : 16,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          SizedBox(height: isLarge ? 12 : 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ParamItem(
                'GÃ¼Ã§',
                '${params.power.toStringAsFixed(1)}%',
                isDark,
                isLarge,
              ),
              _ParamItem(
                'HÄ±z',
                '${params.speed.toStringAsFixed(0)} mm/s',
                isDark,
                isLarge,
              ),
              _ParamItem('GeÃ§iÅŸ', '${params.passes}', isDark, isLarge),
              _ParamItem('Kalite', '$quality/10', isDark, isLarge),
            ],
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
  final bool isLarge;

  const _ParamItem(this.label, this.value, this.isDark, this.isLarge);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isLarge ? 13 : 12,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        SizedBox(height: isLarge ? 6 : 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isLarge ? 15 : 14,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _VotingSection extends StatefulWidget {
  final String experimentId;
  final String currentUserId;
  final bool isDark;
  final bool isLarge;

  const _VotingSection({
    required this.experimentId,
    required this.currentUserId,
    required this.isDark,
    required this.isLarge,
  });

  @override
  State<_VotingSection> createState() => _VotingSectionState();
}

class _VotingSectionState extends State<_VotingSection> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isVoting = false;
  bool? _hasVoted;
  bool? _userVoteChoice;

  @override
  void initState() {
    super.initState();
    _checkVoteStatus();
  }

  Future<void> _checkVoteStatus() async {
    final voteStatus = await _firestoreService.getUserVoteStatus(
      widget.experimentId,
      widget.currentUserId,
    );

    if (mounted) {
      setState(() {
        _hasVoted = voteStatus['hasVoted'] as bool?;
        _userVoteChoice = voteStatus['isApprove'] as bool?;
      });
    }
  }

  Future<void> _vote(bool isApprove) async {
    if (_isVoting || _hasVoted == true) return;

    setState(() => _isVoting = true);

    try {
      await _firestoreService.voteOnExperiment(
        widget.experimentId,
        widget.currentUserId,
        isApprove,
      );

      if (mounted) {
        setState(() {
          _hasVoted = true;
          _userVoteChoice = isApprove;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isApprove ? 'âœ… OnaylandÄ±!' : 'âŒ Reddedildi!'),
            backgroundColor: isApprove ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  void _showChangeVoteDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor:
                widget.isDark ? Colors.grey.shade900 : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.swap_horiz, color: Colors.orange),
                const SizedBox(width: 12),
                Text(
                  'Oyunu DeÄŸiÅŸtir',
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Åžu anki oyunuz: ${_userVoteChoice == true ? "Onay" : "Red"}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _userVoteChoice == true ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Oyunuzu deÄŸiÅŸtirmek istediÄŸinize emin misiniz?',
                  style: TextStyle(
                    color:
                        widget.isDark ? Colors.grey.shade300 : Colors.black87,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Ä°ptal',
                  style: TextStyle(
                    color:
                        widget.isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _changeVote();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Evet, DeÄŸiÅŸtir'),
              ),
            ],
          ),
    );
  }

  Future<void> _changeVote() async {
    if (_isVoting) return;

    setState(() => _isVoting = true);

    try {
      final newVoteChoice = !_userVoteChoice!;

      await _firestoreService.changeExperimentVote(
        widget.experimentId,
        widget.currentUserId,
        newVoteChoice,
      );

      if (mounted) {
        setState(() {
          _userVoteChoice = newVoteChoice;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newVoteChoice ? 'âœ… Onaya Ã§evrildi!' : 'âŒ Redde Ã§evrildi!',
            ),
            backgroundColor: newVoteChoice ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasVoted == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: CircularProgressIndicator(
            color: widget.isDark ? Colors.white : Colors.deepPurple,
          ),
        ),
      );
    }

    if (_hasVoted == true) {
      return Container(
        padding: EdgeInsets.all(widget.isLarge ? 16 : 12),
        decoration: BoxDecoration(
          color:
              _userVoteChoice == true
                  ? (widget.isDark
                      ? Colors.green.shade900.withOpacity(0.3)
                      : Colors.green.shade50)
                  : (widget.isDark
                      ? Colors.red.shade900.withOpacity(0.3)
                      : Colors.red.shade50),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                _userVoteChoice == true
                    ? (widget.isDark
                        ? Colors.green.shade700
                        : Colors.green.shade200)
                    : (widget.isDark
                        ? Colors.red.shade700
                        : Colors.red.shade200),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _userVoteChoice == true ? Icons.check_circle : Icons.cancel,
                  color: _userVoteChoice == true ? Colors.green : Colors.red,
                  size: widget.isLarge ? 24 : 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _userVoteChoice == true
                        ? 'Bu veriyi onayladÄ±nÄ±z'
                        : 'Bu veriyi reddettiniz',
                    style: TextStyle(
                      color:
                          _userVoteChoice == true ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: widget.isLarge ? 15 : 14,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _showChangeVoteDialog,
                  child: Text(
                    'DeÄŸiÅŸtir',
                    style: TextStyle(
                      color:
                          _userVoteChoice == true
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(widget.isLarge ? 16 : 12),
      decoration: BoxDecoration(
        color:
            widget.isDark
                ? Colors.orange.shade900.withOpacity(0.3)
                : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              widget.isDark ? Colors.orange.shade700 : Colors.orange.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.how_to_vote,
                color: Colors.orange,
                size: widget.isLarge ? 24 : 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Bu veri doÄŸru mu?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: widget.isLarge ? 15 : 14,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: widget.isLarge ? 16 : 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isVoting ? null : () => _vote(true),
                  icon: const Icon(Icons.thumb_up),
                  label: Text(
                    'Onayla',
                    style: TextStyle(fontSize: widget.isLarge ? 15 : 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: widget.isLarge ? 14 : 12,
                    ),
                  ),
                ),
              ),
              SizedBox(width: widget.isLarge ? 16 : 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isVoting ? null : () => _vote(false),
                  icon: const Icon(Icons.thumb_down),
                  label: Text(
                    'Reddet',
                    style: TextStyle(fontSize: widget.isLarge ? 15 : 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: widget.isLarge ? 14 : 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
