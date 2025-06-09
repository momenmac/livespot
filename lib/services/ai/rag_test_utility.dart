import 'package:flutter_application_2/services/ai/gemini_ai_service.dart';
import 'package:flutter_application_2/services/ai/rag_integration_service.dart';
import 'package:flutter_application_2/providers/posts_provider.dart';
import 'package:flutter_application_2/services/location/location_cache_service.dart';

/// Utility class to test and demonstrate the enhanced RAG integration
class RAGTestUtility {
  static final GeminiAIService _aiService = GeminiAIService();
  static final RAGIntegrationService _ragService = RAGIntegrationService();

  /// Initialize services for testing
  static void initializeServices({
    PostsProvider? postsProvider,
    LocationCacheService? locationCacheService,
  }) {
    _aiService.initialize(
      postsProvider: postsProvider,
      locationCacheService: locationCacheService,
    );
    
    _ragService.initialize(
      postsProvider: postsProvider,
      locationCacheService: locationCacheService,
    );
  }

  /// Test basic RAG retrieval functionality
  static Future<Map<String, dynamic>> testRAGRetrieval(String query) async {
    try {
      print('🔍 Testing RAG retrieval for query: "$query"');
      
      // Test direct RAG service
      final relevantPosts = await _ragService.retrieveRelevantPosts(
        query,
        maxResults: 5,
        context: {'test_mode': true},
      );
      
      final summary = _ragService.generateContextualSummary(relevantPosts, query);
      
      return {
        'success': true,
        'posts_found': relevantPosts.length,
        'posts': relevantPosts.map((p) => {
          'id': p.id,
          'title': p.title,
          'content': p.content.length > 100 ? '${p.content.substring(0, 100)}...' : p.content,
          'category': p.category,
          'location': p.location.address ?? 'Unknown',
          'votes': '${p.upvotes} up, ${p.downvotes} down',
          'happening': p.isHappening == true,
        }).toList(),
        'summary': summary,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Test enhanced AI response generation
  static Future<Map<String, dynamic>> testEnhancedAIResponse(String query) async {
    try {
      print('🤖 Testing enhanced AI response for query: "$query"');
      
      final response = await _aiService.generateResponse(query);
      
      return {
        'success': true,
        'response': response,
        'response_length': response.length,
        'contains_specific_data': _containsSpecificData(response),
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Test smart search functionality
  static Future<Map<String, dynamic>> testSmartSearch(String searchQuery) async {
    try {
      print('🔎 Testing smart search for query: "$searchQuery"');
      
      final response = await _aiService.performSmartSearch(searchQuery);
      
      return {
        'success': true,
        'search_response': response,
        'response_length': response.length,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Test enhanced recommendations
  static Future<Map<String, dynamic>> testEnhancedRecommendations({String? specificQuery}) async {
    try {
      print('💡 Testing enhanced recommendations${specificQuery != null ? ' for: "$specificQuery"' : ''}');
      
      final response = await _aiService.getEnhancedRecommendations(
        specificQuery: specificQuery,
      );
      
      return {
        'success': true,
        'recommendations': response,
        'response_length': response.length,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Test trending insights
  static Future<Map<String, dynamic>> testTrendingInsights() async {
    try {
      print('📈 Testing trending insights');
      
      final insights = await _ragService.getTrendingInsights();
      
      return {
        'success': insights['error'] == null,
        'insights': insights,
        'has_trending_categories': insights['trending_categories'] != null,
        'has_trending_locations': insights['trending_locations'] != null,
        'total_recent_posts': insights['total_recent_posts'] ?? 0,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Run comprehensive test suite
  static Future<Map<String, dynamic>> runComprehensiveTests() async {
    print('\n🚀 Starting comprehensive RAG integration tests...\n');
    
    final testResults = <String, dynamic>{};
    
    // Test queries
    final testQueries = [
      'events near me',
      'restaurants and food',
      'what\'s happening today',
      'sports events',
      'community activities',
      'traffic updates',
    ];
    
    // Test RAG retrieval
    for (final query in testQueries.take(3)) {
      final key = 'rag_retrieval_${query.replaceAll(' ', '_')}';
      testResults[key] = await testRAGRetrieval(query);
      await Future.delayed(const Duration(milliseconds: 500)); // Rate limiting
    }
    
    // Test AI responses
    for (final query in testQueries.take(2)) {
      final key = 'ai_response_${query.replaceAll(' ', '_')}';
      testResults[key] = await testEnhancedAIResponse(query);
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    // Test smart search
    testResults['smart_search'] = await testSmartSearch('food restaurants');
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Test recommendations
    testResults['enhanced_recommendations'] = await testEnhancedRecommendations();
    await Future.delayed(const Duration(milliseconds: 500));
    
    testResults['specific_recommendations'] = await testEnhancedRecommendations(
      specificQuery: 'fun activities for weekend',
    );
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Test trending insights
    testResults['trending_insights'] = await testTrendingInsights();
    
    // Calculate success rate
    final totalTests = testResults.length;
    final successfulTests = testResults.values.where((result) => result['success'] == true).length;
    final successRate = (successfulTests / totalTests * 100).toStringAsFixed(1);
    
    testResults['_summary'] = {
      'total_tests': totalTests,
      'successful_tests': successfulTests,
      'success_rate': '$successRate%',
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    print('\n✅ Test suite completed!');
    print('📊 Success rate: $successRate% ($successfulTests/$totalTests)');
    
    return testResults;
  }

  /// Check if response contains specific data (not just generic responses)
  static bool _containsSpecificData(String response) {
    final specificIndicators = [
      'location',
      'event',
      'category',
      'post',
      'votes',
      'happening',
      'near',
      'address',
      'specific',
      'found',
    ];
    
    final lowerResponse = response.toLowerCase();
    return specificIndicators.any((indicator) => lowerResponse.contains(indicator));
  }

  /// Print detailed test results
  static void printTestResults(Map<String, dynamic> results) {
    print('\n📋 Detailed Test Results:\n');
    
    for (final entry in results.entries) {
      if (entry.key.startsWith('_')) continue; // Skip summary
      
      print('🔸 ${entry.key}:');
      final result = entry.value as Map<String, dynamic>;
      
      if (result['success'] == true) {
        print('  ✅ Success');
        if (result.containsKey('posts_found')) {
          print('  📊 Posts found: ${result['posts_found']}');
        }
        if (result.containsKey('response_length')) {
          print('  📝 Response length: ${result['response_length']} chars');
        }
        if (result.containsKey('contains_specific_data')) {
          print('  🎯 Contains specific data: ${result['contains_specific_data']}');
        }
      } else {
        print('  ❌ Failed: ${result['error']}');
      }
      print('');
    }
    
    // Print summary
    if (results.containsKey('_summary')) {
      final summary = results['_summary'] as Map<String, dynamic>;
      print('📈 Summary:');
      print('  Total tests: ${summary['total_tests']}');
      print('  Successful: ${summary['successful_tests']}');
      print('  Success rate: ${summary['success_rate']}');
      print('  Completed at: ${summary['timestamp']}');
    }
  }
}

/// Example usage in a widget or test
class RAGDemoHelper {
  /// Demo method showing how to use the enhanced AI in your app
  static Future<void> demonstrateEnhancedAI() async {
    // This would typically be called in your app's initialization
    print('🎯 Demonstrating Enhanced RAG AI Integration\n');
    
    // Example 1: Ask for recommendations
    print('Example 1: Getting personalized recommendations');
    final aiService = GeminiAIService();
    final recommendations = await aiService.getEnhancedRecommendations();
    print('🤖 AI Response: $recommendations\n');
    
    // Example 2: Smart search
    print('Example 2: Performing smart search');
    final searchResults = await aiService.performSmartSearch('best restaurants near me');
    print('🔍 Search Results: $searchResults\n');
    
    // Example 3: Enhanced conversation
    print('Example 3: Enhanced conversation with context');
    final response = await aiService.generateResponse(
      'What events are happening this weekend?',
      previousMessages: ['Hello!', 'Hi! How can I help you today?'],
    );
    print('💬 AI Response: $response\n');
  }
}
