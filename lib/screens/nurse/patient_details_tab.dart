import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/patient_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';

class PatientDetailsTab extends StatefulWidget {
  final int wardNumber;
  final int bedNumber;

  const PatientDetailsTab({
    super.key,
    required this.wardNumber,
    required this.bedNumber,
  });

  @override
  State<PatientDetailsTab> createState() => _PatientDetailsTabState();
}

class _PatientDetailsTabState extends State<PatientDetailsTab> {
  final _formKey = GlobalKey<FormState>();
  final _databaseService = DatabaseService();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _notesController = TextEditingController();
  final _allergyController = TextEditingController();

  String _selectedGender = 'Male';
  DateTime _admissionDate = DateTime.now();
  UserModel? _selectedDoctor;
  List<UserModel> _doctors = [];
  List<String> _allergies = [];
  bool _isCritical = false;
  bool _isLoading = false;
  bool _isSaving = false;
  PatientModel? _existingPatient;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
    _loadExistingPatient();
  }

  @override
  void didUpdateWidget(PatientDetailsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wardNumber != widget.wardNumber ||
        oldWidget.bedNumber != widget.bedNumber) {
      _loadExistingPatient();
    }
  }

  Future<void> _loadDoctors() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final doctors = await authProvider.getAllDoctors();
    setState(() {
      _doctors = doctors;
      if (_doctors.isNotEmpty && _selectedDoctor == null) {
        _selectedDoctor = _doctors.first;
      }
    });
  }

  Future<void> _loadExistingPatient() async {
    setState(() => _isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(AppConstants.patientsCollection)
          .where('wardNumber', isEqualTo: widget.wardNumber)
          .where('bedNumber', isEqualTo: widget.bedNumber)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final patient = PatientModel.fromFirestore(snapshot.docs.first);
        _populateForm(patient);
      } else {
        _clearForm();
      }
    } catch (e) {
      _clearForm();
    }

    setState(() => _isLoading = false);
  }

  void _populateForm(PatientModel patient) {
    setState(() {
      _existingPatient = patient;
      _nameController.text = patient.name;
      _ageController.text = patient.age.toString();
      _diagnosisController.text = patient.diagnosisSummary;
      _notesController.text = patient.specialNotes ?? '';
      _selectedGender = patient.gender;
      _admissionDate = patient.admissionDate;
      _allergies = List.from(patient.allergies);
      _isCritical = patient.isCritical;

      // Find the selected doctor
      _selectedDoctor = _doctors.firstWhere(
        (d) => d.id == patient.attendingDoctorId,
        orElse: () => _doctors.isNotEmpty ? _doctors.first : _selectedDoctor!,
      );
    });
  }

  void _clearForm() {
    setState(() {
      _existingPatient = null;
      _nameController.clear();
      _ageController.clear();
      _diagnosisController.clear();
      _notesController.clear();
      _selectedGender = 'Male';
      _admissionDate = DateTime.now();
      _allergies = [];
      _isCritical = false;
    });
  }

  Future<void> _savePatient() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDoctor == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a doctor')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final patient = PatientModel(
        id: _existingPatient?.id ?? '',
        name: _nameController.text.trim(),
        age: int.parse(_ageController.text),
        gender: _selectedGender,
        diagnosisSummary: _diagnosisController.text.trim(),
        wardNumber: widget.wardNumber,
        bedNumber: widget.bedNumber,
        admissionDate: _admissionDate,
        attendingDoctorId: _selectedDoctor!.id,
        attendingDoctorName: _selectedDoctor!.name,
        allergies: _allergies,
        specialNotes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        isCritical: _isCritical,
        status: _isCritical
            ? AppConstants.statusCritical
            : AppConstants.statusStable,
        createdAt: _existingPatient?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      bool success;
      if (_existingPatient != null) {
        success = await _databaseService.updatePatient(patient);
      } else {
        final id = await _databaseService.addPatient(patient);
        success = id != null;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Patient saved successfully' : 'Failed to save patient',
            ),
            backgroundColor: success
                ? AppTheme.successColor
                : AppTheme.errorColor,
          ),
        );

        if (success) {
          _loadExistingPatient();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }

    setState(() => _isSaving = false);
  }

  void _addAllergy() {
    if (_allergyController.text.trim().isNotEmpty) {
      setState(() {
        _allergies.add(_allergyController.text.trim());
        _allergyController.clear();
      });
    }
  }

  Future<void> _selectAdmissionDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _admissionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _admissionDate = date);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Critical patient indicator
            if (_existingPatient != null && _isCritical)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.criticalRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.criticalRed),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: AppTheme.criticalRed),
                    const SizedBox(width: 8),
                    Text(
                      'CRITICAL PATIENT',
                      style: TextStyle(
                        color: AppTheme.criticalRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            // Patient Code Badge (for existing patients)
            if (_existingPatient != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.badge_outlined, color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Patient ID',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _existingPatient!.displayCode,
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Patient Name
            _buildSectionTitle('Patient Information'),
            const SizedBox(height: 12),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Patient Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter patient name';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Age and Gender row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Age',
                      prefixIcon: Icon(Icons.cake_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedGender,
                    decoration: const InputDecoration(
                      labelText: 'Gender',
                      prefixIcon: Icon(Icons.wc_outlined),
                    ),
                    items: ['Male', 'Female', 'Other'].map((g) {
                      return DropdownMenuItem(value: g, child: Text(g));
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedGender = value!);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Diagnosis
            _buildSectionTitle('Diagnosis'),
            const SizedBox(height: 12),

            TextFormField(
              controller: _diagnosisController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Diagnosis Summary',
                prefixIcon: Icon(Icons.medical_information_outlined),
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter diagnosis';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Admission Details
            _buildSectionTitle('Admission Details'),
            const SizedBox(height: 12),

            // Admission Date
            GestureDetector(
              onTap: _selectAdmissionDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.dividerColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: AppTheme.textSecondary),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admission Date',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          DateFormat('MMMM dd, yyyy').format(_admissionDate),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Attending Doctor
            DropdownButtonFormField<UserModel>(
              initialValue: _selectedDoctor,
              decoration: const InputDecoration(
                labelText: 'Attending Doctor',
                prefixIcon: Icon(Icons.local_hospital_outlined),
              ),
              items: _doctors.map((doctor) {
                return DropdownMenuItem(
                  value: doctor,
                  child: Text('Dr. ${doctor.name}'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedDoctor = value);
              },
            ),

            const SizedBox(height: 24),

            // Allergies
            _buildSectionTitle('Allergies'),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _allergyController,
                    decoration: const InputDecoration(
                      labelText: 'Add Allergy',
                      prefixIcon: Icon(Icons.warning_amber_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  onPressed: _addAllergy,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allergies.map((allergy) {
                return Chip(
                  label: Text(allergy),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () {
                    setState(() => _allergies.remove(allergy));
                  },
                  backgroundColor: AppTheme.warningOrange.withValues(
                    alpha: 0.2,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Special Notes
            _buildSectionTitle('Special Notes'),
            const SizedBox(height: 12),

            TextFormField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notes',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 24),

            // Critical Patient Toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isCritical
                    ? AppTheme.criticalRed.withValues(alpha: 0.1)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isCritical
                      ? AppTheme.criticalRed
                      : AppTheme.dividerColor,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: _isCritical
                        ? AppTheme.criticalRed
                        : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Critical Patient',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _isCritical
                                ? AppTheme.criticalRed
                                : AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Mark if patient requires urgent attention',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isCritical,
                    onChanged: (value) {
                      setState(() => _isCritical = value);
                    },
                    activeThumbColor: AppTheme.criticalRed,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _savePatient,
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _existingPatient != null
                            ? 'Update Patient'
                            : 'Add Patient',
                        style: const TextStyle(fontSize: 18),
                      ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(color: AppTheme.primaryColor),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _diagnosisController.dispose();
    _notesController.dispose();
    _allergyController.dispose();
    super.dispose();
  }
}
