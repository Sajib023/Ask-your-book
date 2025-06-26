import 'dart:convert';

class DocumentModel {
  final String id;
  final String name;
  final String path;
  final String content;
  final DateTime createdAt;
  final List<DocumentChunk> chunks;

  DocumentModel({
    required this.id,
    required this.name,
    required this.path,
    required this.content,
    required this.createdAt,
    this.chunks = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'content': content,
      'created_at': createdAt.millisecondsSinceEpoch,
      'chunks': chunks.map((chunk) => chunk.toMap()).toList(),
    };
  }

  factory DocumentModel.fromMap(Map<String, dynamic> map) {
    return DocumentModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      path: map['path'] ?? '',
      content: map['content'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] ?? 0),
      chunks: (map['chunks'] as List<dynamic>?)
              ?.map((chunk) => DocumentChunk.fromMap(chunk))
              .toList() ??
          [],
    );
  }

  String toJson() => json.encode(toMap());

  factory DocumentModel.fromJson(String source) =>
      DocumentModel.fromMap(json.decode(source));

  DocumentModel copyWith({
    String? id,
    String? name,
    String? path,
    String? content,
    DateTime? createdAt,
    List<DocumentChunk>? chunks,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      chunks: chunks ?? this.chunks,
    );
  }

  @override
  String toString() {
    return 'DocumentModel(id: $id, name: $name, path: $path, createdAt: $createdAt, chunks: ${chunks.length})';
  }
}

class DocumentChunk {
  final String id;
  final String documentId;
  final String content;
  final int startIndex;
  final int endIndex;
  final List<double> embedding;

  DocumentChunk({
    required this.id,
    required this.documentId,
    required this.content,
    required this.startIndex,
    required this.endIndex,
    this.embedding = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'document_id': documentId,
      'content': content,
      'start_index': startIndex,
      'end_index': endIndex,
      'embedding': embedding,
    };
  }

  factory DocumentChunk.fromMap(Map<String, dynamic> map) {
    return DocumentChunk(
      id: map['id'] ?? '',
      documentId: map['document_id'] ?? '',
      content: map['content'] ?? '',
      startIndex: map['start_index']?.toInt() ?? 0,
      endIndex: map['end_index']?.toInt() ?? 0,
      embedding: (map['embedding'] as List<dynamic>?)
              ?.map((e) => e.toDouble())
              .toList() ??
          [],
    );
  }

  String toJson() => json.encode(toMap());

  factory DocumentChunk.fromJson(String source) =>
      DocumentChunk.fromMap(json.decode(source));

  @override
  String toString() {
    return 'DocumentChunk(id: $id, documentId: $documentId, content: ${content.substring(0, content.length > 50 ? 50 : content.length)}...)';
  }
}
