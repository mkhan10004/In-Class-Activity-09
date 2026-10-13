import 'package:flutter/material.dart';

import 'database_helper.dart';
import 'models.dart' as models;

const List<String> supportedSuits = ['\u2660', '\u2665', '\u2666', '\u2663'];

void main() {
  runApp(const CardCatalogApp());
}

class CardCatalogApp extends StatelessWidget {
  const CardCatalogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Card Catalog',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const FolderHomePage(),
    );
  }
}

class FolderHomePage extends StatefulWidget {
  const FolderHomePage({super.key});

  @override
  State<FolderHomePage> createState() => _FolderHomePageState();
}

class _FolderHomePageState extends State<FolderHomePage> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<models.FolderWithCount> _folders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshFolders();
  }

  Future<void> _refreshFolders() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final folders = await _databaseHelper.getFoldersWithCounts();
      if (!mounted) return;
      setState(() {
        _folders = folders;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _addOrEditFolder({models.Folder? folder}) async {
    final controller = TextEditingController(text: folder?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(folder == null ? 'Add folder' : 'Rename folder'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Folder name',
              hintText: 'e.g. Travel',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: Text(folder == null ? 'Create' : 'Save'),
            ),
          ],
        );
      },
    );

    if (name == null) {
      return;
    }
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Folder name is required.')));
      return;
    }

    try {
      if (folder == null) {
        await _databaseHelper.insertFolder(
          models.Folder(
            name: name,
            createdAt: DateTime.now().toUtc().toIso8601String(),
          ),
        );
      } else {
        final affected = await _databaseHelper.updateFolder(
          folder.copyWith(name: name),
        );
        if (affected != 1) {
          throw StateError('Folder ${folder.id} no longer exists.');
        }
      }
      if (!mounted) return;
      await _refreshFolders();
    } catch (error) {
      debugPrint('Unable to save folder: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to save folder: $error')));
    }
  }

  Future<void> _deleteFolder(models.FolderWithCount item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete folder?'),
        content: Text(
          'Delete ${item.folder.name} and ${item.cardCount} linked card${item.cardCount == 1 ? '' : 's'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      final affected = await _databaseHelper.deleteFolder(item.folder.id!);
      if (affected != 1) {
        throw StateError('Folder ${item.folder.id} no longer exists.');
      }
      if (!mounted) return;
      await _refreshFolders();
    } catch (error) {
      debugPrint('Unable to delete folder ${item.folder.id}: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete folder: $error')),
      );
    }
  }

  void _openFolder(models.Folder folder) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            FolderDetailPage(folder: folder, databaseHelper: _databaseHelper),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Folders'),
        actions: [
          IconButton(
            tooltip: 'Legacy guest data',
            onPressed: () async {
              final rows = await _databaseHelper.getGuests();
              if (!mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => LegacyGuestScreen(rows: rows),
                ),
              );
            },
            icon: const Icon(Icons.people_alt_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditFolder(),
        child: const Icon(Icons.create_new_folder_outlined),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!),
              ),
            )
          : _folders.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No folders yet. Create one to begin.'),
              ),
            )
          : ListView.builder(
              itemCount: _folders.length,
              itemBuilder: (context, index) {
                final item = _folders[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${item.cardCount}')),
                    title: Text(item.folder.name),
                    subtitle: Text(
                      'Created ${item.folder.createdAt.substring(0, 10)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Rename',
                          onPressed: () =>
                              _addOrEditFolder(folder: item.folder),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: () => _deleteFolder(item),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    onTap: () => _openFolder(item.folder),
                  ),
                );
              },
            ),
    );
  }
}

class FolderDetailPage extends StatefulWidget {
  const FolderDetailPage({
    super.key,
    required this.folder,
    required this.databaseHelper,
  });

  final models.Folder folder;
  final DatabaseHelper databaseHelper;

  @override
  State<FolderDetailPage> createState() => _FolderDetailPageState();
}

