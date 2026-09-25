import 'package:flutter/material.dart';

import '../theme.dart';
import 'motion.dart';

/// Rounded surface with a whisper of shadow instead of a hard border.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color,
    this.radius = kRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final card = AnimatedContainer(
      duration: Motion.of(context, Motion.medium),
      curve: Motion.curve,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? tc.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: tc.text.withValues(alpha: tc.dark ? 0.18 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return TapScale(onTap: onTap!, child: card);
  }
}

/// Shrinks a touch while pressed: the "soft button" feel everywhere.
class TapScale extends StatefulWidget {
  const TapScale({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.scale = 0.96,
  });

  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double scale;

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Motion.of(context, Motion.fast),
        curve: Motion.curve,
        child: widget.child,
      ),
    );
  }
}

enum PillKind { primary, soft, surface, ghost }

class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.kind = PillKind.primary,
    this.color,
    this.expand = false,
    this.big = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final PillKind kind;

  /// Overrides the accent (the pause uses orange).
  final Color? color;
  final bool expand;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final accent = color ?? tc.accent;
    final (bg, fg) = switch (kind) {
      PillKind.primary => (accent, Color.lerp(accent, Colors.white, 0)!),
      PillKind.soft => (
        Color.lerp(accent, tc.surface, tc.dark ? 0.72 : 0.8)!,
        tc.dark ? Color.lerp(accent, Colors.white, 0.35)! : Color.lerp(accent, Colors.black, 0.25)!,
      ),
      PillKind.surface => (tc.surface, tc.dark ? accent : Color.lerp(accent, Colors.black, 0.15)!),
      PillKind.ghost => (Colors.transparent, tc.muted),
    };
    final onBg = kind == PillKind.primary ? _onColor(bg) : fg;
    final disabled = onTap == null;

    final content = AnimatedContainer(
      duration: Motion.of(context, Motion.medium),
      curve: Motion.curve,
      height: big ? 58 : 48,
      padding: EdgeInsets.symmetric(horizontal: big ? 28 : 20),
      decoration: BoxDecoration(
        color: disabled ? tc.raised : bg,
        borderRadius: BorderRadius.circular(40),
        boxShadow: kind == PillKind.surface || kind == PillKind.primary
            ? [
                BoxShadow(
                  color: tc.text.withValues(alpha: tc.dark ? 0.2 : 0.07),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: big ? 22 : 20, color: disabled ? tc.muted : onBg),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize: big ? 17 : 15,
                color: disabled ? tc.muted : onBg,
              ),
            ),
          ),
        ],
      ),
    );
    if (disabled) return content;
    return TapScale(
      onTap: () {
        Haptic.light();
        onTap!();
      },
      child: content,
    );
  }

  static Color _onColor(Color bg) =>
      bg.computeLuminance() > 0.45 ? const Color(0xFF26231F) : Colors.white;
}

/// Segmented pill control with a sliding thumb (Giorno / Settimana / ...).
class PillSelector<T> extends StatelessWidget {
  const PillSelector({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.color,
  });

  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    final index = values.indexOf(selected).clamp(0, values.length - 1);
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tc.dark ? tc.raised : tc.raised.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(40),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth / values.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: Motion.of(context, Motion.medium),
                curve: Motion.emphasized,
                left: w * index,
                top: 0,
                bottom: 0,
                width: w,
                child: Container(
                  decoration: BoxDecoration(
                    color: tc.surface,
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: tc.text.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < values.length; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (i != index) Haptic.select();
                          onChanged(values[i]);
                        },
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: Motion.of(context, Motion.fast),
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 13.5,
                              fontWeight: i == index
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: i == index
                                  ? (color ?? tc.text)
                                  : tc.muted,
                            ),
                            child: Text(labels[i], maxLines: 1),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Integer that rolls to its new value.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount(this.value, {super.key, this.style, this.format});

  final int value;
  final TextStyle? style;
  final String Function(int)? format;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: Motion.of(context, Motion.slower),
      curve: Motion.curve,
      builder: (context, v, _) {
        final n = v.round();
        return Text(format?.call(n) ?? '$n', style: style);
      },
    );
  }
}

/// Fades and lifts a list item in, a little later for each index.
class StaggeredIn extends StatelessWidget {
  const StaggeredIn({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return child;
    final delay = (index.clamp(0, 10)) * 45;
    final total = delay + 380;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Motion.curve),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 14), child: child),
      ),
      child: child,
    );
  }
}

/// The pastel page background; slides to warm orange when [paused].
class PastelBackground extends StatelessWidget {
  const PastelBackground({super.key, required this.child, this.paused = false});

  final Widget child;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: paused ? 1 : 0),
      duration: Motion.of(context, Motion.slower),
      curve: Motion.curve,
      builder: (context, t, child) {
        final top = Color.lerp(tc.bgTop, tc.pauseBgTop, t)!;
        final bottom = Color.lerp(tc.bgBottom, tc.pauseBgBottom, t)!;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [top, bottom],
            ),
          ),
          child: child,
        );
      },
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.titleMedium),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Bottom sheet with the app's shape and safe insets.
Future<T?> showSoftSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool scrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: scrollControlled,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: builder(context),
    ),
  );
}

/// A soft confirmation dialog.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  bool danger = false,
}) async {
  final tc = context.tc;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: TextButton.styleFrom(foregroundColor: tc.muted),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: danger
              ? FilledButton.styleFrom(backgroundColor: tc.danger)
              : null,
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.art,
  });

  final String title;
  final String? subtitle;
  final Widget? art;

  @override
  Widget build(BuildContext context) {
    final tc = context.tc;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?art,
          if (art != null) const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(color: tc.muted, fontSize: 13.5, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

/// Short message with "Annulla" that goes away by itself after a few seconds
/// (with an action, Flutter would otherwise keep it on screen until tapped).
void showUndo(ScaffoldMessengerState messenger, String message, Future<void> Function() undo) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        persist: false,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(label: 'Annulla', onPressed: undo),
      ),
    );
}
