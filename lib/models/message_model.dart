import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String receiverId;
  final String receiverName;
  final String patientId;
  final String patientName;
  final String content;
  final String type; // 'text', 'voice', 'image'
  final DateTime sentAt;
  final bool isDelivered;
  final bool isRead;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final String? attachmentUrl;
  final String? voiceNotePath;
  final int? voiceDurationSeconds;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.receiverId,
    required this.receiverName,
    required this.patientId,
    required this.patientName,
    required this.content,
    required this.type,
    required this.sentAt,
    this.isDelivered = false,
    this.isRead = false,
    this.deliveredAt,
    this.readAt,
    this.attachmentUrl,
    this.voiceNotePath,
    this.voiceDurationSeconds,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'patientId': patientId,
      'patientName': patientName,
      'content': content,
      'type': type,
      'sentAt': Timestamp.fromDate(sentAt),
      'isDelivered': isDelivered,
      'isRead': isRead,
      'deliveredAt': deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'attachmentUrl': attachmentUrl,
      'voiceNotePath': voiceNotePath,
      'voiceDurationSeconds': voiceDurationSeconds,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderRole: map['senderRole'] ?? '',
      receiverId: map['receiverId'] ?? '',
      receiverName: map['receiverName'] ?? '',
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'] ?? '',
      content: map['content'] ?? '',
      type: map['type'] ?? 'text',
      sentAt: (map['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDelivered: map['isDelivered'] ?? false,
      isRead: map['isRead'] ?? false,
      deliveredAt: (map['deliveredAt'] as Timestamp?)?.toDate(),
      readAt: (map['readAt'] as Timestamp?)?.toDate(),
      attachmentUrl: map['attachmentUrl'],
      voiceNotePath: map['voiceNotePath'],
      voiceDurationSeconds: map['voiceDurationSeconds'],
    );
  }

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel.fromMap({...data, 'id': doc.id});
  }

  MessageModel copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? senderRole,
    String? receiverId,
    String? receiverName,
    String? patientId,
    String? patientName,
    String? content,
    String? type,
    DateTime? sentAt,
    bool? isDelivered,
    bool? isRead,
    DateTime? deliveredAt,
    DateTime? readAt,
    String? attachmentUrl,
    String? voiceNotePath,
    int? voiceDurationSeconds,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      content: content ?? this.content,
      type: type ?? this.type,
      sentAt: sentAt ?? this.sentAt,
      isDelivered: isDelivered ?? this.isDelivered,
      isRead: isRead ?? this.isRead,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      voiceNotePath: voiceNotePath ?? this.voiceNotePath,
      voiceDurationSeconds: voiceDurationSeconds ?? this.voiceDurationSeconds,
    );
  }

  bool get isTextMessage => type == 'text';
  bool get isVoiceMessage => type == 'voice';
  bool get isImageMessage => type == 'image';

  String get statusLabel {
    if (isRead) return 'Read';
    if (isDelivered) return 'Delivered';
    return 'Sent';
  }

  String get voiceDurationLabel {
    if (voiceDurationSeconds == null) return '0:00';
    final minutes = voiceDurationSeconds! ~/ 60;
    final seconds = voiceDurationSeconds! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
