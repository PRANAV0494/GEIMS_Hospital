import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../core/validators.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: false,
          labelPadding: EdgeInsets.zero,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Home'),
            Tab(icon: Icon(Icons.bed), text: 'Map'),
            Tab(icon: Icon(Icons.medical_services), text: 'Doctors'),
            Tab(icon: Icon(Icons.person), text: 'Nurses'),
            Tab(icon: Icon(Icons.settings), text: 'Config'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authProvider = Provider.of<AuthProvider>(
                context,
                listen: false,
              );
              await authProvider.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(
            authService: _authService,
            databaseService: _databaseService,
          ),
          _BedMapTab(databaseService: _databaseService),
          _StaffListTab(
            title: 'Doctors',
            role: 'doctor',
            authService: _authService,
            databaseService: _databaseService,
          ),
          _StaffListTab(
            title: 'Nurses',
            role: 'nurse',
            authService: _authService,
            databaseService: _databaseService,
          ),
          _InfrastructureTab(databaseService: _databaseService),
        ],
      ),
    );
  }
}

// ==================== OVERVIEW TAB ====================
class _OverviewTab extends StatefulWidget {
  final AuthService authService;
  final DatabaseService databaseService;

  const _OverviewTab({
    required this.authService,
    required this.databaseService,
  });

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  late Stream<List<UserModel>> _doctorsStream;
  late Stream<List<UserModel>> _nursesStream;

  @override
  void initState() {
    super.initState();
    // Bug #36: staff counts were fetched once and never refreshed after
    // adding/removing staff. Live streams keep them current.
    _doctorsStream = widget.databaseService.streamActiveStaff('doctor');
    _nursesStream = widget.databaseService.streamActiveStaff('nurse');
  }

