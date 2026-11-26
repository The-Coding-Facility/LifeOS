import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../note_repository.dart';
import '../providers.dart';

/// Editor für eine Notiz. Speichert automatisch 600 ms nach der letzten
/// Eingabe und beim Verlassen. Leere Notizen werden beim Verlassen gelöscht.
class NoteEditorPage extends ConsumerStatefulWidget {
  const NoteEditorPage({super.key, required this.noteId, required this.onClose});

  final String noteId;

  /// Zurück zur Liste.
  final VoidCallback onClose;

  @override
  ConsumerState<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends ConsumerState<NoteEditorPage> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  late final NoteRepository _repository;
  Timer? _debounce;
  bool _loaded = false;
  bool _dirty = false;
  bool _deleted = false;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(noteRepositoryProvider);
    _load();
  }

  Future<void> _load() async {
    final note = await _repository.watch(widget.noteId).first;
    if (!mounted) return;
    if (note == null) {
      widget.onClose();
      return;
    }
    _title.text = note.title;
    _body.text = note.body;
    setState(() => _loaded = true);
  }

  void _onChanged(String _) {
    _dirty = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _save);
  }

  Future<void> _save() async {
    if (!_dirty || _deleted) return;
    _dirty = false;
    await _repository.update(widget.noteId, title: _title.text, body: _body.text);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notiz löschen?'),
        content: const Text('Die Notiz wandert in den Papierkorb und wird auf allen Geräten entfernt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _debounce?.cancel();
    _deleted = true;
    await _repository.delete(widget.noteId);
    if (mounted) widget.onClose();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_loaded && !_deleted) {
      final title = _title.text;
      final body = _body.text;
      if (title.trim().isEmpty && body.trim().isEmpty) {
        unawaited(_repository.delete(widget.noteId));
      } else if (_dirty) {
        unawaited(_repository.update(widget.noteId, title: title, body: body));
      }
    }
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notiz'),
        actions: [
          IconButton(
            tooltip: 'Löschen',
            icon: const Icon(Icons.delete_outline),
            onPressed: _loaded ? _confirmDelete : null,
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  TextField(
                    controller: _title,
                    onChanged: _onChanged,
                    style: theme.textTheme.titleLarge,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Titel',
                      border: InputBorder.none,
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: TextField(
                      controller: _body,
                      onChanged: _onChanged,
                      autofocus: _title.text.isEmpty && _body.text.isEmpty,
                      maxLines: null,
                      expands: true,
                      keyboardType: TextInputType.multiline,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        hintText: 'Schreib los … (Markdown wird später formatiert angezeigt)',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
