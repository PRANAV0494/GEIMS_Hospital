import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
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

  PatientModel? _patient;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPatient();
  }

  @override
  void didUpdateWidget(ClinicalDataTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wardNumber != widget.wardNumber ||
        oldWidget.bedNumber != widget.bedNumber) {
      _loadPatient();
    }
  }

  Future<void> _loadPatient() async {
    setState(() => _isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(AppConstants.patientsCollection)
          .where('wardNumber', isEqualTo: widget.wardNumber)
          .where('bedNumber', isEqualTo: widget.bedNumber)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _patient = PatientModel.fromFirestore(snapshot.docs.first);
      } else {
        _patient = null;
      }
    } catch (e) {
      _patient = null;
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_patient == null) {
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
                  color: _patient!.isCritical
                      ? AppTheme.criticalRed.withValues(alpha: 0.1)
                      : AppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  color: _patient!.isCritical
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
                      _patient!.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${_patient!.age} yrs • ${_patient!.gender}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (_patient!.isCritical)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              _VitalsSection(patient: _patient!, databaseService: _databaseService),
              _MedicationsSection(patient: _patient!, databaseService: _databaseService),
            ],
          ),
        ),
      ],
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

  const _VitalsSection({
    required this.patient,
    required this.databaseService,
  });

  @override
  State<_VitalsSection> createState() => _VitalsSectionState();
}

class _VitalsSectionState extends State<_VitalsSection> {
  final _heartRateController = TextEditingController();
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _oxygenController = TextEditingController();
  final _tempController = TextEditingController();
  final _respController = TextEditingController();
  final _glucoseController = TextEditingController();
  bool _isSaving = false;

