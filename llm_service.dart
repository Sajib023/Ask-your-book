import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'vector_store.dart';

class LlmService {
  static const String _groqApiUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _openRouterApiUrl = 'https://openrouter.ai/api/v1/chat/completions';
  
  String? _apiKey;
  String _apiProvider = 'groq'; // 'groq' or 'openrouter'
  String _model = 'llama3-8b-8192'; // Default Groq model

  final VectorStore _vectorStore = VectorStore();

  /// Initialize the LLM service
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString('llm_api_key');
    _apiProvider = prefs.getString('llm_provider') ?? 'groq';
    _model = prefs.getString('llm_model') ?? 'llama3-8b-8192';
    
    await _vectorStore.initialize();
  }

  /// Set API configuration
  Future<void> setApiConfig(String apiKey, String provider, String model) async {
    _apiKey = apiKey;
    _apiProvider = provider;
    _model = model;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('llm_api_key', apiKey);
    await prefs.setString('llm_provider', provider);
    await prefs.setString('llm_model', model);
  }

  /// Generate response using RAG
  Future<String> generateResponse(String query, {List<String>? conversationHistory}) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('API key not configured. Please set up your API key in settings.');
    }

    try {
      // Search for relevant chunks
      final searchResults = await _vectorStore.searchSimilar(query, limit: 5, threshold: 0.1);
      
      // Build context from search results
      final context = _buildContext(searchResults);
      
      // Generate prompt
      final prompt = _buildPrompt(query, context, conversationHistory);
      
      // Get response from LLM
      final response = await _callLlmApi(prompt);
      
      return response;
    } catch (e) {
      print('Error generating response: $e');
      rethrow;
    }
  }

  /// Build context from search results
  String _buildContext(List<SearchResult> searchResults) {
    if (searchResults.isEmpty) {
      return 'No relevant information found in the documents.';
    }

    final contextParts = <String>[];
    
    for (int i = 0; i < searchResults.length; i++) {
      final result = searchResults[i];
      final relevanceScore = (result.similarity * 100).toStringAsFixed(1);
      
      contextParts.add('''
Document: ${result.document.name}
Relevance: ${relevanceScore}%
Content: ${result.chunk.content}
''');
    }
    
    return contextParts.join('\n---\n');
  }

  /// Build the complete prompt for the LLM
  String _buildPrompt(String query, String context, List<String>? conversationHistory) {
    final systemPrompt = '''You are a helpful AI assistant that answers questions based on the provided document context. 

Instructions:
- Answer the user's question using ONLY the information provided in the context below
- If the context doesn't contain enough information to answer the question, say so clearly
- Be concise but thorough in your response
- Cite specific parts of the documents when relevant
- If multiple documents contain relevant information, synthesize the information appropriately

Context from documents:
$context''';

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    // Add conversation history if provided
    if (conversationHistory != null && conversationHistory.isNotEmpty) {
      for (int i = 0; i < conversationHistory.length; i++) {
        final role = i % 2 == 0 ? 'user' : 'assistant';
        messages.add({'role': role, 'content': conversationHistory[i]});
      }
    }

    // Add current user query
    messages.add({'role': 'user', 'content': query});

    return jsonEncode({'messages': messages});
  }

  /// Call the LLM API
  Future<String> _callLlmApi(String prompt) async {
    final String apiUrl;
    final Map<String, String> headers;
    final Map<String, dynamic> requestBody;

    switch (_apiProvider) {
      case 'groq':
        apiUrl = _groqApiUrl;
        headers = {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        };
        requestBody = {
          'model': _model,
          'messages': jsonDecode(prompt)['messages'],
          'temperature': 0.7,
          'max_tokens': 1024,
          'stream': false,
        };
        break;
      
      case 'openrouter':
        apiUrl = _openRouterApiUrl;
        headers = {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://rag-ai-reader.app',
          'X-Title': 'RAG AI Reader',
        };
        requestBody = {
          'model': _model,
          'messages': jsonDecode(prompt)['messages'],
          'temperature': 0.7,
          'max_tokens': 1024,
        };
        break;
      
      default:
        throw Exception('Unsupported API provider: $_apiProvider');
    }

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: headers,
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'] as String;
      return content.trim();
    } else {
      final errorData = jsonDecode(response.body);
      final errorMessage = errorData['error']['message'] ?? 'Unknown error';
      throw Exception('LLM API Error (${response.statusCode}): $errorMessage');
    }
  }

  /// Get available models for the current provider
  List<String> getAvailableModels() {
    switch (_apiProvider) {
      case 'groq':
        return [
          'llama3-8b-8192',
          'llama3-70b-8192',
          'mixtral-8x7b-32768',
          'gemma-7b-it',
        ];
      case 'openrouter':
        return [
          'openai/gpt-3.5-turbo',
          'openai/gpt-4',
          'anthropic/claude-3-haiku',
          'meta-llama/llama-3-8b-instruct',
          'mistralai/mixtral-8x7b-instruct',
        ];
      default:
        return [];
    }
  }

  /// Test API connection
  Future<bool> testApiConnection() async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      return false;
    }

    try {
      final testPrompt = jsonEncode({
        'messages': [
          {'role': 'user', 'content': 'Hello, this is a test message.'}
        ]
      });

      await _callLlmApi(testPrompt);
      return true;
    } catch (e) {
      print('API connection test failed: $e');
      return false;
    }
  }

  /// Get simple response without RAG (for general queries)
  Future<String> getSimpleResponse(String query, {List<String>? conversationHistory}) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('API key not configured. Please set up your API key in settings.');
    }

    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content': 'You are a helpful AI assistant. Answer the user\'s questions clearly and concisely.'
      },
    ];

    // Add conversation history if provided
    if (conversationHistory != null && conversationHistory.isNotEmpty) {
      for (int i = 0; i < conversationHistory.length; i++) {
        final role = i % 2 == 0 ? 'user' : 'assistant';
        messages.add({'role': role, 'content': conversationHistory[i]});
      }
    }

    messages.add({'role': 'user', 'content': query});

    final prompt = jsonEncode({'messages': messages});
    return await _callLlmApi(prompt);
  }

  /// Check if API is configured
  bool get isApiConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  /// Get current configuration
  Map<String, String> get currentConfig => {
    'provider': _apiProvider,
    'model': _model,
    'hasApiKey': isApiConfigured.toString(),
  };
}
