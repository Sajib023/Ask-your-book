import 'dart:convert';
import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/document_model.dart';
import 'embedding_service.dart';

class VectorStore {
  static const String _dbName = 'rag_vector_store.db';
  static const int _dbVersion = 1;
  
  Database? _database;
  final EmbeddingService _embeddingService = EmbeddingService();

  /// Initialize the vector store
  Future<void> initialize() async {
    await _initDatabase();
    await _embeddingService.initialize();
  }

  /// Initialize the database
  Future<void> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    _database = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createTables,
      onUpgrade: _upgradeTables,
    );
  }

  /// Create database tables
  Future<void> _createTables(Database db, int version) async {
    // Documents table
    await db.execute('''
      CREATE TABLE documents (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        path TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    // Document chunks table with embeddings
    await db.execute('''
      CREATE TABLE document_chunks (
        id TEXT PRIMARY KEY,
        document_id TEXT NOT NULL,
        content TEXT NOT NULL,
        start_index INTEGER NOT NULL,
        end_index INTEGER NOT NULL,
        embedding TEXT NOT NULL,
        FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_chunks_document_id ON document_chunks(document_id)');
    await db.execute('CREATE INDEX idx_documents_created_at ON documents(created_at)');
  }

  /// Upgrade database tables
  Future<void> _upgradeTables(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here if needed
    if (oldVersion < newVersion) {
      // For now, just recreate tables
      await db.execute('DROP TABLE IF EXISTS document_chunks');
      await db.execute('DROP TABLE IF EXISTS documents');
      await _createTables(db, newVersion);
    }
  }

  /// Store a document with its chunks and embeddings
  Future<void> storeDocument(DocumentModel document) async {
    if (_database == null) await initialize();

    await _database!.transaction((txn) async {
      // Insert document
      await txn.insert(
        'documents',
        {
          'id': document.id,
          'name': document.name,
          'path': document.path,
          'content': document.content,
          'created_at': document.createdAt.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Insert chunks with embeddings
      for (final chunk in document.chunks) {
        await txn.insert(
          'document_chunks',
          {
            'id': chunk.id,
            'document_id': chunk.documentId,
            'content': chunk.content,
            'start_index': chunk.startIndex,
            'end_index': chunk.endIndex,
            'embedding': jsonEncode(chunk.embedding),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Generate and store embeddings for document chunks
  Future<DocumentModel> generateEmbeddings(DocumentModel document) async {
    final chunksWithEmbeddings = <DocumentChunk>[];

    for (final chunk in document.chunks) {
      print('Generating embedding for chunk: ${chunk.id}');
      final embedding = await _embeddingService.getEmbedding(chunk.content);
      
      final chunkWithEmbedding = DocumentChunk(
        id: chunk.id,
        documentId: chunk.documentId,
        content: chunk.content,
        startIndex: chunk.startIndex,
        endIndex: chunk.endIndex,
        embedding: embedding,
      );
      
      chunksWithEmbeddings.add(chunkWithEmbedding);
    }

    return document.copyWith(chunks: chunksWithEmbeddings);
  }

  /// Search for similar text chunks
  Future<List<SearchResult>> searchSimilar(String query, {int limit = 5, double threshold = 0.1}) async {
    if (_database == null) await initialize();

    // Get query embedding
    final queryEmbedding = await _embeddingService.getEmbedding(query);

    // Get all chunks from database
    final chunksData = await _database!.query('document_chunks');
    final results = <SearchResult>[];

    for (final chunkData in chunksData) {
      final chunkEmbedding = List<double>.from(
        jsonDecode(chunkData['embedding'] as String),
      );

      // Calculate similarity
      final similarity = _embeddingService.cosineSimilarity(queryEmbedding, chunkEmbedding);

      if (similarity >= threshold) {
        // Get document info
        final docData = await _database!.query(
          'documents',
          where: 'id = ?',
          whereArgs: [chunkData['document_id']],
          limit: 1,
        );

        if (docData.isNotEmpty) {
          results.add(SearchResult(
            chunk: DocumentChunk.fromMap(chunkData),
            document: DocumentModel.fromMap(docData.first),
            similarity: similarity,
          ));
        }
      }
    }

    // Sort by similarity (descending) and limit results
    results.sort((a, b) => b.similarity.compareTo(a.similarity));
    return results.take(limit).toList();
  }

  /// Get all documents
  Future<List<DocumentModel>> getAllDocuments() async {
    if (_database == null) await initialize();

    final documentsData = await _database!.query(
      'documents',
      orderBy: 'created_at DESC',
    );

    final documents = <DocumentModel>[];
    for (final docData in documentsData) {
      final chunksData = await _database!.query(
        'document_chunks',
        where: 'document_id = ?',
        whereArgs: [docData['id']],
      );

      final chunks = chunksData.map((chunk) => DocumentChunk.fromMap(chunk)).toList();
      final document = DocumentModel.fromMap(docData).copyWith(chunks: chunks);
      documents.add(document);
    }

    return documents;
  }

  /// Get document by ID
  Future<DocumentModel?> getDocument(String documentId) async {
    if (_database == null) await initialize();

    final documentsData = await _database!.query(
      'documents',
      where: 'id = ?',
      whereArgs: [documentId],
      limit: 1,
    );

    if (documentsData.isEmpty) return null;

    final chunksData = await _database!.query(
      'document_chunks',
      where: 'document_id = ?',
      whereArgs: [documentId],
    );

    final chunks = chunksData.map((chunk) => DocumentChunk.fromMap(chunk)).toList();
    return DocumentModel.fromMap(documentsData.first).copyWith(chunks: chunks);
  }

  /// Delete document and its chunks
  Future<void> deleteDocument(String documentId) async {
    if (_database == null) await initialize();

    await _database!.transaction((txn) async {
      await txn.delete(
        'document_chunks',
        where: 'document_id = ?',
        whereArgs: [documentId],
      );
      
      await txn.delete(
        'documents',
        where: 'id = ?',
        whereArgs: [documentId],
      );
    });
  }

  /// Get document count
  Future<int> getDocumentCount() async {
    if (_database == null) await initialize();

    final result = await _database!.rawQuery('SELECT COUNT(*) as count FROM documents');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get chunk count
  Future<int> getChunkCount() async {
    if (_database == null) await initialize();

    final result = await _database!.rawQuery('SELECT COUNT(*) as count FROM document_chunks');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Clear all data
  Future<void> clearAll() async {
    if (_database == null) await initialize();

    await _database!.transaction((txn) async {
      await txn.delete('document_chunks');
      await txn.delete('documents');
    });
  }

  /// Close the database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}

/// Search result class
class SearchResult {
  final DocumentChunk chunk;
  final DocumentModel document;
  final double similarity;

  SearchResult({
    required this.chunk,
    required this.document,
    required this.similarity,
  });

  @override
  String toString() {
    return 'SearchResult(similarity: ${similarity.toStringAsFixed(3)}, document: ${document.name}, chunk: ${chunk.content.substring(0, min(50, chunk.content.length))}...)';
  }
}
