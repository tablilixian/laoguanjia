class PetMemory {
  final String id;
  final String petId;
  final String memoryType;
  final String title;
  final String description;
  final String? emotion;
  final List<String> participants;
  final int importance;
  final bool isSummarized;
  final String? interactionId;
  final DateTime occurredAt;
  final DateTime createdAt;

  PetMemory({
    required this.id,
    required this.petId,
    required this.memoryType,
    required this.title,
    required this.description,
    this.emotion,
    required this.participants,
    required this.importance,
    required this.isSummarized,
    this.interactionId,
    required this.occurredAt,
    required this.createdAt,
  });

  factory PetMemory.fromJson(Map<String, dynamic> json) {
    return PetMemory(
      id: json['id'],
      petId: json['pet_id'],
      memoryType: json['memory_type'],
      title: json['title'],
      description: json['description'],
      emotion: json['emotion'],
      participants: List<String>.from(json['participants'] ?? []),
      importance: json['importance'] ?? 3,
      isSummarized: json['is_summarized'] ?? false,
      interactionId: json['interaction_id'],
      occurredAt: DateTime.parse(json['occurred_at']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pet_id': petId,
      'memory_type': memoryType,
      'title': title,
      'description': description,
      'emotion': emotion,
      'participants': participants,
      'importance': importance,
      'is_summarized': isSummarized,
      'interaction_id': interactionId,
      'occurred_at': occurredAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  PetMemory copyWith({
    String? id,
    String? petId,
    String? memoryType,
    String? title,
    String? description,
    String? emotion,
    List<String>? participants,
    int? importance,
    bool? isSummarized,
    String? interactionId,
    DateTime? occurredAt,
    DateTime? createdAt,
  }) {
    return PetMemory(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      memoryType: memoryType ?? this.memoryType,
      title: title ?? this.title,
      description: description ?? this.description,
      emotion: emotion ?? this.emotion,
      participants: participants ?? this.participants,
      importance: importance ?? this.importance,
      isSummarized: isSummarized ?? this.isSummarized,
      interactionId: interactionId ?? this.interactionId,
      occurredAt: occurredAt ?? this.occurredAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static const List<String> memoryTypes = [
    'conversation',
    'milestone',
    'emotion',
    'fact',
    'interaction',
  ];

  static const List<String> emotions = [
    'joy',
    'sadness',
    'fear',
    'surprise',
    'anger',
    'disgust',
    'neutral',
  ];
}
