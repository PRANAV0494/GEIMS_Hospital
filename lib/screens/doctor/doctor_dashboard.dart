import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../models/patient_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import 'patient_detail_view.dart';
import 'patient_detail_view.dart';
import '../../widgets/patient_search_delegate.dart';
import '../settings_screen.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  final _databaseService = DatabaseService();
  int? _selectedWard;
  List<int> _wards = [];

  @override
  void initState() {
    super.initState();
    _loadWards();
  }

  Future<void> _loadWards() async {
    // Get unique wards from patients
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final doctorId = authProvider.currentUser?.id ?? '';
    
    final snapshot = await FirebaseFirestore.instance
        .collection(AppConstants.patientsCollection)
        .where('attendingDoctorId', isEqualTo: doctorId)
        .get();
    
    final wards = snapshot.docs
        .map((doc) => doc.data()['wardNumber'] as int)
        .toSet()
        .toList()
      ..sort();
    
    setState(() {
      _wards = wards;
      if (_wards.isNotEmpty) {
        _selectedWard = _wards.first;
      }
    });
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 36,
              width: 100,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.asset(
                AppConstants.logoPath,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWards,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: PatientSearchDelegate(doctorId: user?.id ?? ''),
              );
            },
            tooltip: 'Search Patient',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          // Doctor info header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [AppTheme.cardShadow],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.local_hospital,
                    color: AppTheme.accentColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dr. ${user?.name ?? 'Doctor'}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (user?.specialization != null)
                        Text(
                          user!.specialization!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Ward tabs
          if (_wards.isNotEmpty)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _wards.length,
                itemBuilder: (context, index) {
                  final ward = _wards[index];
                  final isSelected = _selectedWard == ward;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedWard = ward);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Ward $ward',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Beds list
          Expanded(
            child: _selectedWard == null
                ? _buildEmptyState()
                : _buildBedsList(user?.id ?? ''),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bed_outlined,
            size: 80,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No patients assigned',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Patients will appear here when assigned to you',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBedsList(String doctorId) {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection(AppConstants.patientsCollection)
        .where('attendingDoctorId', isEqualTo: doctorId)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bed_outlined,
                size: 60,
                color: AppTheme.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No patients assigned to you',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
        );
      }

      // Filter by ward and sort client-side to avoid composite index requirement
      final patients = snapshot.data!.docs
          .map((doc) => PatientModel.fromFirestore(doc))
          .where((p) => p.wardNumber == _selectedWard)
          .toList()
        ..sort((a, b) => a.bedNumber.compareTo(b.bedNumber));

      if (patients.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bed_outlined,
                size: 60,
                color: AppTheme.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No patients in Ward $_selectedWard',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
        );
      }

      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.85,
        ),
        itemCount: patients.length,
        itemBuilder: (context, index) {
          return _BedCard(
            patient: patients[index],
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PatientDetailView(
                    patient: patients[index],
                  ),
                ),
              );
            },
          );
        },
      );
    },
  );
}
}

class _BedCard extends StatelessWidget {
  final PatientModel patient;
  final VoidCallback onTap;

  const _BedCard({
    required this.patient,
    required this.onTap,
  });

  Color get _statusColor {
    if (patient.isCritical) return AppTheme.criticalRed;
    switch (patient.status) {
      case AppConstants.statusCritical:
        return AppTheme.criticalRed;
      case AppConstants.statusPending:
        return AppTheme.warningOrange;
      case AppConstants.statusStable:
      default:
        return AppTheme.stableGreen;
    }
  }

  IconData get _statusIcon {
    if (patient.isCritical) return Icons.warning;
    switch (patient.status) {
      case AppConstants.statusCritical:
        return Icons.warning;
      case AppConstants.statusPending:
        return Icons.notifications;
      case AppConstants.statusStable:
      default:
        return Icons.check_circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: patient.isCritical ? AppTheme.criticalRed : AppTheme.dividerColor,
            width: patient.isCritical ? 2 : 1,
          ),
          boxShadow: [AppTheme.cardShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bed number header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bed ${patient.bedNumber}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _statusColor,
                    ),
                  ),
                  Icon(_statusIcon, color: _statusColor, size: 24),
                ],
              ),
            ),

            // Patient info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${patient.age} yrs • ${patient.gender}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        patient.diagnosisSummary,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    // Allergies warning
                    if (patient.hasAllergies)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.warningOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_amber,
                              size: 14,
                              color: AppTheme.warningOrange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${patient.allergies.length} Allergies',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.warningOrange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
