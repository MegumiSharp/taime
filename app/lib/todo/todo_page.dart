import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../db.dart';
import '../main.dart' show shellTab;
import '../palette.dart';
import '../settings.dart';
import '../theme.dart';
import '../ui/motion.dart';
import '../ui/swatches.dart';
import '../ui/widgets.dart';
import 'notes.dart';
import 'parser.dart';
import 'recurrence.dart';
import 'todo_sync.dart';

/// The two halves of the Liste tab.
enum ListsView { todo, note }

/// Which half is showing; notifications can switch it (a note reminder opens
/// the notes).
final listsView = ValueNotifier<ListsView>(ListsView.todo);

const _horizonIcons = [Icons.wb_sunny_rounded, Icons.view_week_rounded, Icons.hourglass_empty_rounded];
const _horizonShort = ['Oggi', 'Settimana', 'Più avanti'];

Color priorityColor(BuildContext context, int p) {
  final tc = context.tc;
  return switch (p) {
    1 => tc.danger,
    2 => tc.pause,
    3 => Color(oklch(tc.dark ? 0.78 : 0.58, 0.1, 245)),
    _ => tc.muted,
  };
}

String dueLabel(DateTime due, bool hasTime) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(due.year, due.month, due.day);
  final diff = (d.difference(today).inHours / 24).round();
  final day = switch (diff) {
    0 => 'Oggi',
    1 => 'Domani',
    -1 => 'Ieri',
    _ when diff > 1 && diff < 7 => _cap(DateFormat('EEEE', 'it').format(d)),
    _ => DateFormat('d MMM', 'it').format(d),
  };
  return hasTime ? '$day ${DateFormat.Hm().format(due)}' : day;
}

