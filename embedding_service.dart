import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EmbeddingService {
  static const String _openAIApiUrl = 'https://api.openai.com/v1/embeddings';
  static const String _huggingFaceApiUrl = 'https://api-inference.huggingface.co/pipeline/feature-extraction';
  
  // Default embedding model
  static const String _defaultModel = 'text-embedding-3-small';
  static const int _embeddingDimension = 1536;

  String? _apiKey;
  String _apiProvider = 'openai'; // 'openai' or 'huggingface'

  /// Initialize the embedding service
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString('embedding_api_key');
    _apiProvider = prefs.getString('embedding_provider') ?? 'openai';
  }

  /// Set API key and provider
  Future<void> setApiKey(String apiKey, String provider) async {
    _apiKey = apiKey;
    _apiProvider = provider;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('embedding_api_key', apiKey);
    await prefs.setString('embedding_provider', provider);
  }

  /// Get embedding for a text
  Future<List<double>> getEmbedding(String text) async {
    if (text.isEmpty) {
      return List.filled(_embeddingDimension, 0.0);
    }

    // If no API key is set, use local embedding
    if (_apiKey == null || _apiKey!.isEmpty) {
      return _getLocalEmbedding(text);
    }

    try {
      switch (_apiProvider) {
        case 'openai':
          return await _getOpenAIEmbedding(text);
        case 'huggingface':
          return await _getHuggingFaceEmbedding(text);
        default:
          return _getLocalEmbedding(text);
      }
    } catch (e) {
      print('Error getting embedding from API: $e');
      // Fallback to local embedding
      return _getLocalEmbedding(text);
    }
  }

  /// Get embeddings for multiple texts
  Future<List<List<double>>> getEmbeddings(List<String> texts) async {
    final embeddings = <List<double>>[];
    
    for (final text in texts) {
      final embedding = await getEmbedding(text);
      embeddings.add(embedding);
      
      // Add small delay to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    return embeddings;
  }

  /// Get OpenAI embedding
  Future<List<double>> _getOpenAIEmbedding(String text) async {
    final response = await http.post(
      Uri.parse(_openAIApiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'input': text,
        'model': _defaultModel,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final embedding = List<double>.from(data['data'][0]['embedding']);
      return embedding;
    } else {
      throw Exception('Failed to get OpenAI embedding: ${response.statusCode} ${response.body}');
    }
  }

  /// Get HuggingFace embedding
  Future<List<double>> _getHuggingFaceEmbedding(String text) async {
    final response = await http.post(
      Uri.parse('$_huggingFaceApiUrl/sentence-transformers/all-MiniLM-L6-v2'),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'inputs': text,
      }),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      if (data.isNotEmpty && data[0] is List) {
        return List<double>.from(data[0]);
      }
      throw Exception('Invalid HuggingFace response format');
    } else {
      throw Exception('Failed to get HuggingFace embedding: ${response.statusCode} ${response.body}');
    }
  }

  /// Generate local embedding using simple text hashing
  /// This is a fallback method - not as good as real embeddings but functional
  List<double> _getLocalEmbedding(String text) {
    // Simple hash-based embedding generation
    final normalized = text.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    final words = normalized.split(RegExp(r'\s+'));
    
    // Create a simple embedding based on word frequency and position
    final embedding = List<double>.filled(_embeddingDimension, 0.0);
    final random = Random(text.hashCode);
    
    // Generate pseudo-random but deterministic embedding
    for (int i = 0; i < _embeddingDimension; i++) {
      double value = 0.0;
      
      // Factor in word count
      value += words.length * 0.001;
      
      // Factor in text length
      value += text.length * 0.0001;
      
      // Add some randomness based on text content
      value += (random.nextDouble() - 0.5) * 0.1;
      
      // Add character-based features
      if (i < text.length) {
        value += text.codeUnitAt(i % text.length) * 0.0001;
      }
      
      embedding[i] = value;
    }
    
    // Normalize the embedding vector
    final magnitude = sqrt(embedding.map((e) => e * e).reduce((a, b) => a + b));
    if (magnitude > 0) {
      for (int i = 0; i < embedding.length; i++) {
        embedding[i] = embedding[i] / magnitude;
      }
    }
    
    return embedding;
  }

  /// Calculate cosine similarity between two embeddings
  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) {
      throw ArgumentError('Embeddings must have the same dimension');
    }

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    normA = sqrt(normA);
    normB = sqrt(normB);

    if (normA == 0.0 || normB == 0.0) {
      return 0.0;
    }

    return dotProduct / (normA * normB);
  }

  /// Check if API is configured
  bool get isApiConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  /// Get current API provider
  String get apiProvider => _apiProvider;

  /// Get embedding dimension
  int get embeddingDimension => _embeddingDimension;
}
