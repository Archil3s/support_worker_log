enum PersonalLogCategory { gym, bodyWeight, health, note, goal }

extension PersonalLogCategoryLabel on PersonalLogCategory {
  String get label {
    switch (this) {
      case PersonalLogCategory.gym:
        return 'Gym';
      case PersonalLogCategory.bodyWeight:
        return 'Body Weight';
      case PersonalLogCategory.health:
        return 'Health';
      case PersonalLogCategory.note:
        return 'Note';
      case PersonalLogCategory.goal:
        return 'Goal';
    }
  }
}

PersonalLogCategory personalLogCategoryFromName(String? value) {
  return PersonalLogCategory.values.firstWhere(
    (category) => category.name == value,
    orElse: () => PersonalLogCategory.note,
  );
}

class PersonalLogEntry {
  const PersonalLogEntry({
    required this.id,
    required this.category,
    required this.date,
    required this.title,
    required this.notes,
    this.metric = '',
  });

  final String id;
  final PersonalLogCategory category;
  final DateTime date;
  final String title;
  final String notes;
  final String metric;

  PersonalLogEntry copyWith({
    String? id,
    PersonalLogCategory? category,
    DateTime? date,
    String? title,
    String? notes,
    String? metric,
  }) {
    return PersonalLogEntry(
      id: id ?? this.id,
      category: category ?? this.category,
      date: date ?? this.date,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      metric: metric ?? this.metric,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category.name,
      'date': date.toIso8601String(),
      'title': title,
      'notes': notes,
      'metric': metric,
    };
  }

  factory PersonalLogEntry.fromJson(Map<String, dynamic> json) {
    return PersonalLogEntry(
      id:
          json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      category: personalLogCategoryFromName(json['category'] as String?),
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      title: json['title'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      metric: json['metric'] as String? ?? '',
    );
  }
}
