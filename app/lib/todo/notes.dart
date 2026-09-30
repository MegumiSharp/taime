import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../db.dart';
import '../notif.dart';
import '../theme.dart';
import '../ui/motion.dart';
import '../ui/widgets.dart';
import 'checklist.dart';
import 'todo_page.dart' show ListsHeader, ListsView, listsQuery, matchesQuery;
import 'todo_sync.dart' show dueLabel;

/// Soft colours a note can wear (a subset of the activity swatches).
const List<int> kNoteSwatches = [
  0xFFE8A0A8, // rosa
  0xFFF2B38A, // pesca
  0xFFEBCB74, // miele
  0xFFA9D18E, // pistacchio
  0xFF86CDB5, // menta
  0xFF8DB5E8, // cielo
  0xFFB89BE3, // lavanda
  0xFFC9A3B4, // malva
];

// --- Writes with side effects -----------------------------------------------------

Future<void> syncNoteReminder(Note n) async {
  try {
    final d = n.date;
    if (!n.remind || d == null) {
      await cancelNoteReminder(n.id);
      return;
    }
    await scheduleNoteReminder(noteId: n.id, at: n.hasTime ? d : DateTime(d.year, d.month, d.day, 9), text: n.body);
  } catch (_) {
    // Reminders are a nicety; notes must keep working without them.
  }
}

Future<void> resyncNoteReminders() async {
  try {
    for (final n in await (db.select(db.notes)..where((n) => n.remind.equals(true))).get()) {
      await syncNoteReminder(n);
    }
  } catch (_) {}
}

/// Returns an undo callback.
Future<Future<void> Function()> deleteNote(Note n) async {
  await (db.delete(db.notes)..where((x) => x.id.equals(n.id))).go();
  await cancelNoteReminder(n.id);
  return () async {
    await db.into(db.notes).insert(n);
    await syncNoteReminder(n);
  };
}

// --- The list ----------------------------------------------------------------------

/// Pins or unpins a note.
Future<void> setPinned(Note n, bool pinned) =>
    (db.update(db.notes)..where((x) => x.id.equals(n.id))).write(NotesCompanion(pinned: Value(pinned)));

/// An endless column of notes, pinned first, newest first (or by date),
/// filterable by colour and by the search box.
class NotesList extends StatefulWidget {
  const NotesList({super.key});

  @override
  State<NotesList> createState() => _NotesListState();
}