class _FolderDetailPageState extends State<FolderDetailPage> {
  List<models.Card> _cards = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshCards();
  }

  Future<void> _refreshCards() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cards = await widget.databaseHelper.getCards(widget.folder.id!);
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _loading = false;
      });
    } catch (error) {
      debugPrint('Unable to load cards for folder ${widget.folder.id}: $error');
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _deleteCard(models.Card card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete card?'),
        content: Text('Delete ${card.title}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      final affected = await widget.databaseHelper.deleteCard(card.id!);
      if (affected != 1) {
        throw StateError('Card ${card.id} no longer exists.');
      }
      if (!mounted) return;
      await _refreshCards();
    } catch (error) {
      debugPrint('Unable to delete card ${card.id}: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to delete card: $error')));
    }
  }

  Future<void> _showCardEditor({models.Card? card}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => CardEditorDialog(
        folderId: widget.folder.id!,
        card: card,
        databaseHelper: widget.databaseHelper,
      ),
    );

    if (saved == true) {
      await _refreshCards();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.folder.name)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCardEditor(),
        child: const Icon(Icons.add_card_rounded),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!),
              ),
            )
          : _cards.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('This folder is empty. Add a card to get started.'),
              ),
            )
          : ListView.builder(
              itemCount: _cards.length,
              itemBuilder: (context, index) {
                final card = _cards[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: CardImagePreview(
                      imageRef: card.imageRef,
                      suit: card.safeSuit,
                    ),
                    title: Text(card.title),
                    subtitle: Text(
                      '${card.suit} • ${card.notes.isEmpty ? 'No notes' : card.notes}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _showCardEditor(card: card),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: () => _deleteCard(card),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class CardEditorDialog extends StatefulWidget {
  const CardEditorDialog({
    super.key,
    required this.folderId,
    this.card,
    required this.databaseHelper,
  });

  final int folderId;
  final models.Card? card;
  final DatabaseHelper databaseHelper;

  @override
  State<CardEditorDialog> createState() => _CardEditorDialogState();
}

class _CardEditorDialogState extends State<CardEditorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final TextEditingController _imageController;
  late String _selectedSuit;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.card?.title ?? '');
    _notesController = TextEditingController(text: widget.card?.notes ?? '');
    _imageController = TextEditingController(text: widget.card?.imageRef ?? '');
    _selectedSuit = widget.card?.safeSuit ?? supportedSuits.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _saveCard() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    final card = models.Card(
      id: widget.card?.id,
      title: _titleController.text.trim(),
      suit: _selectedSuit,
      notes: _notesController.text.trim(),
      imageRef: _imageController.text.trim().isEmpty
          ? null
          : _imageController.text.trim(),
      folderId: widget.folderId,
    );

    try {
      if (widget.card == null) {
        await widget.databaseHelper.insertCard(card);
      } else {
        final affected = await widget.databaseHelper.updateCard(card);
        if (affected != 1) {
          throw StateError('Card ${widget.card!.id} no longer exists.');
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint('Unable to save card ${widget.card?.id}: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to save card: $error')));
      setState(() {
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.card == null ? 'Add card' : 'Edit card'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: supportedSuits.contains(_selectedSuit)
                    ? _selectedSuit
                    : supportedSuits.first,
                decoration: const InputDecoration(labelText: 'Suit'),
                items: supportedSuits
                    .map(
                      (suit) => DropdownMenuItem<String>(
                        value: suit,
                        child: Text(suit),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedSuit = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _imageController,
                decoration: const InputDecoration(
                  labelText: 'Image reference (optional)',
                  hintText:
                      'assets/example.png or https://example.com/image.png',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _saveCard,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.card == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }
}

class LegacyGuestScreen extends StatelessWidget {
  const LegacyGuestScreen({super.key, required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Legacy guest data')),
      body: rows.isEmpty
          ? const Center(child: Text('No legacy guest records remain.'))
          : ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                return ListTile(
                  title: Text('${row['name']}'),
                  subtitle: Text(
                    'Age: ${row['age'] ?? 'n/a'} • ${row['created_at']}',
                  ),
                );
              },
            ),
    );
  }
}

class CardImagePreview extends StatelessWidget {
  const CardImagePreview({
    super.key,
    required this.imageRef,
    required this.suit,
  });

  final String? imageRef;
  final String suit;

  @override
  Widget build(BuildContext context) {
    final reference = imageRef?.trim();

    if (reference == null || reference.isEmpty) {
      return _SuitPlaceholder(suit: suit);
    }

    if (reference.startsWith('http://') || reference.startsWith('https://')) {
      return Image.network(
        reference,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _SuitPlaceholder(suit: suit),
      );
    }

    if (reference.startsWith('assets/')) {
      return Image.asset(
        reference,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _SuitPlaceholder(suit: suit),
      );
    }

    return _SuitPlaceholder(suit: suit);
  }
}

class _SuitPlaceholder extends StatelessWidget {
  const _SuitPlaceholder({required this.suit});

  final String suit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: Text(suit, style: const TextStyle(fontSize: 28))),
    );
  }
}
