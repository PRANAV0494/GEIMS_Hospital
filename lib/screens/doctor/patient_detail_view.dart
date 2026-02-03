import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/patient_model.dart';
import '../../models/vitals_model.dart';
import '../../models/medication_model.dart';
import '../../models/message_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';

class PatientDetailView extends StatefulWidget {
  final PatientModel patient;

  const PatientDetailView({super.key, required this.patient});

  @override
  State<PatientDetailView> createState() => _PatientDetailViewState();
}

class _PatientDetailViewState extends State<PatientDetailView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _databaseService = DatabaseService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  // Voice recording state
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _recordTimer;
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    setState(() => _isSending = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    final message = MessageModel(
      id: '',
      senderId: user?.id ?? '',
      senderName: user?.name ?? 'Unknown Doctor',
      senderRole: AppConstants.roleDoctor,
      receiverId: widget.patient.assignedNurseId ?? '',
      receiverName: 'Nurse',
      patientId: widget.patient.id,
      patientName: widget.patient.name,
      content: _messageController.text.trim(),
      type: AppConstants.messageTypeText,
      sentAt: DateTime.now(),
    );

    final result = await _databaseService.sendMessage(message);

    if (mounted) {
      setState(() => _isSending = false);

      if (result != null) {
        _messageController.clear();
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        _recordingPath = '${directory.path}/$fileName';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: _recordingPath!,
        );

        setState(() {
          _isRecording = true;
          _recordDuration = 0;
        });

        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() => _recordDuration++);
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission required')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    final path = await _audioRecorder.stop();

    if (path != null && mounted) {
      setState(() => _isRecording = false);
      await _sendVoiceMessage(path);
    }
  }

  void _cancelRecording() {
    _recordTimer?.cancel();
    _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _recordDuration = 0;
    });
  }

  Future<void> _sendVoiceMessage(String filePath) async {
    setState(() => _isSending = true);

    try {
      // Upload to Firebase Storage
      final file = File(filePath);

      // Verify file exists
      if (!await file.exists()) {
        throw Exception('Recording file not found');
      }

      final fileBytes = await file.length();
      if (fileBytes == 0) {
        throw Exception('Recording file is empty');
      }

      final fileName =
          'voice_messages/${widget.patient.id}_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final storageRef = FirebaseStorage.instance.ref().child(fileName);

      // Upload with metadata
      final uploadTask = await storageRef.putFile(
        file,
        SettableMetadata(contentType: 'audio/mp4'),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();

      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      final message = MessageModel(
        id: '',
        senderId: user?.id ?? '',
        senderName: user?.name ?? 'Unknown Doctor',
        senderRole: AppConstants.roleDoctor,
        receiverId: widget.patient.assignedNurseId ?? '',
        receiverName: 'Nurse',
        patientId: widget.patient.id,
        patientName: widget.patient.name,
        content: '🎤 Voice message',
        type: AppConstants.messageTypeVoice,
        sentAt: DateTime.now(),
        voiceNotePath: downloadUrl,
        voiceDurationSeconds: _recordDuration,
      );

      final result = await _databaseService.sendMessage(message);

      if (mounted && result != null) {
        setState(() => _recordDuration = 0);
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send voice message: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Bed ${widget.patient.bedNumber}')),
      body: Column(
        children: [
          // Patient header
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
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.patient.isCritical
                        ? AppTheme.criticalRed.withValues(alpha: 0.1)
                        : AppTheme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    size: 32,
                    color: widget.patient.isCritical
                        ? AppTheme.criticalRed
                        : AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.patient.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (widget.patient.isCritical) ...[
                            const SizedBox(width: 8),
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
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Patient Code Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.patient.displayCode,
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.patient.age} yrs • ${widget.patient.gender} • Ward ${widget.patient.wardNumber}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.patient.diagnosisSummary,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Allergies warning
          if (widget.patient.hasAllergies)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppTheme.warningOrange.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: AppTheme.warningOrange),
                  const SizedBox(width: 8),
                  Text(
                    'Allergies: ${widget.patient.allergies.join(", ")}',
                    style: TextStyle(
                      color: AppTheme.warningOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          // Tab bar
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppTheme.accentColor,
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppTheme.textSecondary,
              tabs: const [
                Tab(text: 'Vitals'),
                Tab(text: 'Meds'),
                Tab(text: 'Messages'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildVitalsTab(),
                _buildMedicationsTab(),
                _buildMessagesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsTab() {
    return StreamBuilder<List<VitalsModel>>(
      stream: _databaseService.getVitalsForPatient(widget.patient.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.monitor_heart_outlined,
                  size: 60,
                  color: AppTheme.textSecondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No vitals recorded',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        }

        final vitals = snapshot.data!;
        final latest = vitals.first;
        final chartData = vitals.take(10).toList().reversed.toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Latest vitals
              Text(
                'Latest Vitals',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),

              _buildVitalsGrid(latest),

              const SizedBox(height: 24),

              // Heart Rate Chart
              Text(
                'Heart Rate Trend',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),

              _buildLineChart(
                chartData,
                (v) => v.heartRate.toDouble(),
                AppTheme.criticalRed,
                'bpm',
              ),

              const SizedBox(height: 24),

              // Oxygen Saturation Chart
              Text(
                'Oxygen Saturation Trend',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),

              _buildLineChart(
                chartData,
                (v) => v.oxygenSaturation,
                AppTheme.accentColor,
                '%',
              ),

              const SizedBox(height: 24),

              // Vitals History
              Text('History', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),

              ...vitals
                  .take(5)
                  .map(
                    (v) => _VitalsHistoryCard(
                      vitals: v,
                      onTap: () => _showVitalDetailDialog(v),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVitalsGrid(VitalsModel vitals) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        _VitalCard(
          label: 'Heart Rate',
          value: '${vitals.heartRate}',
          unit: 'bpm',
          icon: Icons.favorite,
          color: VitalsModel.isHeartRateNormal(vitals.heartRate)
              ? AppTheme.stableGreen
              : AppTheme.criticalRed,
        ),
        _VitalCard(
          label: 'Blood Pressure',
          value: vitals.bloodPressure,
          unit: 'mmHg',
          icon: Icons.speed,
          color: VitalsModel.isSystolicBPNormal(vitals.systolicBP)
              ? AppTheme.stableGreen
              : AppTheme.warningOrange,
        ),
        _VitalCard(
          label: 'O₂ Saturation',
          value: vitals.oxygenSaturation.toStringAsFixed(1),
          unit: '%',
          icon: Icons.air,
          color: VitalsModel.isOxygenNormal(vitals.oxygenSaturation)
              ? AppTheme.stableGreen
              : AppTheme.criticalRed,
        ),
        _VitalCard(
          label: 'Temperature',
          value: vitals.temperature.toStringAsFixed(1),
          unit: '°C',
          icon: Icons.thermostat,
          color: VitalsModel.isTemperatureNormal(vitals.temperature)
              ? AppTheme.stableGreen
              : AppTheme.warningOrange,
        ),
        _VitalCard(
          label: 'Resp Rate',
          value: '${vitals.respiratoryRate}',
          unit: '/min',
          icon: Icons.masks,
          color: VitalsModel.isRespiratoryRateNormal(vitals.respiratoryRate)
              ? AppTheme.stableGreen
              : AppTheme.warningOrange,
        ),
        _VitalCard(
          label: 'Glucose',
          value: vitals.glucoseLevel.toStringAsFixed(0),
          unit: 'mg/dL',
          icon: Icons.water_drop,
          color: VitalsModel.isGlucoseNormal(vitals.glucoseLevel)
              ? AppTheme.stableGreen
              : AppTheme.warningOrange,
        ),
      ],
    );
  }

  Widget _buildLineChart(
    List<VitalsModel> data,
    double Function(VitalsModel) getValue,
    Color color,
    String unit,
  ) {
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
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 20,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: Colors.grey.shade200, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: data.asMap().entries.map((e) {
                return FlSpot(e.key.toDouble(), getValue(e.value));
              }).toList(),
              isCurved: true,
              color: color,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: color,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationsTab() {
    return StreamBuilder<List<MedicationModel>>(
      stream: _databaseService.getMedicationsForPatient(widget.patient.id),
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
                  'No medications prescribed',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        }

        final medications = snapshot.data!;
        final pending = medications.where((m) => !m.isAdministered).toList();
        final administered = medications
            .where((m) => m.isAdministered)
            .toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (pending.isNotEmpty) ...[
              Text('Pending', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              ...pending.map((m) => _MedicationLogCard(medication: m)),
              const SizedBox(height: 24),
            ],
            if (administered.isNotEmpty) ...[
              Text(
                'Administered',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ...administered.map((m) => _MedicationLogCard(medication: m)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildMessagesTab() {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.currentUser?.id;

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<MessageModel>>(
            stream: _databaseService.getMessagesForPatient(widget.patient.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 60,
                        color: AppTheme.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No messages yet',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                );
              }

              final messages = snapshot.data!;

              // Mark messages as read
              for (final message in messages) {
                if (message.receiverId == currentUserId && !message.isRead) {
                  _databaseService.markMessageAsRead(message.id);
                }
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isMe = message.senderId == currentUserId;

                  return _MessageBubble(message: message, isMe: isMe);
                },
              );
            },
          ),
        ),

        // Message input
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: _isRecording
                ? _buildRecordingUI()
                : Row(
                    children: [
                      // Voice record button
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: _isSending ? null : _startRecording,
                          icon: Icon(Icons.mic, color: AppTheme.primaryColor),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Reply to nurse...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          maxLines: null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: _isSending ? null : _sendMessage,
                          icon: _isSending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingUI() {
    return Row(
      children: [
        // Cancel button
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: _cancelRecording,
            icon: const Icon(Icons.close, color: Colors.grey),
          ),
        ),
        const SizedBox(width: 12),

        // Recording indicator
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.criticalRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.criticalRed.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppTheme.criticalRed,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Recording...',
                  style: TextStyle(
                    color: AppTheme.criticalRed,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(_recordDuration ~/ 60).toString().padLeft(2, '0')}:${(_recordDuration % 60).toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: AppTheme.criticalRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Stop/Send button
        Container(
          decoration: BoxDecoration(
            color: AppTheme.criticalRed,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: _stopRecording,
            icon: const Icon(Icons.stop, color: Colors.white),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
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
}

class _VitalCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _VitalCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          Text(
            unit,
            style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}

class _VitalsHistoryCard extends StatelessWidget {
  final VitalsModel vitals;
  final VoidCallback? onTap;

  const _VitalsHistoryCard({required this.vitals, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [AppTheme.cardShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMM dd, yyyy HH:mm').format(vitals.timestamp),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    Text(
                      vitals.recordedByName,
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
              runSpacing: 8,
              children: [
                _miniVital('HR', '${vitals.heartRate} bpm'),
                _miniVital('BP', vitals.bloodPressure),
                _miniVital(
                  'O₂',
                  '${vitals.oxygenSaturation.toStringAsFixed(0)}%',
                ),
                _miniVital(
                  'Temp',
                  '${vitals.temperature.toStringAsFixed(1)}°C',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniVital(String label, String value) {
    return Text(
      '$label: $value',
      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
    );
  }
}

class _MedicationLogCard extends StatelessWidget {
  final MedicationModel medication;

  const _MedicationLogCard({required this.medication});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: medication.isAdministered
              ? AppTheme.stableGreen.withValues(alpha: 0.5)
              : medication.isOverdue
              ? AppTheme.criticalRed
              : AppTheme.dividerColor,
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
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${medication.dosage} • ${medication.routeLabel}',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  medication.isAdministered
                      ? 'Given at ${DateFormat('HH:mm').format(medication.administeredTime!)} by ${medication.administeredByName}'
                      : 'Scheduled: ${DateFormat('MMM dd, HH:mm').format(medication.scheduledTime)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: medication.isAdministered
                        ? AppTheme.stableGreen
                        : medication.isOverdue
                        ? AppTheme.criticalRed
                        : AppTheme.textSecondary,
                    fontWeight: medication.isOverdue
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          if (medication.isAdministered)
            Icon(Icons.check_circle, color: AppTheme.stableGreen)
          else if (medication.isOverdue)
            Icon(Icons.warning, color: AppTheme.criticalRed),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  // ignore: unused_field - Reserved for UI progress display in future update
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.message.isVoiceMessage) {
      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() => _isPlaying = state == PlayerState.playing);
        }
      });
      _audioPlayer.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      });
      _audioPlayer.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (widget.message.voiceNotePath != null) {
        await _audioPlayer.play(UrlSource(widget.message.voiceNotePath!));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: widget.isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!widget.isMe)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  widget.message.senderName,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: widget.isMe ? AppTheme.accentColor : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(widget.isMe ? 16 : 4),
                  bottomRight: Radius.circular(widget.isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: widget.message.isVoiceMessage
                  ? _buildVoiceMessage()
                  : Text(
                      widget.message.content,
                      style: TextStyle(
                        color: widget.isMe
                            ? Colors.white
                            : AppTheme.textPrimary,
                        fontSize: 15,
                      ),
                    ),
            ),

            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('HH:mm').format(widget.message.sentAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (widget.isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      widget.message.isRead
                          ? Icons.done_all
                          : widget.message.isDelivered
                          ? Icons.done_all
                          : Icons.done,
                      size: 14,
                      color: widget.message.isRead
                          ? AppTheme.primaryColor
                          : AppTheme.textSecondary,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceMessage() {
    final totalSeconds = widget.message.voiceDurationSeconds ?? 0;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final durationLabel =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _playPause,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: widget.isMe
                  ? Colors.white.withValues(alpha: 0.2)
                  : AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: widget.isMe ? Colors.white : AppTheme.primaryColor,
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎤 Voice Message',
              style: TextStyle(
                color: widget.isMe ? Colors.white : AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _isPlaying
                  ? '${_position.inSeconds ~/ 60}:${(_position.inSeconds % 60).toString().padLeft(2, '0')} / $durationLabel'
                  : durationLabel,
              style: TextStyle(
                color: widget.isMe
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
