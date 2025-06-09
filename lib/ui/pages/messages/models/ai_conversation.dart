import 'package:flutter_application_2/ui/pages/messages/models/conversation.dart';
import 'package:flutter_application_2/ui/pages/messages/models/message.dart';
import 'package:flutter_application_2/ui/pages/messages/models/user.dart';
import 'package:flutter_application_2/services/ai/gemini_ai_service.dart';

/// AI-specific conversation model that handles AI assistant interactions
class AIConversation extends Conversation {
  // Use the singleton instance to ensure proper initialization
  GeminiAIService get _aiService => GeminiAIService();

  AIConversation({
    required String currentUserId,
    Message? initialMessage,
  }) : super(
          id: GeminiAIService().aiAssistantId,
          participants: [
            // Current user
            User(
              id: currentUserId,
              name: "You",
              avatarUrl: "",
              isOnline: true,
            ),
            // AI Assistant
            User(
              id: GeminiAIService().aiAssistantId,
              name: GeminiAIService().aiAssistantName,
              avatarUrl:
                  "https://cdn-icons-png.flaticon.com/512/149/149071.png", // Use a simple neutral avatar
              isOnline: true,
            ),
          ],
          lastMessage: initialMessage ?? _createInitialMessage(currentUserId),
          messages: initialMessage != null
              ? [initialMessage]
              : [_createInitialMessage(currentUserId)],
          isGroup: false,
          isArchived: false,
          isMuted: false,
          unreadCount: 0,
        );

  /// Create initial welcome message from AI
  static Message _createInitialMessage(String currentUserId) {
    final aiService = GeminiAIService();
    return Message(
      id: 'ai_initial_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: aiService.aiAssistantId,
      senderId: aiService.aiAssistantId,
      senderName: aiService.aiAssistantName,
      content:
          "Hi! I'm your LiveSpot AI Assistant. I can help you discover new places, analyze your activity patterns, and provide personalized recommendations. How can I assist you today?",
      timestamp: DateTime.now(),
      messageType: MessageType.text,
      status: MessageStatus.delivered,
      isRead: true, // Mark as read since it's a welcome message
    );
  }

  /// Generate AI response with better context handling and deduplication
  Future<Message> generateAIResponse(String userMessage) async {
    try {
      // Generate unique message ID to avoid duplicates
      final messageId =
          'ai_response_${DateTime.now().millisecondsSinceEpoch}_${userMessage.hashCode.abs()}';

      // Check for specific commands or requests
      String aiResponse;

      if (_isAnalysisRequest(userMessage)) {
        aiResponse = await _aiService.analyzePostsAndProvideInsights();
      } else if (_isRecommendationRequest(userMessage)) {
        aiResponse = await _aiService.getPersonalizedRecommendations();
      } else if (_isLocationRequest(userMessage)) {
        aiResponse = await _aiService.handleLocationQuery(userMessage);
      } else if (_isSearchRequest(userMessage)) {
        aiResponse = await _aiService.performSmartSearch(userMessage);
      } else {
        // Generate contextual response with conversation memory
        aiResponse = await _aiService.generateResponse(
          userMessage,
          conversationId: id,
        );
      }

      // Ensure response is not empty or generic
      if (aiResponse.trim().isEmpty || _isGenericResponse(aiResponse)) {
        aiResponse = _generateContextualFallback(userMessage);
      }

      // Create AI message with unique ID
      final aiMessage = Message(
        id: messageId,
        conversationId: id,
        senderId: _aiService.aiAssistantId,
        senderName: _aiService.aiAssistantName,
        content: aiResponse,
        timestamp: DateTime.now(),
        messageType: MessageType.text,
        status: MessageStatus.delivered,
        isRead: true,
      );

      return aiMessage;
    } catch (e) {
      print('Error generating AI response: $e');
      return _createErrorMessage();
    }
  }

  /// Check if user message is requesting analysis
  bool _isAnalysisRequest(String message) {
    final analysisKeywords = [
      'analyze',
      'analysis',
      'insights',
      'patterns',
      'activity',
      'posts',
      'behavior',
      'trends',
      'summary',
      'review'
    ];

    final lowerMessage = message.toLowerCase();
    return analysisKeywords.any((keyword) => lowerMessage.contains(keyword));
  }

