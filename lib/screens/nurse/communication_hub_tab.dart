import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../models/message_model.dart';
import '../../models/patient_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';

class CommunicationHubTab extends StatefulWidget {
  final int wardNumber;
  final int bedNumber;

  /// Whether this tab is the one the nurse is actually looking at.
  /// IndexedStack keeps hidden tabs alive; without this gate, a hidden
  /// Messages tab marked messages as read that the nurse never saw
  /// (bug #20).
  final bool isActive;

  const CommunicationHubTab({
    super.key,
    required this.wardNumber,
    required this.bedNumber,
    this.isActive = true,
  });

  @override
  State<CommunicationHubTab> createState() => _CommunicationHubTabState();
}

class _CommunicationHubTabState extends State<CommunicationHubTab> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _databaseService = DatabaseService();

  bool _isSending = false;

  // Patient doc ids whose unread messages have been marked read for the
  // current activation of this tab - prevents repeat writes on rebuilds.
  final Set<String> _markedPatientIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _markVisibleUnread());
    }
  }

  @override
  void didUpdateWidget(CommunicationHubTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _markedPatientIds.clear();
      _markVisibleUnread();
    }
  }

  /// Marks unread messages addressed to me in THIS bed's conversation as
  /// read - but only while the tab is visible, and outside build().
  void _markVisibleUnread() {
    if (!widget.isActive || !mounted) return;

    final currentUserId = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).currentUser?.id;
    if (currentUserId == null) return;

    // Resolve the bed's conversation, then flip receipts for messages sent to
    // me. Runs once per activation (guarded by _markedPatientIds).
    _databaseService
        .getPatientForBed(widget.wardNumber, widget.bedNumber)
        .first
        .then((patient) {
          if (patient == null ||
              !mounted ||
              _markedPatientIds.contains(patient.id)) {
            return;
          }
          _markedPatientIds.add(patient.id);
          _databaseService
              .getMessagesForPatient(patient.id)
              .first
              .then((messages) {
                for (final message in messages) {
                  if (message.receiverId == currentUserId && !message.isRead) {
                    _databaseService.markMessageAsRead(message.id);
                  }
                }
              })
              .catchError((_) {});
        })
        .catchError((_) {});
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Capture before any await (context across async gaps).
    final messenger = ScaffoldMessenger.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    // Send against the CURRENT patient from the live stream - a fast ward
    // switch can no longer file a message under the previous patient's
    // record (bug #17 race).
    final patient = await _databaseService
        .getPatientForBed(widget.wardNumber, widget.bedNumber)
        .first;
    if (patient == null) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No patient in this bed')),
        );
      }
      return;
    }

    if (mounted) setState(() => _isSending = true);

    final message = MessageModel(
      id: '',
      senderId: user?.id ?? '',
      senderName: user?.name ?? 'Unknown Nurse',
      senderRole: AppConstants.roleNurse,
      receiverId: patient.attendingDoctorId,
      receiverName: patient.attendingDoctorName,
      patientId: patient.id,
      patientName: patient.name,
      content: text,
      type: AppConstants.messageTypeText,
      sentAt: DateTime.now(),
    );

    final result = await _databaseService.sendMessage(message);

    if (mounted) {
      setState(() => _isSending = false);

      if (result != null) {
        _messageController.clear();
        // Scroll to bottom
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to send message'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PatientModel?>(
      stream: _databaseService.getPatientForBed(
        widget.wardNumber,
        widget.bedNumber,
      ),
      builder: (context, patientSnapshot) {
        if (patientSnapshot.hasError) {
          return Center(
            child: Text(
              'Could not load patient data',
              style: TextStyle(color: AppTheme.criticalRed),
            ),
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
                  'Add patient details first to enable messaging',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Doctor info header
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_hospital,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dr. ${patient.attendingDoctorName}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Attending Doctor for ${patient.name}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Messages list
            Expanded(
              child: StreamBuilder<List<MessageModel>>(
                stream: _databaseService.getMessagesForPatient(patient.id),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
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
                          Text(
                            'Could not load messages',
                            style: TextStyle(color: AppTheme.textSecondary),
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
                            Icons.chat_bubble_outline,
                            size: 60,
                            color: AppTheme.textSecondary.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No messages yet',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Send a message to the doctor',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final messages = snapshot.data!;
                  final authProvider = Provider.of<AuthProvider>(context);
                  final currentUserId = authProvider.currentUser?.id;

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.senderId == currentUserId;

                      return MessageBubble(message: message, isMe: isMe);
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
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
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
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
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
      },
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

/// Chat bubble with role-aware sender labeling (bug #27: every non-self
/// sender was labeled "Dr. X", misattributing nurse messages as physician
/// instructions) and a working voice-note player (#27: voice notes rendered
/// as dead text here).
class MessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;

  const MessageBubble({super.key, required this.message, required this.isMe});

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    if (widget.message.isVoiceMessage) {
      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() => _isPlaying = state == PlayerState.playing);
        }
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else if (widget.message.voiceNotePath != null) {
        await _audioPlayer.play(UrlSource(widget.message.voiceNotePath!));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not play voice message')),
        );
      }
    }
  }

  String get _senderLabel {
    final name = widget.message.senderName;
    // Trust the stored role instead of assuming "doctor".
    return widget.message.senderRole == AppConstants.roleDoctor
        ? 'Dr. $name'
        : name;
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
            // Sender name for other-party messages
            if (!widget.isMe)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  _senderLabel,
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
                color: widget.isMe ? AppTheme.primaryColor : Colors.white,
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

            // Time and status
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
                          ? AppTheme.accentColor
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
        Text(
          _isPlaying ? 'Playing...' : durationLabel,
          style: TextStyle(
            color: widget.isMe
                ? Colors.white.withValues(alpha: 0.9)
                : AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
