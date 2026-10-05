import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:taime_native/taime_native.dart';

import 'app.dart';

/// "Cerca aggiornamenti": the latest GitHub release, downloaded and handed to
/// Android's installer. The only time Taime goes online; nothing is sent.
const _latest = 'https://api.github.com/repos/MegumiSharp/taime/releases/latest';

typedef Release = ({String version, String notes, String url, int size});

/// True when [a] (e.g. "2.4.10") is a later version than [b].
bool isNewer(String a, String b) {
  List<int> parts(String v) => [for (final p in v.replaceFirst('v', '').split('.')) int.tryParse(p) ?? 0];
  final x = parts(a), y = parts(b);
  for (var i = 0; i < 3; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d > 0;
  }
  return false;
}

/// The release's APK for this phone ([abi] "arm64" or "arm32"), or null.
Release? releaseFrom(Map<String, dynamic> json, String abi) {
  for (final a in (json['assets'] as List).cast<Map<String, dynamic>>()) {
    if ((a['name'] as String).endsWith('-$abi.apk')) {
      return (
        version: (json['tag_name'] as String).replaceFirst('v', ''),
        // Only the bullet points: the install hints are for the web page.
        notes: (json['body'] as String? ?? '')
            .split('\n')
            .where((l) => l.startsWith('- '))
            .join('\n')
            .replaceAll('**', '')
            .replaceAll('`', ''),
        url: a['browser_download_url'] as String,
        size: a['size'] as int,
      );
    }
  }
  return null;
}

Future<File> _apk() async => File('${(await getTemporaryDirectory()).path}/updates/Taime.apk');

/// The newer release, or null when this is already the latest.
Future<Release?> checkUpdate() async {
  final http = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final res = await (await http.getUrl(Uri.parse(_latest))).close();
    if (res.statusCode != 200) throw HttpException('GitHub ${res.statusCode}');
    final json = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
    final r = releaseFrom(json, await TaimeSystem.abi());
    if (r != null && isNewer(r.version, kAppVersion)) return r;
    // Up to date: the APK of the last update is not needed any more.
    final old = await _apk();
    if (await old.exists()) await old.delete();
    return null;
  } finally {
    http.close();
  }
}

/// Downloads [r] (reusing a complete earlier download) and opens the
/// installer. False when Android first needs "Installa app sconosciute".
Future<bool> installUpdate(Release r, void Function(double) onProgress) async {
  final file = await _apk();
  if (!await file.exists() || await file.length() != r.size) {
    await file.parent.create(recursive: true);
    final http = HttpClient();
    try {
      final res = await (await http.getUrl(Uri.parse(r.url))).close();
      if (res.statusCode != 200) throw HttpException('GitHub ${res.statusCode}');
      final sink = file.openWrite();
      var got = 0;
      await for (final chunk in res) {
        sink.add(chunk);
        got += chunk.length;
        onProgress(got / r.size);
      }
      await sink.close();
    } finally {
      http.close();
    }
  }
  return TaimeSystem.installApk(file.path);
}

Future<void> showUpdate(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _UpdateDialog());

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog();

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _checking = true;
  Release? _release;
  double? _progress;
  String? _message;

  @override
  void initState() {
    super.initState();
    checkUpdate()
        .then((r) => _release = r)
        .catchError((_) {
          _message = 'Non riesco a raggiungere GitHub. Controlla la connessione e riprova.';
          return null;
        })
        .whenComplete(() => mounted ? setState(() => _checking = false) : null);
  }

  Future<void> _install() async {
    setState(() {
      _progress = 0;
      _message = null;
    });
    try {
      final started = await installUpdate(_release!, (p) => mounted ? setState(() => _progress = p) : null);
      _message = started
          ? null
          : 'Permetti a Taime di installare app (si è aperta l\'impostazione), poi torna qui e tocca di nuovo Aggiorna.';
    } catch (_) {
      _message = 'Download interrotto. Controlla la connessione e riprova.';
    }
    if (mounted) setState(() => _progress = null);
  }

  @override
  Widget build(BuildContext context) {
    final r = _release;
    return AlertDialog(
      title: Text(r == null ? 'Aggiornamenti' : 'Taime ${r.version}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_checking)
              const Row(
                children: [
                  SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
                  SizedBox(width: 14),
                  Text('Cerco aggiornamenti…'),
                ],
              )
            else if (r == null && _message == null)
              const Text('Hai già l\'ultima versione ($kAppVersion).')
            else if (r != null) ...[
              Text('È disponibile una nuova versione (hai la $kAppVersion).'),
              if (r.notes.isNotEmpty) ...[const SizedBox(height: 12), Text(r.notes)],
            ],
            if (_progress != null) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 6),
              Text('Scarico… ${(_progress! * 100).round()}%'),
            ],
            if (_message != null) ...[const SizedBox(height: 12), Text(_message!)],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Chiudi')),
        if (r != null) FilledButton(onPressed: _progress == null ? _install : null, child: const Text('Aggiorna')),
      ],
    );
  }
}