  Future<void> _saveVitals() async {
    // Validate inputs
    final heartRate = int.tryParse(_heartRateController.text);
    final systolic = int.tryParse(_systolicController.text);
    final diastolic = int.tryParse(_diastolicController.text);
    final oxygen = double.tryParse(_oxygenController.text);
    final temp = double.tryParse(_tempController.text);
    final resp = int.tryParse(_respController.text);
    final glucose = double.tryParse(_glucoseController.text);

    if (heartRate == null || systolic == null || diastolic == null ||
        oxygen == null || temp == null || resp == null || glucose == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields with valid numbers')),
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
    return SingleChildScrollView(
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
            stream: widget.databaseService.getVitalsForPatient(widget.patient.id),
            builder: (context, snapshot) {
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

              final vitals = snapshot.data!.take(10).toList().reversed.toList();
              
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
                          return FlSpot(e.key.toDouble(), e.value.heartRate.toDouble());
                        }).toList(),
                        isCurved: true,
                        color: AppTheme.criticalRed,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                      ),
                      // Oxygen line
                      LineChartBarData(
                        spots: vitals.asMap().entries.map((e) {
                          return FlSpot(e.key.toDouble(), e.value.oxygenSaturation);
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
            stream: widget.databaseService.getVitalsForPatient(widget.patient.id),
            builder: (context, snapshot) {
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
                                DateFormat('MMM dd, yyyy • HH:mm').format(vital.timestamp),
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
                                  Icon(Icons.touch_app, size: 14, color: AppTheme.textSecondary),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 16,
                            runSpacing: 4,
                            children: [
                              _vitalChip('❤️ ${vital.heartRate} bpm', vital.isHeartRateAbnormal ? AppTheme.criticalRed : null),
                              _vitalChip('💧 ${vital.oxygenSaturation.toStringAsFixed(0)}%', vital.isOxygenLow ? AppTheme.criticalRed : null),
                              _vitalChip('🌡️ ${vital.temperature.toStringAsFixed(1)}°C', vital.isTemperatureAbnormal ? AppTheme.warningOrange : null),
                              _vitalChip('🩸 ${vital.systolicBP}/${vital.diastolicBP}', vital.isBPAbnormal ? AppTheme.warningOrange : null),
                              _vitalChip('🫁 ${vital.respiratoryRate}/min', vital.isRespiratoryAbnormal ? AppTheme.warningOrange : null),
                              _vitalChip('🍬 ${vital.glucoseLevel.toStringAsFixed(0)} mg/dL', vital.isGlucoseAbnormal ? AppTheme.warningOrange : null),
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
          ),

          _vitalInput(
            controller: _tempController,
            label: 'Temperature',
            unit: '°C',
            icon: Icons.thermostat,
            color: AppTheme.primaryColor,
            hint: '36.1-37.2',
          ),

          _vitalInput(
            controller: _respController,
            label: 'Respiratory Rate',
            unit: '/min',
            icon: Icons.masks,
            color: AppTheme.primaryLight,
            hint: '12-20',
          ),

          _vitalInput(
            controller: _glucoseController,
            label: 'Glucose Level',
            unit: 'mg/dL',
            icon: Icons.water_drop,
            color: Colors.purple,
            hint: '70-140',
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
    );
  }

  Widget _vitalInput({
    required TextEditingController controller,
    required String label,
    required String unit,
    required IconData icon,
    required Color color,
    required String hint,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixText: unit,
          prefixIcon: Icon(icon, color: color),
        ),
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
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('EEEE, MMMM dd, yyyy').format(vital.timestamp),
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    value: '${vital.oxygenSaturation.toStringAsFixed(1)}',
                    unit: '%',
                    isAbnormal: vital.isOxygenLow,
                  ),
                  _vitalDetailCard(
                    icon: '🌡️',
                    label: 'Temperature',
                    value: '${vital.temperature.toStringAsFixed(1)}',
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
                    value: '${vital.glucoseLevel.toStringAsFixed(0)}',
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
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
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
                  color: isAbnormal ? AppTheme.criticalRed : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
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
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
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
  void _showAddMedicationDialog() {
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    String selectedRoute = 'oral';
    String selectedFrequency = 'once';
    bool isInjection = false;
    DateTime scheduledTime = DateTime.now().add(const Duration(hours: 1));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
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
                    value: selectedRoute,
                    decoration: const InputDecoration(
                      labelText: 'Route',
                      prefixIcon: Icon(Icons.route),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'oral', child: Text('Oral')),
                      DropdownMenuItem(value: 'iv', child: Text('IV')),
                      DropdownMenuItem(value: 'im', child: Text('IM')),
                      DropdownMenuItem(value: 'sc', child: Text('SC')),
                      DropdownMenuItem(value: 'topical', child: Text('Topical')),
                    ],
                    onChanged: (value) {
                      setModalState(() {
                        selectedRoute = value!;
                        isInjection = value == 'iv' || value == 'im' || value == 'sc';
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: selectedFrequency,
                    decoration: const InputDecoration(
                      labelText: 'Frequency',
                      prefixIcon: Icon(Icons.schedule),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'once', child: Text('Once')),
                      DropdownMenuItem(value: 'bid', child: Text('Twice Daily')),
                      DropdownMenuItem(value: 'tid', child: Text('Three Times Daily')),
                      DropdownMenuItem(value: 'qid', child: Text('Four Times Daily')),
                      DropdownMenuItem(value: 'prn', child: Text('As Needed')),
                    ],
                    onChanged: (value) {
                      setModalState(() => selectedFrequency = value!);
                    },
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.isEmpty || dosageController.text.isEmpty) {
                          return;
                        }

                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                        final medication = MedicationModel(
                          id: '',
                          patientId: widget.patient.id,
                          name: nameController.text.trim(),
                          dosage: dosageController.text.trim(),
                          route: selectedRoute,
                          frequency: selectedFrequency,
                          scheduledTime: scheduledTime,
                          isInjection: isInjection,
                          prescribedById: widget.patient.attendingDoctorId,
                          prescribedByName: widget.patient.attendingDoctorName,
                          createdAt: DateTime.now(),
                        );

                        await widget.databaseService.addMedication(medication);
                        if (context.mounted) Navigator.of(context).pop();
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
            stream: widget.databaseService.getMedicationsForPatient(widget.patient.id),
            builder: (context, snapshot) {
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
                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      await widget.databaseService.administerMedication(
                        medicationId: med.id,
                        nurseId: authProvider.currentUser?.id ?? '',
                        nurseName: authProvider.currentUser?.name ?? 'Unknown',
                      );
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

  const _MedicationCard({
    required this.medication,
    required this.onAdminister,
  });

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
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd, HH:mm').format(medication.scheduledTime),
                  style: TextStyle(
                    color: isOverdue ? AppTheme.criticalRed : AppTheme.textSecondary,
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
                  Icon(Icons.check_circle, size: 16, color: AppTheme.successColor),
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
