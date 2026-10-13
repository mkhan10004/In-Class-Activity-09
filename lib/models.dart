class Folder {
  const Folder({this.id, required this.name, required this.createdAt});

  final int? id;
  final String name;
  final String createdAt;

  String get displayName => name.trim();

  Folder copyWith({int? id, String? name, String? createdAt}) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {'id': id, 'name': displayName, 'created_at': createdAt};
  }

  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'] as int?,
      name: (map['name'] ?? '') as String,
      createdAt:
          (map['created_at'] ?? DateTime.now().toUtc().toIso8601String())
              as String,
    );
  }
}

class FolderWithCount {
  const FolderWithCount({required this.folder, required this.cardCount});

  final Folder folder;
  final int cardCount;
}

class Card {
  const Card({
    this.id,
    required this.title,
    required this.suit,
    this.notes = '',
    this.imageRef,
    required this.folderId,
  });

  final int? id;
  final String title;
  final String suit;
  final String notes;
  final String? imageRef;
  final int folderId;

  String get safeTitle => title.trim();
  String get safeNotes => notes.trim();
  String get safeSuit => suit.trim().isNotEmpty ? suit.trim() : '\u2660';
  String get fallbackSymbol => safeSuit;

  Card copyWith({
    int? id,
    String? title,
    String? suit,
    String? notes,
    String? imageRef,
    int? folderId,
  }) {
    return Card(
      id: id ?? this.id,
      title: title ?? this.title,
      suit: suit ?? this.suit,
      notes: notes ?? this.notes,
      imageRef: imageRef ?? this.imageRef,
      folderId: folderId ?? this.folderId,
    );
  }

  Map<String, Object?> toMap() {
    final map = <String, Object?>{
      'title': safeTitle,
      'suit': safeSuit,
      'notes': safeNotes,
      'image_ref': imageRef,
      'folder_id': folderId,
    };

    if (id != null) {
      map['id'] = id;
    }

    return map;
  }

  factory Card.fromMap(Map<String, dynamic> map) {
    return Card(
      id: map['id'] as int?,
      title: (map['title'] ?? '') as String,
      suit: (map['suit'] ?? '\u2660') as String,
      notes: (map['notes'] ?? '') as String,
      imageRef: map['image_ref'] as String?,
      folderId: map['folder_id'] as int? ?? 0,
    );
  }
}
