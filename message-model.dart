import 'dart:convert';

enum MessageType { user, assistant, system }

class MessageModel {
  final String id;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final List<String>? sources;
  final bool isLoading;

  MessageModel({
    required this.id,
    required this.content,
    required this.type,
    required this.timestamp,
    this.sources,
    this.isLoading = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'type': type.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'sources': sources,
      'is_loading': isLoading,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] ?? '',
      content: map['content'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MessageType.user,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      sources: (map['sources'] as List<dynamic>?)?.cast<String>(),
      isLoading: map['is_loading'] ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory MessageModel.fromJson(String source) =>
      MessageModel.fromMap(json.decode(source));

  MessageModel copyWith({
    String? id,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    List<String>? sources,
    bool? isLoading,
  }) {
    return MessageModel(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      sources: sources ?? this.sources,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  String toString() {
    return 'MessageModel(id: $id, type: $type, content: ${content.length > 100 ? content.substring(0, 100) + '...' : content})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageModel && other.id == id;
  }

  @override
  int get hashCode {
    return id.hashCode;
  }
}
