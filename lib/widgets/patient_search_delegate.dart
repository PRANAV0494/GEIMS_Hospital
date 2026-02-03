import 'package:flutter/material.dart';
import '../models/patient_model.dart';
import '../services/database_service.dart';
import '../config/app_theme.dart';
import '../config/routes.dart';
import '../screens/doctor/patient_detail_view.dart';

class PatientSearchDelegate extends SearchDelegate<PatientModel?> {
  final DatabaseService _databaseService = DatabaseService();
  final String doctorId; // Optional: to filter by doctor if needed

  PatientSearchDelegate({this.doctorId = ''});

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Search by ID, Name, Ward, or Bed',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    // Since Firestore doesn't support native full-text search,
    // we'll fetch patients (optimized for the specific doctor) and filter client-side.
    // For a larger app, we'd use Algolia or similar.
    // Use getAllPatients() to search across ALL wards (as requested "search each ward")
    return StreamBuilder<List<PatientModel>>(
      stream: _databaseService.getAllPatients(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No patients found'));
        }

        final patients = snapshot.data!;
        final filteredPatients = patients.where((patient) {
          final q = query.toLowerCase();
          return patient.name.toLowerCase().contains(q) ||
              patient.wardNumber.toString().contains(q) ||
              patient.bedNumber.toString().contains(q) ||
              patient.id.toLowerCase().contains(q) ||
              (patient.patientCode?.toLowerCase().contains(q) ?? false);
        }).toList();

        if (filteredPatients.isEmpty) {
          return const Center(child: Text('No matching patients found'));
        }

        return ListView.separated(
          itemCount: filteredPatients.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final patient = filteredPatients[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: patient.isCritical
                    ? AppTheme.criticalRed.withValues(alpha: 0.1)
                    : AppTheme.primaryColor.withValues(alpha: 0.1),
                child: Icon(
                  Icons.person,
                  color: patient.isCritical
                      ? AppTheme.criticalRed
                      : AppTheme.primaryColor,
                ),
              ),
              title: Text(
                patient.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (patient.patientCode != null)
                      Text(
                        patient.patientCode!,
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Ward ${patient.wardNumber}  •  Bed ${patient.bedNumber}',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              trailing: patient.isCritical
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.criticalRed,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'CRITICAL',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    )
                  : null,
              onTap: () {
                // close(context, patient);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PatientDetailView(patient: patient),
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