  @override
  Widget build(BuildContext context) {
    // Single stream for all patient data - eliminates duplicate fetching
    return StreamBuilder(
      stream: widget.databaseService.getAllPatients(),
      builder: (context, snapshot) {
        final patients = snapshot.data ?? [];
        final criticalPatients = patients
            .where((p) => p.status.toLowerCase() == 'critical')
            .toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.analytics,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hospital Analytics',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Real-time overview of hospital status',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Stats Grid - uses live staff counts and streamed patient data
              _buildStatsGrid(context, patients, criticalPatients.length),

              const SizedBox(height: 24),

              // Critical Alerts Section - reuses same patient data
              _buildCriticalAlertsSection(criticalPatients),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsGrid(
    BuildContext context,
    List<dynamic> patients,
    int criticalCount,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Total Patients',
                value: '${patients.length}',
                icon: Icons.people,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: 'Critical',
                value: '$criticalCount',
                icon: Icons.warning_amber,
                color: AppTheme.criticalRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StreamBuilder<List<UserModel>>(
                stream: _doctorsStream,
                builder: (context, snapshot) {
                  final count = snapshot.hasData ? snapshot.data!.length : 0;
                  return _StatCard(
                    title: 'Doctors',
                    value: '$count',
                    icon: Icons.medical_services,
                    color: Colors.blue,
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StreamBuilder<List<UserModel>>(
                stream: _nursesStream,
                builder: (context, snapshot) {
                  final count = snapshot.hasData ? snapshot.data!.length : 0;
                  return _StatCard(
                    title: 'Nurses',
                    value: '$count',
                    icon: Icons.person,
                    color: AppTheme.stableGreen,
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Occupied Beds',
                value: '${patients.length}',
                icon: Icons.bed,
                color: Colors.purple,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ],
    );
  }

  Widget _buildCriticalAlertsSection(List<dynamic> criticalPatients) {
    if (criticalPatients.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.stableGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.stableGreen.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.stableGreen),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'No critical alerts at this time',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.warning, color: AppTheme.criticalRed),
            const SizedBox(width: 8),
            Text(
              'Critical Alerts (${criticalPatients.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...criticalPatients.map(
          (patient) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.criticalRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.criticalRed.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.criticalRed.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.person, color: AppTheme.criticalRed),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Ward ${patient.wardNumber} • Bed ${patient.bedNumber}',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.criticalRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'CRITICAL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ==================== BED MAP TAB ====================
class _BedMapTab extends StatefulWidget {
  final DatabaseService databaseService;

  const _BedMapTab({required this.databaseService});

  @override
  State<_BedMapTab> createState() => _BedMapTabState();
}

class _BedMapTabState extends State<_BedMapTab> {
  int _selectedWard = 1;
  int _totalWards = 5;
  int _bedsPerWard = 10;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await widget.databaseService.getHospitalConfig();
    if (!mounted || config == null) return;
    setState(() {
      _totalWards = config['totalWards'] ?? 5;
      _bedsPerWard = config['bedsPerWard'] ?? 10;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Ward Selector
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo, Colors.indigo.withValues(alpha: 0.8)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bed, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bed Map',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'View patient-bed assignments',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Ward Selector Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedWard,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down),
                items: List.generate(_totalWards, (index) {
                  final ward = index + 1;
                  return DropdownMenuItem(
                    value: ward,
                    child: Row(
                      children: [
                        Icon(Icons.domain, color: AppTheme.primaryColor),
                        const SizedBox(width: 12),
                        Text(
                          'Ward $ward',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedWard = value);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Legend
          Row(
            children: [
              _buildLegendItem(AppTheme.stableGreen, 'Occupied'),
              const SizedBox(width: 24),
              _buildLegendItem(Colors.grey.shade300, 'Empty'),
              const SizedBox(width: 24),
              _buildLegendItem(AppTheme.criticalRed, 'Critical'),
            ],
          ),
          const SizedBox(height: 16),

          // Bed Grid
          _buildBedGrid(),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildBedGrid() {
    return StreamBuilder(
      stream: widget.databaseService.getPatientsForWard(_selectedWard),
      builder: (context, snapshot) {
        final patients = snapshot.data ?? [];

        // Create a map of bed number to patient
        final bedPatientMap = <int, dynamic>{};
        for (final patient in patients) {
          bedPatientMap[patient.bedNumber] = patient;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: _bedsPerWard,
          itemBuilder: (context, index) {
            final bedNumber = index + 1;
            final patient = bedPatientMap[bedNumber];
            final isOccupied = patient != null;
            final isCritical =
                isOccupied && patient.status?.toLowerCase() == 'critical';

            Color bedColor;
            if (isCritical) {
              bedColor = AppTheme.criticalRed;
            } else if (isOccupied) {
              bedColor = AppTheme.stableGreen;
            } else {
              bedColor = Colors.grey.shade300;
            }

            return GestureDetector(
              onTap: isOccupied ? () => _showPatientDetails(patient) : null,
              child: Container(
                decoration: BoxDecoration(
                  color: bedColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: bedColor, width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isOccupied ? Icons.person : Icons.bed,
                      color: bedColor,
                      size: 28,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bed $bedNumber',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: bedColor,
                      ),
                    ),
                    if (isOccupied)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          patient.name,
                          style: const TextStyle(fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPatientDetails(dynamic patient) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.person, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Expanded(child: Text(patient.name)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Ward', '${patient.wardNumber}'),
            _buildDetailRow('Bed', '${patient.bedNumber}'),
            _buildDetailRow('Age', '${patient.age}'),
            _buildDetailRow('Gender', patient.gender),
            _buildDetailRow('Status', patient.status),
            if (patient.diagnosisSummary.isNotEmpty)
              _buildDetailRow('Diagnosis', patient.diagnosisSummary),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _StaffListTab extends StatefulWidget {
  final String title;
  final String role;
  final AuthService authService;
  final DatabaseService databaseService;

  const _StaffListTab({
    required this.title,
    required this.role,
    required this.authService,
    required this.databaseService,
  });

  @override
  State<_StaffListTab> createState() => _StaffListTabState();
}

class _StaffListTabState extends State<_StaffListTab> {
  List<UserModel> _staff = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Bug #28/#36: the list used to be a FutureBuilder whose future was
  // re-created inline in build(), so it reset to a full-screen spinner on
  // every tab swipe and never refreshed after adding staff.
  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final staff = widget.role == 'doctor'
          ? await widget.authService.getAllDoctors()
          : await widget.authService.getAllNurses();
      if (!mounted) return;
      setState(() {
        _staff = staff;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off, size: 60, color: AppTheme.criticalRed),
                  const SizedBox(height: 16),
                  Text(
                    'Could not load staff',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: _staff.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.7,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  widget.role == 'doctor'
                                      ? Icons.medical_services_outlined
                                      : Icons.person_outline,
                                  size: 80,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No active ${widget.role}s found',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _staff.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final user = _staff[index];
                        return _StaffCard(
                          user: user,
                          onDelete: () => _confirmDeactivate(user),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStaffDialog,
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add),
        label: Text('Add ${widget.role == 'doctor' ? 'Doctor' : 'Nurse'}'),
      ),
    );
  }

  /// Bug #5: staff creation previously called signUp() on the PRIMARY auth
  /// instance, which signed the admin out and hijacked the session. The
  /// service now provisions via a secondary app instance and the admin's
  /// session is untouched.
  void _showAddStaffDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final employeeIdController = TextEditingController();
    final wardController = TextEditingController();
    final specializationController = TextEditingController();

    final dialogFuture = showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Add New ${widget.role == 'doctor' ? 'Doctor' : 'Nurse'}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password * (min 6 characters)',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: employeeIdController,
                decoration: const InputDecoration(
                  labelText: 'Employee ID *',
                  prefixIcon: Icon(Icons.badge),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: wardController,
                decoration: const InputDecoration(
                  labelText: 'Assigned Ward',
                  prefixIcon: Icon(Icons.location_on),
                ),
                keyboardType: TextInputType.number,
              ),
              if (widget.role == 'doctor') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: specializationController,
                  decoration: const InputDecoration(
                    labelText: 'Specialization',
                    prefixIcon: Icon(Icons.medical_information),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Capture lookups before any await (context across async gaps).
              final rootMessenger = ScaffoldMessenger.of(context);
              final dialogMessenger = ScaffoldMessenger.of(dialogContext);

              // Bug #31 companion: add-staff had NO validation - invalid
              // emails created accounts that could never log in.
              final email = emailController.text.trim();
              final name = nameController.text.trim();

              if (name.isEmpty ||
                  employeeIdController.text.trim().isEmpty ||
                  passwordController.text.length < 6 ||
                  Validators.email(email) != null) {
                dialogMessenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Name, employee ID and a valid email are required; '
                      'password needs at least 6 characters.',
                    ),
                    backgroundColor: AppTheme.warningOrange,
                  ),
                );
                return;
              }

              try {
                await widget.authService.createStaffAccount(
                  email: email,
                  password: passwordController.text,
                  name: name,
                  employeeId: employeeIdController.text.trim(),
                  role: widget.role,
                  assignedWard: wardController.text.trim().isNotEmpty
                      ? wardController.text.trim()
                      : null,
                  specialization:
                      specializationController.text.trim().isNotEmpty
                      ? specializationController.text.trim()
                      : null,
                );

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                  rootMessenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        '${widget.role == 'doctor' ? 'Doctor' : 'Nurse'} '
                        'added successfully',
                      ),
                      backgroundColor: AppTheme.stableGreen,
                    ),
                  );
                }
              } on FirebaseAuthException catch (e) {
                if (e.code == 'email-already-in-use') {
                  // Bug #15: deactivated staff keep their reserved Auth
                  // account, so re-adding their email used to fail forever.
                  // Offer reactivation instead.
                  final reactivated = await widget.authService
                      .reactivateStaffByEmail(email);
                  if (!dialogContext.mounted) return;
                  if (reactivated != null) {
                    Navigator.pop(dialogContext, true);
                    rootMessenger.showSnackBar(
                      SnackBar(
                        content: Text('${reactivated.name} reactivated'),
                        backgroundColor: AppTheme.stableGreen,
                      ),
                    );
                  } else {
                    dialogMessenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'This email already has an active account.',
                        ),
                        backgroundColor: AppTheme.criticalRed,
                      ),
                    );
                  }
                } else {
                  dialogMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.message ?? e.code}'),
                      backgroundColor: AppTheme.criticalRed,
                    ),
                  );
                }
              } catch (e) {
                dialogMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: AppTheme.criticalRed,
                  ),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    // Bug #36: six TextEditingControllers leaked on every dialog open.
    dialogFuture
        .whenComplete(() {
          nameController.dispose();
          emailController.dispose();
          passwordController.dispose();
          employeeIdController.dispose();
          wardController.dispose();
          specializationController.dispose();
        })
        .then((created) {
          if (created == true) {
            _load();
          }
        });
  }

  void _confirmDeactivate(UserModel user) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Staff Member'),
        content: Text(
          'Deactivate ${user.name}? They will immediately lose access to the '
          'app. Their login can be restored later by adding them again with '
          'the same email.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.criticalRed,
            ),
            onPressed: () async {
              final rootMessenger = ScaffoldMessenger.of(context);
              // Bug #15: only the Firestore doc was deleted (which rules
              // denied anyway), while the Auth account lived on with full
              // sign-in ability. Deactivation flips isActive, which both the
              // rosters and the sign-in flow honor.
              final success = await widget.databaseService.deactivateUser(
                user.id,
              );
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              rootMessenger.showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? '${user.name} deactivated'
                        : 'Failed to deactivate ${user.name}',
                  ),
                  backgroundColor: success
                      ? AppTheme.stableGreen
                      : AppTheme.criticalRed,
                ),
              );
              if (success) {
                _load();
              }
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onDelete;

  const _StaffCard({required this.user, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: user.isDoctor
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : AppTheme.stableGreen.withValues(alpha: 0.1),
          child: Icon(
            user.isDoctor ? Icons.medical_services : Icons.person,
            color: user.isDoctor ? AppTheme.primaryColor : AppTheme.stableGreen,
          ),
        ),
        title: Text(
          user.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.email,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            if (user.assignedWard != null)
              Text(
                'Ward: ${user.assignedWard}',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            if (user.specialization != null)
              Text(
                user.specialization!,
                style: TextStyle(color: AppTheme.primaryColor, fontSize: 12),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

class _InfrastructureTab extends StatefulWidget {
  final DatabaseService databaseService;

  const _InfrastructureTab({required this.databaseService});

  @override
  State<_InfrastructureTab> createState() => _InfrastructureTabState();
}

class _InfrastructureTabState extends State<_InfrastructureTab> {
  int _totalWards = 5;
  int _bedsPerWard = 10;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await widget.databaseService.getHospitalConfig();
    if (!mounted) return;
    setState(() {
      _totalWards = config?['totalWards'] ?? 5;
      _bedsPerWard = config?['bedsPerWard'] ?? 10;
      _isLoading = false;
    });
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);
    final success = await widget.databaseService.updateHospitalConfig(
      totalWards: _totalWards,
      bedsPerWard: _bedsPerWard,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Configuration saved!' : 'Failed to save'),
        backgroundColor: success ? AppTheme.stableGreen : AppTheme.criticalRed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.apartment,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hospital Infrastructure',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Configure wards and beds',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Ward Configuration
          _buildConfigCard(
            title: 'Total Wards',
            subtitle: 'Number of wards in the hospital',
            icon: Icons.domain,
            value: _totalWards,
            onIncrement: () => setState(() => _totalWards++),
            onDecrement: () {
              if (_totalWards > 1) setState(() => _totalWards--);
            },
          ),
          const SizedBox(height: 16),

          // Bed Configuration
          _buildConfigCard(
            title: 'Beds per Ward',
            subtitle: 'Number of beds in each ward',
            icon: Icons.single_bed,
            value: _bedsPerWard,
            onIncrement: () => setState(() => _bedsPerWard++),
            onDecrement: () {
              if (_bedsPerWard > 1) setState(() => _bedsPerWard--);
            },
          ),
          const SizedBox(height: 24),

          // Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.stableGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.stableGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.stableGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Total Capacity: ${_totalWards * _bedsPerWard} beds across $_totalWards wards',
                    style: TextStyle(
                      color: AppTheme.stableGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Save Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveConfig,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Saving...' : 'Save Configuration'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required int value,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: onDecrement,
                icon: const Icon(Icons.remove_circle_outline),
                color: AppTheme.criticalRed,
                iconSize: 32,
              ),
              Container(
                width: 50,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: onIncrement,
                icon: const Icon(Icons.add_circle_outline),
                color: AppTheme.stableGreen,
                iconSize: 32,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
