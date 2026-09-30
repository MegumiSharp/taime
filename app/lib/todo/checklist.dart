import 'package:flutter/services.dart';

/// Checklists inside a note are plain lines that start with a box, so they
/// read fine anywhere (backup, share, another app).
const String kBox = '☐ ';
const String kTicked = '☑ ';

bool isCheckLine(String line) => line.startsWith(kBox) || line.startsWith(kTicked);

bool isTicked(String line) => line.startsWith(kTicked);

/// The line without its box.
String checkText(String line) => isCheckLine(line) ? line.substring(kBox.length) : line;

/// Ticks or unticks the [index]-th line of [body].
String toggleLine(String body, int index) {
  final lines = body.split('\n');
  if (index < 0 || index >= lines.length || !isCheckLine(lines[index])) return body;
  final l = lines[index];
  lines[index] = (isTicked(l) ? kBox : kTicked) + checkText(l);
  return lines.join('\n');
}

/// Adds or removes the box on the line under the cursor.
TextEditingValue toggleBoxAtCursor(TextEditingValue v) {
  final text = v.text;
  final cursor = v.selection.isValid ? v.selection.baseOffset.clamp(0, text.length) : text.length;
  final start = text.lastIndexOf('\n', cursor - 1) + 1;
  final line = text.substring(start);
  if (isCheckLine(line)) {
    return TextEditingValue(
      text: text.replaceRange(start, start + kBox.length, ''),
      selection: TextSelection.collapsed(offset: (cursor - kBox.length).clamp(start, text.length)),
    );
  }
  return TextEditingValue(
    text: text.replaceRange(start, start, kBox),
    selection: TextSelection.collapsed(offset: cursor + kBox.length),
  );
}

/// Enter after a checklist line starts a new item; Enter on an empty item
/// ends the list.
class ChecklistFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue now) {
    final at = now.selection.baseOffset;
    final typedNewline = now.text.length == old.text.length + 1 && at > 0 && now.text[at - 1] == '\n';
    if (!typedNewline) return now;
    final lineStart = now.text.lastIndexOf('\n', at - 2) + 1;
    final previous = now.text.substring(lineStart, at - 1);
    if (!isCheckLine(previous)) return now;
    if (checkText(previous).trim().isEmpty) {
      // An empty item: drop it and the new line, the list is over.
      return TextEditingValue(
        text: now.text.replaceRange(lineStart, at, ''),
        selection: TextSelection.collapsed(offset: lineStart),
      );
    }
    return TextEditingValue(
      text: now.text.replaceRange(at, at, kBox),
      selection: TextSelection.collapsed(offset: at + kBox.length),
    );
  }
}
