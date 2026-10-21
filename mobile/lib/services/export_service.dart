import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/content.dart';
import '../logic/logic.dart';
import '../state/app_state.dart';

/// Saved-words export (CSV) — mirrors src/lib/export.ts.
String _cell(String v) => RegExp(r'[",\n\r]').hasMatch(v) ? '"${v.replaceAll('"', '""')}"' : v;

String wordsCsv(Iterable<SavedWord> words, Content? content) {
  final rows = <List<String>>[
    ['word', 'reading', 'romaji', 'meaning', 'sentence', 'translation', 'status', 'saved'],
  ];
  for (final w in words) {
    if (w.status == 'removed') continue;
    final clip = content?.byId[w.clipId];
    final line = clip != null && w.line < clip.lines.length ? clip.lines[w.line] : null;
    final st = w.status == 'ignored' ? 'ignored' : wordStatus(status: w.status, card: w.card);
    final saved = DateTime.fromMillisecondsSinceEpoch(w.addedAt, isUtc: true).toIso8601String().substring(0, 10);
    rows.add([w.word, w.reading, w.romaji, w.gloss, line?.ja ?? '', line?.en ?? '', st, saved]);
  }
  return rows.map((r) => r.map(_cell).join(',')).join('\n');
}

Future<void> shareWordsCsv(Iterable<SavedWord> words, Content? content) async {
  final dir = await getTemporaryDirectory();
  final date = DateTime.now().toIso8601String().substring(0, 10);
  final f = File('${dir.path}/kizuki-words-$date.csv');
  await f.writeAsString('\uFEFF${wordsCsv(words, content)}');
  await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: 'text/csv')], subject: 'My Kizuki words'));
}
