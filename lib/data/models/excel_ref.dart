class ExcelRef {
  final int? id;
  final String name;
  final String filePath;
  final DateTime createdAt;

  ExcelRef({
    this.id,
    required this.name,
    required this.filePath,
    required this.createdAt,
  });

  ExcelRef copyWith({
    int? id,
    String? name,
    String? filePath,
    DateTime? createdAt,
  }) {
    return ExcelRef(
      id: id ?? this.id,
      name: name ?? this.name,
      filePath: filePath ?? this.filePath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'file_path': filePath,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ExcelRef.fromMap(Map<String, dynamic> map) {
    return ExcelRef(
      id: map['id'] as int?,
      name: (map['name'] ?? '') as String,
      filePath: (map['file_path'] ?? '') as String,
      createdAt: DateTime.parse((map['created_at'] ?? DateTime.now().toIso8601String()) as String),
    );
  }
}
