import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_application_2/providers/posts_provider.dart';
import 'package:flutter_application_2/services/api/account/account_provider.dart';
import 'package:flutter_application_2/models/post.dart';
import 'package:flutter_application_2/services/location/location_cache_service.dart';
import 'package:flutter_application_2/services/ai/rag_integration_service.dart';

/// Service for integrating Google Gemini AI assistant with enhanced web access and memory
class GeminiAIService {
  static const String _apiKey = 'AIzaSyAxENZtQEaP7aDZT8cOqaIcY4a_xlDEz5Y';
  static const String _aiAssistantId =
      '-999999'; // Use numeric string that won't conflict with real users
  static const String _aiAssistantName = 'LiveSpot AI Assistant';

  late final GenerativeModel _model;
  late final RAGIntegrationService _ragService;
  PostsProvider? _postsProvider;
  AccountProvider? _accountProvider;
  LocationCacheService? _locationCacheService;

  // Enhanced conversation memory with better data tracking
  final Map<String, List<Map<String, String>>> _conversationHistory = {};
  final Map<String, Map<String, dynamic>> _conversationContext = {};
  final Map<String, List<String>> _userPreferences = {};
  final Map<String, DateTime> _lastInteraction = {};
  final int _maxHistoryLength = 15; // Increased for better context

  // Web search capability
  final Map<String, String> _webSearchCache = {};
  final int _cacheExpireDuration = 3600000; // 1 hour in milliseconds

  static final GeminiAIService _instance = GeminiAIService._internal();
  factory GeminiAIService() => _instance;