String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// Title, the To-do | Note switch and a trailing control.
class ListsHeader extends StatelessWidget {
  const ListsHeader({super.key, required this.view, this.trailing});
  final ListsView view;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(view == ListsView.todo ? 'To-do' : 'Note', style: Theme.of(context).textTheme.headlineMedium),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 14),
        PillSelector<ListsView>(
          values: ListsView.values,
          labels: const ['To-do', 'Note'],
          selected: view,
          onChanged: (v) => listsView.value = v,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class TodoPage extends StatefulWidget {
  const TodoPage({super.key, required this.settings});
  final Settings settings;

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  int? _category; // null = all
  bool _showDone = false;
  final Set<int> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ListsView>(
      valueListenable: listsView,
      builder: (context, view, _) => Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 78),
          child: FloatingActionButton.extended(
            heroTag: 'lists-fab',
            onPressed: () =>
                view == ListsView.todo ? showNewTodo(context, categoryId: _category) : openNote(context, null),
            icon: const Icon(Icons.add_rounded),
            label: Text(view == ListsView.todo ? 'To-do' : 'Nota'),
          ),
        ),
        body: PastelBackground(
          child: SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: Motion.of(context, Motion.medium),
              child: view == ListsView.note
                  ? const NotesList(key: ValueKey('notes'))
                  : KeyedSubtree(key: const ValueKey('todos'), child: _todos(context)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _todos(BuildContext context) {
    return StreamBuilder<List<TodoCategory>>(
      stream: db.watchTodoCategories(),
      builder: (context, cSnap) {
        final cats = cSnap.data ?? const <TodoCategory>[];
        return StreamBuilder<List<Todo>>(
          stream: db.watchTodos(),
          builder: (context, snap) => _list(context, snap.data ?? const <Todo>[], cats),
        );
      },
    );
  }

  Widget _list(BuildContext context, List<Todo> all, List<TodoCategory> cats) {
    final tc = context.tc;
    final byParent = <int, List<Todo>>{};
    for (final t in all) {
      if (t.parentId != null) byParent.putIfAbsent(t.parentId!, () => []).add(t);
    }
    final catById = {for (final c in cats) c.id: c};
    final top = all.where((t) => t.parentId == null && (_category == null || t.categoryId == _category)).toList();
    final now = DateTime.now();
    final sections = [<Todo>[], <Todo>[], <Todo>[]];
    for (final t in top.where((t) => t.completedAt == null)) {
      sections[sectionOf(t, now)].add(t);
    }
    int order(Todo a, Todo b) {
      final c = (a.due ?? DateTime(9999)).compareTo(b.due ?? DateTime(9999));
      if (c != 0) return c;
      final p = a.priority.compareTo(b.priority);
      return p != 0 ? p : a.id.compareTo(b.id);
    }

    for (final s in sections) {
      s.sort(order);
    }
    final done = top.where((t) => t.completedAt != null).toList()
      ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));

    Widget tile(Todo t) => _TodoTile(
      key: ValueKey(t.id),
      todo: t,
      category: t.categoryId == null ? null : catById[t.categoryId],
      subtasks: byParent[t.id] ?? const [],
    );

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          sliver: SliverToBoxAdapter(
            child: ListsHeader(
              view: ListsView.todo,
              trailing: _CategoryMenu(
                categories: cats,
                selected: _category,
                onChanged: (c) => setState(() => _category = c),
              ),
            ),
          ),
        ),
        for (var i = 0; i < 3; i++)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.list(
              children: [
                _SectionHeader(
                  title: kHorizonNames[i],
                  icon: _horizonIcons[i],
                  count: sections[i].length,
                  collapsed: _collapsed.contains(i),
                  onToggle: () => setState(() => _collapsed.contains(i) ? _collapsed.remove(i) : _collapsed.add(i)),
                  onAdd: () => showNewTodo(context, categoryId: _category, horizon: i),
                ),
                if (!_collapsed.contains(i)) ...[
                  if (sections[i].isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                      child: Text(
                        i == 0 ? 'Niente per oggi. Tocca + per aggiungere qualcosa.' : 'Niente qui.',
                        style: TextStyle(color: tc.muted, fontSize: 13),
                      ),
                    ),
                  for (var k = 0; k < sections[i].length; k++) StaggeredIn(index: k, child: tile(sections[i][k])),
                ],
              ],
            ),
          ),
        if (done.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: TapScale(
                      onTap: () => setState(() => _showDone = !_showDone),
                      child: Row(
                        children: [
                          AnimatedRotation(
                            turns: _showDone ? 0.25 : 0,
                            duration: Motion.of(context, Motion.medium),
                            child: Icon(Icons.chevron_right_rounded, color: tc.muted),
                          ),
                          Text(
                            'Completati (${done.length})',
                            style: TextStyle(color: tc.muted, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      Haptic.medium();
                      final undo = await clearCompleted(done);
                      showUndo(
                        messenger,
                        done.length == 1 ? 'Eliminato 1 completato' : 'Eliminati ${done.length} completati',
                        undo,
                      );
                    },
                    style: TextButton.styleFrom(foregroundColor: tc.muted),
                    icon: const Icon(Icons.delete_sweep_rounded, size: 19),
                    label: const Text('Svuota'),
                  ),
                ],
              ),
            ),
          ),
        if (_showDone)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.list(children: [for (final t in done.take(60)) tile(t)]),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 170)),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.count,
    required this.collapsed,
    required this.onToggle,
    required this.onAdd,
  });

  final String title;
  final IconData icon;
  final int count;
  final bool collapsed;
  final VoidCallback onToggle, onAdd;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: TapScale(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: tc.accent),
                    const SizedBox(width: 8),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                    const SizedBox(width: 8),
                    if (count > 0)
                      Text(
                        '$count',
                        style: TextStyle(color: tc.muted, fontWeight: FontWeight.w700),
                      ),
                    const SizedBox(width: 2),
                    AnimatedRotation(
                      turns: collapsed ? -0.25 : 0,
                      duration: Motion.of(context, Motion.medium),
                      child: Icon(Icons.expand_more_rounded, size: 20, color: tc.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Aggiungi in $title',
            onPressed: onAdd,
            icon: Icon(Icons.add_rounded, color: tc.muted, size: 22),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _CategoryMenu extends StatelessWidget {
  const _CategoryMenu({required this.categories, required this.selected, required this.onChanged});
  final List<TodoCategory> categories;
  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final current = categories.where((c) => c.id == selected).firstOrNull;
    return PopupMenuButton<int>(
      tooltip: 'Categoria',
      position: PopupMenuPosition.under,
      onSelected: (v) {
        if (v == -2) {
          showSoftSheet<void>(context, builder: (_) => const _CategoryManager());
        } else {
          onChanged(v == -1 ? null : v);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: -1, child: Text('Tutte le categorie')),
        for (final c in categories)
          PopupMenuItem(
            value: c.id,
            child: Row(
              children: [
                _Dot(color: activityColor(c.color, dark: tc.dark)),
                const SizedBox(width: 10),
                Text(c.name),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: -2, child: Text('Gestisci categorie…')),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(color: tc.surface.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(22)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (current != null) ...[
              _Dot(color: activityColor(current.color, dark: tc.dark)),
              const SizedBox(width: 8),
            ],
            Text(current?.name ?? 'Tutte', style: const TextStyle(fontWeight: FontWeight.w700)),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, this.size = 10});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _TodoTile extends StatefulWidget {
  const _TodoTile({super.key, required this.todo, required this.category, required this.subtasks});
  final Todo todo;
  final TodoCategory? category;
  final List<Todo> subtasks;

  @override
  State<_TodoTile> createState() => _TodoTileState();
}

class _TodoTileState extends State<_TodoTile> {
  bool _checking = false;

  Future<void> _toggle() async {
    final t = widget.todo;
    Haptic.light();
    if (t.completedAt != null) {
      await uncompleteTodo(t);
      return;
    }
    setState(() => _checking = true);
    await Future<void>.delayed(Motion.of(context, const Duration(milliseconds: 420)));
    final undo = await completeTodo(t);
    if (!mounted) return;
    showUndo(
      ScaffoldMessenger.of(context),
      t.recurrence != null ? 'Fatto! Il prossimo è già in lista' : 'Fatto!',
      undo,
    );
  }

  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);
    final undo = await deleteTodo(widget.todo);
    showUndo(messenger, 'Eliminato', undo);
  }

  Future<bool> _swipeLeft() async {
    final t = widget.todo;
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final current = sectionOf(t, now);
    final choice = await showSoftSheet<String>(
      context,
      scrollControlled: false,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (t.due == null)
                for (var i = 0; i < 3; i++)
                  if (i != current)
                    ListTile(
                      leading: Icon(_horizonIcons[i]),
                      title: Text('Sposta in ${kHorizonNames[i]}'),
                      onTap: () => Navigator.pop(context, 'h$i'),
                    ),
              if (t.due != null) ...[
                ListTile(
                  leading: const Icon(Icons.wb_sunny_rounded),
                  title: const Text('Rinvia a domani'),
                  onTap: () => Navigator.pop(context, 'tomorrow'),
                ),
                ListTile(
                  leading: const Icon(Icons.event_busy_rounded),
                  title: const Text('Togli la data'),
                  onTap: () => Navigator.pop(context, 'nodate'),
                ),
              ],
              ListTile(
                leading: const Icon(Icons.event_rounded),
                title: Text(t.due == null ? 'Dai una data' : 'Scegli un\'altra data'),
                onTap: () => Navigator.pop(context, 'pick'),
              ),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: context.tc.danger),
                title: Text('Elimina', style: TextStyle(color: context.tc.danger)),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return false;
    Future<void> Function()? undo;
    String? msg;
    if (choice.startsWith('h')) {
      final h = int.parse(choice.substring(1));
      final old = t.horizon;
      await updateTodo(t.id, TodosCompanion(horizon: Value(h)));
      undo = () => updateTodo(t.id, TodosCompanion(horizon: Value(old)));
      msg = 'Spostato in ${kHorizonNames[h]}';
    } else if (choice == 'tomorrow') {
      undo = await postponeTodo(t, DateTime(now.year, now.month, now.day + 1));
      msg = 'Rinviato a domani';
    } else if (choice == 'nodate') {
      final old = t;
      // Stays where it was: the horizon follows the section it was in.
      await updateTodo(
        t.id,
        TodosCompanion(
          due: const Value(null),
          hasTime: const Value(false),
          remindBefore: const Value(null),
          recurrence: const Value(null),
          horizon: Value(current),
        ),
      );
      undo = () => updateTodo(
        t.id,
        TodosCompanion(
          due: Value(old.due),
          hasTime: Value(old.hasTime),
          remindBefore: Value(old.remindBefore),
          recurrence: Value(old.recurrence),
          horizon: Value(old.horizon),
        ),
      );
      msg = 'Data tolta';
    } else if (choice == 'pick') {
      final d = await showDatePicker(
        context: context,
        initialDate: t.due ?? now,
        firstDate: DateTime(now.year - 1),
        lastDate: DateTime(now.year + 5),
      );
      if (d == null) return false;
      undo = await postponeTodo(t, d);
      msg = 'Spostato a ${DateFormat('d MMM', 'it').format(d)}';
    } else if (choice == 'delete') {
      undo = await deleteTodo(t);
      msg = 'Eliminato';
    }
    if (undo != null) showUndo(messenger, msg!, undo);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final t = widget.todo;
    final completed = t.completedAt != null;
    final done = completed || _checking;
    final pc = priorityColor(context, t.priority);
    final now = DateTime.now();
    final overdue = t.due != null && !completed && t.due!.isBefore(DateTime(now.year, now.month, now.day));
    final subsDone = widget.subtasks.where((s) => s.completedAt != null).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey('d${t.id}'),
        direction: DismissDirection.horizontal,
        confirmDismiss: (dir) async {
          if (completed) {
            await _delete();
            return false;
          }
          if (dir == DismissDirection.startToEnd) {
            await _toggle();
            return false;
          }
          return _swipeLeft();
        },
        background: completed
            ? _SwipeBg(color: tc.danger, icon: Icons.delete_outline_rounded, left: true)
            : _SwipeBg(color: tc.accent, icon: Icons.check_rounded, left: true),
        secondaryBackground: completed
            ? _SwipeBg(color: tc.danger, icon: Icons.delete_outline_rounded, left: false)
            : _SwipeBg(color: tc.pause, icon: Icons.schedule_rounded, left: false),
        child: SoftCard(
          padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
          onTap: () => showTodoDetail(context, t.id),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggle,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: AnimatedContainer(
                    duration: Motion.of(context, Motion.medium),
                    curve: Motion.spring,
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? pc : pc.withValues(alpha: 0.1),
                      border: Border.all(color: pc, width: 2),
                    ),
                    child: AnimatedScale(
                      scale: done ? 1 : 0,
                      duration: Motion.of(context, Motion.medium),
                      curve: Motion.spring,
                      child: Icon(Icons.check_rounded, size: 16, color: tc.surface),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: AnimatedOpacity(
                  opacity: done ? 0.5 : 1,
                  duration: Motion.of(context, Motion.medium),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            decoration: done ? TextDecoration.lineThrough : null,
                            decorationColor: tc.muted,
                          ),
                        ),
                        if (t.notes.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              t.notes,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: tc.muted, fontSize: 13),
                            ),
                          ),
                        if (t.due != null ||
                            widget.category != null ||
                            widget.subtasks.isNotEmpty ||
                            t.recurrence != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (t.due != null)
                                  _Meta(
                                    icon: Icons.event_rounded,
                                    text: dueLabel(t.due!, t.hasTime),
                                    color: overdue ? tc.pause : tc.accent,
                                  ),
                                if (t.recurrence != null)
                                  _Meta(
                                    icon: Icons.repeat_rounded,
                                    text: recurrenceLabel(t.recurrence!),
                                    color: tc.muted,
                                  ),
                                if (t.remindBefore != null)
                                  _Meta(icon: Icons.notifications_active_rounded, text: '', color: tc.muted),
                                if (widget.subtasks.isNotEmpty)
                                  _Meta(
                                    icon: Icons.checklist_rounded,
                                    text: '$subsDone/${widget.subtasks.length}',
                                    color: tc.muted,
                                  ),
                                if (widget.category != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _Dot(color: activityColor(widget.category!.color, dark: tc.dark), size: 8),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.category!.name,
                                        style: TextStyle(color: tc.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
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

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: color),
      if (text.isNotEmpty) ...[
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
      ],
    ],
  );
}

class _SwipeBg extends StatelessWidget {
  const _SwipeBg({required this.color, required this.icon, required this.left});
  final Color color;
  final IconData icon;
  final bool left;

  @override
  Widget build(BuildContext context) => Container(
    alignment: left ? Alignment.centerLeft : Alignment.centerRight,
    padding: const EdgeInsets.symmetric(horizontal: 24),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(kRadius)),
    child: Icon(icon, color: color),
  );
}

// --- New to-do: a small dialog ----------------------------------------------------

/// Colours the parts of the text the parser understood, while typing.
class _HighlightController extends TextEditingController {
  List<ParsedToken> tokens = const [];
  Color highlight = Colors.transparent;
  Color highlightText = Colors.black;

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    if (tokens.isEmpty || text.isEmpty) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }
    final spans = <TextSpan>[];
    var i = 0;
    for (final t in tokens) {
      if (t.start < i || t.end > text.length) continue;
      if (t.start > i) spans.add(TextSpan(text: text.substring(i, t.start)));
      spans.add(
        TextSpan(
          text: text.substring(t.start, t.end),
          style: TextStyle(backgroundColor: highlight, color: highlightText, fontWeight: FontWeight.w800),
        ),
      );
      i = t.end;
    }
    if (i < text.length) spans.add(TextSpan(text: text.substring(i)));
    return TextSpan(style: style, children: spans);
  }
}

/// A compact dialog: what, when (Oggi / Settimana / Più avanti or a date),
/// and a few one-tap extras.
Future<void> showNewTodo(BuildContext context, {int? categoryId, int horizon = 0}) async {
  final messenger = ScaffoldMessenger.of(context);
  final where = await showDialog<String>(
    context: context,
    builder: (_) => _NewTodo(categoryId: categoryId, horizon: horizon),
  );
  if (where != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Aggiunto in $where'), duration: const Duration(seconds: 2)));
  }
}

class _NewTodo extends StatefulWidget {
  const _NewTodo({this.categoryId, required this.horizon});
  final int? categoryId;
  final int horizon;

  @override
  State<_NewTodo> createState() => _NewTodoState();
}

class _NewTodoState extends State<_NewTodo> {
  final _c = _HighlightController();
  final Set<String> _ignored = {};
  ParsedTask _parsed = parseTask('', DateTime.now());
  late int _horizon = widget.horizon;
  DateTime? _date;
  TimeOfDay? _time;
  String? _recurrence;
  int? _remind;
  int _priority = 4;
  late int? _category = widget.categoryId;

  @override
  void initState() {
    super.initState();
    _c.addListener(_reparse);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _reparse() {
    final p = parseTask(_c.text, DateTime.now(), ignored: _ignored);
    _c.tokens = p.tokens;
    setState(() => _parsed = p);
  }

  /// Drops what the parser read for [kind], so a tap on a chip wins.
  void _forget(TokenKind kind) {
    for (final t in _parsed.tokens.where((t) => t.kind == kind)) {
      _ignored.add(t.key);
    }
    _reparse();
  }

  DateTime? get _day => _parsed.date ?? _date;
  TimeOfDay? get _clock => _parsed.hasTime ? TimeOfDay(hour: _parsed.hour!, minute: _parsed.minute ?? 0) : _time;
  String? get _rule => _parsed.recurrence ?? _recurrence;
  int get _prio => _parsed.priority ?? _priority;

  /// The due moment, filling in "today" when a time, repeat or reminder needs one.
  DateTime? _due() {
    var day = _day;
    final now = DateTime.now();
    if (day == null && _rule != null) day = firstOccurrence(now, _rule!);
    if (day == null && (_clock != null || _remind != null)) day = now;
    if (day == null) return null;
    final c = _clock;
    return DateTime(day.year, day.month, day.day, c?.hour ?? 0, c?.minute ?? 0);
  }

  Future<void> _submit() async {
    final title = _parsed.title.trim();
    if (title.isEmpty) return;
    final nav = Navigator.of(context);
    int? cat = _category;
    if (_parsed.category != null) cat = await categoryIdFor(_parsed.category!);
    final due = _due();
    final now = DateTime.now();
    final t = TodosCompanion.insert(
      title: title,
      categoryId: Value(cat),
      due: Value(due),
      hasTime: Value(_clock != null),
      priority: Value(_prio),
      recurrence: Value(_rule),
      remindBefore: Value(due == null ? null : _remind),
      sort: Value(now.millisecondsSinceEpoch ~/ 1000),
      createdAt: now,
      horizon: Value(_horizon),
    );
    await addTodo(t);
    Haptic.light();
    nav.pop(kHorizonNames[sectionFor(due, _horizon, now)]);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _day ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (d == null) return;
    _forget(TokenKind.date);
    setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _clock ?? const TimeOfDay(hour: 9, minute: 0));
    if (t == null) return;
    _forget(TokenKind.time);
    setState(() => _time = t);
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    _c.highlight = tc.accentSoft;
    _c.highlightText = tc.dark ? tc.text : Color.lerp(tc.accent, Colors.black, 0.2)!;
    final day = _day;
    final clock = _clock;
    final label = TextStyle(color: tc.muted, fontWeight: FontWeight.w700, fontSize: 12.5);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Nuovo to-do', style: Theme.of(context).textTheme.titleLarge)),
                IconButton(
                  tooltip: 'Chiudi',
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: tc.muted),
                ),
              ],
            ),
            TextField(
              controller: _c,
              autofocus: true,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(hintText: 'Cosa devi fare?'),
            ),
            if (_parsed.tokens.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Ho capito: tocca per annullare', style: label),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in _parsed.tokens)
                    SoftChip(
                      label: _tokenLabel(t, _parsed),
                      icon: Icons.close_rounded,
                      selected: true,
                      onTap: () {
                        _ignored.add(t.key);
                        _reparse();
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Text('Quando', style: label),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < 3; i++)
                  SoftChip(
                    label: _horizonShort[i],
                    icon: _horizonIcons[i],
                    selected: day == null && _rule == null && _horizon == i,
                    onTap: () {
                      _forget(TokenKind.date);
                      _forget(TokenKind.recurrence);
                      setState(() {
                        _horizon = i;
                        _date = null;
                        _recurrence = null;
                      });
                    },
                  ),
                SoftChip(
                  label: day == null ? 'Data' : dueLabel(day, false),
                  icon: Icons.event_rounded,
                  selected: day != null,
                  onTap: _pickDate,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Extra', style: label),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SoftChip(
                  label: clock == null ? 'Ora' : clock.format(context),
                  icon: Icons.schedule_rounded,
                  selected: clock != null,
                  onTap: _pickTime,
                ),
                PopupMenuButton<String>(
                  tooltip: 'Ripeti',
                  onSelected: (v) {
                    _forget(TokenKind.recurrence);
                    setState(() => _recurrence = v.isEmpty ? null : v);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: '', child: Text('Non si ripete')),
                    for (final e in kRecurrenceChoices.entries) PopupMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  child: SoftChip(
                    label: _rule == null ? 'Ripeti' : recurrenceLabel(_rule!),
                    icon: Icons.repeat_rounded,
                    selected: _rule != null,
                  ),
                ),
                PopupMenuButton<int>(
                  tooltip: 'Promemoria',
                  onSelected: (v) => setState(() => _remind = v < 0 ? null : v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: -1, child: Text('Nessun promemoria')),
                    PopupMenuItem(value: 0, child: Text('All\'ora (o alle 9 del giorno)')),
                    PopupMenuItem(value: 15, child: Text('15 minuti prima')),
                    PopupMenuItem(value: 60, child: Text('1 ora prima')),
                  ],
                  child: SoftChip(
                    label: _remind == null ? 'Promemoria' : (_remind == 0 ? 'All\'ora' : '$_remind min prima'),
                    icon: Icons.notifications_rounded,
                    selected: _remind != null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text('Priorità', style: label),
                const SizedBox(width: 10),
                for (var p = 1; p <= 4; p++)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _forget(TokenKind.priority);
                      setState(() => _priority = p);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: AnimatedContainer(
                        duration: Motion.of(context, Motion.fast),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _prio == p
                              ? priorityColor(context, p)
                              : priorityColor(context, p).withValues(alpha: 0.15),
                          border: Border.all(color: priorityColor(context, p), width: 2),
                        ),
                        child: _prio == p ? Icon(Icons.check_rounded, size: 14, color: tc.surface) : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            StreamBuilder<List<TodoCategory>>(
              stream: db.watchTodoCategories(),
              builder: (context, snap) {
                final cats = snap.data ?? const <TodoCategory>[];
                final parsedCat = _parsed.category;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final c in [null, ...cats])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: SoftChip(
                            label: c?.name ?? 'Nessuna categoria',
                            dot: c == null ? null : activityColor(c.color, dark: tc.dark),
                            selected: parsedCat == null
                                ? _category == c?.id
                                : c?.name.toLowerCase() == parsedCat.toLowerCase(),
                            onTap: () {
                              _forget(TokenKind.category);
                              setState(() => _category = c?.id);
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            PillButton(
              label: 'Aggiungi',
              icon: Icons.add_rounded,
              expand: true,
              onTap: _parsed.title.trim().isEmpty ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  String _tokenLabel(ParsedToken t, ParsedTask p) => switch (t.kind) {
    TokenKind.date => p.date == null ? t.text : dueLabel(p.date!, false),
    TokenKind.time =>
      p.hour == null ? t.text : '${p.hour.toString().padLeft(2, '0')}:${(p.minute ?? 0).toString().padLeft(2, '0')}',
    TokenKind.recurrence => recurrenceLabel(p.recurrence ?? ''),
    TokenKind.priority => 'Priorità ${p.priority}',
    TokenKind.category => p.category ?? t.text,
  };
}

// --- Detail ----------------------------------------------------------------------

Future<void> showTodoDetail(BuildContext context, int id) {
  return showSoftSheet<void>(context, builder: (_) => _TodoDetail(id: id));
}

class _TodoDetail extends StatefulWidget {
  const _TodoDetail({required this.id});
  final int id;

  @override
  State<_TodoDetail> createState() => _TodoDetailState();
}

class _TodoDetailState extends State<_TodoDetail> {
  final _sub = TextEditingController();

  @override
  void dispose() {
    _sub.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return StreamBuilder<List<Todo>>(
      stream: db.watchTodos(),
      builder: (context, snap) {
        final all = snap.data ?? const <Todo>[];
        final t = all.where((x) => x.id == widget.id).firstOrNull;
        if (t == null) return const SizedBox(height: 120);
        final subs = all.where((x) => x.parentId == t.id).toList();
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              TextFormField(
                key: ValueKey('title${t.id}'),
                initialValue: t.title,
                style: Theme.of(context).textTheme.titleLarge,
                decoration: const InputDecoration(filled: false, border: InputBorder.none, hintText: 'Titolo'),
                onChanged: (v) {
                  if (v.trim().isNotEmpty) updateTodo(t.id, TodosCompanion(title: Value(v.trim())));
                },
              ),
              TextFormField(
                key: ValueKey('notes${t.id}'),
                initialValue: t.notes,
                maxLines: null,
                decoration: const InputDecoration(hintText: 'Note'),
                onChanged: (v) => updateTodo(t.id, TodosCompanion(notes: Value(v))),
              ),
              const SizedBox(height: 14),
              if (t.due == null) ...[
                Text(
                  'Quando',
                  style: TextStyle(color: tc.muted, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (var i = 0; i < 3; i++)
                      SoftChip(
                        label: _horizonShort[i],
                        icon: _horizonIcons[i],
                        selected: t.horizon == i,
                        onTap: () => updateTodo(t.id, TodosCompanion(horizon: Value(i))),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              _Field(
                icon: Icons.event_rounded,
                label: 'Scadenza',
                value: t.due == null ? 'Nessuna' : dueLabel(t.due!, t.hasTime),
                onTap: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(
                    context: context,
                    initialDate: t.due ?? now,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 5),
                  );
                  if (d == null || !context.mounted) return;
                  final time = await showTimePicker(
                    context: context,
                    initialTime: t.hasTime ? TimeOfDay.fromDateTime(t.due!) : const TimeOfDay(hour: 9, minute: 0),
                    helpText: 'Orario (Annulla = senza orario)',
                  );
                  await updateTodo(
                    t.id,
                    TodosCompanion(
                      due: Value(DateTime(d.year, d.month, d.day, time?.hour ?? 0, time?.minute ?? 0)),
                      hasTime: Value(time != null),
                    ),
                  );
                },
                onClear: t.due == null
                    ? null
                    : () => updateTodo(
                        t.id,
                        TodosCompanion(
                          due: const Value(null),
                          hasTime: const Value(false),
                          remindBefore: const Value(null),
                          recurrence: const Value(null),
                          horizon: Value(sectionOf(t, DateTime.now())),
                        ),
                      ),
              ),
              _Field(
                icon: Icons.flag_rounded,
                label: 'Priorità',
                iconColor: priorityColor(context, t.priority),
                value: t.priority == 4 ? 'Nessuna' : 'Priorità ${t.priority}',
                onTap: () => updateTodo(t.id, TodosCompanion(priority: Value((t.priority % 4) + 1))),
              ),
              StreamBuilder<List<TodoCategory>>(
                stream: db.watchTodoCategories(),
                builder: (context, cSnap) {
                  final cats = cSnap.data ?? const <TodoCategory>[];
                  final cur = cats.where((c) => c.id == t.categoryId).firstOrNull;
                  return PopupMenuButton<int>(
                    onSelected: (v) => updateTodo(t.id, TodosCompanion(categoryId: Value(v == -1 ? null : v))),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: -1, child: Text('Nessuna')),
                      for (final c in cats) PopupMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    child: _Field(icon: Icons.label_rounded, label: 'Categoria', value: cur?.name ?? 'Nessuna'),
                  );
                },
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  final rule = v == '' ? null : v;
                  updateTodo(
                    t.id,
                    TodosCompanion(
                      recurrence: Value(rule),
                      // A repeat needs a first day.
                      due: rule != null && t.due == null
                          ? Value(firstOccurrence(DateTime.now(), rule))
                          : const Value.absent(),
                    ),
                  );
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: '', child: Text('Non si ripete')),
                  for (final e in kRecurrenceChoices.entries) PopupMenuItem(value: e.key, child: Text(e.value)),
                  if (t.due != null)
                    PopupMenuItem(
                      value: 'weekly:${t.due!.weekday}',
                      child: Text(recurrenceLabel('weekly:${t.due!.weekday}')),
                    ),
                ],
                child: _Field(
                  icon: Icons.repeat_rounded,
                  label: 'Ripeti',
                  value: t.recurrence == null ? 'Non si ripete' : recurrenceLabel(t.recurrence!),
                ),
              ),
              PopupMenuButton<int>(
                enabled: t.due != null,
                onSelected: (v) => updateTodo(t.id, TodosCompanion(remindBefore: Value(v < 0 ? null : v))),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: -1, child: Text('Nessun promemoria')),
                  PopupMenuItem(value: 0, child: Text('All\'orario di scadenza')),
                  PopupMenuItem(value: 5, child: Text('5 minuti prima')),
                  PopupMenuItem(value: 15, child: Text('15 minuti prima')),
                  PopupMenuItem(value: 30, child: Text('30 minuti prima')),
                  PopupMenuItem(value: 60, child: Text('1 ora prima')),
                ],
                child: _Field(
                  icon: Icons.notifications_rounded,
                  label: 'Promemoria',
                  value: t.due == null
                      ? 'Serve una scadenza'
                      : t.remindBefore == null
                      ? 'Nessuno'
                      : !t.hasTime
                      ? 'Alle 9:00 del giorno'
                      : t.remindBefore == 0
                      ? 'All\'orario'
                      : '${t.remindBefore} min prima',
                ),
              ),
              const SizedBox(height: 18),
              Text('Sottotask', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final s in subs)
                Row(
                  children: [
                    Checkbox(
                      value: s.completedAt != null,
                      shape: const CircleBorder(),
                      onChanged: (v) =>
                          updateTodo(s.id, TodosCompanion(completedAt: Value(v == true ? DateTime.now() : null))),
                    ),
                    Expanded(
                      child: Text(
                        s.title,
                        style: TextStyle(
                          decoration: s.completedAt != null ? TextDecoration.lineThrough : null,
                          color: s.completedAt != null ? tc.muted : tc.text,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 18, color: tc.muted),
                      onPressed: () => (db.delete(db.todos)..where((x) => x.id.equals(s.id))).go(),
                    ),
                  ],
                ),
              TextField(
                controller: _sub,
                decoration: const InputDecoration(
                  hintText: 'Aggiungi un sottotask',
                  prefixIcon: Icon(Icons.add_rounded),
                ),
                onSubmitted: (v) async {
                  if (v.trim().isEmpty) return;
                  await db
                      .into(db.todos)
                      .insert(
                        TodosCompanion.insert(
                          parentId: Value(t.id),
                          title: v.trim(),
                          createdAt: DateTime.now(),
                          sort: Value(subs.length),
                        ),
                      );
                  _sub.clear();
                },
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: PillButton(
                      label: 'Avvia focus',
                      icon: Icons.spa_rounded,
                      expand: true,
                      onTap: () async {
                        final nav = Navigator.of(context);
                        final prefs = await db.allPrefs();
                        final acts = await db.watchActivities().first;
                        if (acts.isEmpty) return;
                        final last = int.tryParse(prefs['lastActivityId'] ?? '');
                        final act = acts.where((a) => a.id == last).firstOrNull ?? acts.first;
                        await tracker.start(act.id, note: t.title);
                        nav.pop();
                        shellTab.value = 0;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  PillButton(
                    label: 'Elimina',
                    icon: Icons.delete_outline_rounded,
                    kind: PillKind.ghost,
                    color: tc.danger,
                    onTap: () async {
                      final nav = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      final undo = await deleteTodo(t);
                      nav.pop();
                      showUndo(messenger, 'Eliminato', undo);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.onClear,
    this.iconColor,
  });

  final IconData icon;
  final String label, value;
  final VoidCallback? onTap, onClear;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor ?? tc.muted),
          const SizedBox(width: 14),
          Text(
            label,
            style: TextStyle(color: tc.muted, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.close_rounded, size: 18, color: tc.muted),
              ),
            ),
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: row);
  }
}

// --- Categories ------------------------------------------------------------------

class _CategoryManager extends StatelessWidget {
  const _CategoryManager();

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: StreamBuilder<List<TodoCategory>>(
          stream: db.watchTodoCategories(),
          builder: (context, snap) {
            final cats = snap.data ?? const <TodoCategory>[];
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Categorie', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                for (final c in cats)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: GestureDetector(
                      onTap: () {
                        final i = activitySwatches.indexOf(c.color);
                        final next = activitySwatches[(i + 3) % activitySwatches.length];
                        (db.update(
                          db.todoCategories,
                        )..where((x) => x.id.equals(c.id))).write(TodoCategoriesCompanion(color: Value(next)));
                      },
                      child: _Dot(color: activityColor(c.color, dark: tc.dark), size: 22),
                    ),
                    title: Text(c.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, size: 20),
                          onPressed: () => _rename(context, c),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline_rounded, size: 20, color: tc.danger),
                          onPressed: () async {
                            final ok = await confirm(
                              context,
                              title: 'Eliminare "${c.name}"?',
                              message: 'I to-do restano, senza categoria.',
                              action: 'Elimina',
                              danger: true,
                            );
                            if (ok) await (db.delete(db.todoCategories)..where((x) => x.id.equals(c.id))).go();
                          },
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Text('Tocca il pallino per cambiare colore.', style: TextStyle(color: tc.muted, fontSize: 12.5)),
                const SizedBox(height: 12),
                PillButton(
                  label: 'Nuova categoria',
                  icon: Icons.add_rounded,
                  kind: PillKind.soft,
                  onTap: () => _rename(context, null),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, TodoCategory? c) async {
    final ctrl = TextEditingController(text: c?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(c == null ? 'Nuova categoria' : 'Rinomina'),
        content: TextField(controller: ctrl, autofocus: true, textCapitalization: TextCapitalization.sentences),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Salva')),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty) return;
    if (c == null) {
      await categoryIdFor(name);
    } else {
      await (db.update(
        db.todoCategories,
      )..where((x) => x.id.equals(c.id))).write(TodoCategoriesCompanion(name: Value(name)));
    }
  }
}
