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
import 'parser.dart';
import 'recurrence.dart';
import 'todo_sync.dart';

enum TodoView { oggi, prossimi, tutti }

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
  final diff = d.difference(today).inDays;
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

class TodoPage extends StatefulWidget {
  const TodoPage({super.key, required this.settings});
  final Settings settings;

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  TodoView _view = TodoView.oggi;
  int? _category; // null = all
  bool _showDone = false;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 78),
        child: FloatingActionButton.extended(
          onPressed: () => showQuickAdd(context, categoryId: _category),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nuovo'),
        ),
      ),
      body: PastelBackground(
        child: SafeArea(
          bottom: false,
          child: StreamBuilder<List<TodoCategory>>(
            stream: db.watchTodoCategories(),
            builder: (context, cSnap) {
              final cats = cSnap.data ?? const <TodoCategory>[];
              return StreamBuilder<List<Todo>>(
                stream: db.watchTodos(),
                builder: (context, snap) {
                  final all = snap.data ?? const <Todo>[];
                  return _list(context, tc, all, cats);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, TaimeColors tc, List<Todo> all, List<TodoCategory> cats) {
    final byParent = <int, List<Todo>>{};
    for (final t in all) {
      if (t.parentId != null) byParent.putIfAbsent(t.parentId!, () => []).add(t);
    }
    final catById = {for (final c in cats) c.id: c};
    final top = all.where((t) => t.parentId == null && (_category == null || t.categoryId == _category)).toList();
    final open = top.where((t) => t.completedAt == null).toList();
    final done = top.where((t) => t.completedAt != null).toList()
      ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int byTime(Todo a, Todo b) {
      final c = (a.due ?? DateTime(9999)).compareTo(b.due ?? DateTime(9999));
      return c != 0 ? c : a.priority.compareTo(b.priority);
    }

    final sections = <(String, List<Todo>, bool)>[];
    switch (_view) {
      case TodoView.oggi:
        final overdue = open.where((t) => t.due != null && t.due!.isBefore(today)).toList()..sort(byTime);
        final todays = open
            .where((t) => t.due != null && !t.due!.isBefore(today) && t.due!.isBefore(today.add(const Duration(days: 1))))
            .toList()
          ..sort(byTime);
        if (overdue.isNotEmpty) sections.add(('Scaduti', overdue, true));
        sections.add(('Oggi', todays, false));
      case TodoView.prossimi:
        for (var i = 0; i < 7; i++) {
          final d = DateTime(today.year, today.month, today.day + i);
          final next = DateTime(d.year, d.month, d.day + 1);
          final items = open.where((t) => t.due != null && !t.due!.isBefore(d) && t.due!.isBefore(next)).toList()
            ..sort(byTime);
          if (items.isNotEmpty || i < 2) sections.add((dueLabel(d, false), items, false));
        }
      case TodoView.tutti:
        sections.add(('', open, false));
    }

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
          sliver: SliverList.list(
            children: [
              Row(
                children: [
                  Expanded(child: Text('To-do', style: Theme.of(context).textTheme.headlineMedium)),
                  _CategoryMenu(
                    categories: cats,
                    selected: _category,
                    onChanged: (c) => setState(() => _category = c),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              PillSelector<TodoView>(
                values: TodoView.values,
                labels: const ['Oggi', 'Prossimi 7 giorni', 'Tutti'],
                selected: _view,
                onChanged: (v) => setState(() => _view = v),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        if (_view == TodoView.tutti)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: open.isEmpty
                ? SliverToBoxAdapter(child: _empty(context))
                : SliverReorderableList(
                    itemCount: open.length,
                    onReorderItem: (a, b) => _reorder(open, a, b),
                    proxyDecorator: (child, _, _) => Material(color: Colors.transparent, child: child),
                    itemBuilder: (context, i) => ReorderableDelayedDragStartListener(
                      key: ValueKey(open[i].id),
                      index: i,
                      child: tile(open[i]),
                    ),
                  ),
          )
        else
          for (final (title, items, late) in sections)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.list(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                    child: Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: late ? tc.pause : tc.text,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (items.isNotEmpty)
                          Text('${items.length}', style: TextStyle(color: tc.muted, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  if (items.isEmpty && title == 'Oggi')
                    _empty(context)
                  else if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 6),
                      child: Text('Niente in programma', style: TextStyle(color: tc.muted, fontSize: 13)),
                    ),
                  for (var i = 0; i < items.length; i++) StaggeredIn(index: i, child: tile(items[i])),
                ],
              ),
            ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          sliver: SliverToBoxAdapter(
            child: done.isEmpty
                ? const SizedBox.shrink()
                : TapScale(
                    onTap: () => setState(() => _showDone = !_showDone),
                    child: Row(
                      children: [
                        AnimatedRotation(
                          turns: _showDone ? 0.25 : 0,
                          duration: Motion.of(context, Motion.medium),
                          child: Icon(Icons.chevron_right_rounded, color: tc.muted),
                        ),
                        Text('Completati (${done.length})',
                            style: TextStyle(color: tc.muted, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
          ),
        ),
        if (_showDone)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.list(
              children: [for (final t in done.take(40)) tile(t)],
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 170)),
      ],
    );
  }

  Widget _empty(BuildContext context) => const EmptyState(
    title: 'Tutto fatto',
    subtitle: 'Tocca "Nuovo" e scrivi, per esempio:\n"chiamare Anna domani alle 18 #personale"',
  );

  Future<void> _reorder(List<Todo> list, int from, int to) async {
    final moved = [...list];
    final item = moved.removeAt(from);
    moved.insert(to, item);
    await db.batch((b) {
      for (var i = 0; i < moved.length; i++) {
        b.update(db.todos, TodosCompanion(sort: Value(i)), where: (t) => t.id.equals(moved[i].id));
      }
    });
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
        decoration: BoxDecoration(
          color: tc.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(22),
        ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t.recurrence != null ? 'Fatto! Il prossimo è già in lista' : 'Fatto!'),
        action: SnackBarAction(label: 'Annulla', onPressed: undo),
      ),
    );
  }

  Future<bool> _swipeLeft() async {
    final t = widget.todo;
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showSoftSheet<String>(
      context,
      scrollControlled: false,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.wb_sunny_rounded),
                title: const Text('Rinvia a domani'),
                onTap: () => Navigator.pop(context, 'tomorrow'),
              ),
              ListTile(
                leading: const Icon(Icons.event_rounded),
                title: const Text('Scegli una data'),
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
    final now = DateTime.now();
    Future<void> Function()? undo;
    String? msg;
    if (choice == 'tomorrow') {
      undo = await postponeTodo(t, DateTime(now.year, now.month, now.day + 1));
      msg = 'Rinviato a domani';
    } else if (choice == 'pick') {
      final d = await showDatePicker(
        context: context,
        initialDate: t.due ?? now,
        firstDate: DateTime(now.year - 1),
        lastDate: DateTime(now.year + 5),
      );
      if (d == null) return false;
      undo = await postponeTodo(t, d);
      msg = 'Rinviato a ${DateFormat('d MMM', 'it').format(d)}';
    } else if (choice == 'delete') {
      undo = await deleteTodo(t);
      msg = 'Eliminato';
    }
    if (undo != null) {
      messenger.showSnackBar(SnackBar(content: Text(msg!), action: SnackBarAction(label: 'Annulla', onPressed: undo)));
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final t = widget.todo;
    final done = t.completedAt != null || _checking;
    final pc = priorityColor(context, t.priority);
    final now = DateTime.now();
    final overdue = t.due != null && t.completedAt == null && t.due!.isBefore(DateTime(now.year, now.month, now.day));
    final subsDone = widget.subtasks.where((s) => s.completedAt != null).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey('d${t.id}'),
        direction: t.completedAt == null ? DismissDirection.horizontal : DismissDirection.none,
        confirmDismiss: (dir) async {
          if (dir == DismissDirection.startToEnd) {
            await _toggle();
            return false;
          }
          return _swipeLeft();
        },
        background: _SwipeBg(color: tc.accent, icon: Icons.check_rounded, left: true),
        secondaryBackground: _SwipeBg(color: tc.pause, icon: Icons.schedule_rounded, left: false),
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
                            child: Text(t.notes, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: tc.muted, fontSize: 13)),
                          ),
                        if (t.due != null || widget.category != null || widget.subtasks.isNotEmpty || t.recurrence != null)
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
                                  _Meta(icon: Icons.repeat_rounded, text: recurrenceLabel(t.recurrence!), color: tc.muted),
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
                                      Text(widget.category!.name,
                                          style: TextStyle(color: tc.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
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
        Text(text, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w700)),
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
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(kRadius),
    ),
    child: Icon(icon, color: color),
  );
}

// --- Quick add -------------------------------------------------------------------

/// Colours the parts of the text the parser understood, while typing.
class _HighlightController extends TextEditingController {
  List<ParsedToken> tokens = const [];
  Color highlight = Colors.transparent;
  Color highlightText = Colors.black;

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    if (tokens.isEmpty || text.isEmpty) return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    final spans = <TextSpan>[];
    var i = 0;
    for (final t in tokens) {
      if (t.start < i || t.end > text.length) continue;
      if (t.start > i) spans.add(TextSpan(text: text.substring(i, t.start)));
      spans.add(TextSpan(
        text: text.substring(t.start, t.end),
        style: TextStyle(backgroundColor: highlight, color: highlightText, fontWeight: FontWeight.w800),
      ));
      i = t.end;
    }
    if (i < text.length) spans.add(TextSpan(text: text.substring(i)));
    return TextSpan(style: style, children: spans);
  }
}

Future<void> showQuickAdd(BuildContext context, {int? categoryId}) {
  return showSoftSheet<void>(context, builder: (_) => _QuickAdd(categoryId: categoryId));
}

class _QuickAdd extends StatefulWidget {
  const _QuickAdd({this.categoryId});
  final int? categoryId;

  @override
  State<_QuickAdd> createState() => _QuickAddState();
}

class _QuickAddState extends State<_QuickAdd> {
  final _c = _HighlightController();
  final _focus = FocusNode();
  final Set<String> _ignored = {};
  ParsedTask _parsed = parseTask('', DateTime.now());
  DateTime? _pickedDate;
  int? _pickedPriority;
  int? _pickedCategory;
  int? _remind;
  int _added = 0;

  @override
  void initState() {
    super.initState();
    _pickedCategory = widget.categoryId;
    _c.addListener(_reparse);
  }

  void _reparse() {
    final p = parseTask(_c.text, DateTime.now(), ignored: _ignored);
    _c.tokens = p.tokens;
    setState(() => _parsed = p);
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final p = _parsed;
    if (p.title.isEmpty) return;
    int? cat = _pickedCategory;
    if (p.category != null) cat = await categoryIdFor(p.category!);
    final due = p.due ?? _pickedDate;
    await addTodo(
      TodosCompanion.insert(
        title: p.title,
        categoryId: Value(cat),
        due: Value(due),
        hasTime: Value(p.hasTime),
        priority: Value(p.priority ?? _pickedPriority ?? 4),
        recurrence: Value(p.recurrence),
        remindBefore: Value(due == null ? null : _remind),
        sort: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
        createdAt: DateTime.now(),
      ),
    );
    Haptic.light();
    _ignored.clear();
    _c.clear();
    setState(() {
      _added++;
      _pickedDate = null;
      _pickedPriority = null;
      _remind = null;
    });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    _c.highlight = tc.accentSoft;
    _c.highlightText = tc.dark ? tc.text : Color.lerp(tc.accent, Colors.black, 0.2)!;
    final p = _parsed;
    final due = p.due ?? _pickedDate;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Nuovo to-do', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                AnimatedSwitcher(
                  duration: Motion.of(context, Motion.medium),
                  child: _added == 0
                      ? const SizedBox.shrink()
                      : Text('$_added aggiunti', key: ValueKey(_added),
                          style: TextStyle(color: tc.accent, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _c,
              focusNode: _focus,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'es. studiare fisica domani alle 15 #studio !1',
                suffixIcon: IconButton(
                  onPressed: _submit,
                  icon: Icon(Icons.arrow_upward_rounded, color: tc.accent),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // What was understood; tap to undo a recognition.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in p.tokens)
                  InputChip(
                    label: Text(_tokenLabel(t, p)),
                    avatar: Icon(_tokenIcon(t.kind), size: 16),
                    onDeleted: () {
                      _ignored.add(t.key);
                      _reparse();
                    },
                    deleteIcon: const Icon(Icons.close_rounded, size: 16),
                    shape: const StadiumBorder(),
                  ),
              ],
            ),
            if (p.tokens.isNotEmpty) const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _QuickChip(
                    icon: Icons.event_rounded,
                    label: due == null ? 'Data' : dueLabel(due, p.hasTime),
                    active: due != null,
                    onTap: () async {
                      final now = DateTime.now();
                      final d = await showDatePicker(
                        context: context,
                        initialDate: due ?? now,
                        firstDate: DateTime(now.year - 1),
                        lastDate: DateTime(now.year + 5),
                      );
                      if (d != null) setState(() => _pickedDate = d);
                    },
                  ),
                  _QuickChip(
                    icon: Icons.flag_rounded,
                    label: 'Priorità ${p.priority ?? _pickedPriority ?? 4}',
                    active: (p.priority ?? _pickedPriority ?? 4) < 4,
                    color: priorityColor(context, p.priority ?? _pickedPriority ?? 4),
                    onTap: () => setState(() => _pickedPriority = ((_pickedPriority ?? 4) % 4) + 1),
                  ),
                  StreamBuilder<List<TodoCategory>>(
                    stream: db.watchTodoCategories(),
                    builder: (context, snap) {
                      final cats = snap.data ?? const <TodoCategory>[];
                      final cur = cats.where((c) => c.id == _pickedCategory).firstOrNull;
                      return PopupMenuButton<int>(
                        onSelected: (v) => setState(() => _pickedCategory = v == -1 ? null : v),
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: -1, child: Text('Nessuna categoria')),
                          for (final c in cats) PopupMenuItem(value: c.id, child: Text(c.name)),
                        ],
                        child: _QuickChip(
                          icon: Icons.label_rounded,
                          label: p.category ?? cur?.name ?? 'Categoria',
                          active: p.category != null || cur != null,
                        ),
                      );
                    },
                  ),
                  _QuickChip(
                    icon: Icons.notifications_rounded,
                    label: _remind == null ? 'Promemoria' : (_remind == 0 ? 'All\'ora' : '$_remind min prima'),
                    active: _remind != null,
                    onTap: () => setState(() {
                      const cycle = [null, 0, 15, 60];
                      _remind = cycle[(cycle.indexOf(_remind) + 1) % cycle.length];
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _tokenLabel(ParsedToken t, ParsedTask p) => switch (t.kind) {
    TokenKind.date => p.date == null ? t.text : dueLabel(p.date!, false),
    TokenKind.time => p.hour == null ? t.text : '${p.hour.toString().padLeft(2, '0')}:${(p.minute ?? 0).toString().padLeft(2, '0')}',
    TokenKind.recurrence => recurrenceLabel(p.recurrence ?? ''),
    TokenKind.priority => 'Priorità ${p.priority}',
    TokenKind.category => p.category ?? t.text,
  };

  IconData _tokenIcon(TokenKind k) => switch (k) {
    TokenKind.date => Icons.event_rounded,
    TokenKind.time => Icons.schedule_rounded,
    TokenKind.recurrence => Icons.repeat_rounded,
    TokenKind.priority => Icons.flag_rounded,
    TokenKind.category => Icons.label_rounded,
  };
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.icon, required this.label, this.onTap, this.active = false, this.color});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final c = color ?? (active ? tc.accent : tc.muted);
    final chip = AnimatedContainer(
      duration: Motion.of(context, Motion.fast),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? tc.accentSoft : tc.raised,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: active ? tc.text : tc.muted)),
        ],
      ),
    );
    return onTap == null ? chip : TapScale(onTap: onTap!, child: chip);
  }
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
                    : () => updateTodo(t.id, const TodosCompanion(due: Value(null), hasTime: Value(false))),
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
                onSelected: (v) => updateTodo(t.id, TodosCompanion(recurrence: Value(v == '' ? null : v))),
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
                      onChanged: (v) => updateTodo(
                        s.id,
                        TodosCompanion(completedAt: Value(v == true ? DateTime.now() : null)),
                      ),
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
                decoration: const InputDecoration(hintText: 'Aggiungi un sottotask', prefixIcon: Icon(Icons.add_rounded)),
                onSubmitted: (v) async {
                  if (v.trim().isEmpty) return;
                  await db.into(db.todos).insert(
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
                      messenger.showSnackBar(
                        SnackBar(content: const Text('Eliminato'), action: SnackBarAction(label: 'Annulla', onPressed: undo)),
                      );
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
          Text(label, style: TextStyle(color: tc.muted, fontWeight: FontWeight.w600)),
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
                        (db.update(db.todoCategories)..where((x) => x.id.equals(c.id)))
                            .write(TodoCategoriesCompanion(color: Value(next)));
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
      await (db.update(db.todoCategories)..where((x) => x.id.equals(c.id))).write(TodoCategoriesCompanion(name: Value(name)));
    }
  }
}