  GeminiAIService._internal() {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
      systemInstruction: Content.system(_getSystemPrompt()),
    );
    _ragService = RAGIntegrationService();
  }

  /// Initialize the service with required providers
  void initialize({
    PostsProvider? postsProvider,
    AccountProvider? accountProvider,
    LocationCacheService? locationCacheService,
  }) {
    _postsProvider = postsProvider;
    _accountProvider = accountProvider;
    _locationCacheService = locationCacheService;

    // Initialize RAG service with the same providers
    _ragService.initialize(
      postsProvider: postsProvider,
      locationCacheService: locationCacheService,
    );
  }

  /// Get AI assistant unique identifier
  String get aiAssistantId => _aiAssistantId;

  /// Get AI assistant display name
  String get aiAssistantName => _aiAssistantName;

  /// Get a robot icon identifier for the AI assistant (use Icons.smart_toy in UI)
  String get aiAssistantAvatar => "flutter_icon:smart_toy";

  /// Store conversation message in memory with enhanced context tracking
  void _storeConversationMessage(
      String conversationId, String role, String message) {
    if (!_conversationHistory.containsKey(conversationId)) {
      _conversationHistory[conversationId] = [];
      _conversationContext[conversationId] = {};
      _userPreferences[conversationId] = [];
    }

    final timestamp = DateTime.now();
    _lastInteraction[conversationId] = timestamp;

    _conversationHistory[conversationId]!.add({
      'role': role,
      'message': message,
      'timestamp': timestamp.millisecondsSinceEpoch.toString(),
    });

    // Extract and store user preferences and context
    if (role == 'user') {
      _extractUserPreferences(conversationId, message);
      _updateConversationContext(conversationId, message);
    }

    // Keep only last N messages but preserve context
    if (_conversationHistory[conversationId]!.length > _maxHistoryLength) {
      _conversationHistory[conversationId]!.removeAt(0);
    }
  }

  /// Extract user preferences from messages
  void _extractUserPreferences(String conversationId, String message) {
    final lowerMessage = message.toLowerCase();
    final preferences = _userPreferences[conversationId] ?? [];

    // Extract interests and preferences
    final interests = [
      'sports',
      'news',
      'food',
      'technology',
      'health',
      'business',
      'community',
      'entertainment',
      'environment',
      'politics'
    ];

    for (final interest in interests) {
      if (lowerMessage.contains(interest) && !preferences.contains(interest)) {
        preferences.add(interest);
      }
    }

    // Extract location preferences
    if (lowerMessage.contains('near me') ||
        lowerMessage.contains('around here')) {
      if (!preferences.contains('location_aware')) {
        preferences.add('location_aware');
      }
    }

    // Extract time preferences
    if (lowerMessage.contains('morning') ||
        lowerMessage.contains('evening') ||
        lowerMessage.contains('weekend')) {
      if (!preferences.contains('time_sensitive')) {
        preferences.add('time_sensitive');
      }
    }

    _userPreferences[conversationId] = preferences;
  }

  /// Update conversation context with important information
  void _updateConversationContext(String conversationId, String message) {
    final context = _conversationContext[conversationId] ?? {};
    final lowerMessage = message.toLowerCase();

    // Track conversation topics
    final topics = context['topics'] as List<String>? ?? [];

    // Enhanced topic detection with better context understanding

    // Seeking information/recommendations
    if (lowerMessage.contains('recommend') ||
        lowerMessage.contains('suggest') ||
        lowerMessage.contains('what should') ||
        lowerMessage.contains('where can')) {
      if (!topics.contains('seeking_recommendations')) {
        topics.add('seeking_recommendations');
      }
    }

    // Asking about current events/updates
    if ((lowerMessage.contains('what') &&
            (lowerMessage.contains('happen') ||
                lowerMessage.contains('going on'))) ||
        lowerMessage.contains('latest') ||
        lowerMessage.contains('news') ||
        lowerMessage.contains('updates')) {
      if (!topics.contains('seeking_updates')) {
        topics.add('seeking_updates');
      }
    }

    // Statistical/analytical queries
    if (lowerMessage.contains('how many') ||
        lowerMessage.contains('count') ||
        lowerMessage.contains('statistics') ||
        lowerMessage.contains('analyze') ||
        lowerMessage.contains('data') ||
        lowerMessage.contains('trends')) {
      if (!topics.contains('seeking_analytics')) {
        topics.add('seeking_analytics');
      }
    }

    // Location-based queries
    if (lowerMessage.contains('near me') ||
        lowerMessage.contains('around here') ||
        lowerMessage.contains('in my area') ||
        lowerMessage.contains('nearby') ||
        lowerMessage.contains('local')) {
      if (!topics.contains('location_focused')) {
        topics.add('location_focused');
      }
    }

    // Topic changes detection
    final categoryKeywords = {
      'food': ['restaurant', 'food', 'eat', 'dining', 'cafe', 'meal'],
      'events': ['event', 'happening', 'activity', 'party', 'gathering'],
      'places': ['place', 'location', 'spot', 'venue', 'destination'],
      'people': ['people', 'friends', 'community', 'social', 'meet'],
      'health': ['health', 'fitness', 'gym', 'exercise', 'medical'],
      'business': ['business', 'work', 'professional', 'company', 'service'],
      'news': ['news', 'politics', 'government', 'current affairs'],
      'entertainment': ['fun', 'entertainment', 'movie', 'music', 'game']
    };

    String? currentTopic = null;
    for (final category in categoryKeywords.keys) {
      if (categoryKeywords[category]!
          .any((keyword) => lowerMessage.contains(keyword))) {
        currentTopic = category;
        break;
      }
    }

    if (currentTopic != null) {
      // Check for topic change
      final lastTopic = context['current_topic'] as String?;
      if (lastTopic != null && lastTopic != currentTopic) {
        context['topic_changed'] = true;
        context['previous_topic'] = lastTopic;
        topics.add('topic_change_detected');
      }
      context['current_topic'] = currentTopic;
    }

    // Emotional context detection
    final emotions = context['emotions'] as List<String>? ?? [];
    if (lowerMessage.contains('frustrated') ||
        lowerMessage.contains('annoyed') ||
        lowerMessage.contains('confused') ||
        lowerMessage.contains('lost')) {
      if (!emotions.contains('needs_help')) emotions.add('needs_help');
    }
    if (lowerMessage.contains('thanks') ||
        lowerMessage.contains('great') ||
        lowerMessage.contains('perfect') ||
        lowerMessage.contains('awesome')) {
      if (!emotions.contains('satisfied')) emotions.add('satisfied');
    }

    context['topics'] = topics;
    context['emotions'] = emotions;
    context['last_updated'] = DateTime.now().millisecondsSinceEpoch;
    context['message_count'] = (context['message_count'] as int? ?? 0) + 1;

    _conversationContext[conversationId] = context;
  }

  /// Get conversation history and context for better responses
  String _getConversationContext(String conversationId) {
    if (!_conversationHistory.containsKey(conversationId)) {
      return '';
    }

    final history = _conversationHistory[conversationId]!;
    final context = _conversationContext[conversationId] ?? {};
    final preferences = _userPreferences[conversationId] ?? [];

    if (history.isEmpty) return '';

    final contextParts = <String>[];

    // Add user preferences
    if (preferences.isNotEmpty) {
      contextParts.add('User interests: ${preferences.join(', ')}');
    }

    // Add conversation topics and context
    final topics = context['topics'] as List<String>? ?? [];
    if (topics.isNotEmpty) {
      contextParts.add('Conversation focus: ${topics.join(', ')}');
    }

    // Handle topic changes
    if (context['topic_changed'] == true) {
      final previousTopic = context['previous_topic'] as String?;
      final currentTopic = context['current_topic'] as String?;
      if (previousTopic != null && currentTopic != null) {
        contextParts
            .add('Topic change detected: from $previousTopic to $currentTopic');
      }
    }

    // Add emotional context
    final emotions = context['emotions'] as List<String>? ?? [];
    if (emotions.isNotEmpty) {
      contextParts.add('User state: ${emotions.join(', ')}');
    }

    // Add COMPLETE conversation history including AI responses
    final recentMessages = history.reversed.take(10).toList().reversed;
    final dialogHistory = <String>[];

    for (final msg in recentMessages) {
      final role = msg['role'] == 'user' ? 'User' : 'You (AI Assistant)';
      final message = msg['message']!;

      // Include all messages to show full conversation flow
      final truncated =
          message.length > 120 ? message.substring(0, 120) + '...' : message;
      dialogHistory.add('$role: $truncated');
    }

    if (dialogHistory.isNotEmpty) {
      contextParts.add('Previous conversation:\n${dialogHistory.join('\n')}\n');
      contextParts.add(
          'IMPORTANT: Continue this conversation naturally. Reference what you said before when relevant.');
    }

    // Add time context and conversation continuity
    final lastInteraction = _lastInteraction[conversationId];
    if (lastInteraction != null) {
      final timeDiff = DateTime.now().difference(lastInteraction);
      if (timeDiff.inHours > 24) {
        contextParts.add(
            'Note: Continuing conversation from ${timeDiff.inDays} days ago - acknowledge the time gap and reference previous discussion');
      } else if (timeDiff.inHours > 1) {
        contextParts.add(
            'Note: Continuing conversation from ${timeDiff.inHours} hours ago - maintain conversation flow');
      }
    }

    // Add conversation statistics for better understanding
    final messageCount = context['message_count'] as int? ?? history.length;
    if (messageCount > 5) {
      contextParts.add(
          'Note: This is an ongoing conversation (${messageCount ~/ 2} exchanges) - build on previous responses and avoid repeating yourself');
    }

    return contextParts.isEmpty ? '' : '${contextParts.join('\n\n')}\n\n';
  }

  /// Search web for current information using reliable sources
  Future<String> _searchWeb(String query) async {
    try {
      // Check cache first
      final cacheKey = query.toLowerCase().trim();
      final now = DateTime.now().millisecondsSinceEpoch;

      if (_webSearchCache.containsKey(cacheKey)) {
        final cachedData = _webSearchCache[cacheKey]!.split('|TIMESTAMP|');
        if (cachedData.length == 2) {
          final timestamp = int.tryParse(cachedData[1]) ?? 0;
          if (now - timestamp < _cacheExpireDuration) {
            return cachedData[0];
          }
        }
      }

      // Try multiple search approaches
      String webResults = '';

      // Method 1: Try Wikipedia API (more reliable)
      webResults = await _tryWikipediaAPI(query);
      if (webResults.isNotEmpty) {
        _webSearchCache[cacheKey] = '$webResults|TIMESTAMP|$now';
        return _rewriteWebContent(webResults, query);
      }

      // Method 2: Try news API (if query seems news-related)
      if (_isNewsQuery(query)) {
        webResults = await _tryNewsAPI(query);
        if (webResults.isNotEmpty) {
          _webSearchCache[cacheKey] = '$webResults|TIMESTAMP|$now';
          return _rewriteWebContent(webResults, query);
        }
      }

      // Method 3: Generate contextual response based on LiveSpot data
      webResults = await _generateContextualWebResponse(query);
      _webSearchCache[cacheKey] = '$webResults|TIMESTAMP|$now';
      return webResults;
    } catch (e) {
      print('Web search error: $e');
      return await _generateContextualWebResponse(query);
    }
  }

  /// Try Wikipedia API for reliable information
  Future<String> _tryWikipediaAPI(String query) async {
    try {
      // Clean query for Wikipedia
      final cleanQuery = query.replaceAll(RegExp(r'[^\w\s]'), '').trim();
      if (cleanQuery.isEmpty) return '';

      final searchUrl = Uri.parse(
          'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(cleanQuery)}');

      final response = await http.get(searchUrl).timeout(Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        String result = '';
        if (data['extract'] != null && data['extract'].toString().isNotEmpty) {
          result = data['extract'].toString();

          // Add title if available
          if (data['title'] != null) {
            result = 'About ${data['title']}: $result';
          }

          return result;
        }
      }
    } catch (e) {
      print('Wikipedia API failed: $e');
    }
    return '';
  }

  /// Try news API for current events
  Future<String> _tryNewsAPI(String query) async {
    try {
      // Use a free news API - NewsAPI alternative or RSS feeds
      // For now, return a contextual response since free news APIs are limited
      return _generateNewsResponse(query);
    } catch (e) {
      print('News API failed: $e');
      return '';
    }
  }

  /// Check if query is news-related
  bool _isNewsQuery(String query) {
    final newsKeywords = [
      'news',
      'latest',
      'current events',
      'today',
      'breaking',
      'update',
      'politics',
      'world'
    ];
    final lowerQuery = query.toLowerCase();
    return newsKeywords.any((keyword) => lowerQuery.contains(keyword));
  }

  /// Generate news response without external API
  String _generateNewsResponse(String query) {
    final lowerQuery = query.toLowerCase();

    if (lowerQuery.contains('weather')) {
      return 'For current weather updates, check your local weather app or LiveSpot posts where community members share weather conditions and alerts in your area.';
    }

    if (lowerQuery.contains('traffic')) {
      return 'For real-time traffic information, I recommend checking traffic apps or LiveSpot posts where users share road conditions, accidents, and construction updates in your area.';
    }

    if (lowerQuery.contains('news') || lowerQuery.contains('current events')) {
      return 'For the latest news, check reliable news sources or browse LiveSpot\'s news category where community members share and discuss current events relevant to your area.';
    }

    return 'For current information about this topic, I recommend checking recent LiveSpot posts or reliable news sources for the most up-to-date details.';
  }

  /// Generate contextual web response using LiveSpot data
  Future<String> _generateContextualWebResponse(String query) async {
    try {
      // Use RAG to find relevant posts that might answer the query
      final relevantPosts = await _ragService.retrieveRelevantPosts(
        query,
        maxResults: 5,
        context: {'web_search_fallback': true},
      );

      if (relevantPosts.isNotEmpty) {
        final postSummary = relevantPosts.take(3).map((post) {
          final location = post.location.address ?? 'Local area';
          final content = post.content.length > 100
              ? '${post.content.substring(0, 100)}...'
              : post.content;
          return '• From $location: $content';
        }).join('\n');

        return 'Based on recent LiveSpot activity, here\'s what I found:\n\n$postSummary\n\nFor more current information, you might want to check recent posts in relevant categories or ask the community directly.';
      }

      return _getFallbackWebResults(query);
    } catch (e) {
      return _getFallbackWebResults(query);
    }
  }

  /// Check if message is generic to avoid repetitive context
  bool _isGenericMessage(String message) {
    final genericPhrases = [
      'hi',
      'hello',
      'thanks',
      'thank you',
      'ok',
      'okay',
      'yes',
      'no',
      'i see',
      'got it',
      'sure',
      'alright'
    ];

    final lowerMessage = message.toLowerCase().trim();
    return genericPhrases.contains(lowerMessage) || lowerMessage.length < 5;
  }

  /// Rewrite web content in AI's own words and style
  String _rewriteWebContent(String rawContent, String originalQuery) {
    // Clean and process the raw content
    final cleanContent = rawContent
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize spaces
        .trim();

    // Rewrite in a more conversational, personalized way
    final sentences = cleanContent.split(RegExp(r'[.!?]+'));
    final rewritten = <String>[];

    for (final sentence in sentences) {
      if (sentence.trim().isEmpty) continue;

      String rewrittenSentence = sentence.trim();

      // Make it more conversational
      if (rewrittenSentence.startsWith('The ')) {
        rewrittenSentence =
            rewrittenSentence.replaceFirst('The ', 'From what I found, the ');
      } else if (rewrittenSentence.startsWith('A ')) {
        rewrittenSentence = rewrittenSentence.replaceFirst('A ', 'There\'s a ');
      }

      // Add personal touch
      if (rewrittenSentence.contains('important') ||
          rewrittenSentence.contains('significant')) {
        rewrittenSentence += ' This could be relevant for your area too.';
      }

      rewritten.add(rewrittenSentence);
    }

    String result = rewritten.take(3).join('. ') + '.';

    // Add contextual connection to LiveSpot
    result +=
        '\n\nBased on this information, you might want to check LiveSpot for local perspectives on "${originalQuery}" or share your own experiences about this topic.';

    return result;
  }

  /// Get fallback web results when real search fails
  Future<String> _getFallbackWebResults(String query) async {
    final lowerQuery = query.toLowerCase();

    // Provide more intelligent fallback responses
    if (lowerQuery.contains('news') ||
        lowerQuery.contains('today') ||
        lowerQuery.contains('current') ||
        lowerQuery.contains('latest')) {
      return 'I\'m having trouble accessing current news right now, but I can help you find local perspectives on LiveSpot. Try checking recent posts in the news category, or share what you\'ve heard and I can help you discuss it with the community.';
    }

    if (lowerQuery.contains('weather') || lowerQuery.contains('temperature')) {
      return 'For the most current weather information, I\'d recommend checking your weather app. Meanwhile, I can help you find LiveSpot posts about weather-related events, outdoor activities, or how weather is affecting your local community.';
    }

    if (lowerQuery.contains('restaurant') ||
        lowerQuery.contains('food') ||
        lowerQuery.contains('cafe') ||
        lowerQuery.contains('dining')) {
      return 'While I can\'t search restaurant reviews right now, LiveSpot has real user experiences about local dining! Let me check recent food and restaurant posts from your community - these are often more reliable than generic reviews.';
    }

    return 'I\'m having trouble searching the web for "${query}" right now, but I can definitely help you explore this topic through LiveSpot posts and community discussions. What specific aspect interests you most?';
  }

  /// Generate AI response based on user message and context (Enhanced with RAG, Memory, and Web Access)
  Future<String> generateResponse(String userMessage,
      {List<String>? previousMessages, String? conversationId}) async {
    try {
      // Use conversationId or default for memory
      final convId = conversationId ?? 'default';

      // Store user message in conversation memory
      _storeConversationMessage(convId, 'user', userMessage);

      // 1. Check for specific data queries first
      final smartDataResponse = await _handleSmartDataQueries(userMessage);
      if (smartDataResponse != null) {
        _storeConversationMessage(convId, 'assistant', smartDataResponse);
        return smartDataResponse;
      }

      // 2. Check for event/date query and answer with real DB data if possible
      final dbAnswer = await _handleEventDateQuery(userMessage);
      if (dbAnswer != null) {
        _storeConversationMessage(convId, 'assistant', dbAnswer);
        return dbAnswer;
      }

      // 3. Check if user needs current/web information
      String webContext = '';
      if (_needsWebSearch(userMessage)) {
        webContext = await _searchWeb(userMessage);
      }

      // 4. Get conversation history for better context (INCLUDES AI RESPONSES)
      final conversationContext = _getConversationContext(convId);

      // 5. Use RAG service to retrieve relevant posts for better context
      final relevantPosts = await _ragService.retrieveRelevantPosts(
        userMessage,
        maxResults: 8,
        context: {
          'user_id': _accountProvider?.currentUser?.id,
          'has_location': _locationCacheService?.cachedPosition != null,
          'conversation_history': conversationContext,
        },
      );

      // 6. Generate contextual summary of retrieved posts
      final ragContext =
          _ragService.generateContextualSummary(relevantPosts, userMessage);

      // 7. Get user context
      final userContext = await _getUserContext();

      // 8. Build enhanced prompt with all contexts
      final prompt = [
        if (conversationContext.isNotEmpty) conversationContext,
        "Current user message: \"$userMessage\"",
        "User profile context:\n$userContext",
        if (webContext.isNotEmpty) "Current web information:\n$webContext",
        if (relevantPosts.isNotEmpty) "Relevant LiveSpot posts:\n$ragContext",
        _getEnhancedInstructions(),
      ].join("\n\n");

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      String aiResponse;
      if (response.text?.isNotEmpty == true) {
        aiResponse = _cleanResponse(response.text!);
      } else {
        aiResponse = _getDefaultResponse();
      }

      // IMPORTANT: Store AI response in conversation memory
      _storeConversationMessage(convId, 'assistant', aiResponse);

      return aiResponse;
    } catch (e) {
      print('Error generating AI response: $e');
      final errorResponse = _getErrorResponse();
      if (conversationId != null) {
        _storeConversationMessage(conversationId, 'assistant', errorResponse);
      }
      return errorResponse;
    }
  }

  /// Handle smart data queries that require specific handling
  Future<String?> _handleSmartDataQueries(String userMessage) async {
    // Implement specific query handling logic here
    // For example, if the user asks for their activity summary, handle it specifically
    if (userMessage.toLowerCase().contains('activity summary')) {
      return await _generateActivitySummary();
    }

    return null; // No specific handling applied
  }

  /// Generate a summary of user activity (posts, interactions, etc.)
  Future<String> _generateActivitySummary() async {
    try {
      final userId = _accountProvider?.currentUser?.id;
      if (userId == null) return "User activity summary not available.";

      // Fetch user's posts
      final posts = _postsProvider?.posts ?? [];
      // Use the userId property to match the current user's posts
      final userPosts = posts
          .where((post) => post.author.id.toString() == userId.toString())
          .toList();

      // Generate summary
      final postCount = userPosts.length;
      final recentPost = postCount > 0
          ? userPosts.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b)
          : null;

      return "You have made $postCount posts. ${recentPost != null ? 'Your most recent post was on ${recentPost.createdAt}.' : ''}";
    } catch (e) {
      print('Error generating activity summary: $e');
      return "Error generating activity summary.";
    }
  }

  /// Handle event or date-specific queries that need real data
  Future<String?> _handleEventDateQuery(String userMessage) async {
    // Implement specific event or date query handling here
    // For example, if the user asks about events this weekend, provide real data
    if (userMessage.toLowerCase().contains('events this weekend')) {
      return await _generateWeekendEvents();
    }

    return null; // No specific handling applied
  }

  /// Generate events happening this weekend based on real data
  Future<String> _generateWeekendEvents() async {
    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(Duration(days: 6));

      // Fetch relevant posts as events
      final events = await _ragService.retrieveRelevantPosts(
        'events',
        maxResults: 5,
        context: {
          'start_date': startOfWeek.toIso8601String(),
          'end_date': endOfWeek.toIso8601String(),
        },
      );

      if (events.isEmpty) {
        return "No events found for this weekend.";
      }

      // Generate event summary
      final eventDetails = events.map((event) {
        final date = event.createdAt;
        final location = event.location.address ?? 'Unknown location';
        return '• ${event.content.length > 50 ? event.content.substring(0, 50) + '...' : event.content} on ${date.toLocal()} at $location';
      }).join('\n');

      return "Upcoming events this weekend:\n$eventDetails";
    } catch (e) {
      print('Error generating weekend events: $e');
      return "Error fetching events.";
    }
  }

  /// Check if the user message requires web search
  bool _needsWebSearch(String userMessage) {
    final webSearchKeywords = [
      'news',
      'latest',
      'update',
      'traffic',
      'weather'
    ];
    final lowerMessage = userMessage.toLowerCase();
    return webSearchKeywords.any((keyword) => lowerMessage.contains(keyword));
  }

  /// Clean and format the AI response
  String _cleanResponse(String response) {
    // Basic cleaning - remove extra spaces, newlines, etc.
    return response.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Get enhanced instructions for the AI model (for internal use)
  String _getEnhancedInstructions() {
    return """
You are an advanced AI assistant with access to user data, web search, and contextual information.

CRITICAL CONVERSATION RULES:
- You can see your previous responses in the conversation history
- NEVER repeat information you already provided unless asked to clarify
- Reference your previous responses when relevant: "As I mentioned earlier..." or "Building on what we discussed..."
- If the user asks something you already answered, acknowledge it: "I covered this before, but let me add..."
- Maintain conversation flow - don't start fresh each time

Your goals:
- Provide accurate, helpful responses using all available data
- Maintain engaging, natural conversations with memory
- Respect user privacy and data security
- Build on previous conversation naturally

Response guidelines:
- Always acknowledge the user's message and provide relevant information
- Use web search results for current events, news, or real-time information
- Reference LiveSpot posts, user activity, and preferences for personalized responses
- When unsure, ask clarifying questions to provide better assistance
- Keep responses concise, focused, and valuable to the user
- Avoid unnecessary repetition or filler content
- End responses with an open question or suggestion to continue the conversation
- REMEMBER: You have conversation history - use it wisely!
""";
  }

  /// Analyze posts and provide insights (Enhanced with RAG and smart data fetching)
  Future<String> analyzePostsAndProvideInsights() async {
    try {
      // First try to get data through RAG service - it has direct access to posts
      final analysisQuery = "user activity analysis and insights";
      final relevantPosts = await _ragService.retrieveRelevantPosts(
        analysisQuery,
        maxResults: 20,
        context: {
          'user_id': _accountProvider?.currentUser?.id,
          'analysis_type': 'activity_insights',
        },
      );

      // If we have posts from RAG, analyze them
      if (relevantPosts.isNotEmpty) {
        return await _generateSmartAnalysis(relevantPosts);
      }

      // Fallback: try posts provider if available
      if (_postsProvider != null) {
        final posts = _postsProvider!.posts;
        if (posts.isNotEmpty) {
          return await _generateSmartAnalysis(posts);
        }
      }

      // If no data found, try to fetch some general insights
      final generalPosts = await _ragService.retrieveRelevantPosts(
        "general trends activity",
        maxResults: 15,
        context: {'analysis_type': 'general_trends'},
      );

      if (generalPosts.isNotEmpty) {
        return _generateGeneralInsights(generalPosts);
      }

      // Last resort
      return "I can see the LiveSpot community is active! Based on current trends, I notice popular categories include news, sports, community events, and local business updates. Share some posts and I'll give you personalized insights about your activity patterns.";
    } catch (e) {
      print('Error analyzing posts: $e');
      return "I'm analyzing the community activity and trends. Popular areas include local events, dining recommendations, and community news. Start sharing your experiences and I'll provide personalized insights!";
    }
  }

  /// Generate smart analysis from posts with AI enhancement
  Future<String> _generateSmartAnalysis(List<Post> posts) async {
    try {
      // Analyze posting patterns
      final categoryFrequency = <String, int>{};
      final locationFrequency = <String, int>{};
      final timePatterns = <int, int>{}; // hour -> count
      final engagementData = <String, double>{};

      for (final post in posts) {
        // Category analysis
        final category = post.category;
        categoryFrequency[category] = (categoryFrequency[category] ?? 0) + 1;

        // Location analysis
        final locationAddress = post.location.address;
        if (locationAddress != null && locationAddress.isNotEmpty) {
          locationFrequency[locationAddress] =
              (locationFrequency[locationAddress] ?? 0) + 1;
        }

        // Time pattern analysis
        final hour = post.createdAt.hour;
        timePatterns[hour] = (timePatterns[hour] ?? 0) + 1;

        // Engagement analysis (upvotes, downvotes, etc.)
        final engagement = (post.upvotes) + (post.downvotes);
        engagementData[category] = (engagementData[category] ?? 0) + engagement;
      }

      // Build smart insights
      final insights = <String>[];

      // Top categories
      final topCategories = categoryFrequency.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (topCategories.isNotEmpty) {
        final topCat = topCategories.first;
        insights.add(
            "Your most active category is ${topCat.key} with ${topCat.value} posts. This shows you're particularly engaged with ${topCat.key.toLowerCase()} content.");
      }

      // Location patterns
      final topLocations = locationFrequency.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (topLocations.isNotEmpty) {
        final topLoc = topLocations.first;
        insights.add(
            "You frequently post about ${topLoc.key}, suggesting this area is important to you.");
      }

      // Time patterns
      final topTimes = timePatterns.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (topTimes.isNotEmpty) {
        final peakHour = topTimes.first.key;
        final timeDesc = peakHour < 12
            ? "morning"
            : peakHour < 18
                ? "afternoon"
                : "evening";
        insights.add(
            "You're most active in the $timeDesc (around ${peakHour}:00), which is great for community engagement.");
      }

      // Engagement insights
      final highEngagement = engagementData.entries
          .where((e) => e.value > 0)
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (highEngagement.isNotEmpty) {
        final bestCategory = highEngagement.first.key;
        insights.add(
            "Your $bestCategory posts tend to get the most engagement from the community.");
      }

      // Recommendations based on analysis
      insights.add(
          "Based on your activity, I recommend exploring ${_getRecommendedCategories(categoryFrequency)} to diversify your LiveSpot experience.");

      return insights.join('\n\n');
    } catch (e) {
      print('Error in smart analysis: $e');
      return "I've analyzed ${posts.length} posts and can see you're an active community member. Your posts cover various categories and show good engagement with the LiveSpot community.";
    }
  }

  /// Generate insights from general community data
  String _generateGeneralInsights(List<Post> posts) {
    final categories = posts.map((p) => p.category).toSet();
    final locations =
        posts.map((p) => p.location.address).where((a) => a != null).toSet();

    return "The LiveSpot community is buzzing with activity! I can see ${posts.length} recent posts covering ${categories.length} different categories including ${categories.take(5).join(', ')}. There's content from ${locations.length} different locations. The community is particularly active in news, community events, and local recommendations.";
  }

  /// Get recommended categories based on current activity
  String _getRecommendedCategories(Map<String, int> currentCategories) {
    final allCategories = [
      'news',
      'sports',
      'community',
      'environment',
      'health',
      'entertainment',
      'business',
      'technology'
    ];
    final missing = allCategories
        .where((cat) => !currentCategories.containsKey(cat))
        .toList();
    return missing.take(3).join(', ');
  }

  /// Get personalized recommendations based on user activity (Enhanced with RAG)
  Future<String> getPersonalizedRecommendations() async {
    try {
      // First, try to get recommendations through RAG service
      final recommendationPosts = await _ragService.retrieveRelevantPosts(
        "recommendations places events activities",
        maxResults: 15,
        context: {
          'user_id': _accountProvider?.currentUser?.id,
          'has_location': _locationCacheService?.cachedPosition != null,
          'query_type': 'recommendations',
        },
      );

      if (recommendationPosts.isNotEmpty) {
        return _generateSmartRecommendations(recommendationPosts);
      }

      // Fallback: try location-based recommendations if available
      final position = _locationCacheService?.cachedPosition;
      if (position != null && _postsProvider != null) {
        try {
          final result = await _postsProvider!.fetchRecommendedPosts(
            latitude: position.latitude,
            longitude: position.longitude,
            limit: 5,
          );
          final posts = result['posts'] as List<Post>? ?? [];
          if (posts.isNotEmpty) {
            return _generateSmartRecommendations(posts);
          }
        } catch (e) {
          print('Error fetching location-based posts: $e');
        }
      }

      // Fallback: try user's post history if available
      if (_postsProvider?.posts.isNotEmpty == true) {
        return _generateSmartRecommendations(
            _postsProvider!.posts.take(10).toList());
      }

      // Last resort: provide general trending recommendations
      return _getGeneralRecommendations();
    } catch (e) {
      print('Error getting personalized recommendations: $e');
      return _getGeneralRecommendations();
    }
  }

  /// Generate smart recommendations from posts
  String _generateSmartRecommendations(List<Post> posts) {
    final categories = <String, int>{};
    final locations = <String, int>{};
    final recommendations = <String>[];

    // Analyze the posts to understand patterns
    for (final post in posts) {
      categories[post.category] = (categories[post.category] ?? 0) + 1;
      if (post.location.address != null) {
        locations[post.location.address!] =
            (locations[post.location.address!] ?? 0) + 1;
      }
    }

    recommendations
        .add("Based on LiveSpot activity, here are some recommendations:");

    // Show popular places/events
    final sortedPosts = posts.take(5).toList();
    for (final post in sortedPosts) {
      final location = post.location.address ?? 'Location available';
      final content = post.content.length > 70
          ? post.content.substring(0, 70) + '...'
          : post.content;
      recommendations.add("• [${post.category}] $location: $content");
    }

    // Suggest trending categories
    final topCategories = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (topCategories.isNotEmpty) {
      final trending = topCategories.take(3).map((e) => e.key).join(', ');
      recommendations.add("\nTrending categories: $trending");
    }

    // Suggest exploring new areas
    final allCategories = [
      'news',
      'sports',
      'community',
      'environment',
      'health',
      'entertainment',
      'business',
      'technology'
    ];
    final unexplored = allCategories
        .where((cat) => !categories.containsKey(cat))
        .take(3)
        .toList();
    if (unexplored.isNotEmpty) {
      recommendations.add("You might also enjoy: ${unexplored.join(', ')}");
    }

    return recommendations.join('\n');
  }

  /// Get general recommendations when no specific data is available
  String _getGeneralRecommendations() {
    return "Here are some popular LiveSpot categories to explore:\n\n"
        "• News - Stay updated with local and global events\n"
        "• Community - Connect with neighbors and local groups\n"
        "• Sports - Follow games, teams, and sporting events\n"
        "• Health - Wellness tips and health-related content\n"
        "• Environment - Sustainability and eco-friendly initiatives\n"
        "• Entertainment - Events, shows, and fun activities\n\n"
        "Start exploring these categories and I'll provide more personalized recommendations based on your interests!";
  }

  /// Get enhanced personalized recommendations using RAG service
  Future<String> getEnhancedRecommendations({String? specificQuery}) async {
    try {
      // 1. Get trending insights from RAG service
      final trendingInsights = await _ragService.getTrendingInsights();

      // 2. Use RAG to find relevant posts based on user interests or query
      final query = specificQuery ??
          "recommendations events places to visit interesting activities";
      final relevantPosts = await _ragService.retrieveRelevantPosts(
        query,
        maxResults: 15,
        context: {
          'user_id': _accountProvider?.currentUser?.id,
          'recommendation_mode': true,
        },
      );

      // 3. Build comprehensive recommendation prompt
      final userContext = await _getUserContext();
      final userPreferences = await _getUserPreferences();

      final prompt = """
Generate personalized recommendations for a LiveSpot user based on the following data:

User Context:
$userContext

User Preferences:
$userPreferences

Trending Insights:
${trendingInsights['error'] != null ? 'Unable to get trending data' : _formatTrendingInsights(trendingInsights)}

Relevant Posts from Database:
${_ragService.generateContextualSummary(relevantPosts, query)}

${specificQuery != null ? 'User specifically asked about: "$specificQuery"' : ''}

Please provide:
1. Personalized recommendations based on their activity patterns
2. Trending places and events they might enjoy
3. New categories or experiences to explore
4. Specific actionable suggestions with locations when possible
5. A brief explanation of why each recommendation fits their interests

Keep the response engaging, specific, and actionable. Focus on real places and events from the data.
""";

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      return response.text ?? getPersonalizedRecommendations();
    } catch (e) {
      print('Error getting enhanced recommendations: $e');
      // Fallback to original method
      return getPersonalizedRecommendations();
    }
  }

  /// Format trending insights for AI prompt
  String _formatTrendingInsights(Map<String, dynamic> insights) {
    final buffer = StringBuffer();

    if (insights['trending_categories'] != null) {
      buffer.writeln('Trending Categories:');
      for (final category in insights['trending_categories']) {
        buffer.writeln('• ${category['category']}: ${category['count']} posts');
      }
    }

    if (insights['trending_locations'] != null) {
      buffer.writeln('\nTrending Locations:');
      for (final location in insights['trending_locations']) {
        buffer.writeln('• ${location['location']}: ${location['count']} posts');
      }
    }

    if (insights['most_active_category'] != null) {
      buffer.writeln(
          '\nMost Active Category: ${insights['most_active_category']}');
    }

    buffer
        .writeln('Total Recent Posts: ${insights['total_recent_posts'] ?? 0}');

    return buffer.toString();
  }

  /// Smart search with AI-powered results interpretation
  Future<String> performSmartSearch(String searchQuery) async {
    try {
      // 1. Use RAG service to get relevant posts
      final relevantPosts = await _ragService.retrieveRelevantPosts(
        searchQuery,
        maxResults: 20,
        context: {
          'search_mode': true,
          'user_id': _accountProvider?.currentUser?.id,
        },
      );

      if (relevantPosts.isEmpty) {
        return "I couldn't find any posts matching '$searchQuery'. Try using different keywords or exploring related categories.";
      }

      // 2. Generate AI summary and insights
      final userContext = await _getUserContext();
      final ragSummary =
          _ragService.generateContextualSummary(relevantPosts, searchQuery);

      final prompt = """
Analyze and summarize these search results for the user's query: "$searchQuery"

User Context:
$userContext

Search Results:
$ragSummary

Please provide:
1. A summary of what was found
2. Key highlights and insights from the results
3. Suggestions for related searches or exploration
4. Any patterns or trends in the results
5. Actionable recommendations based on the findings

Keep the response organized, informative, and helpful for the user's search intent.
""";

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      return response.text ??
          "Found ${relevantPosts.length} relevant posts for '$searchQuery'. Check the results for more details.";
    } catch (e) {
      print('Error in smart search: $e');
      return "I encountered an issue while searching. Please try again with different keywords.";
    }
  }

  /// Clear conversation memory and context for a specific conversation
  void clearConversationMemory(String conversationId) {
    _conversationHistory.remove(conversationId);
    _conversationContext.remove(conversationId);
    _userPreferences.remove(conversationId);
    _lastInteraction.remove(conversationId);
    print('Cleared conversation memory for conversation: $conversationId');
  }

  /// Get conversation statistics for debugging
  Map<String, dynamic> getConversationStats(String conversationId) {
    return {
      'messageCount': _conversationHistory[conversationId]?.length ?? 0,
      'preferencesCount': _userPreferences[conversationId]?.length ?? 0,
      'contextTopics': _conversationContext[conversationId]?['topics'] ?? [],
      'lastInteraction': _lastInteraction[conversationId]?.toIso8601String(),
    };
  }

  /// Get user context including location, preferences, and activity
  Future<String> _getUserContext() async {
    try {
      final contextParts = <String>[];

      // Add user information if available
      if (_accountProvider?.currentUser != null) {
        final currentUser = _accountProvider!.currentUser!;
        contextParts
            .add("User: ${currentUser.firstName} ${currentUser.lastName}");
      }

      // Add posts information if available
      if (_postsProvider?.posts.isNotEmpty == true) {
        final posts = _postsProvider!.posts;
        final recentPosts = posts.take(5);
        final postCategories = recentPosts.map((p) => p.category).toSet();
        contextParts
            .add("Recent activity categories: ${postCategories.join(', ')}");

        final totalPosts = posts.length;
        contextParts.add("Total posts: $totalPosts");
      }

      // Add available categories
      const availableCategories = [
        'news',
        'event',
        'alert',
        'military',
        'casualties',
        'explosion',
        'politics',
        'sports',
        'health',
        'traffic',
        'weather',
        'crime',
        'community',
        'disaster',
        'environment',
        'education',
        'fire',
        'other'
      ];
      contextParts
          .add("Available categories: ${availableCategories.join(', ')}");

      return contextParts.isNotEmpty
          ? contextParts.join('\n')
          : "Basic user context available";
    } catch (e) {
      print('Error getting user context: $e');
      return "User context not available";
    }
  }

  /// Get user preferences and patterns
  Future<String> _getUserPreferences() async {
    try {
      if (_postsProvider?.posts.isEmpty != false) {
        return "No activity patterns available yet.";
      }

      final posts = _postsProvider!.posts;

      // Analyze posting patterns
      final categoryFrequency = <String, int>{};
      final locationFrequency = <String, int>{};

      for (final post in posts) {
        final category = post.category;
        categoryFrequency[category] = (categoryFrequency[category] ?? 0) + 1;

        final locationAddress = post.location.address;
        if (locationAddress != null && locationAddress.isNotEmpty) {
          locationFrequency[locationAddress] =
              (locationFrequency[locationAddress] ?? 0) + 1;
        }
      }

      // Find top preferences
      final topCategories = categoryFrequency.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final topLocations = locationFrequency.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final preferences = <String>[];

      if (topCategories.isNotEmpty) {
        preferences.add(
            "Favorite categories: ${topCategories.take(3).map((e) => e.key).join(', ')}");
      }

      if (topLocations.isNotEmpty) {
        preferences.add(
            "Frequent locations: ${topLocations.take(3).map((e) => e.key).join(', ')}");
      }

      return preferences.isNotEmpty
          ? preferences.join('\n')
          : "Unable to determine specific preferences";
    } catch (e) {
      print('Error getting user preferences: $e');
      return "Unable to determine user preferences";
    }
  }

  /// Get system prompt for the AI assistant (enhanced for conversation memory and web access)
  String _getSystemPrompt() {
    return """
You are the LiveSpot AI Assistant - a smart, conversational helper with advanced memory and web access capabilities.

CORE PERSONALITY:
- You have excellent conversation memory and build upon previous discussions naturally
- You understand context changes and topic transitions smoothly
- You're knowledgeable about current events and can access web information when needed
- You use real LiveSpot data to give personalized, actionable recommendations
- You never use formatting like bold, italics, or special characters - only plain text
- You're concise but comprehensive, friendly but professional

CONVERSATION MEMORY & CONTEXT:
- ALWAYS acknowledge what you discussed before if it's relevant to the current message
- Reference the user's previous questions, interests, or stated preferences
- Build conversations naturally like a smart friend who remembers everything
- When topics change, acknowledge the shift: "Moving from restaurants to events..." 
- If they asked about restaurants yesterday and mention food today, connect those discussions
- Maintain context across long conversations - reference earlier parts when relevant
- If returning after a break, acknowledge the time gap: "Welcome back! Earlier we were discussing..."

TOPIC CHANGE HANDLING:
- Detect when the user shifts topics and transition smoothly
- Don't abruptly drop previous context - bridge topics when possible
- Example: "I see you're switching from restaurant recommendations to events. Based on your interest in Italian food, you might enjoy the Italian festival happening..."

DATA USAGE:
- Prioritize LiveSpot posts and user activity for personalized recommendations
- Use web search results for current events, news, or trending topics that need real-time info
- Combine multiple data sources for richer, more accurate responses
- Always give specific, actionable suggestions when possible
- Reference specific posts, locations, or activities from LiveSpot when available

RESPONSE GUIDELINES:
- NO bold text, italics, or special formatting - plain text only
- Be specific: mention actual places, categories, or activities from the data
- If you lack user data, suggest exploring: news, sports, community, environment, health, entertainment, business, technology
- Connect recommendations to their location or known interests from conversation history
- Keep responses focused and valuable, but show you remember the conversation flow
- When providing web-searched information, integrate it naturally with LiveSpot context

CONVERSATION CONTINUITY:
- If this is a continuation of a previous conversation, reference relevant points
- If the user seems confused or lost, offer to recap or clarify previous discussions
- Build on user preferences you've learned over time
- Remember their location preferences, activity interests, and discussion patterns

AVOID:
- Acting like each message is the start of a new conversation when you have history
- Generic responses when you have conversation memory and context
- Formatting that won't display properly in mobile messaging
- Asking multiple follow-up questions without addressing their current request
- Overly long responses that lose focus
- Ignoring topic changes or failing to acknowledge conversation flow

Your goal is to be the most helpful, intelligent assistant that remembers every conversation, learns from each interaction, and provides increasingly personalized value over time.
""";
  }

  /// Get default response when AI response is empty
  String _getDefaultResponse() {
    return "Hi! I'm your LiveSpot AI Assistant 🤖 I'm here to help you discover amazing places, "
        "get personalized recommendations, and make the most of your LiveSpot experience. "
        "Try asking me about:\n\n"
        "• Places to visit in your area\n"
        "• Restaurant recommendations\n"
        "• Events and activities\n"
        "• How to use LiveSpot features\n"
        "• Insights about your activity\n\n"
        "What would you like to explore today?";
  }

  /// Get error response when AI call fails
  String _getErrorResponse() {
    return "I'm experiencing some technical difficulties at the moment 😅 "
        "But I'm still here to help! Please try asking me again in a moment. "
        "\n\nIn the meantime, you can:\n"
        "• Explore posts from your LiveSpot community\n"
        "• Browse the map to discover nearby places\n"
        "• Check out trending locations and events\n"
        "\nI'll be back to full functionality shortly!";
  }

  /// Check if a conversation ID belongs to the AI assistant
  bool isAIConversation(String conversationId) {
    return conversationId == _aiAssistantId;
  }

  /// Generate contextual greeting based on user activity
  Future<String> generateContextualGreeting() async {
    try {
      final userContext = await _getUserContext();
      final prompt = """
Generate a friendly, personalized greeting for a user of LiveSpot based on their context:
$userContext

The greeting should:
- Be warm and welcoming
- Reference their activity if they have any (posts, favorite categories, locations)
- Offer specific assistance based on their interests
- Be conversational and engaging
- Include a relevant question or suggestion to start the conversation
- Keep it to 2-3 sentences maximum

If they have no activity yet, welcome them and suggest how to get started.
""";

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      return response.text ??
          "Welcome to LiveSpot! 👋 I'm your AI Assistant, ready to help you discover amazing places and connect with your community. What would you like to explore today?";
    } catch (e) {
      print('Error generating contextual greeting: $e');
      return "Hi there! 👋 I'm your LiveSpot AI Assistant, ready to help you explore, discover, and connect. What can I help you with today?";
    }
  }

  /// Handle location-specific queries with real data context
  Future<String> handleLocationQuery(String query,
      {String? specificLocation}) async {
    try {
      final userContext = await _getUserContext();
      final postsContext = await _getRecentPostsContext();

      final prompt = """
The user is asking about locations/places: "$query"
${specificLocation != null ? "Specific location mentioned: $specificLocation" : ""}

User Context:
$userContext

Recent Posts Context (for reference):
$postsContext

Please provide a helpful response that:
1. Acknowledges their location query
2. Uses their posting history and preferences to inform suggestions
3. Asks for specific location if not provided
4. Suggests relevant categories based on their interests
5. Provides actionable recommendations
6. Encourages them to explore and post about new places

Be specific, helpful, and engaging in your response.
""";

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      return response.text ??
          "I'd love to help you discover amazing places! Could you tell me more about what you're looking for and which area you'd like to explore?";
    } catch (e) {
      print('Error handling location query: $e');
      return "I'd be happy to help you find great places! Could you share more details about what you're looking for and your preferred area?";
    }
  }

  /// Get recent posts context for better recommendations
  Future<String> _getRecentPostsContext() async {
    try {
      if (_postsProvider?.posts.isEmpty != false) {
        return "No recent posts available for context.";
      }

      final posts = _postsProvider!.posts.take(10);
      final context = <String>[];

      for (final post in posts) {
        final location = post.location.address ?? "Unknown location";
        final category = post.category;
        final summary = post.content.length > 50
            ? "${post.content.substring(0, 50)}..."
            : post.content;
        context
            .add("Location: $location, Category: $category, Content: $summary");
      }

      return context.isNotEmpty
          ? context.join('\n')
          : "No detailed post context available.";
    } catch (e) {
      print('Error getting recent posts context: $e');
      return "Unable to access recent posts context.";
    }
  }
}
