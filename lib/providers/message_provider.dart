import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../services/database_service.dart';

class MessageProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();

  List<MessageModel> _messages = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _unreadCount = 0;

  List<MessageModel> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get unreadCount => _unreadCount;

  // Send message
  Future<bool> sendMessage(MessageModel message) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final id = await _databaseService.sendMessage(message);
      if (id != null) {
        return true;
      }
      _errorMessage = 'Failed to send message';
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Mark message as read
  Future<void> markAsRead(String messageId) async {
    try {
      await _databaseService.markMessageAsRead(messageId);
    } catch (e) {
      // Silently fail
    }
  }

  // Get unread message count
  Future<void> loadUnreadCount(String userId) async {
    try {
      _unreadCount = await _databaseService.getUnreadMessageCount(userId);
      notifyListeners();
    } catch (e) {
      // Silently fail
    }
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