  /// Check if user message is requesting recommendations
  bool _isRecommendationRequest(String message) {
    final recommendationKeywords = [
      'recommend',
      'suggestions',
      'suggest',
      'places',
      'discover',
      'find',
      'explore',
      'visit',
      'try',
      'new',
      'ideas'
    ];

    final lowerMessage = message.toLowerCase();
    return recommendationKeywords
        .any((keyword) => lowerMessage.contains(keyword));
  }

  /// Check if user message is requesting location information
  bool _isLocationRequest(String message) {
    final locationKeywords = [
      'where',
      'location',
      'place',
      'near me',
      'nearby',
      'around here',
      'local',
      'area',
      'directions',
      'address'
    ];

    final lowerMessage = message.toLowerCase();
    return locationKeywords.any((keyword) => lowerMessage.contains(keyword));
  }

  /// Check if user message is a search request
  bool _isSearchRequest(String message) {
    final searchKeywords = [
      'search',
      'find',
      'look for',
      'show me',
      'tell me about',
      'what about',
      'information',
      'details'
    ];

    final lowerMessage = message.toLowerCase();
    return searchKeywords.any((keyword) => lowerMessage.contains(keyword));
  }

  /// Check if response is too generic
  bool _isGenericResponse(String response) {
    final genericPhrases = [
      'I can help you',
      'How can I assist you',
      'What would you like to know',
      'I\'m here to help',
    ];

    final lowerResponse = response.toLowerCase();
    return genericPhrases
            .any((phrase) => lowerResponse.contains(phrase.toLowerCase())) &&
        response.length < 100;
  }

  /// Generate contextual fallback when AI response is generic
  String _generateContextualFallback(String userMessage) {
    final lowerMessage = userMessage.toLowerCase();

    if (lowerMessage.contains('food') || lowerMessage.contains('restaurant')) {
      return 'I can help you discover great dining spots! Check out the restaurant posts on LiveSpot where community members share their favorite places to eat, current deals, and food experiences in your area.';
    }

    if (lowerMessage.contains('event') || lowerMessage.contains('activity')) {
      return 'Looking for something to do? Browse the events category on LiveSpot where people post about local gatherings, concerts, festivals, and community activities happening near you.';
    }

    if (lowerMessage.contains('news') || lowerMessage.contains('update')) {
      return 'For the latest updates, check out the news section on LiveSpot where community members share local news, announcements, and important information affecting your area.';
    }

    return 'I\'m here to help you explore your community! You can ask me about local places, events, news, or get personalized recommendations based on LiveSpot activity in your area.';
  }

  /// Create error message with more helpful content
  Message _createErrorMessage() {
    return Message(
      id: 'ai_error_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: id,
      senderId: _aiService.aiAssistantId,
      senderName: _aiService.aiAssistantName,
      content:
          "I'm having some technical difficulties, but I'm still here to help! Try asking me about:\n\n• Local restaurants and dining\n• Events and activities\n• Community news and updates\n• Places to visit\n\nWhat interests you most?",
      timestamp: DateTime.now(),
      messageType: MessageType.text,
      status: MessageStatus.delivered,
      isRead: true,
    );
  }

  /// Get improved quick action suggestions
  List<String> getQuickActions() {
    return [
      "What's happening nearby?",
      "Recommend restaurants",
      "Show local events",
      "Analyze my activity",
      "Find trending places",
      "Community updates"
    ];
  }

  /// Check if this conversation should be pinned at the top
  @override
  bool get isPinned => true;

  /// Override displayName to show AI assistant name
  @override
  String get displayName => _aiService.aiAssistantName;

  /// Override avatarUrl to show AI avatar
  @override
  String get avatarUrl => _aiService.aiAssistantAvatar;

  /// Override isOnline to always show AI as available
  @override
  bool get isOnline => true;

  /// Convert to regular conversation data for storage (if needed)
  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['isAI'] = true;
    json['isPinned'] = true;
    return json;
  }

  /// Create AI conversation from existing data
  static AIConversation fromConversationData(
      Map<String, dynamic> data, String currentUserId) {
    final lastMessage = Message.fromJson(data['lastMessage'] ?? {});
    return AIConversation(
      currentUserId: currentUserId,
      initialMessage: lastMessage,
    );
  }
}
