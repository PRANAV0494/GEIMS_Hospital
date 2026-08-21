import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../core/validators.dart';
import '../../models/patient_model.dart';
import '../../models/vitals_model.dart';
import '../../models/medication_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';

class ClinicalDataTab extends StatefulWidget {
  final int wardNumber;
  final int bedNumber;

  const ClinicalDataTab({
    super.key,
    required this.wardNumber,
    required this.bedNumber,
  });

  @override
  State<ClinicalDataTab> createState() => _ClinicalDataTabState();
}

class _ClinicalDataTabState extends State<ClinicalDataTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    // Bug #18: this tab used a one-shot get(), so a patient admitted into an
    // empty bed stayed invisible ("No patient in this bed") until the nurse
    // re-picked the ward, and a doctor reassignment kept routing data to
    // stale state. A live stream keeps the tab in sync with admissions and
    // edits automatically.
    return StreamBuilder<PatientModel?>(
      stream: _databaseService.getPatientForBed(
        widget.wardNumber,
        widget.bedNumber,
      ),
      builder: (context, patientSnapshot) {
        if (patientSnapshot.hasError) {
          return _buildErrorView(
            'Could not load patient: ${patientSnapshot.error}',
          );
        }
        if (!patientSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final patient = patientSnapshot.data;

        if (patient == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_off_outlined,
                  size: 80,
                  color: AppTheme.textSecondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No patient in this bed',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add patient details first',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Patient header
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [AppTheme.cardShadow],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: patient.isCritical
                          ? AppTheme.criticalRed.withValues(alpha: 0.1)
                          : AppTheme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person,
                      color: patient.isCritical
                          ? AppTheme.criticalRed
                          : AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${patient.age} yrs • ${patient.gender}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  if (patient.isCritical)
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

            // Tab bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppTheme.textSecondary,
                tabs: const [
                  Tab(text: 'Vitals'),
                  Tab(text: 'Medications'),
                ],
              ),
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _VitalsSection(
                    patient: patient,
                    databaseService: _databaseService,
                  ),
                  _MedicationsSection(
                    patient: patient,
                    databaseService: _databaseService,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 60, color: AppTheme.criticalRed),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppTheme.criticalRed),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

// Vitals Section Widget
class _VitalsSection extends StatefulWidget {
  final PatientModel patient;
  final DatabaseService databaseService;

  const _VitalsSection({required this.patient, required this.databaseService});

  @override
  State<_VitalsSection> createState() => _VitalsSectionState();
}

class _VitalsSectionState extends State<_VitalsSection> {
  final _formKey = GlobalKey<FormState>();
  final _heartRateController = TextEditingController();
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _oxygenController = TextEditingController();
  final _tempController = TextEditingController();
  final _respController = TextEditingController();
  final _glucoseController = TextEditingController();
  bool _isSaving = false;

  // Bug #28: streams are created once per patient and cached, instead of
  // being re-created inside build() on every keystroke/rebuild.
  Stream<List<VitalsModel>>? _vitalsStream;
  String? _streamPatientId;

  Stream<List<VitalsModel>> _getVitalsStream(String patientId) {
    if (_vitalsStream == null || _streamPatientId != patientId) {
      _streamPatientId = patientId;
      _vitalsStream = widget.databaseService.getVitalsForPatient(patientId);
    }
    return _vitalsStream!;
  }

  Future<void> _saveVitals() async {
    // Form-level validation catches malformed AND clinically implausible
    // values via core/validators.dart (bug #23 - previously dead code).
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final heartRate = int.tryParse(_heartRateController.text);
    final systolic = int.tryParse(_systolicController.text);
    final diastolic = int.tryParse(_diastolicController.text);
    final oxygen = double.tryParse(_oxygenController.text);
    final temp = double.tryParse(_tempController.text);
    final resp = int.tryParse(_respController.text);
    final glucose = double.tryParse(_glucoseController.text);

    if (heartRate == null ||
        systolic == null ||
        diastolic == null ||
        oxygen == null ||
        temp == null ||
        resp == null ||
        glucose == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields with valid numbers'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    final vitals = VitalsModel(
      id: '',
      patientId: widget.patient.id,
      recordedById: user?.id ?? '',
      recordedByName: user?.name ?? 'Unknown',
      timestamp: DateTime.now(),
      heartRate: heartRate,
      systolicBP: systolic,
      diastolicBP: diastolic,
      oxygenSaturation: oxygen,
      temperature: temp,
      respiratoryRate: resp,
      glucoseLevel: glucose,
    );

    final result = await widget.databaseService.addVitals(vitals);

    if (mounted) {
      setState(() => _isSaving = false);

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Vitals recorded successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        // Clear form
        _heartRateController.clear();
        _systolicController.clear();
        _diastolicController.clear();
        _oxygenController.clear();
        _tempController.clear();
        _respController.clear();
        _glucoseController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to record vitals'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vitals Trend Chart
            Text(
              'Recent Trends',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            StreamBuilder<List<VitalsModel>>(
              stream: _getVitalsStream(widget.patient.id),
              builder: (context, snapshot) {
                // Bug #21: backend/rules failures previously fell through to
                // "No vitals recorded yet", affirmatively telling a nurse there
                // was no data when the data simply failed to load.
                if (snapshot.hasError) {
                  return _buildStreamError('Could not load vitals');
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'No vitals recorded yet',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  );
                }

                final vitals = snapshot.data!
                    .take(10)
                    .toList()
                    .reversed
                    .toList();

                return Container(
                  height: 180,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [AppTheme.cardShadow],
                  ),
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        // Heart Rate line
                        LineChartBarData(
                          spots: vitals.asMap().entries.map((e) {
                            return FlSpot(
                              e.key.toDouble(),
                              e.value.heartRate.toDouble(),
                            );
                          }).toList(),
                          isCurved: true,
                          color: AppTheme.criticalRed,
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                        ),
                        // Oxygen line
                        LineChartBarData(
                          spots: vitals.asMap().entries.map((e) {
                            return FlSpot(
                              e.key.toDouble(),
                              e.value.oxygenSaturation,
                            );
                          }).toList(),
                          isCurved: true,
                          color: AppTheme.accentColor,
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendItem('Heart Rate', AppTheme.criticalRed),
                const SizedBox(width: 24),
                _legendItem('O₂ Saturation', AppTheme.accentColor),
              ],
            ),

            const SizedBox(height: 24),

            // Vitals History List
            Text(
              'Vitals History',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            StreamBuilder<List<VitalsModel>>(
              stream: _getVitalsStream(widget.patient.id),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildStreamError('Could not load vitals history');
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'No vitals recorded yet',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  );
                }

                final allVitals = snapshot.data!;
                return Column(
                  children: allVitals.take(5).map((vital) {
                    return GestureDetector(
                      onTap: () => _showVitalDetailDialog(vital),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.dividerColor),
                          boxShadow: [AppTheme.cardShadow],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat(
                                    'MMM dd, yyyy • HH:mm',
                                  ).format(vital.timestamp),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      'by ${vital.recordedByName}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.touch_app,
                                      size: 14,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 16,
                              runSpacing: 4,
                              children: [
                                _vitalChip(
                                  '❤️ ${vital.heartRate} bpm',
                                  vital.isHeartRateAbnormal
                                      ? AppTheme.criticalRed
                                      : null,
                                ),
                                _vitalChip(
                                  '💧 ${vital.oxygenSaturation.toStringAsFixed(0)}%',
                                  vital.isOxygenLow
                                      ? AppTheme.criticalRed
                                      : null,
                                ),
                                _vitalChip(
                                  '🌡️ ${vital.temperature.toStringAsFixed(1)}°C',
                                  vital.isTemperatureAbnormal
                                      ? AppTheme.warningOrange
                                      : null,
                                ),
                                _vitalChip(
                                  '🩸 ${vital.systolicBP}/${vital.diastolicBP}',
                                  vital.isBPAbnormal
                                      ? AppTheme.warningOrange
                                      : null,
                                ),
                                _vitalChip(
                                  '🫁 ${vital.respiratoryRate}/min',
                                  vital.isRespiratoryAbnormal
                                      ? AppTheme.warningOrange
                                      : null,
                                ),
                                _vitalChip(
                                  '🍬 ${vital.glucoseLevel.toStringAsFixed(0)} mg/dL',
                                  vital.isGlucoseAbnormal
                                      ? AppTheme.warningOrange
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 24),

            // Add Vitals Form
            Text(
              'Record New Vitals',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            // Heart Rate
            _vitalInput(
              controller: _heartRateController,
              label: 'Heart Rate',
              unit: 'bpm',
              icon: Icons.favorite,
              color: AppTheme.criticalRed,
              hint: '60-100',
              validator: Validators.heartRate,
            ),

            Row(
              children: [
                Expanded(
                  child: _vitalInput(
                    controller: _systolicController,
                    label: 'Systolic BP',
                    unit: 'mmHg',
                    icon: Icons.arrow_upward,
                    color: AppTheme.warningOrange,
                    hint: '90-120',
                    validator: Validators.bloodPressureSystolic,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _vitalInput(
                    controller: _diastolicController,
                    label: 'Diastolic BP',
                    unit: 'mmHg',
                    icon: Icons.arrow_downward,
                    color: AppTheme.warningOrange,
                    hint: '60-80',
                    validator: Validators.bloodPressureDiastolic,
                  ),
                ),
              ],
            ),

            _vitalInput(
              controller: _oxygenController,
              label: 'Oxygen Saturation',
              unit: '%',
              icon: Icons.air,
              color: AppTheme.accentColor,
              hint: '95-100',
              validator: Validators.oxygenSaturation,
            ),

            _vitalInput(
              controller: _tempController,
              label: 'Temperature',
              unit: '°C',
              icon: Icons.thermostat,
              color: AppTheme.primaryColor,
              hint: '36.1-37.2',
              validator: Validators.temperature,
            ),

            _vitalInput(
              controller: _respController,
              label: 'Respiratory Rate',
              unit: '/min',
              icon: Icons.masks,
              color: AppTheme.primaryLight,
              hint: '12-20',
              validator: Validators.respiratoryRate,
            ),

            _vitalInput(
              controller: _glucoseController,
              label: 'Glucose Level',
              unit: 'mg/dL',
              icon: Icons.water_drop,
              color: Colors.purple,
              hint: '70-140',
              validator: Validators.glucoseLevel,
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveVitals,
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
                label: const Text('Record Vitals'),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _vitalInput({
    required TextEditingController controller,
    required String label,
    required String unit,
    required IconData icon,
    required Color color,
    required String hint,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixText: unit,
          prefixIcon: Icon(icon, color: color),
        ),
      ),
    );
  }

  /// Error placeholder for failed streams (bug #21).
  Widget _buildStreamError(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.criticalRed.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.criticalRed.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off, color: AppTheme.criticalRed, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }

  void _showVitalDetailDialog(VitalsModel vital) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vitals Details',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat(
                          'EEEE, MMMM dd, yyyy',
                        ).format(vital.timestamp),
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      DateFormat('HH:mm:ss').format(vital.timestamp),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              Text(
                'Recorded by ${vital.recordedByName}',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Vital Signs Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: [
                  _vitalDetailCard(
                    icon: '❤️',
                    label: 'Heart Rate',
                    value: '${vital.heartRate}',
                    unit: 'bpm',
                    isAbnormal: vital.isHeartRateAbnormal,
                  ),
                  _vitalDetailCard(
                    icon: '💧',
                    label: 'Oxygen Saturation',
                    value: vital.oxygenSaturation.toStringAsFixed(1),
                    unit: '%',
                    isAbnormal: vital.isOxygenLow,
                  ),
                  _vitalDetailCard(
                    icon: '🌡️',
                    label: 'Temperature',
                    value: vital.temperature.toStringAsFixed(1),
                    unit: '°C',
                    isAbnormal: vital.isTemperatureAbnormal,
                  ),
                  _vitalDetailCard(
                    icon: '🩸',
                    label: 'Blood Pressure',
                    value: '${vital.systolicBP}/${vital.diastolicBP}',
                    unit: 'mmHg',
                    isAbnormal: vital.isBPAbnormal,
                  ),
                  _vitalDetailCard(
                    icon: '🫁',
                    label: 'Respiratory Rate',
                    value: '${vital.respiratoryRate}',
                    unit: '/min',
                    isAbnormal: vital.isRespiratoryAbnormal,
                  ),
                  _vitalDetailCard(
                    icon: '🍬',
                    label: 'Glucose Level',
                    value: vital.glucoseLevel.toStringAsFixed(0),
                    unit: 'mg/dL',
                    isAbnormal: vital.isGlucoseAbnormal,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Close button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vitalDetailCard({
    required String icon,
    required String label,
    required String value,
    required String unit,
    required bool isAbnormal,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAbnormal
            ? AppTheme.criticalRed.withValues(alpha: 0.1)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAbnormal ? AppTheme.criticalRed : AppTheme.dividerColor,
          width: isAbnormal ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isAbnormal
                      ? AppTheme.criticalRed
                      : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _vitalChip(String text, Color? alertColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: alertColor?.withValues(alpha: 0.1) ?? Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: alertColor != null ? Border.all(color: alertColor) : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: alertColor ?? AppTheme.textSecondary,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _heartRateController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _oxygenController.dispose();
    _tempController.dispose();
    _respController.dispose();
    _glucoseController.dispose();
    super.dispose();
  }
}

// Medications Section Widget
class _MedicationsSection extends StatefulWidget {
  final PatientModel patient;
  final DatabaseService databaseService;

  const _MedicationsSection({
    required this.patient,
    required this.databaseService,
  });

  @override
  State<_MedicationsSection> createState() => _MedicationsSectionState();
}

class _MedicationsSectionState extends State<_MedicationsSection> {
  // Bug #28: one shared stream per patient instead of a new subscription on
  // every rebuild.
  Stream<List<MedicationModel>>? _medsStream;
  String? _streamPatientId;

  Stream<List<MedicationModel>> _getMedsStream(String patientId) {
    if (_medsStream == null || _streamPatientId != patientId) {
      _streamPatientId = patientId;
      _medsStream = widget.databaseService.getMedicationsForPatient(patientId);
    }
    return _medsStream!;
  }

  static int _doseCountFor(String frequency) {
    switch (frequency) {
      case 'bid':
        return 2;
      case 'tid':
        return 3;
      case 'qid':
        return 4;
      default:
        return 1; // once / prn
    }
  }

  void _showAddMedicationDialog() {
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    String selectedRoute = 'oral';
    String selectedFrequency = 'once';
    bool isInjection = false;

    // Bug #9: "Twice Daily" previously created exactly ONE dose hardcoded to
    // now + 1h with no way to change it, and after a single "Give" the whole
    // prescription showed permanently administered. The schedule below
    // creates one record PER DOSE, each independently administrable.
    const defaultsByIndex = [
      TimeOfDay(hour: 8, minute: 0),
      TimeOfDay(hour: 14, minute: 0),
      TimeOfDay(hour: 20, minute: 0),
      TimeOfDay(hour: 2, minute: 0),
    ];
    List<TimeOfDay> doseTimes() => List.generate(
      _doseCountFor(selectedFrequency),
      (i) => defaultsByIndex[i],
    );
    var times = doseTimes();

    final sheetFuture = showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Medication',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),

                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Medication Name',
                      prefixIcon: Icon(Icons.medication),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: dosageController,
                    decoration: const InputDecoration(
                      labelText: 'Dosage (e.g., 500mg)',
                      prefixIcon: Icon(Icons.scale),
                    ),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue: selectedRoute,
                    decoration: const InputDecoration(
                      labelText: 'Route',
                      prefixIcon: Icon(Icons.route),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'oral', child: Text('Oral')),
                      DropdownMenuItem(value: 'iv', child: Text('IV')),
                      DropdownMenuItem(value: 'im', child: Text('IM')),
                      DropdownMenuItem(value: 'sc', child: Text('SC')),
                      DropdownMenuItem(
                        value: 'topical',
                        child: Text('Topical'),
                      ),
                    ],
                    onChanged: (value) {
                      setModalState(() {
                        selectedRoute = value!;
                        isInjection =
                            value == 'iv' || value == 'im' || value == 'sc';
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue: selectedFrequency,
                    decoration: const InputDecoration(
                      labelText: 'Frequency',
                      prefixIcon: Icon(Icons.schedule),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'once', child: Text('Once')),
                      DropdownMenuItem(
                        value: 'bid',
                        child: Text('Twice Daily'),
                      ),
                      DropdownMenuItem(
                        value: 'tid',
                        child: Text('Three Times Daily'),
                      ),
                      DropdownMenuItem(
                        value: 'qid',
                        child: Text('Four Times Daily'),
                      ),
                      DropdownMenuItem(value: 'prn', child: Text('As Needed')),
                    ],
                    onChanged: (value) {
                      setModalState(() {
                        selectedFrequency = value!;
                        times = doseTimes();
                      });
                    },
                  ),

                  // One editable time per daily dose.
                  ...List.generate(times.length, (index) {
                    final t = times[index];
                    final label = index == 0 && selectedFrequency == 'prn'
                        ? 'Give at'
                        : 'Dose ${index + 1}';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Text(label),
                      trailing: TextButton.icon(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: t,
                          );
                          if (picked != null) {
                            setModalState(() => times[index] = picked);
                          }
                        },
                        icon: const Icon(Icons.access_time, size: 18),
                        label: Text(t.format(context)),
                      ),
                    );
                  }),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.trim().isEmpty ||
                            dosageController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please enter medication name and dosage',
                              ),
                            ),
                          );
                          return;
                        }

                        // Bug #10: nurse-entered meds were attributed to the
                        // attending doctor (audit-trail falsification). The
                        // prescriber of record here is the staff member who
                        // actually entered the order.
                        final authProvider = Provider.of<AuthProvider>(
                          dialogContext,
                          listen: false,
                        );
                        final user = authProvider.currentUser;

                        DateTime nextOccurrence(TimeOfDay t) {
                          final now = DateTime.now();
                          var dt = DateTime(
                            now.year,
                            now.month,
                            now.day,
                            t.hour,
                            t.minute,
                          );
                          if (!dt.isAfter(now)) {
                            dt = dt.add(const Duration(days: 1));
                          }
                          return dt;
                        }

                        // Capture before awaits (context across async gaps).
                        final sectionMessenger = ScaffoldMessenger.of(
                          this.context,
                        );

                        var allSucceeded = true;
                        for (final t in times) {
                          final medication = MedicationModel(
                            id: '',
                            patientId: widget.patient.id,
                            name: nameController.text.trim(),
                            dosage: dosageController.text.trim(),
                            route: selectedRoute,
                            frequency: selectedFrequency,
                            scheduledTime: nextOccurrence(t),
                            isInjection: isInjection,
                            prescribedById: user?.id ?? '',
                            prescribedByName: user?.name ?? 'Unknown',
                            createdAt: DateTime.now(),
                          );
                          final ok = await widget.databaseService.addMedication(
                            medication,
                          );
                          if (ok == null) allSucceeded = false;
                        }

                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                        if (!allSucceeded) {
                          sectionMessenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Some doses could not be saved. Please '
                                'verify the medication list.',
                              ),
                              backgroundColor: AppTheme.errorColor,
                            ),
                          );
                        }
                      },
                      child: const Text('Add Medication'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    // Dispose the dialog's controllers when the sheet closes.
    sheetFuture.whenComplete(() {
      nameController.dispose();
      dosageController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Add button
        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: _showAddMedicationDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Medication'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),

        // Medications list
        Expanded(
          child: StreamBuilder<List<MedicationModel>>(
            stream: _getMedsStream(widget.patient.id),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                // Bug #21: errors must not read as "No medications scheduled".
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_off,
                        size: 60,
                        color: AppTheme.criticalRed,
                      ),
                      const SizedBox(height: 16),
                      const Text('Could not load medications'),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.medication_outlined,
                        size: 60,
                        color: AppTheme.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No medications scheduled',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                );
              }

              final medications = snapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: medications.length,
                itemBuilder: (context, index) {
                  final med = medications[index];
                  return _MedicationCard(
                    medication: med,
                    onAdminister: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final authProvider = Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      );

                      // Bug #12: blind update() let two devices both mark a
                      // dose given (patient double-dosed, record shows one).
                      // The service call is now transactional.
                      final result = await widget.databaseService
                          .administerMedication(
                            medicationId: med.id,
                            nurseId: authProvider.currentUser?.id ?? '',
                            nurseName:
                                authProvider.currentUser?.name ?? 'Unknown',
                          );

                      if (!mounted) return;
                      switch (result) {
                        case MedicationAdminResult.success:
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('${med.name} marked as given'),
                              backgroundColor: AppTheme.successColor,
                            ),
                          );
                        case MedicationAdminResult.alreadyAdministered:
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                '${med.name} was already administered by '
                                'another device - no double dose recorded.',
                              ),
                              backgroundColor: AppTheme.warningOrange,
                            ),
                          );
                        case MedicationAdminResult.failed:
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Failed to record administration of '
                                '${med.name}',
                              ),
                              backgroundColor: AppTheme.errorColor,
                            ),
                          );
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MedicationCard extends StatelessWidget {
  final MedicationModel medication;
  final VoidCallback onAdminister;

  const _MedicationCard({required this.medication, required this.onAdminister});

  @override
  Widget build(BuildContext context) {
    final isOverdue = medication.isOverdue;
    final isPending = medication.isPending && !isOverdue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverdue
              ? AppTheme.criticalRed
              : isPending
              ? AppTheme.warningOrange
              : medication.isAdministered
              ? AppTheme.successColor
              : AppTheme.dividerColor,
          width: isOverdue || isPending ? 2 : 1,
        ),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: medication.isInjection
                  ? AppTheme.accentColor.withValues(alpha: 0.1)
                  : AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              medication.isInjection ? Icons.vaccines : Icons.medication,
              color: medication.isInjection
                  ? AppTheme.accentColor
                  : AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medication.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${medication.dosage} • ${medication.routeLabel}',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd, HH:mm').format(medication.scheduledTime),
                  style: TextStyle(
                    color: isOverdue
                        ? AppTheme.criticalRed
                        : AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          if (!medication.isAdministered)
            ElevatedButton(
              onPressed: onAdminister,
              style: ElevatedButton.styleFrom(
                backgroundColor: isOverdue
                    ? AppTheme.criticalRed
                    : AppTheme.successColor,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('Give'),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: AppTheme.successColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Given',
                    style: TextStyle(
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.w600,
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