class _NotesListState extends State<NotesList> {
  int? _color; // null = all
  bool _byDate = false;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return StreamBuilder<List<Note>>(
      stream: db.watchNotes(),
      builder: (context, snap) => ValueListenableBuilder<String>(
        valueListenable: listsQuery,
        builder: (context, query, _) {
          final all = snap.data ?? const <Note>[];
          final colors = {for (final n in all) ?n.color};
          final shown = [
            for (final n in all)
              if ((_color == null || n.color == _color) && matchesQuery(n.body, query)) n,
          ];
          if (_byDate) {
            // Pinned first; then dated notes, soonest on top; the rest newest first.
            shown.sort((a, b) {
              if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
              if (a.date == null && b.date == null) return b.createdAt.compareTo(a.createdAt);
              if (a.date == null) return 1;
              if (b.date == null) return -1;
              return a.date!.compareTo(b.date!);
            });
          }
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: ListsHeader(
                    view: ListsView.note,
                    trailing: PopupMenuButton<bool>(
                      tooltip: 'Ordina',
                      position: PopupMenuPosition.under,
                      onSelected: (v) => setState(() => _byDate = v),
                      itemBuilder: (_) => [
                        CheckedPopupMenuItem(value: false, checked: !_byDate, child: const Text('Più recenti')),
                        CheckedPopupMenuItem(value: true, checked: _byDate, child: const Text('Per data')),
                      ],
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
                        decoration: BoxDecoration(
                          color: tc.surface.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sort_rounded, size: 18, color: tc.muted),
                            const SizedBox(width: 6),
                            Text(_byDate ? 'Per data' : 'Recenti', style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (colors.isNotEmpty)
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                    child: Row(
                      children: [
                        SoftChip(label: 'Tutte', selected: _color == null, onTap: () => setState(() => _color = null)),
                        for (final c in kNoteSwatches.where(colors.contains))
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _ColorDot(
                              color: activityColor(c, dark: tc.dark),
                              selected: _color == c,
                              onTap: () => setState(() => _color = _color == c ? null : c),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (shown.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(
                    title: all.isEmpty
                        ? 'Ancora nessuna nota'
                        : query.trim().isNotEmpty
                        ? 'Nessuna nota con "${query.trim()}"'
                        : 'Nessuna nota di questo colore',
                    subtitle: all.isEmpty
                        ? 'Tocca "Nota" per scrivere un\'idea, una lista, qualcosa da ricordare.'
                        : null,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                  sliver: SliverList.builder(
                    itemCount: shown.length,
                    itemBuilder: (context, i) => _NoteCard(key: ValueKey(shown[i].id), note: shown[i]),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 170)),
            ],
          );
        },
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color, required this.selected, required this.onTap});
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return Semantics(
      label: 'Colore',
      selected: selected,
      child: TapScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: selected ? tc.text : Colors.transparent, width: 2.5),
          ),
          child: selected ? Icon(Icons.check_rounded, size: 18, color: tc.surface) : null,
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({super.key, required this.note});
  final Note note;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final n = note;
    final lines = n.body.trim().split('\n');
    // The first line is the title, unless it is already a checklist item.
    final hasTitle = !isCheckLine(lines.first);
    final title = hasTitle ? lines.first : null;
    final rest = hasTitle ? lines.skip(1).toList() : lines;
    while (rest.isNotEmpty && rest.first.trim().isEmpty) {
      rest.removeAt(0);
    }
    final firstIndex = lines.length - rest.length;
    final shown = rest.take(8).toList();
    final now = DateTime.now();
    final past =
        n.date != null &&
        (n.hasTime ? n.date! : DateTime(n.date!.year, n.date!.month, n.date!.day, 23, 59)).isBefore(now);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey('n${n.id}'),
        confirmDismiss: (_) async {
          final messenger = ScaffoldMessenger.of(context);
          final undo = await deleteNote(n);
          showUndo(messenger, 'Nota eliminata', undo);
          return false;
        },
        background: _DeleteBg(left: true),
        secondaryBackground: _DeleteBg(left: false),
        child: SoftCard(
          color: n.color == null ? null : activitySoft(n.color!, dark: tc.dark),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          onTap: () => openNote(context, n),
          onLongPress: () {
            Haptic.medium();
            setPinned(n, !n.pinned);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null || n.pinned)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(title ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                    ),
                    if (n.pinned)
                      Semantics(
                        label: 'Fissata in alto',
                        child: Icon(Icons.push_pin_rounded, size: 16, color: tc.accent),
                      ),
                  ],
                ),
              for (final (k, line) in shown.indexed)
                if (isCheckLine(line))
                  _CheckRow(
                    text: checkText(line),
                    ticked: isTicked(line),
                    onTap: () => (db.update(db.notes)..where((x) => x.id.equals(n.id))).write(
                      NotesCompanion(
                        body: Value(toggleLine(n.body.trim(), firstIndex + k)),
                        updatedAt: Value(DateTime.now()),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(line, style: const TextStyle(height: 1.4)),
                  ),
              if (rest.length > shown.length)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '…',
                    style: TextStyle(color: tc.muted, fontWeight: FontWeight.w800),
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (n.date != null) ...[
                    Icon(Icons.event_rounded, size: 14, color: past ? tc.muted : tc.accent),
                    const SizedBox(width: 4),
                    Text(
                      dueLabel(n.date!, n.hasTime),
                      style: TextStyle(color: past ? tc.muted : tc.accent, fontWeight: FontWeight.w700, fontSize: 12.5),
                    ),
                    if (n.remind) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.notifications_active_rounded, size: 14, color: past ? tc.muted : tc.accent),
                    ],
                  ],
                  const Spacer(),
                  Text(
                    DateFormat('d MMM', 'it').format(n.createdAt),
                    style: TextStyle(color: tc.muted, fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A checklist line on a note card: tap the box to tick it.
class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.text, required this.ticked, required this.onTap});
  final String text;
  final bool ticked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return Semantics(
      checked: ticked,
      label: text,
      child: InkWell(
        onTap: () {
          Haptic.light();
          onTap();
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                ticked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                size: 20,
                color: ticked ? tc.accent : tc.muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    decoration: ticked ? TextDecoration.lineThrough : null,
                    color: ticked ? tc.muted : tc.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteBg extends StatelessWidget {
  const _DeleteBg({required this.left});
  final bool left;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return Container(
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(color: tc.danger.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(kRadius)),
      child: Icon(Icons.delete_outline_rounded, color: tc.danger),
    );
  }
}

// --- Editor ------------------------------------------------------------------------

/// Opens a note, or a new blank one when [note] is null. Saves as you type.
Future<void> openNote(BuildContext context, Note? note) {
  return showSoftSheet<void>(context, builder: (_) => _NoteEditor(note: note));
}

class _NoteEditor extends StatefulWidget {
  const _NoteEditor({required this.note});
  final Note? note;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final _c = TextEditingController(text: widget.note?.body ?? '');
  late int? _id = widget.note?.id;
  late int? _color = widget.note?.color;
  late DateTime? _date = widget.note?.date;
  late bool _hasTime = widget.note?.hasTime ?? false;
  late bool _remind = widget.note?.remind ?? false;
  late bool _pinned = widget.note?.pinned ?? false;
  bool _deleted = false;

  /// Saves run one after the other: typing fast must not insert twice.
  Future<void> _queue = Future.value();

  NotesCompanion _row(DateTime now, String text) => NotesCompanion(
    body: Value(text),
    color: Value(_color),
    date: Value(_date),
    hasTime: Value(_hasTime),
    remind: Value(_remind && _date != null),
    pinned: Value(_pinned),
    updatedAt: Value(now),
  );

  Future<void> _save({bool sync = false}) {
    final text = _c.text;
    return _queue = _queue.then((_) async {
      final now = DateTime.now();
      if (_id == null) {
        if (text.trim().isEmpty) return;
        _id = await db.into(db.notes).insert(_row(now, text).copyWith(createdAt: Value(now)));
      } else {
        await (db.update(db.notes)..where((n) => n.id.equals(_id!))).write(_row(now, text));
      }
      if (sync) {
        final n = await db.noteById(_id!);
        if (n != null) await syncNoteReminder(n);
      }
    });
  }

  @override
  void dispose() {
    // Leaving an emptied note deletes it; otherwise the last words are kept.
    if (!_deleted) {
      if (_c.text.trim().isEmpty) {
        _queue.then((_) async {
          final id = _id;
          if (id == null) return;
          await (db.delete(db.notes)..where((n) => n.id.equals(id))).go();
          await cancelNoteReminder(id);
        });
      } else {
        _save(sync: true);
      }
    }
    _c.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: _hasTime && _date != null ? TimeOfDay.fromDateTime(_date!) : const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Orario (Annulla = senza orario)',
    );
    setState(() {
      _date = DateTime(d.year, d.month, d.day, t?.hour ?? 0, t?.minute ?? 0);
      _hasTime = t != null;
    });
    await _save(sync: true);
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final bg = _color == null ? tc.raised : activitySoft(_color!, dark: tc.dark);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  TapScale(
                    onTap: () {
                      setState(() => _color = null);
                      _save();
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: tc.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: _color == null ? tc.text : tc.outline, width: 2.5),
                      ),
                      child: Icon(Icons.format_color_reset_rounded, size: 17, color: tc.muted),
                    ),
                  ),
                  for (final c in kNoteSwatches)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _ColorDot(
                        color: activityColor(c, dark: tc.dark),
                        selected: _color == c,
                        onTap: () {
                          setState(() => _color = c);
                          _save();
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // The note itself, as a card in its colour.
            AnimatedContainer(
              duration: Motion.of(context, Motion.medium),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.45),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(kRadius)),
              child: TextField(
                controller: _c,
                inputFormatters: [ChecklistFormatter()],
                autofocus: widget.note == null,
                minLines: 6,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 16, height: 1.45),
                decoration: const InputDecoration(
                  hintText: 'Scrivi una nota…\nLa prima riga fa da titolo. "Casella" crea una lista da spuntare.',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onChanged: (_) => _save(),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SoftChip(
                  label: 'Casella',
                  icon: Icons.checklist_rounded,
                  onTap: () {
                    _c.value = toggleBoxAtCursor(_c.value);
                    _save();
                  },
                ),
                SoftChip(
                  label: _pinned ? 'Fissata' : 'Fissa in alto',
                  icon: Icons.push_pin_rounded,
                  selected: _pinned,
                  onTap: () {
                    setState(() => _pinned = !_pinned);
                    _save();
                  },
                ),
                SoftChip(
                  label: _date == null ? 'Aggiungi una data' : dueLabel(_date!, _hasTime),
                  icon: Icons.event_rounded,
                  selected: _date != null,
                  onTap: _pickDate,
                ),
                if (_date != null)
                  SoftChip(
                    label: 'Ricordamelo',
                    icon: _remind ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                    selected: _remind,
                    onTap: () async {
                      setState(() => _remind = !_remind);
                      await _save(sync: true);
                    },
                  ),
                if (_date != null)
                  IconButton(
                    tooltip: 'Togli la data',
                    onPressed: () async {
                      setState(() {
                        _date = null;
                        _hasTime = false;
                        _remind = false;
                      });
                      await _save(sync: true);
                    },
                    icon: Icon(Icons.close_rounded, size: 18, color: tc.muted),
                  ),
              ],
            ),
            if (_date != null && _remind)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  _hasTime ? 'Ti avviso all\'orario scelto.' : 'Ti avviso alle 9:00 di quel giorno.',
                  style: TextStyle(color: tc.muted, fontSize: 12.5),
                ),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (_id != null)
                  PillButton(
                    label: 'Elimina',
                    icon: Icons.delete_outline_rounded,
                    kind: PillKind.ghost,
                    color: tc.danger,
                    onTap: () async {
                      final nav = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      final n = await db.noteById(_id!);
                      _deleted = true;
                      nav.pop();
                      if (n != null) showUndo(messenger, 'Nota eliminata', await deleteNote(n));
                    },
                  ),
                const Spacer(),
                PillButton(label: 'Fatto', icon: Icons.check_rounded, onTap: () => Navigator.pop(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
