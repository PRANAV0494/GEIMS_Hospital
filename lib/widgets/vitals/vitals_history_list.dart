import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/vitals_model.dart';
import '../../config/app_theme.dart';

/// Reusable widget for displaying vitals history in a list
class VitalsHistoryList extends StatelessWidget {
  final List<VitalsModel> vitals;
  final VoidCallback? onLoadMore;
  final bool hasMore;
  final bool isLoading;

  const VitalsHistoryList({
    super.key,
    required this.vitals,
    this.onLoadMore,
    this.hasMore = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (vitals.isEmpty) {
      return const Center(child: Text('No vitals recorded yet'));
    }

    return ListView.builder(
      itemCount: vitals.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == vitals.length) {
          return _buildLoadMoreButton();
        }

        final vital = vitals[index];
        return VitalsCard(vital: vital);
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

/// Individual vitals card widget
class VitalsCard extends StatelessWidget {
  final VitalsModel vital;

  const VitalsCard({super.key, required this.vital});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMM dd, yyyy - HH:mm').format(vital.timestamp),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (vital.hasAnyAlert)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'ALERT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildVitalRow(
              'Heart Rate',
              '${vital.heartRate} bpm',
              vital.alerts['heart_rate'] == true,
            ),
            _buildVitalRow(
              'Blood Pressure',
              '${vital.systolicBP}/${vital.diastolicBP} mmHg',
              vital.alerts['blood_pressure'] == true,
            ),
            _buildVitalRow(
              'Oxygen',
              '${vital.oxygenSaturation}%',
              vital.alerts['oxygen'] == true,
            ),
            _buildVitalRow(
              'Temperature',
              '${vital.temperature}°C',
              vital.alerts['temperature'] == true,
            ),
            _buildVitalRow(
              'Respiratory Rate',
              '${vital.respiratoryRate} breaths/min',
              false,
            ),
            _buildVitalRow('Glucose', '${vital.glucoseLevel} mg/dL', false),
            if (vital.notes != null && vital.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Notes: ${vital.notes}',
                style: const TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Recorded by: ${vital.recordedByName}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalRow(String label, String value, bool hasAlert) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: hasAlert ? AppTheme.errorColor : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
