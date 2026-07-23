enum GeneralActionScope {
  client,
  knowledgeGap;

  String get label {
    switch (this) {
      case GeneralActionScope.client:
        return 'Client';
      case GeneralActionScope.knowledgeGap:
        return 'Knowledge gap';
    }
  }
}

class GeneralActionItem {
  const GeneralActionItem({
    required this.id,
    required this.title,
    required this.scope,
    required this.createdAt,
    this.client,
    this.completedAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final GeneralActionScope scope;
  final DateTime createdAt;
  final String? client;
  final DateTime? completedAt;
  final DateTime? updatedAt;

  bool get isCompleted => completedAt != null;

  GeneralActionItem copyWith({
    String? id,
    String? title,
    GeneralActionScope? scope,
    DateTime? createdAt,
    String? client,
    bool clearClient = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? updatedAt,
  }) {
    return GeneralActionItem(
      id: id ?? this.id,
      title: title ?? this.title,
      scope: scope ?? this.scope,
      createdAt: createdAt ?? this.createdAt,
      client: clearClient ? null : client ?? this.client,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'scope': scope.name,
      'createdAt': createdAt.toIso8601String(),
      'client': client,
      'completedAt': completedAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory GeneralActionItem.fromJson(Map<String, dynamic> json) {
    final scopeName = json['scope'] as String?;
    final scope = GeneralActionScope.values.firstWhere(
      (item) => item.name == scopeName,
      orElse: () => GeneralActionScope.client,
    );
    final createdAt =
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now();

    return GeneralActionItem(
      id:
          json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? '',
      scope: scope,
      createdAt: createdAt,
      client: json['client'] as String?,
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}
