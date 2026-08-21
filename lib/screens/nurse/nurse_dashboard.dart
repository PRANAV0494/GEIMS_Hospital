import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/service_locator.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import 'patient_details_tab.dart';
import '../../widgets/patient_search_delegate.dart';
import 'clinical_data_tab.dart';
import 'communication_hub_tab.dart';
import 'tasks_tab.dart';
import '../settings_screen.dart';
import '../../services/database_service.dart';

class NurseDashboard extends StatefulWidget {
  const NurseDashboard({super.key});

  @override
  State<NurseDashboard> createState() => _NurseDashboardState();
}

class _NurseDashboardState extends State<NurseDashboard> {
  final DatabaseService _databaseService = getIt<DatabaseService>();
  int _currentIndex = 0;
  int _selectedWard = 1;
  int _selectedBed = 1;

  List<Widget> _buildTabs() {
    return [
      PatientDetailsTab(
        key: ValueKey('patient_$_selectedWard,$_selectedBed'),
        wardNumber: _selectedWard,
        bedNumber: _selectedBed,
      ),
      ClinicalDataTab(
        key: ValueKey('clinical_$_selectedWard,$_selectedBed'),
        wardNumber: _selectedWard,
        bedNumber: _selectedBed,
      ),
      // Only treat messages as "seen" while this tab is actually visible -
      // IndexedStack keeps hidden tabs alive, and they must not mark messages
      // read that the nurse never looked at (bug #20).
      CommunicationHubTab(
        key: ValueKey('comm_$_selectedWard,$_selectedBed'),
        wardNumber: _selectedWard,
        bedNumber: _selectedBed,
        isActive: _currentIndex == 2,
      ),
      TasksTab(wardNumber: _selectedWard),
    ];
  }

  void _updateSelection(int ward, int bed) {
    setState(() {
      _selectedWard = ward;
      _selectedBed = bed;
      _buildTabs(); // Rebuild only when ward/bed actually changes
    });
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  // Removed unused method _updateWardBed - not referenced anywhere

  void _showWardBedSelector() {
    // Bug #4: the sheet previously mutated the dashboard's _selectedWard/
    // _selectedBed directly as the nurse tapped around, so swipe-dismissing
    // left the header showing one ward/bed while the tabs still charted
    // against the previous patient. Selection now lives in local temp state
    // and is committed only when the nurse confirms.
    // Local, uncommitted selection - declared OUTSIDE the sheet builder so
    // an async config load re-rendering the sheet can't reset taps the
    // nurse already made.
    int tempWard = _selectedWard;
    int tempBed = _selectedBed;

    showModalBottomSheet<Map<String, int>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => FutureBuilder<Map<String, dynamic>?>(
        future: _databaseService.getHospitalConfig(),
        builder: (context, configSnapshot) {
          // Fallbacks must match DatabaseService defaults (5 wards x 10 beds)
          // so a config-load failure can't render phantom wards (bug #37).
          final totalWards = (configSnapshot.data?['totalWards'] ?? 5) as int;
          final bedsPerWard =
              (configSnapshot.data?['bedsPerWard'] ?? 10) as int;

          return StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Ward & Bed',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 24),

                    // Ward selector
                    Text(
                      'Ward Number',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: List.generate(totalWards, (index) {
                        final ward = index + 1;
                        final isSelected = tempWard == ward;
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              tempWard = ward;
                            });
                          },
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '$ward',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 24),

                    // Bed selector
                    Text(
                      'Bed Number',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: List.generate(bedsPerWard, (index) {
                        final bed = index + 1;
                        final isSelected = tempBed == bed;
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              tempBed = bed;
                            });
                          },
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.accentColor
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.accentColor
                                    : Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '$bed',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 32),

                    // Confirm button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(
                            sheetContext,
                          ).pop({'ward': tempWard, 'bed': tempBed});
                        },
                        child: const Text(
                          'Confirm Selection',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          );
        },
      ),
    ).then((result) {
      if (!mounted || result == null) return;
      _updateSelection(result['ward']!, result['bed']!);
    });
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
              child: Image.asset(AppConstants.logoPath, fit: BoxFit.contain),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Bug #11: nurses previously landed on the doctor-only
              // PatientDetailView, where their messages were stored with
              // senderRole 'doctor' and an empty receiverId. Instead, jump
              // this dashboard to the found patient's ward/bed.
              showSearch(
                context: context,
                delegate: PatientSearchDelegate(
                  onPatientSelected: (patient) {
                    _updateSelection(patient.wardNumber, patient.bedNumber);
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
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
          // Ward & Bed selector header
          GestureDetector(
            onTap: _showWardBedSelector,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [AppTheme.cardShadow],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.person_outline,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Nurse',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Ward $_selectedWard',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.accentColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Bed $_selectedBed',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          // Tab content
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _buildTabs()),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
          // No need to rebuild tabs on navigation - streams handle updates
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Patient',
          ),
          NavigationDestination(
            icon: Icon(Icons.medical_information_outlined),
            selectedIcon: Icon(Icons.medical_information),
            label: 'Clinical',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.task_alt_outlined),
            selectedIcon: Icon(Icons.task_alt),
            label: 'Tasks',
          ),
        ],
      ),
    );
  }
}
