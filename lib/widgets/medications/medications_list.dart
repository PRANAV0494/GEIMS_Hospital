import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/medication_model.dart';
import '../../config/app_theme.dart';

/// Reusable widget for displaying medications list
class MedicationsList extends StatelessWidget {
  final List<MedicationModel> medications;

  /// Called when a nurse taps "Mark as Administered". The caller owns the
  /// current-user context and the transactional service call.
  final void Function(MedicationModel medication)? onAdminister;
  final bool isNurse;
  final VoidCallback? onLoadMore;
  final bool hasMore;
  final bool isLoading;

  const MedicationsList({
    super.key,
    required this.medications,
    this.onAdminister,
    this.isNurse = false,
    this.onLoadMore,
    this.hasMore = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (medications.isEmpty) {
      return const Center(child: Text('No medications scheduled'));
    }

    return ListView.builder(
      itemCount: medications.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == medications.length) {
          return _buildLoadMoreButton();
        }

        final medication = medications[index];
        return MedicationCard(
          medication: medication,
          onAdminister: onAdminister,
          isNurse: isNurse,
        );
      },
    );
  }

  Widget _buildLoadMoreButton() {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton(
        onPressed: onLoadMore,
        child: const Text('Load More'),
      ),
    );
  }
}

/// Individual medication card widget
class MedicationCard extends StatelessWidget {
  final MedicationModel medication;
  final void Function(MedicationModel medication)? onAdminister;
  final bool isNurse;

  const MedicationCard({
    super.key,
    required this.medication,
    this.onAdminister,
    this.isNurse = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPending = !medication.isAdministered;
    final bool isOverdue =
        isPending && medication.scheduledTime.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isPending ? 3 : 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    medication.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusBadge(isPending, isOverdue),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Dosage', medication.dosage),
            _buildInfoRow('Route', medication.route),
            _buildInfoRow('Frequency', medication.frequency),
            _buildInfoRow(
              'Scheduled',
              DateFormat(
                'MMM dd, yyyy - HH:mm',
              ).format(medication.scheduledTime),
            ),
            if (medication.isInjection)
              const Padding(
                padding: EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                    SizedBox(width: 4),
                    Text(
                      'Injection',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            if (medication.notes != null && medication.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Notes: ${medication.notes}',
                style: const TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (medication.isAdministered) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.check_circle, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    'Administered by ${medication.administeredByName} at ${DateFormat('HH:mm').format(medication.administeredTime!)}',
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ],
              ),
            ],
            if (isPending && isNurse && onAdminister != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  // Bug #38: this was a TODO no-op - tapping "Mark as
                  // Administered" did nothing. The caller now receives the
                  // medication and performs the transactional administration.
                  onPressed: () => onAdminister!(medication),
                  icon: const Icon(Icons.check),
                  label: const Text('Mark as Administered'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isPending, bool isOverdue) {
    if (!isPending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'DONE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (isOverdue) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.errorColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'OVERDUE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'PENDING',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
